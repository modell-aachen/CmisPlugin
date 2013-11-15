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

package Foswiki::Plugins::CmisPlugin::Action::Delete;

=begin TML

---+ package CmisPlugin::Action::Delete

This implements action="delete" of the %CMIS macro.

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

  my $renderer = $this->{core}->getRenderer;

  my $errorFormat = $params->{delete_errorformat};
  $errorFormat = $params->{errorformat} unless defined $errorFormat;
  $errorFormat = '$reason' unless defined $errorFormat;
  $errorFormat = $renderer->formatObj($web, $topic, { %$params, format => $errorFormat, }, $obj);

  my $successFormat = $params->{delete_successformat};
  $successFormat = $params->{successformat} unless defined $successFormat;
  $successFormat = '' unless defined $successFormat;
  $successFormat = $renderer->formatObj($web, $topic, { %$params, format => $successFormat, }, $obj);

  my $error;
  try {
    $obj->delete;
  }
  catch WebService::Cmis::ClientException with {
    $error = shift;
    $error =~ s/ at .*$//;    # bit of cleanup
  };

  if (defined $error) {
    $errorFormat =~ s/\$reason/$error/g;
    return Foswiki::Func::decodeFormatTokens($errorFormat);
  }

  return Foswiki::Func::decodeFormatTokens($successFormat);
}

1;

