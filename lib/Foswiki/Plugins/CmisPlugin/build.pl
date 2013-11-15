#!/usr/bin/perl -w
#
# Build file for CmisPlugin
#
BEGIN {
  foreach my $pc (split(/:/, $ENV{FOSWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use Foswiki::Contrib::Build;

$build = new Foswiki::Contrib::Build("CmisPlugin");
$build->build($build->{target});
