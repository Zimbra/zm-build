package Zimbra::LocalConfig;

require Exporter;

use strict;
use warnings;

use XML::Simple;

my $ERROR;

use Exporter qw(import);
our @EXPORT_OK= qw(deleteLocalConfig getLocalConfig getLocalConfigRaw setLocalConfig setLocalConfigRandom);

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

our %loaded=();
our %saved=();

=head2 deleteLocalConfig

Deletes the key specified using zmlocalconfig.

=cut
sub deleteLocalConfig {
    my $key = shift;

    detail("Deleting local config $key");
    my $rc = qx("/opt/zimbra/bin/zmlocalconfig -u ${key} 2> /dev/null");
    if ( $rc == 0 ) {
        delete( $loaded{lc}{$key} ) if ( exists $loaded{lc}{$key} );
        return 1;
    }
    else {
        return;
    }
}

=head2 getLocalConfig

Returns the value for the key specified using zmlocalconfig with substitutions.

=cut
sub getLocalConfig {
  my $key = shift;

  return $loaded{lc}{$key}
    if (exists $loaded{lc}{$key});

  my $val = qx(/opt/zimbra/bin/zmlocalconfig -x -s -m nokey ${key} 2> /dev/null);
  chomp $val;
  $loaded{lc}{$key} = $val;
  return $val;
}

=head2 getLocalConfigRaw

Returns the raw value for the key specified using zmlocalconfig.

=cut
sub getLocalConfigRaw {
    my $key = shift;

    return $loaded{lc}{"$key-raw"}
      if ( exists $loaded{lc}{"$key-raw"} );

    my $val = qx(/opt/zimbra/bin/zmlocalconfig -s -m nokey ${key} 2> /dev/null);
    chomp $val;
    $loaded{lc}{"$key-raw"} = $val;
    return $val;
}

=head2 setLocalConfig

Sets the key specified with the value provided using zmlocalconfig.

=cut
sub setLocalConfig {
  my $key = shift;
  my $val = shift;

  if (exists $saved{lc}{$key} && $saved{lc}{$key} eq $val) {
    return;
  }
  $saved{lc}{$key} = $val;
  qx(/opt/zimbra/bin/zmlocalconfig -f -e ${key}=\'${val}\' 2> /dev/null);
}

=head2 setLocalConfigRandom

Sets a random value to the key specified using zmlocalconfig.

=cut
sub setLocalConfigRandom {
  my $key = shift;
  qx(/opt/zimbra/bin/zmlocalconfig -f -e -r ${key} 2> /dev/null);
}

1;
