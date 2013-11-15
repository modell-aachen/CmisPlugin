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

package Foswiki::Plugins::CmisPlugin::Action::UpdateProperties;

=begin TML

---+ package CmisPlugin::Action::UpdateProperties

This implements action="updateproperties" of the %CMIS macro

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

  # test for method = POST
  my $request = Foswiki::Func::getRequestObject;
  throw Error::Simple("illegal request method") unless $request->method =~ /^post$/i;

  my $repo = $this->{core}->getRepository($params);
  my $obj = $repo->getObject($params->{object});
  throw Error::Simple("no such object") unless defined $obj;

  my $errorFormat = $params->{createfolder_errorformat};
  $errorFormat = $params->{errorformat} unless defined $errorFormat;
  $errorFormat = '$reason' unless defined $errorFormat;

  my $successFormat = $params->{createfolder_successformat};
  $successFormat = $params->{successformat} unless defined $successFormat;
  $successFormat = '' unless defined $successFormat;

  my $renderer = $this->{core}->getRenderer;

  my $name = $params->{name};
  my $summary = $params->{summary};

  my $currentName = $obj->getProperty("cmis:name");
  my $currentSummary = $obj->getSummary;

  my $error;
  if (defined $name && $name ne $currentName) {

    try {
      $obj->rename($name);
    }
    catch WebService::Cmis::ClientException with {
      $error = shift;
      $error =~ s/ at .*$//;    # bit of cleanup
    };

    if (defined $error) {
      $errorFormat =~ s/\$reason/$error/g;
      return Foswiki::Func::decodeFormatTokens($renderer->formatObj($web, $topic, { %$params, format => $errorFormat, }, $obj));
    }
  }

  if (defined $summary && $summary ne $currentSummary) {
    try {
      $obj->updateSummary($summary);
    }
    catch WebService::Cmis::ClientException with {
      $error = shift;
      $error =~ s/ at .*$//;    # bit of cleanup
    };

    if (defined $error) {
      $errorFormat =~ s/\$reason/$error/g;
      return Foswiki::Func::decodeFormatTokens($renderer->formatObj($web, $topic, { %$params, format => $errorFormat, }, $obj));
    }
  }

  return Foswiki::Func::decodeFormatTokens($renderer->formatObj($web, $topic, { %$params, format => $successFormat, }, $obj));
}

1;

