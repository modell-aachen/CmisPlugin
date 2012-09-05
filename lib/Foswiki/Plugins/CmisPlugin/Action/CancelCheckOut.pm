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

package Foswiki::Plugins::CmisPlugin::Action::CancelCheckOut;

=begin TML

---+ package CmisPlugin::Action::CancelCheckOut

This implements action="cancelcheckout" of the %CMIS macro. It must be called
as part of a POST request.

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
  throw Error::Simple("illegal request method")
    unless $request->method =~ /^post$/i;

  my $repo = $this->{core}->getRepository($params);

  throw Error::Simple("no object specified") unless defined $params->{object};

  my $obj = $repo->getObject($params->{object});
  throw Error::Simple("no such object") unless defined $obj;

  my $errorFormat = $params->{cancelcheckout_errorformat};
  $errorFormat = $params->{errorformat} unless defined $errorFormat;
  $errorFormat = '$reason' unless defined $errorFormat;

  my $success = $params->{cancelcheckout_successformat};
  $success = $params->{successformat} unless defined $success;
  $success = '' unless defined $success;

  my $renderer = $this->{core}->getRenderer;

  unless ($obj->isa('WebService::Cmis::Document')) {
    $errorFormat =~ s/\$reason/not a cmis:document object/g;
    return Foswiki::Func::decodeFormatTokens($renderer->formatObj($web, $topic, { %$params, format => $errorFormat, }, $obj));
  }

  unless ($obj->getProperty("cmis:isVersionSeriesCheckedOut")) {
    $errorFormat =~ s/\$reason/object not checked out/g;
    return Foswiki::Func::decodeFormatTokens($renderer->formatObj($web, $topic, { %$params, format => $errorFormat, }, $obj));
  }

  my $error;
  try {
    $obj->cancelCheckOut;
  }
  catch WebService::Cmis::ClientException with {
    $error = shift;
    $error =~ s/ at .*$//;    # bit of cleanup
  };

  if (defined $error) {
    $errorFormat =~ s/\$reason/$error/g;
    return Foswiki::Func::decodeFormatTokens($renderer->formatObj($web, $topic, { %$params, format => $errorFormat, }, $obj));
  }


  return Foswiki::Func::decodeFormatTokens($renderer->formatObj($web, $topic, { %$params, format => $success, }, $obj));
}

1;
