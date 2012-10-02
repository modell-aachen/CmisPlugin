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

package Foswiki::Plugins::CmisPlugin::Renderer;

=begin TML

---+ package CmisPlugin::Renderer

This is used to format objects and atom feed.

=cut

use strict;
use warnings;

=begin TML

---++ ClassMethod new($core)

Constructs the renderer 

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

---++ ObjectMethod formatProperties($web, $topic, $params, $props) -> $result

formats a list of properties 

=cut

sub formatProperties {
  my ($this, $web, $topic, $params, $props) = @_;

  return '' unless defined $props;

  my @result = ();

  my $theFormat = $params->{propformat};
  $theFormat = '$key=$value' unless defined $theFormat;

  my $theHeader = $params->{propheader};
  my $theFooter = $params->{propfooter};
  my $theSep = $params->{propseparator};
  my $theHideEmpty = Foswiki::Func::isTrue($params->{propshideempty}, 1);
  my $theExclude = $params->{propexclude};
  my $theInclude = $params->{propinclude};

  $theSep = '' unless defined $theSep;
  $theHeader = '' unless defined $theHeader;
  $theFooter = '' unless defined $theFooter;

  my %keys = map {
    my $key = $_; 
    $key =~ s/^(.*:)?(.+?)$/$2/; 
    $_ => $key
  } keys %$props;

  foreach my $key (sort keys %$props) {
    my $mappedKey = $keys{$key};

    next if defined $theExclude && $key =~ /$theExclude/;
    next if defined $theInclude && $key !~ /$theInclude/;

    my $val = $props->{$key};
    $val = $props->{$key}->getValue if ref($val);
    next if $theHideEmpty && (!defined $val || $val eq '');

    my $line = $theFormat;
    $line = $params->{ $mappedKey . '_format' } if defined $params->{ $mappedKey . '_format' };
    $line =~ s/\$origkey/$key/g;
    $line =~ s/\$key/$mappedKey/g;
    $line =~ s/\$value/$val/g;

    push @result, $line if $line ne '';
  }

  my $theHideNull = Foswiki::Func::isTrue($params->{hidenull}, 1);
  return '' if $theHideNull && !@result;

  return $theHeader . join($theSep, @result) . $theFooter;
}

=begin TML

---++ ObjectMethod formatSummary($web, $topic, $params, $object, $subst) -> $result

formats the atom:summary field of an object. newlines are replaced with $subst, e.g. a '<br />'

=cut

sub formatSummary {
  my ($this, $web, $topic, $params, $obj, $subst) = @_;

  my $summary = $obj->getSummary;
  $summary =~ s/^\s*//;
  $summary =~ s/\s*$//;
  $summary =~ s/\n/$subst/g if defined $subst;

  return $summary;
}

=begin TML

---++ ObjectMethod formatBreadcrumbs($web, $topic, $params, $object) -> $result

formats the path property of an object

=cut

sub formatBreadcrumbs {
  my ($this, $web, $topic, $params, $obj) = @_;

  return '' unless defined $obj;

  my $theFormat = $params->{breadcrumbsformat};
  $theFormat = '$name' unless defined $theFormat;

  my $theHeader = $params->{breadcrumbsheader};
  my $theFooter = $params->{breadcrumbsfooter};
  my $theSep = $params->{breadcrumbsseparator};
  $theSep = ', ' unless defined $theSep;
  $theHeader = '' unless defined $theHeader;
  $theFooter = '' unless defined $theFooter;

  my $path = $obj->getPath;
  return '' unless defined $path;

  my @path = split(/\//, $path);
  @path = ('') unless @path;    # for the root element

  my $breadcrumbs = '';
  my @result = ();
  foreach my $item (@path) {
    my $line = $theFormat;
    $breadcrumbs .= '/' . $item unless $item eq '';
    $line =~ s/\$name/($item||'Root')/ge;
    $line =~ s/\$path/$breadcrumbs/g;
    push @result, $line;
  }

  return $theHeader . join($theSep, @result) . $theFooter;
}

=begin TML

---++ Object formatPager($web, $topic, $params, $obj) -> $result

formats a pager for the list of children in the object

=cut

sub formatPager {
  my ($this, $web, $topic, $params, $obj) = @_;

  return '' unless defined $obj;

  my $lastPage = $this->_lastPage($params, $obj);
  return '' unless $lastPage > 0;

  my $currentPage = $params->{skip} || 0;

  #print STDERR "lastPage=$lastPage, currentPage=$currentPage\n";

  my $result = '';
  if ($currentPage > 0) {
    my $scriptUrl = $this->_getScriptUrl($web, $topic, $params, $currentPage - 1);
    $result .= "<a href='$scriptUrl' class='cmisPagerPrev'>%MAKETEXT{\"Previous\"}%</a>";
  } else {
    $result .= "<span class='cmisPagerPrev foswikiGrayText'>%MAKETEXT{\"Previous\"}%</span>";
  }

  my $startPage = $currentPage - 4;
  my $endPage = $currentPage + 4;
  if ($endPage >= $lastPage) {
    $startPage -= ($endPage - $lastPage + 1);
    $endPage = $lastPage;
  }
  if ($startPage < 0) {
    $endPage -= $startPage;
    $startPage = 0;
  }
  $endPage = $lastPage if $endPage > $lastPage;

  if ($startPage > 0) {
    my $scriptUrl = $this->_getScriptUrl($web, $topic, $params, 0);
    $result .= "<a href='$scriptUrl'>1</a>";
  }

  if ($startPage > 1) {
    $result .= "<span class='cmisPagerEllipsis'>&hellip;</span>";
  }

  my $count = 1;
  my $marker = '';
  for (my $i = $startPage; $i <= $endPage; $i++) {
    my $scriptUrl = $this->_getScriptUrl($web, $topic, $params, $i);
    $marker = $i == $currentPage ? 'current' : '';
    $result .= "<a href='$scriptUrl' class='$marker'>" . ($i + 1) . "</a>";
    $count++;
  }

  if ($endPage < $lastPage - 1) {
    $result .= "<span class='cmisPagerEllipsis'>&hellip;</span>";
  }

  if ($endPage < $lastPage) {
    my $scriptUrl = $this->_getScriptUrl($web, $topic, $params, $lastPage);
    $marker = $currentPage == $lastPage ? 'current' : '';
    $result .= "<a href='$scriptUrl' class='$marker'>" . ($lastPage + 1) . "</a>";
  }

  if ($currentPage < $lastPage) {
    my $scriptUrl = $this->_getScriptUrl($web, $topic, $params, $currentPage + 1);
    $result .= "<a href='$scriptUrl' class='cmisPagerNext'>%MAKETEXT{\"Next\"}%</a>";
  } else {
    $result .= "<span class='cmisPagerNext foswikiGrayText'>%MAKETEXT{\"Next\"}%</span>";
  }

  if ($result) {
    $result = "<div class='cmisPager'>$result</div>";
  }

  return $result;
}

sub _lastPage {
  my ($this, $params, $obj) = @_;

  my $children = $obj->getChildren;
  my $pageSize = $params->{pagesize} || $children->getPageSize;    # || get it from the child feed
  my $total = $children->getSize;

  return POSIX::ceil($total / $pageSize) - 1 if $pageSize;
  return 0;
}

sub _getScriptUrl {
  my ($this, $web, $topic, $params, $start) = @_;

  my $path = $params->{path};
  my $query = $params->{query};
  my $sort = $params->{sort};

  my @urlParams = ();
  push @urlParams, skip => $start if defined $start;
  push @urlParams, path => $path if defined $path;
  push @urlParams, sort => $sort if defined $sort;
  push @urlParams, query => $query if defined $query;

  return Foswiki::Func::getScriptUrl($web, $topic, 'view', @urlParams);
}

=begin TML

---++ ObjectMethod formatObj($web, $topic, $params, $obj, $seen) -> $result

format the given CMIS object. this method might be called recursively
for child objects.

=cut

sub formatObj {
  my ($this, $web, $topic, $params, $obj, $seen) = @_;

  return '' unless $obj;

  $seen ||= {};
  return '' if $seen->{$obj};
  $seen->{$obj} = 1;

  throw Error::Simple("object not found") unless defined $obj;

  my $theFormat = $params->{format};
  $theFormat = '$objectId' unless defined $theFormat;

  my $result = $theFormat;
  my $props = $obj->getProperties;

  $result =~ s/\$title/$obj->getTitle/ge;
  $result =~ s/\$properties/$this->formatProperties($web, $topic, $params, $props)/ge;
  $result =~ s/\$breadcrumbs/$this->formatBreadcrumbs($web, $topic, $params, $obj)/ge;
  $result =~ s/\$summary(?:\((.*?)\))?/$this->formatSummary($web, $topic, $params, $obj, $1)/ge;
  $result =~ s/\$selfLink/$obj->getSelfLink/ge;
  $result =~ s/\$editLink/$obj->getEditLink/ge;
  $result =~ s/\$downloadLink/$this->formatDownloadLink($web, $topic, $params, $obj)/ge;
  $result =~ s/\$webdavLink/$this->formatWebDavLink($web, $topic, $params, $obj)/ge;
  $result =~ s/\$published/$obj->getPublished/ge;

  # generic properties
  foreach my $key (keys %$props) {
    my $val = $props->{$key}->getValue;
    $val = '' unless defined $val;
    my $origKey = $key;
    $key =~ s/^(.*:)?(.+?)$/$2/;
    $result =~ s/\$$origKey/foo $val/g;
    $result =~ s/\$$key/$val/g;
  }

  # allowed actions
  my $allowableActions = $obj->getAllowableActions;
  while (my ($action, $booleanFlag) = each %$allowableActions) {
    $result =~ s/\$$action/$booleanFlag/g;
  }

  my $size;
  if ($result =~ /\$size/) {
    $size = $props->{"cmis:contentStreamLength"};
    if ($size) {
      $size = $size->getValue;
      my $unit = '';
      if ($size > 1024) {
        $size = $size / 1024;
        $unit = 'K';
      }
      if ($size > 1024) {
        $size = $size / 1024;
        $unit = 'M';
      }
      if ($size > 1024) {
        $size = $size / 1024;
        $unit = 'G';
      }
      $size = sprintf("%.0f", $size) . $unit;
    } else {
      $size = '';
    }
  }

  # specific formating for folders
  # SMELL: how to deal with other non-standard ObjectTypes
  #
  if ($obj->isa('WebService::Cmis::Folder')) {

    # children
    my $thePageSize = $params->{pagesize} || -1;
    my $theSkip = $params->{skip} || 0;
    $result =~ s/\$children/$this->formatAtomFeed($web, $topic, {
      %$params,
      format=>$params->{childformat}||'$path',
    }, $obj->getChildren(maxItems=>$thePageSize, skipCount=>$theSkip, orderBy=>'cmis:name'))/ge;

    # parent
    $result =~ s/\$parent/$this->formatObj($web, $topic, {
      %$params,
      format=>$params->{parentformat}||'$path'
    }, $obj->getFolderParent())/ge;

    # pager
    $result =~ s/\$pager/$this->formatPager($web, $topic, $params, $obj)/ge;

    # size
    if ($result =~ /\$size/) {
      $size = $obj->getChildren->getSize;
    }

    # TODO:
    # descendants
    # parent
    # tree

  } elsif ($obj->isa('WebService::Cmis::Document')) {

    # thumbnail
    $result =~ s/\$thumbnail/$obj->getRenditionLink(kind=>"thumbnail")||''/ge;

    # icon
    $result =~ s/\$icon\(\d*\)?/$obj->getRenditionLink(kind=>"icon", width=>($1||16))||''/ge;

    # contentLink
    $result =~ s/\$contentLink/$obj->getContentLink/ge;

    # parent
    # SMELL can return an object _or_ a feed
    $result =~ s/\$parent/$this->formatParent($web, $topic, $params, $obj)/ge;

    # TODO:
    # isCheckedOut
    # checkedOutBy
    # versions

  } elsif ($obj->isa('WebService::Cmis::Relationship')) {

    # TODO
  } elsif ($obj->isa('WebService::Cmis::Policy')) {

    # TODO
  }

  $result =~ s/\$size\b/$size/g;
  $result =~ s/\$formatTime\((.*?)(?:,\s*'([^']*?)')?\)/formatTime($1, $2)/geo;

  # cleanup a bit
  $result =~ s/\$(children|thumbnail|icon\(\d*\)?|contentLink|parent|contentStreamLength)//g;

  return $result;
}

=begin TML

---++ StaticMethod formatTime($time, $format) -> $result;

a fault tolerant wrapper of Foswiki::Time

=cut

sub formatTime {
  my ($time, $format) = @_;

  $time ||= 0;

  if ($time =~ /^(-?\d+)(Z|[-+]\d\d(?::\d\d)?)?$/) {
    $time = $1;    # SMELL: strips off timezone
  } else {
    $time = Foswiki::Time::parseTime($time);
  }

  return "???" unless defined $time;

  return Foswiki::Func::formatTime($time, $format);
}

=begin TML

---++ ObjectMethod formatAtomFeed($web, $topic, $params, $feed) -> $result

format the given result set

=cut

sub formatAtomFeed {
  my ($this, $web, $topic, $params, $feed, $seen) = @_;

  my @results = ();
  my $limit = $params->{limit} || 0;

  my $index = 0;
  while (my $obj = $feed->getNext) {
    next if $obj->getProperty("cmis:isVersionSeriesCheckedOut") && !$obj->getProperty("cmis:isImmutable");    # skip the pwc
    $index++;
    last if $limit && $index > $limit;
    push @results, $this->formatObj($web, $topic, $params, $obj, $seen);
  }
  my $theHideNull = Foswiki::Func::isTrue($params->{hidenull}, 1);
  return '' if $theHideNull && !@results;

  my $theSep = $params->{childseparator};
  my $theFooter = $params->{childfooter};
  my $theHeader = $params->{childheader};
  $theSep = '' unless defined $theSep;
  $theHeader = '' unless defined $theHeader;
  $theFooter = '' unless defined $theFooter;

  my $result = $theHeader . join($theSep, @results) . $theFooter;

  $result =~ s/\$size/$feed->getSize/ge;
  return $result;
}

=begin TML

---++ ObjectMethod formatDownloadLink($web, $topic, $params, $obj) -> $result

returns a link with a content disposition so that the browser offers a save-as dialog when
clicking on it

=cut

sub formatDownloadLink {
  my ($this, $web, $topic, $params, $obj) = @_;

  my $downloadLink = $obj->getEditLink;
  return '' unless defined $downloadLink;

  my $name = $obj->getProperty("cmis:name");
  
  # replace the content.ext part with a different name
  # SMELL: this seems to be specific for alfresco
  $downloadLink =~ s/^(.*)\/content\..*?$/$1\/$name/;

  return $downloadLink;
}

=begin TML

---++ ObjectMethod formatWebDavLink($web, $topic, $params, $obj) -> $result

returns a webdav-enabled link for a cmis object. Only objects matching the file extension
as configured in =$Foswiki::cfg{CmisPlugin}{WebDAVFilter}= will be enabled. All other
objects return an empty webdav link.

=cut

sub formatWebDavLink {
  my ($this, $web, $topic, $params, $obj) = @_;

  return '' unless defined $obj;

  my $name = $obj->getName;
  my $path = $obj->getPath;
  return '' unless defined $name;

  unless (defined $path) {
    my $parent = $obj->getObjectParents;
    if ($parent->isa('WebService::Cmis::AtomFeed')) {
      $parent = $parent->getFirst;
    }
    return '' unless $parent;
    $path = $parent->getPath;
  }
  return '' unless defined $path;
  $path =~ s/^\///;

  my $webdavFilter = $Foswiki::cfg{CmisPlugin}{WebDAVFilter};
  return '' unless $webdavFilter;
  return '' unless $name =~ /$webdavFilter$/;

  my $id = $params->{connection};
  $id = $this->{core}{defaultConnection} unless defined $id;
  my $connection = $Foswiki::cfg{CmisPlugin}{Connections}{$id};
  my $url = $connection->{webdavUrl};

  my $host = $Foswiki::cfg{DefaultUrlHost};
  $host =~ s/^https?:\/\///;

  $url =~ s/\$host/$host/g;
  $url =~ s/\$path/$path/g;
  $url =~ s/\$name/$name/g;

  #print STDERR "url=$url\n";

  return $url;
}

=begin TML

---++ ObjectMethod formatParent($web, $topic, $params, $obj) -> $result

formats properties of a parent object. 

=cut

sub formatParent {
  my ($this, $web, $topic, $params, $obj) = @_;

  my $parents = $obj->getObjectParents;
  return '' unless defined $parents;

  my $theFormat = $params->{parentformat};
  my $theSep = $params->{parentseparator};
  my $theFooter = $params->{parentfooter};
  my $theHeader = $params->{parentheader};
  $theFormat = '$path' unless defined $theFormat;
  $theSep = '' unless defined $theSep;
  $theHeader = '' unless defined $theHeader;
  $theFooter = '' unless defined $theFooter;

  if ($parents->isa('WebService::Cmis::AtomFeed')) {
    return $this->formatAtomFeed(
      $web, $topic,
      {
        %$params,
        format => $theFormat,
        separator => $theSep,
        footer => $theFooter,
        header => $theHeader,
      },
      $parents
    );
  }

  return $this->formatObj(
    $web, $topic,
    {
      %$params,
      format => $theFormat,
      separator => $theSep,
      footer => $theFooter,
      header => $theHeader,
    },
    $parents
  );
}

1;
