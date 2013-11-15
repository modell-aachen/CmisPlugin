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

package Foswiki::Plugins::CmisPlugin::Core;

=begin TML

---+ package CmisPlugin::Core

=cut

use strict;
use warnings;

use Encode ();
use Error qw(:try);
use WebService::Cmis ();
use Foswiki::Func ();
use Foswiki::Plugins ();
use Cache::FileCache();

our %classOfAction = (
  'cancelcheckout' => 'Foswiki::Plugins::CmisPlugin::Action::CancelCheckOut',
  'checkout' => 'Foswiki::Plugins::CmisPlugin::Action::CheckOut',
  'createfolder' => 'Foswiki::Plugins::CmisPlugin::Action::CreateFolder',
  'delete' => 'Foswiki::Plugins::CmisPlugin::Action::Delete',
  'info' => 'Foswiki::Plugins::CmisPlugin::Action::RepositoryInfo',
  'objectbyid' => 'Foswiki::Plugins::CmisPlugin::Action::ObjectById',
  'objectbypath' => 'Foswiki::Plugins::CmisPlugin::Action::ObjectByPath',
  'query' => 'Foswiki::Plugins::CmisPlugin::Action::Query',
  'updateproperties' => 'Foswiki::Plugins::CmisPlugin::Action::UpdateProperties',
  'upload' => 'Foswiki::Plugins::CmisPlugin::Action::Upload',
);

=begin TML

---++ ClassMethod new()

Constructs the core of the plugin.

=cut

sub new {
  my $class = shift;

  my $this = { @_ };

  $this->{defaultConnection} = $Foswiki::cfg{CmisPlugin}{DefaultConnection};

  # or get the first connection specified
  unless (defined $this->{DefaultConnection}) {
    my @knownConnections = keys %{ $Foswiki::cfg{CmisPlugin}{Connections} };
    $this->{defaultConnection} = shift @knownConnections if scalar(@knownConnections) == 1;
  }

  return bless($this, $class);
}

=begin TML

---++ ObjectMethod finish()

finalize the core; called at the very end of the request handler

=cut

sub finish {
  my $this = shift;
  foreach my $id (sort keys %{ $this->{_clients} }) {
    my $client = $this->{_clients}{$id};
    _writeDebug("$id had " . ($client->getCacheHits || 0) . " cache hits");
  }
  undef $this->{_clients};
  undef $this->{_handlers};
  undef $this->{_renderer};
}

=begin TML

---++ ObjectMethod handleCMISTREE($session, $params, $theTopic, $theWeb) -> $result

implementation of this macro

=cut

sub handleCMISTREE {
  my ($this, $session, $params, $theTopic, $theWeb) = @_;

  require Foswiki::Plugins::CmisPlugin::CmisTree;

  my $result;
  my $error;

  try {
    $result = Foswiki::Plugins::CmisPlugin::CmisTree::doit($this, $session, $params, $theTopic, $theWeb);
  } catch Error::Simple with {
    $error = shift;
    $error =~ s/ at .*$//;
  };

  return _inlineError($error) if defined $error;

  return $result;
}

=begin TML

---++ ObjectMethod handleCMIS($session, $params, $theTopic, $theWeb) -> $result

implementation of this macro

=cut

sub handleCMIS {
  my ($this, $session, $params, $theTopic, $theWeb) = @_;

  #_writeDebug("called CMIS(".$params->stringify.")");
  my $theAction = $params->{action};
  $this->{_session} = $session;

  return '' if defined $theAction && $theAction eq 'nop'; # shortcut

  # guess action based on given parameters
  unless (defined $theAction) {
    $theAction = 'objectbyid' if defined $params->{object};
    $theAction = 'objectbypath' if defined $params->{path};
    $theAction = 'query' if defined $params->{query};
  }

  my $handler = $this->getHandler($theAction);
  return _inlineError("unknown action '$theAction'") 
    unless defined $handler;

  my $result;
  try {
    $result = $handler->doit($theWeb, $theTopic, $params);
    $result = _fromUtf8($result);
  } otherwise {
    my $error = shift;
    $error =~ s/ at .*$//;
    $result = _inlineError($error);
  };

  return $result;
}

=begin TML

---++ ObjectMethod jsonRpcUpload

=cut

sub jsonRpcUpload {
  my ($this, $request) = @_;

  my $handler = $this->getHandler("upload");
  throw Error::Simple("can't get uploader")
    unless defined $handler;

  return $handler->jsonRpcUpload($request);
}

=begin TML

---++ ObjectMethod getRenderer -> $renderer

returns a renderer to format objects and atom feeds.

=cut

sub getRenderer {
  my $this = shift;

  unless (defined $this->{_renderer}) {
    require Foswiki::Plugins::CmisPlugin::Renderer;
    $this->{_renderer} = Foswiki::Plugins::CmisPlugin::Renderer->new($this);
  }

  return $this->{_renderer};
}

=begin TML

---++ Object getSession -> $session

returns the Foswiki session object for the current request.

=cut

sub getSession {
  my $this = shift;

  return $this->{_session} || $Foswiki::Plugins::SESSION;
}

=begin TML

---++ ObjectMethod getClient($params) -> $client

returns a WebService::Cmis::Client object for the given connection id
as configured in LocalSite.cfg. 

can throw Error::Simple, WebService::Cmis::ServerException or
WebService::Cmis::ClientException

=cut

sub getClient {
  my ($this, $params) = @_;

  my $theConnection = $params->{connection};
  $theConnection = $this->{defaultConnection} unless defined $theConnection;
  my $conn = $this->getConnection($theConnection);

  my $theCache = $params->{cache};
  $theCache = $conn->{cacheExpires} unless defined $theCache;

  my $client = $this->{_clients}{$theConnection};
  unless (defined $client) {
    if ($theCache) {
      my $cacheRoot = Foswiki::Func::getWorkArea("CmisPlugin") . '/' . $theConnection;
      unless (-d $cacheRoot) {
        mkdir $cacheRoot || throw Error::Simple("can't create cache root at $cacheRoot");
      }
      $conn->{cache} = Cache::FileCache->new(
        {
          cache_root => $cacheRoot,
          default_expires_in => $theCache
        }
      );
    }

    $client = WebService::Cmis::getClient(%$conn);

    my $user = Foswiki::Func::getWikiName();
    $user = Foswiki::Func::wikiToUserName($user);

    my $ticket = Foswiki::Func::getSessionValue("CMIS_TICKET");
    $client->login(
      user => $user,
      ticket => $ticket
    ) if defined $ticket;

    my $query = Foswiki::Func::getRequestObject();
    my $refresh = $query->param('refresh') || '';
    $refresh = ($refresh =~ /^(on|cmis)$/) ? 1 : 0;

    $client->clearCache if $refresh;

    $client->get;    # this connection test might throw a WebService::Cmis::ServerException
    $this->{_clients}{$theConnection} = $client;    # cache the object if everything is fine
  }

  return $client;
}

=begin TML

returns the connection descriptor as configured in <nop>LocalSite.cfg

=cut

sub getConnection {
  my ($this, $id) = @_;

  $id = $this->{defaultConnection} unless defined $id;
  throw Error::Simple("no connection specified") unless defined $id;

  my $conn = $Foswiki::cfg{CmisPlugin}{Connections}{$id};
  throw Error::Simple("unknown connection $id") unless defined $conn;

  return $conn;
}

=begin TML

---++ ObjectMethod getRepository($params) -> $repo

returns the the repository to use for this action

=cut

sub getRepository {
  my ($this, $params) = @_;

  my $theRepositoryId = $params->{repository};
  my $connId = $params->{connection};
  my $conn = $this->getConnection($connId);
  $theRepositoryId = $conn->{repositoryId} unless defined $theRepositoryId;

  my $client = $this->getClient($params);
  return $client->getRepository($theRepositoryId);
}


=begin TML

---++ ObjectMethod getHandler($action)

returns a handler for the given action. returns an instance of a
subclass of Foswiki::Plugin::CmisPlugin::Action, or undef when 
the action is unknown

=cut

sub getHandler {
  my ($this, $action) = @_;

  return unless $action;

  unless (defined $this->{_handler}{$action}) {
    my $class = $classOfAction{$action};
    return unless defined $class;

    eval "use $class";
    if ($@) {
      print STDERR "Error: ".$@."\n";
      return;
    }

    $this->{_handler}{$action} = $class->new($this);
  }

  return $this->{_handler}{$action};
}

sub _writeDebug {
  print STDERR "CmisPlugin - $_[0]\n" if $Foswiki::cfg{CmisPlugin}{Debug};
}


sub _inlineError {
  return "<span class='foswikiAlert'>$_[0]</span>";
}

sub _fromUtf8 {
  my $string = shift;

  $string = Encode::decode_utf8($string);
  $string = Encode::encode($Foswiki::cfg{Site}{CharSet}, $string);

  return $string;
}

1;
