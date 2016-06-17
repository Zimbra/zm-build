package Zimbra::LDAP;

use strict;
use warnings;

use Zimbra::LocalConfig;
use Net::LDAP;

my $ERROR;
my $TLSVERIFY = "require";               # "none"
my $CAPATH    = "/opt/zimbra/conf/ca";

=head1 NAME

Zimbra::LDAP - Access to Zimbra LDAP directory

=head1 SYNOPSIS

  my $zl     = Zimbra::LDAP->new;
  my $global = $zl->global;
  my $server = $zl->server('mail.zimbra.com');
  my $admin  = $zl->mail('admin@mail.zimbra.com');
  
  print $global->get_value("zimbraSmtpHostname") , "\n";
  print $server->get_value("zimbraSmtpHostname") , "\n";
  print $admin->get_value("cn") , "\n";
  
  
  # when default settings are not what you need
  use Zimbra::LocalConfig;
  use Zimbra::LDAP;
   
  my $zlc = Zimbra::LocalConfig->new( file => "some non-default file" )
    ;    # when working with multiple environments create multiple objects
  my $zl = Zimbra::LDAP->new(
      dn       => $zlc->get('my local config dn'),          # grab from config
      password => $zlc->get('my local config password'),    # grab from config
      config => $zlc,                  # pass in custom local config
      url    => $zlc->get('my url')    # grab from config
  );


=head1 DESCRIPTION

Perl API for interacting with the Zimbra LDAP server.

=head1 CONSTRUCTOR

=head2 new

Creates new instance of Zimbra::LDAP.

New supports passing in the following values:

=over

=item url

=item dn

=item password

=item config

=back

See each of the above methods for more details about each value.

  my $zl = Zimbra::LDAP->new;
  my $zl = Zimbra::LDAP->new( dn => "my dn", password => "my dn password" );

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

    return unless ( $self->config );
    return unless ( $self->ldap );
    return $self;
}

=head1 PROPERTIES

=head2 error

Returns last error message.

  print Zimbra::LDAP->error, "\n";
  print $zl->error,          "\n";

=cut

sub error {
    $ERROR = $_[1] if ($#_);
    return $ERROR;
}

=head2 config

Returns the Zimbra::LocalConfig object.

  print $zl->config->get("ldap_url"), "\n";

=cut

sub config {
    $_[0]->{_config} = $_[1] if ($#_);    # allow new to assign value
    unless ( exists( $_[0]->{_config} ) ) {
        unless ( $_[0]->{_config} = Zimbra::LocalConfig->new ) {
            $_[0]->error(
                "Zimbra::LocalConfig error: " . Zimbra::LocalConfig->error );
            return;
        }
    }
    return $_[0]->{_config};
}

=head2 dn

Returns the local config zimbra_ldap_userdn or the dn value passed during new.

  print $zl->dn, "\n";

=cut

sub dn {
    $_[0]->{_dn} = $_[1] if ($#_);    # allow new to assign value
    $_[0]->{_dn} = $_[0]->config->get("zimbra_ldap_userdn")
      unless ( exists( $_[0]->{_dn} ) );    # assign default dn;
    return $_[0]->{_dn};
}

=head2 password

Returns the local config zimbra_ldap_password or the password value passed during new.

  print $zl->password, "\n";

=cut

sub password {
    $_[0]->{_password} = $_[1] if ($#_);    # allow new to assign value
    $_[0]->{_password} = $_[0]->config->get("zimbra_ldap_password")
      unless ( exists( $_[0]->{_password} ) );    # assign default password;
    return $_[0]->{_password};
}

=head2 url

Returns the local config ldap_url or the value url value passed during new.

  print $zl->url, "\n";

=cut

sub url {
    $_[0]->{_url} = $_[1] if ($#_);                  # allow new to assign value
    $_[0]->{_url} = $_[0]->config->get("ldap_url")
      unless ( exists( $_[0]->{_url} ) );            # assign default url;
    return $_[0]->{_url};
}

=head2 ldap

Returns the Net::LDAP object.

  my $result = $zl->ldap->search(...);

=cut

sub ldap {
    unless ( exists( $_[0]->{_ldap} ) ) {
        if ( my $ldapurl = $_[0]->url ) {
            my $servers = [ split( / /, $ldapurl ) ];

            # connect to ldap server
            unless ( $_[0]->{_ldap} = Net::LDAP->new($servers) ) {
                delete( $_[0]->{_ldap} );
                $_[0]->error( "Failed to connect to LDAP ("
                      . join( " ", @$servers ) . "):"
                      . $@ );
                return;
            }

       #print "LDAP Host: ",$_[0]->{_ldap}->host," ",$_[0]->{_ldap}->scheme," ",
       #     $_[0]->config->get("ldap_starttls_supported"),"\n";
       # start TLS if desired
            if ( $_[0]->{_ldap}->scheme !~ /^ldaps$/i ) {
                if ( $_[0]->config->get("ldap_starttls_supported") ) {
                    my $mesg = $_[0]->{_ldap}->start_tls(
                        verify => $TLSVERIFY,
                        capath => $CAPATH
                    );
                    if ( $mesg->code ) {
                        $_[0]->error( "start tls failed: " . $mesg->error );
                        return;
                    }
                }
            }

            # bind ldap
            my $mesg =
              $_[0]->{_ldap}->bind( $_[0]->dn, password => $_[0]->password );
            if ( $mesg->code ) {
                $_[0]->error( "bind failed: " . $mesg->error );
                return;
            }
        }
        else {
            $_[0]->error("ldap_url not defined in localconfig");
            return;
        }
    }
    return $_[0]->{_ldap};
}

=head2 global

Returns Net::LDAP::Entry for the Zimbra global config LDAP entry.

  print $zl->global->get_value("zimbraSmtpHostname"), "\n";

=cut

sub global {
    unless ( exists( $_[0]->{_global} ) ) {
        $_[0]->{_global} = $_[0]->searchsingle(
            scope  => "base",
            base   => "cn=config,cn=zimbra",
            filter => "cn=config"
        );
    }
    return $_[0]->{_global};
}

=head1 METHODS

=head2 mail

Returns Net::LDAP::Entry for the passed mail address.

  my $admin=$zl->mail('admin@mail.zimbra.com');

=cut

sub mail {
    my $self = shift;
    my $mail = shift;
    return $self->searchsingle( filter => "(mail=$mail)" );
}

=head2 searchsingle

Passes all arguments to Net::LDAP search method and checks that we only get one result and returns that specific Net::LDAP::Entry value.

  my $mail = $zl->searchsingle( filter => "(mail=$mail)" );
  unless ($mail) {
      print $zl->error, "\n";
  }

=cut

sub searchsingle {
    my ( $self, %args ) = @_;
    my $mesg  = $self->ldap->search(%args);
    my $count = $mesg->count;
    if ( $count != 1 ) {
        $self->error("$count matches for '$args{filter}'");
        return;
    }
    return $mesg->entry(0);
}

=head2 server

Returns Net::LDAP::Entry for the passed server name.

  my $server = $zl->server('mail.zimbra.com');

=cut

sub server {
    my $self = shift;
    my $host = shift;
    return $self->searchsingle(
        base   => "cn=servers,cn=zimbra",
        filter => "(cn=$host)"
    );
}

=head1 SEE ALSO

L<Zimbra::LocalConfig>, L<Net::LDAP>

=cut

1;
