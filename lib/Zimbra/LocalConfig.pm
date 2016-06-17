package Zimbra::LocalConfig;

use strict;
use warnings;

use XML::Simple;

my $ERROR;

=head1 NAME

Zimbra::LocalConfig - Read access to all Zimbra local config values

=head1 SYNOPSIS

  use Zimbra::LocalConfig;
  my $zlc = Zimbra::LocalConfig->new;
  print $zlc->get('ldap_url'), "\n";

=head1 DESCRIPTION

Perl API for accessing zimbra local config values.

=head1 CONSTRUCTOR

=head2 new

Creates new instance of Zimbra::LocalConfig.

  my $zlc = Zimbra::LocalConfig->new;
  my $zlc = Zimbra::LocalConfig->new(file=>"my zimbra config xml file");

=cut

sub new {
    my $class = shift;
    my %args  = @_;
    my $self  = {};

    bless $self, $class;

    foreach my $key ( keys %args ) {
        if ( $self->can($key) ) {
            unless ( $self->$key( $args{$key} ) ) {
                return;
            }
        }
    }

    return unless ( $self->xml );
    return $self;
}

=head1 PROPERTIES

=head2 error

Returns last error message.

  print Zimbra::LocalConfig->error, "\n";
  print $zlc->error,                "\n";

=cut

sub error {
    $ERROR = $_[1] if ($#_);
    return $ERROR;
}

=head2 file

Returns the local config file name. Defaults to:

/opt/zimbra/conf/localconfig.xml

  print $zlc->file, "\n";

=cut

sub file {
    $_[0]->{_file} = $_[1] if ($#_);    # allow new to assign value
    $_[0]->{_file} = "/opt/zimbra/conf/localconfig.xml"
      unless ( exists( $_[0]->{_file} ) );    # assign default file;
    return $_[0]->{_file};
}

=head2 xml

Returns HASH representation of XML file.


  print $zlc->xml->{key}{ldap_url}, "\n";

=cut

sub xml {
    $_[0]->{_xml} = $_[1] if ($#_);    # allow new to assign value
    unless ( exists( $_[0]->{_xml} ) ) {
        unless ( $_[0]->{_xml} = XMLin( $_[0]->file ) ) {
            $_[0]->error( "failed to open " . $_[0]->file . ": " . $@ );
            return;
        }
    }
    return $_[0]->{_xml};
}

=head1 METHODS

=head2 get

Get passed local config value.

  my $ldapurl = $zlc->get('ldap_url');

=cut

sub get {
    if ( exists( $_[0]->xml->{key}{ $_[1] } ) ) {
        return $_[0]->xml->{key}{ $_[1] }{value};
    }
    else {
        return;
    }
}

=head1 SEE ALSO

L<XML::Simple>

=cut

1;
