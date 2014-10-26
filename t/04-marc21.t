#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Catmandu::Importer::MARC;
use Test::Simple tests => 3;
use Data::Dumper;

my $importer = Catmandu::Importer::MARC->new( file => 't/marc.xml', type => "XML" );

my @records;

my $n = $importer->each(
    sub {
        push( @records, $_[0] );
    }
);

ok(@records == 1);

ok($records[0]->{record}->[1]->[0] eq '920');

ok($records[0]->{record}->[8]->[6] eq 'TEEM (한국전기전자재료학회)');

1;
