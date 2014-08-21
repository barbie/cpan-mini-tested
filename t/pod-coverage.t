#!/usr/bin/perl

use strict;
use Test::More tests => 1;

eval "use Pod::Coverage";

plan skip_all => "Pod::Coverage required" if $@;

ok( Pod::Coverage->new( package => 'CPAN::Mini::Tested' ) );
