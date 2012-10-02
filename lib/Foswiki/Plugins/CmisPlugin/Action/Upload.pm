# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# CmisPlugin is Copyright (C) 2010-2012 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::CmisPlugin::Action::Upload;

=begin TML

---+ package CmisPlugin::Action::BaseClass

This is the base class implementing a NOP. Use it as a template 
to derive other Actions from it.

=cut

use strict;
use warnings;

use Error qw(:try);
use Foswiki::Func ();
use Foswiki::Plugins ();
use Foswiki::Plugins::CmisPlugin::Action ();
use Foswiki::Contrib::JsonRpcContrib::Error ();
our @ISA = ('Foswiki::Plugins::CmisPlugin::Action');
use constant DRY => 0; # toggle me

=begin TML

---++ ObjectMethod doit($web, $topic, $params) -> $result

endpoint called by the core

=cut

sub doit {
  my ($this, $web, $topic, $params) = @_;

  #my $repo = $this->{core}->getRepository($params);

  return 'todo';
}

=begin TML

---++ ObjectMethod jsonRpcUpload($request) -> $responseObject

backend that takes over the files from the browser and forwards it to the repository 

JSON-RPC Error codes:

   * 100: invalid param
   * 101: stream not found
   * 102: system error
   * 103: zero file 
   * 104: file too large
   * 110: misc

=cut

sub jsonRpcUpload {
  my ($this, $request) = @_;

  print STDERR "called jsonRpcUpload\n";

  my $id = $request->id();
  if (defined $id) {
    $id =~ /^(\d*)$/; 
    $id = $1; # untaint
  }
  throw Foswiki::Contrib::JsonRpcContrib::Error(100, "no id") if !defined $id || $id eq '';

  my $fileName = $request->param('file');
  my $origName;
  throw Foswiki::Contrib::JsonRpcContrib::Error(100, "no file param") unless defined $fileName;
    
  ($fileName, $origName) = Foswiki::Func::sanitizeAttachmentName($fileName);

  _writeDebug("'$origName' has been renamed to '$fileName'")
    unless $fileName eq $origName;
  
  # read additional params
  my $session = $Foswiki::Plugins::SESSION;
  my $cgiRequest = $session->{request};
  my $nrChunks = $request->param('chunks') || 0;
  my $contentType = $cgiRequest->header('content-type') || '';
  my $isMultiPart = ($contentType =~ /multipart/)?1:0;
  my $chunk = $request->param('chunk') || 0;

  my $fileComment = $request->param('filecomment');
  $fileComment = '' unless defined $fileComment;

  my $target = $request->param('target');
  throw Foswiki::Contrib::JsonRpcContrib::Error(100, "no target specified") if !defined $target || $target eq '';

  _writeDebug("receiving file $fileName, chunk $chunk of $nrChunks, id=$id".($isMultiPart?' in multipart mode':' in normal mode'));

  # read application/octet-stream, can't use CGI.pm means
  my $tmpDir = Foswiki::Func::getWorkArea("CmisPlugin");
  my $tmpFileName = $tmpDir.'/'.$fileName.'_part_'.$id;
  my $data = '';

  # read data from request, either from a multipart of streamed request
  if ($isMultiPart) {
    my $stream = $cgiRequest->upload('file');
    throw Foswiki::Contrib::JsonRpcContrib::Error(101, "Stream not found for '$fileName'")
      unless defined $stream;

    my $r;
    my $transfer;
    while ($r = sysread($stream, $transfer, 0x80000)) {
      if (!defined $r) {
        next if ($! == Errno::EINTR);
        throw Foswiki::Contrib::JsonRpcContrib::Error(102, "System read error: $!");
      }
      $data .= $transfer;
    }
  } else {
    $data = $request->param("POSTDATA") || '';
  }

  if (-e $tmpFileName && $chunk <= $nrChunks) {
    _writeDebug("appending to $tmpFileName");
    _appendFile($tmpFileName, $data);
  } else {
    _writeDebug("saving to $tmpFileName");
    Foswiki::Func::saveFile($tmpFileName, $data);
  }

  # end of transaction
  if ($chunk+1 >= $nrChunks) {
    my $newFileName = $tmpFileName;
    $newFileName =~ s/_part_.*?$//;
    rename $tmpFileName, $newFileName 
      if $tmpFileName ne $newFileName;

    _writeDebug("finished uploading $newFileName");

    my @stats = stat $newFileName;
    my $fileSize = $stats[7] || 0;
    my $fileDate = $stats[9] || 0;

    throw Foswiki::Contrib::JsonRpcContrib::Error(103, "Zero-sized file upload of '$fileName'") unless $fileSize;

    # check content length
    my $maxSize = Foswiki::Func::getPreferencesValue('ATTACHFILESIZELIMIT');
    $maxSize = 0 unless ($maxSize =~ /([0-9]+)/o);
    $maxSize =~ s/[^\d]//g;

    _writeDebug("fileSize=$fileSize, maxSize=$maxSize, fileDate=$fileDate, fileComment=$fileComment");

    throw Foswiki::Contrib::JsonRpcContrib::Error(104, "Oversized upload of '$fileName'") 
      if $maxSize && $fileSize > $maxSize * 1024;

    my $error;
    try {
      _writeDebug("uploading $fileName CMIS folder ???");
      unless (DRY) {
        $this->handleUpload(
          name => $fileName,
          comment => $fileComment,
          file => $newFileName,
          target => $target,
        );
      }

    } otherwise {
      $error = shift->{-text};
      _writeDebug("ERROR: $error");
    };

    _writeDebug("removing temp file $newFileName");
    unlink $newFileName if -e $newFileName;

    sleep(1); # sleep for a while to prevent a firing hurdle of events on save handlers in other extensions

    throw Foswiki::Contrib::JsonRpcContrib::Error(110, $error) if $error;
  }

  return {$origName => $fileName};
}

=begin TML

---++ ObjectMethod handleUpload(%params) 

this method will be called once the upload has finished. %params contains

   * name: the name of the file
   * file: the full path to the stream being uploaded
   * comment: an optional comment string
   * target: the target descriptor where the file will be located once the upload finished

=cut

sub handleUpload {
  my $this = shift;
  my %params = @_;

  my $repo = $this->{core}->getRepository;
  my $name = delete $params{name};
  my $file = delete $params{file};
  my $target = delete $params{target};
  my $comment = delete $params{comment} || '';
  $comment =~ s/%([\da-f]{2})/chr(hex($1))/gei;

  my $folder = $repo->getObject($target);

  throw Error::Simple("target folder $target not found") unless defined $folder;
  throw Error::Simple("no file name") unless defined $name;
  throw Error::Simple("no file stream") unless defined $file;

  my $path = $folder->getPath;

  _writeDebug("uploading to folder ".$path);

  my $document = $repo->getObjectByPath($path.'/'.$name);

  if (defined $document) {
    $document = $document->setContentStream(
      contentFile=>$file,
    );
    $document->updateSummary($comment) if $comment;
  } else {
    $params{summary} = $comment;
    $params{contentFile} = $file;
    $document = $folder->createDocument($name, %params);
  }
}

sub _appendFile {
  my ($name, $text) = @_;
  my $FILE;
  unless (open($FILE, '>>', $name)) {
    die "Can't append to $name - $!\n";
  }
  print $FILE $text;
  close($FILE);
}

sub _writeDebug {
  print STDERR "CmisPlugin::Action::Upload - $_[0]\n" if $Foswiki::cfg{CmisPlugin}{Debug};
}

1;
;
