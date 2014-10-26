package Catmandu::Importer::MARC;

use Catmandu::Sane;
use Moo;
use MARC::File::USMARC;
use MARC::File::MicroLIF;
use MARC::File::XML (BinaryEncoding => 'UTF-8', DefaultEncoding => 'UTF-8', RecordFormat => 'MARC21');

with 'Catmandu::Importer';

has type => (is => 'ro' , default => sub { 'USMARC' });
has id   => (is => 'ro' , default => sub { '001' });

sub aleph_generator {
    my $self = shift;

    sub {
        state $fh = $self->fh;
        state $prev_id;
	    state $record = [];

        while(<$fh>) {
           chop;
           next unless (length $_ >= 18);

           my ($sysid,$s1,$tag,$ind1,$ind2,$s2,$char,$s3,$data) = unpack("A9A1A3A1A1A1A1A1U0A*",$_);
           unless ($tag =~ m{^[0-9A-Z]+}) {
               warn "skipping $sysid $tag unknown tag";
               next;
           }
           unless ($ind1 =~ m{[A-Za-z0-9]}) {
               $ind1 = " ";
           }
           unless ($ind2 =~ m{[A-Za-z0-9]}) {
               $ind2 = " ";
           }
           unless (utf8::decode($data)) {
               warn "skipping $sysid $tag unknown data";
               next;
           }
           if ($tag eq 'LDR') {
               $data =~ s/\^/ /g;
           }
           my @parts = ('_' , split(/\$\$(.)/, $data) );

           # All control-fields contain an underscore field containing the data
           # all other fields not.
           unless ($tag =~ /LDR|00./o) {
              shift @parts;
              shift @parts;
           }

           # If we have an empty subfield at the end, then we need to add a implicit empty value
           push(@parts,'') unless int(@parts) % 2 == 0;

           if (defined $prev_id && $prev_id != $sysid) {
		       my $result = { _id => $prev_id , record => [ @$record ] };
		       $record  = [[$tag, $ind1, $ind2, @parts]];
           	   $prev_id = $sysid;
		       return $result;
	       }

           push @$record, [$tag, $ind1, $ind2, @parts];

           $prev_id = $sysid;
        }

	    if (@$record > 0) {
    	   my $result = { _id => $prev_id , record => [ @$record ] };
	       $record = [];
	       return $result;
        }
	    else {
	       return;
 	    }
    };
}

sub marc_generator {
    my ($self) = @_;
    my $type = $self->type;
    my $file;

    if ($type eq 'USMARC') {
        $file = MARC::File::USMARC->in($self->fh);
    }
    elsif ($type eq 'MicroLIF') {
        $file = MARC::File::MicroLIF->in($self->fh);
    }
    elsif ($type eq 'XML') {
        $file = MARC::File::XML->in($self->fh);
    }
    else {
        die "unknown";
    }

    my $id = $self->id;

    sub {
        my $record = $file->next();
        return unless $record;

        my @result = ();

        push @result , [ 'LDR' , undef, undef, '_' , $record->leader ];

        for my $field ($record->fields()) {
            my $tag  = $field->tag;
            my $ind1 = $field->indicator(1);
            my $ind2 = $field->indicator(2);

            my @sf = ();

            if ($field->is_control_field) {
                push @sf , '_', $field->data;
            }

            for my $subfield ($field->subfields) {
                push @sf , @$subfield;
            }

            push @result, [$tag,$ind1,$ind2,@sf];
        }

        my $sysid = undef;

        if ($id =~ /^00/) {
            $sysid = $record->field($id)->data();
        }
        elsif (defined $id) {
            $sysid = $record->field($id)->subfield("a");
        }

        return { _id => $sysid , record => \@result };
    };
}

sub generator {
    my ($self) = @_;
    my $type = $self->type;

    if ($type =~ /^USMARC|MicroLIF|XML$/) {
       return $self->marc_generator;
    }
    if ($type eq 'ALEPHSEQ') {
       return $self->aleph_generator;
    }
    die "need USMARC, MicroLIF, XML or ALEPHSEQ";
}

=head1 NAME

Catmandu::Importer::MARC - Package that imports MARC data

=head1 SYNOPSIS

    use Catmandu::Importer::MARC;

    my $importer = Catmandu::Importer::MARC->new(file => "/foo/bar.marc", type=> "USMARC");

    my $n = $importer->each(sub {
        my $hashref = $_[0];
        # ...
    });

=head1 MARC

The parsed MARC is a HASH containing two keys '_id' containing the 001 field (or the system
identifier of the record) and 'record' containing an ARRAY of ARRAYs for every field:

 {
  'record' => [
                      [
                        '001',
                        undef,
                        undef,
                        '_',
                        'fol05882032 '
                      ],
 		      [
                        245,
                        '1',
                        '0',
                        'a',
                        'Cross-platform Perl /',
                        'c',
                        'Eric F. Johnson.'
                      ],
	      ],
  '_id' => 'fol05882032'
 } 

=head1 METHODS

=head2 new(file => $filename,type=>$type,[id=>$id_field])

Create a new MARC importer for $filename. Use STDIN when no filename is given. Type 
describes the sytax of the MARC records. Currently we support: USMARC, MicroLIF 
, XML and ALEPHSEQ.
Optionally provide an 'id' option pointing to the identifier field of the MARC record
(default 001).

=head2 count

=head2 each(&callback)

=head2 ...

Every Catmandu::Importer is a Catmandu::Iterable all its methods are inherited. The
Catmandu::Importer::MARC methods are not idempotent: MARC feeds can only be read once.

=head1 SEE ALSO

L<Catmandu::Iterable>

=cut

1;
