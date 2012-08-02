package NAP::Messaging::Validator;
use NAP::policy;
use Scalar::Util 'blessed';
use List::MoreUtils 'uniq';
use NAP::Messaging::Exception::Validation;
use Class::MOP;
use Data::Rx;

# ABSTRACT: a wrapper around L<Data::Rx>

=head1 DESCRIPTION

This class simplifies checking data structures against a L<Data::Rx>
schema. It requires the "NAP modified" C<Data::Rx> with the
C<validate> method.

This class exposes only class methods.

=cut

my %type_prefixes;
my @type_plugins;
my $rx;

sub _build_rx_instance {
    $rx = Data::Rx->new( {
        ( %type_prefixes ? (prefix => \%type_prefixes) : () ),
        ( @type_plugins ? (type_plugins => \@type_plugins) : () ),
    } );
}

=method C<add_type_plugins>

  NAP::Messaging::Validator->add_type_plugins('MyApp::DataRx::Types');

Loads the given class, and adds it as a type plugin to the L<Data::Rx>
schema builder.

=cut

sub add_type_plugins {
    my ($package,@plugins)=@_;

    Class::MOP::load_class($_) for @plugins;

    push @type_plugins,@plugins;
    @type_plugins = uniq @type_plugins;
    _build_rx_instance();
}

=method C<add_type_prefixes>

  NAP::Messaging::Validator->add_type_prefixes(
    myapp => 'tag:myapp,2012:rx',
  );

Adds the given prefix map to the L<Data::Rx> schema builder.

=cut

sub add_type_prefixes {
    my ($package,%prefixes)=@_;

    @type_prefixes{keys %prefixes}=values %prefixes;
    _build_rx_instance();
}

__PACKAGE__->add_type_plugins('NAP::Messaging::DataRx::Types');
__PACKAGE__->_build_rx_instance();

=method C<build_validator>

  my $schema = NAP::Messaging::Validator->build_validator($spec)

Returns a L<Data::Rx> schema object that validates against the given
C<$spec>. Uses the type plugins and prefixes added up to this
point. The L<NAP::Messaging::DataRx::Types> plugin is always loaded.

=cut

sub build_validator {
    my ($class,$spec) = @_;

    $spec //= { type => '//any' };
    return $rx->make_schema($spec);
}

=method C<validate>

  my ($ok,$errors) = NAP::Messaging::Validator->validate($schema,$data);

If C<$schema> is not a C<Data::Rx> schema, it is transformed into one
via L</build_validator>.

It is then used to check C<$data>. If it validates, this method
returns C<1>. If it does not validate, this method returns C<0> and an
error string explaining what went wrong. The string is generated by
L<NAP::Messaging::Exception::Validation>'s method
C<rx_failure_reason>.

=cut

sub validate {
    my ($class,$validator,$data) = @_;

    # just in case we get passed a hashref instead of a Data::Rx object
    if (!(blessed($validator) && $validator->can('validate'))) {
        $validator = $class->build_validator($validator);
    }

    my $validation_errors;
    try {
        $validator->validate($data);
    }
    catch (Data::Rx::Failure $e) {
        my $exc = NAP::Messaging::Exception::Validation->new({
            source_class => $class,
            data => $data,
            error => $e,
        });
        $validation_errors = $exc->rx_failure_reason;
    }
    catch ($e) {
        $validation_errors = $e;
    }

    return 1 unless $validation_errors;
    return (0, $validation_errors);
}