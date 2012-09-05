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

package Foswiki::Plugins::CmisPlugin::Action::RepositoryInfo;

=begin TML

---+ package CmisPlugin::Action::RepositoryInfo

This implements action="info" of the %CMIS macro

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

  my $theConnection = $params->{connection};
  my $conn = $this->{core}->getConnection($theConnection);

  my $theRepositoryId = $params->{repository};
  $theRepositoryId = $conn->{repositoryId} unless defined $theRepositoryId;
 
  my $client = $this->{core}->getClient($params);

  # get list of repositories to inform about
  my $repos = ();
  if (defined $theRepositoryId && $theRepositoryId ne '') {
    if ($theRepositoryId =~ /^(default)?$/) {

      # only add the default repo
      my $repo = $client->getRepository;
      $repos->{ $repo->getRepositoryId } = $repo;
    } else {
      $repos->{$theRepositoryId} = $client->getRepository($theRepositoryId);
      return inline("unknown repository $theRepositoryId") unless defined $repos->{$theRepositoryId};
    }
  } else {
    $repos = $client->getRepositories;
  }

  # sort them
  my $theSort = Foswiki::Func::isTrue($params->{sort}, 1);

  my @repos;
  if ($theSort) {
    @repos = sort { lc($a->getRepositoryName) cmp lc($b->getRepositoryName) } values %$repos;
  } else {
    @repos = values %$repos;
  }

  # loop thru all repos and output info
  my $theFormat = $params->{format};
  my $theHeader = $params->{header};
  my $theFooter = $params->{footer};
  my $theSep = $params->{separator};
  $theHeader = '' unless defined $theHeader;
  $theFooter = '' unless defined $theFooter;

  $theFormat = '   * $repositoryName ($repositoryId, $vendorName)' unless defined $theFormat;
  $theSep = '$n' unless defined $theSep;

  my @results = ();
  my $nrRepos = scalar(@repos);
  my $index = 1;
  foreach my $repo (@repos) {

    my $line = $theFormat;
    my $repoInfo = $repo->getRepositoryInfo;

    foreach my $key (keys %$repoInfo) {
      $line =~ s/\$$key/$repoInfo->{$key}/g;
    }

    $line =~ s/\$properties/$this->{core}->getRenderer->formatProperties($web, $topic, $params, $repoInfo)/ge; 
    $line =~ s/\$size/$nrRepos/g;
    $line =~ s/\$index/$index/g;
    $index++;

    push @results, $line;
  }

  my $theHideNull = Foswiki::Func::isTrue($params->{hidenull}, 1);
  return '' if $theHideNull && !@results;
  return Foswiki::Func::decodeFormatTokens($theHeader . join($theSep, @results) . $theFooter);
}

1;
