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

package Foswiki::Plugins::CmisPlugin::Action::ObjectById;

=begin TML

---+ package CmisPlugin::Action::ObjectById

This implements action="querybyid" of the %CMIS macro

=cut

use strict;
use warnings;

use Error qw(:try);
use Foswiki::Plugins::CmisPlugin::Action;
our @ISA = ('Foswiki::Plugins::CmisPlugin::Action');

=begin TML

---++ ObjectMethod doit($web, $topic, $params) -> $result

endpoint called by the core

=cut

sub doit {
  my ($this, $web, $topic, $params) = @_;

  my $repo = $this->{core}->getRepository($params);
  my $obj = $repo->getObject($params->{object});
  throw Error::Simple("unknown object") unless defined $obj;

  my $result = $this->{core}->getRenderer->formatObj($web, $topic, $params, $obj);
  $result = '' unless defined $result;

  my $theHideNull = Foswiki::Func::isTrue($params->{hidenull}, 1);
  return '' if $theHideNull && $result eq '';

  my $theHeader = $params->{header};
  my $theFooter = $params->{footer};
  $theHeader = '' unless defined $theHeader;
  $theFooter = '' unless defined $theFooter;
  return Foswiki::Func::decodeFormatTokens($theHeader . $result . $theFooter);
}

1;
