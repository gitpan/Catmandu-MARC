package Catmandu::Fix::marc_xml;

use Catmandu::Sane;
use Moo;
use Catmandu::Exporter::MARC;
use Catmandu::Util qw(:is :data);

has path  => (is => 'ro' , required => 1);
has key   => (is => 'ro' , required => 1);
has opts  => (is => 'ro');

around BUILDARGS => sub {
    my ($orig, $class, $path, %opts) = @_;
    $opts{-record} ||= 'record';
    my ($p, $key) = parse_data_path($path) if defined $path && length $path;
    $orig->($class, path => $p, key => $key, opts => \%opts);
};

# Transform a raw MARC array into MARCXML
sub fix {
    my ($self, $data) = @_;

    my $path = $self->path;
    my $key  = $self->key;
    my $rec_key = $self->opts->{-record};

    my $match = [grep ref, data_at($path, $data, key => $key, create => 1)]->[0];

    if ($match) {
        $match->{$key} = Catmandu::Exporter::MARC->marc_raw_to_marc_xml($data->{$rec_key});
    }

    $data;
}

=head1 NAME

Catmandu::Fix::marc_xml - transform a Catmandu MARC record into MARCXML

=head1 SYNOPSIS
   
   # Transforms the 'record' key into an MARCXML string
   marc_xml('record');

=head1 SEE ALSO

L<Catmandu::Fix>

=cut

1;
