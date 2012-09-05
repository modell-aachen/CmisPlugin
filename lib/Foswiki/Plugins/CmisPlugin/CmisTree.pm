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

package Foswiki::Plugins::CmisPlugin::CmisTree;

=begin TML

---+ package CmisPlugin::CmisTree

This renders %CMISTREE

=cut

use strict;
use warnings;
use Error qw(:try);
use Foswiki::Func ();

sub doit {
  my ($core, $session, $params, $theTopic, $theWeb) = @_;

  my $thePath = $params->{path} || "/";

  my $repo = $core->getRepository($params);
  my $obj = $repo->getObjectByPath($thePath);
  throw Error::Simple("no object at $thePath") unless $obj;

  unless ($obj->isa("WebService::Cmis::Folder")) {
    my $parents = $obj->getObjectParents;
    if ($parents->isa('WebService::Cmis::AtomFeed')) {
      $obj = $parents->getFirst;
    } else {
      $obj = $parents;
    }
  }

  my $theFormat = $params->{format} || '$indent* $name';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theSep = $params->{separator} || "\n";

  my $renderer = $core->getRenderer;

  my $path = $obj->getPath;
  my @path = split(/\//, $path);
  @path = ('') unless @path;    # for the root element

  my @result = ();
  my $depth = 1;
  my $prefix = '';

  foreach my $item (@path) {
    my $line = $theFormat;
    $prefix .= '/' . $item unless $item eq '';
    $line =~ s/\$name/($item||'Root')/ge;
    $line =~ s/\$indent/'   ' x $depth/ge;
    $line =~ s/\$path/($prefix||'\/')/ge;
    push @result, $line;
    $depth++;
  }

  $path = '' if $path eq '/';

  my $children = $obj->getChildren(orderBy=>'cmis:name');
  while (my $child = $children->getNext) {
    my $line = $theFormat;
    next unless $child->isa("WebService::Cmis::Folder");
    my $name = $child->getName;
    $line =~ s/\$name/$name/ge;
    $line =~ s/\$indent/'   ' x $depth/ge;
    $line =~ s/\$path/$path\/$name/g;
    push @result, $line;
  }

  return Foswiki::Func::decodeFormatTokens($theHeader.join($theSep, @result).$theFooter);
}

1;
