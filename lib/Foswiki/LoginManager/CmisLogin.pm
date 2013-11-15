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

package Foswiki::LoginManager::CmisLogin;

use strict;
use warnings;
use Error qw(:try);

use WebService::Cmis ();
use WebService::Cmis::ClientException ();
use Foswiki::LoginManager ();
use Foswiki::LoginManager::TemplateLogin ();
our @ISA = ('Foswiki::LoginManager::TemplateLogin');

=begin TML

---+ package CmisLogin

This login manager makes sure the user is logged in to the CMIS repository
simultaneously.

=cut

=begin TML

---++ ClassMethod new ($session, $impl)

Construct the CmisLogin object

=cut

sub new {
  my ($class, $session) = @_;
  my $this = $class->SUPER::new($session);

  $Foswiki::LoginManager::secretSK{CMIS_TICKET} = 1;
  $Foswiki::LoginManager::readOnlySK{CMIS_TICKET} = 1;

  return $this;
}

=begin TML

---++ ObjectMethod login( $query, $session )

=cut

sub login {
  my ($this, $query, $session) = @_;

  my $user = $query->param('username');
  my $password = $query->param('password');

  $this->SUPER::login($query, $session);

  my $ticket;

  if (defined $user && defined $password) {
    #print STDERR "CMIS login\n";

    try {
      my $client= $this->getClient->login(
        user=>$user, 
        password=>$password
      );
        
      $ticket = $client->{ticket};

    } catch WebService::Cmis::ClientException with {
      print STDERR "WARNING: user $user failed to login to cmis repository\n";
    };
  }

  if (defined $ticket) {
    #print STDERR "setting CMIS_TICKET for user $user\n";
    $this->setSessionValue('CMIS_TICKET', $ticket) || 0;
  } else {
    $this->clearSessionValue('CMIS_TICKET');
  }
}

=begin TML

---++ ObjectMethod getClient(  )

our local version used to authenticate

=cut

sub getClient {
  my $this = shift;

  unless ($this->{_cmis}) {

    my $id = $Foswiki::cfg{CmisPlugin}{DefaultConnection};
    my $conn = $Foswiki::cfg{CmisPlugin}{Connections}{$id};

    $this->{_cmis} = WebService::Cmis::getClient(%$conn);
  }

  return $this->{_cmis};
}

=begin TML

---++ ObjectMethod userLoggedIn( $query, $session )

log out from CMIS repo as well

=cut

sub userLoggedIn {
  my ($this, $authUser, $wikiName) = @_;

  if (!defined $authUser || $authUser eq $Foswiki::cfg{DefaultUserLogin}) {
    my $ticket = $this->getSessionValue('CMIS_TICKET');
    if ($ticket) {
      #print STDERR "CMIS logout\n";
      $this->getClient->logout;
      $this->clearSessionValue('CMIS_TICKET');
    }
  }

  return $this->SUPER::userLoggedIn($authUser, $wikiName);
}

=begin TML

---++ ObjectMethod finish()

clean up

=cut

sub finish {
  my $this = shift;

  undef $this->{_cmis};
  $this->SUPER::finish();
}

1;

