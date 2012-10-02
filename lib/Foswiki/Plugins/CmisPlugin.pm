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

package Foswiki::Plugins::CmisPlugin;

use strict;
use warnings;

=begin TML

---+ package CmisPlugin

=cut

use Foswiki::Func ();
use Foswiki::Contrib::JsonRpcContrib ();

our $VERSION = '$Rev: 20121001 (2012-10-01) $';
our $RELEASE = '1.00';
our $SHORTDESCRIPTION = 'CMIS for Foswiki';
our $NO_PREFS_IN_TOPIC = 1;
our $core;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean

=cut

sub initPlugin {

  Foswiki::Func::registerTagHandler('CMIS', sub {
    return getCore()->handleCMIS(@_);
  });

  Foswiki::Func::registerTagHandler('CMISTREE', sub {
    return getCore()->handleCMISTREE(@_);
  });

  Foswiki::Contrib::JsonRpcContrib::registerMethod("CmisPlugin", "upload", sub {
    shift;
    return getCore()->jsonRpcUpload(@_);
  });

  $ENV{CMIS_DEBUG} = 1 if $Foswiki::cfg{CmisPlugin}{Debug} && $Foswiki::cfg{CmisPlugin}{Debug} > 1;

  $core = undef;
  return 1;
}

=begin TML

---++ finishPlugin()

clean up internal objects

=cut

sub finishPlugin {
  if ($core) {
    $core->finish();
    undef $core;
  }
}

=begin TML

---++ getCore()

get the plugin core

=cut

sub getCore {
  unless ($core) {
    require Foswiki::Plugins::CmisPlugin::Core;
    $core = Foswiki::Plugins::CmisPlugin::Core->new();
  }

  return $core;
}

1;
