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

package Foswiki::Plugins::CmisPlugin::Action;

=begin TML

---+ package CmisPlugin::Action

This is the base class to implement action endpoints of the %CMIS
macro. Each action parameter will be routed to a subclass of Action.

=cut

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Time ();
use POSIX ();

=begin TML

---++ ClassMethod new($core)

Constructs the Action 

=cut

sub new {
  my $class = shift;
  my $core = shift;

  my $this = { 
    core => $core,
    @_ 
  };

  return bless($this, $class);
}

=begin TML

---++ VirtualMethod doit($web, $topic, $params)

this is the main entry point called from the core to perform the action
implemented.

=cut

sub doIt {
  die "must be implemented in a subclass";
}

1;
