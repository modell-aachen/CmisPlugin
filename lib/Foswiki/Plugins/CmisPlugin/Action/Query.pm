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

package Foswiki::Plugins::CmisPlugin::Action::Query;

=begin TML

---+ package CmisPlugin::Action::Query

This implements action="query" of the %CMIS macro.

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

  my $theHeader = $params->{header};
  my $theFooter = $params->{footer};
  my $theSkip = $params->{skip} || 0;
  my $thePageSize = $params->{pagesize} || -1;
  my $theLimit = $params->{limit};
  my $theQuery = $params->{query};

  $theHeader = '' unless defined $theHeader;
  $theFooter = '' unless defined $theFooter;

  return '' unless defined $theQuery;

  # special case limit=1 forces a pagesize=1 for performance reasons
  $thePageSize = 1 if $theLimit && $theLimit == 1;


  my $result;
  my $error;
  my $feed;
  try {
    $feed = $repo->query($theQuery, maxItems => $thePageSize, skipCount => $theSkip);
  }
  catch WebService::Cmis::ServerException with {
    throw Error::Simple("can't execute query: <literal><pre>$theQuery</pre></literal>\n\n" . shift);
  };

  my $theHideNull = Foswiki::Func::isTrue($params->{hidenull}, 1);

  my $size = $feed->getSize;
  return '' if $theHideNull && !$size;

  $result = $this->{core}->getRenderer->formatAtomFeed($web, $topic, $params, $feed);
  $result = '' unless defined $result;
  return '' if $theHideNull && $result eq '';

  $result = $theHeader . $result . $theFooter;
  $result =~ s/\$count/$feed->getSize/ge;

  return Foswiki::Func::decodeFormatTokens($result);
}

1;
