package NAP::Messaging::DataRx::Types::sku;

use strict;
use warnings;

use parent 'Data::Rx::CommonType::EasyNew';

# ABSTRACT: An RxType to validate a sku type.

=head1 SYNOPSIS

 { type => '/nap/sku' }

This will accept sku values that comply with C<m{^\d+-\d{3,}$}>.

=cut

sub type_uri {
  sprintf 'http://net-a-porter.com/%s', $_[0]->subname
}

sub subname { 'sku' };

sub assert_valid {
    my ( $self, $value ) = @_;
    return 1 if $value =~ m{^\d+-\d{3,}$};
    $self->fail({
        error   => ['sku'],
        message => 'invalid sku value',
        value   => $value,
    });
}

sub to_json_schema {
    return {
        type => 'string',
        pattern => '^\d+-\d{3,}$',
    }
}

1;

=begin Pod::Coverage

type_uri
subname
assert_valid
to_json_schema

=end Pod::Coverage
