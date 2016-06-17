package Zimbra::SMTP;

use strict;
use warnings;

use Zimbra::LDAP;
use Net::SMTP;
use Net::DNS;

my $ERROR;

=head1 NAME

Zimbra::SMTP - Access to Zimbra SMTP mail servers

=head1 SYNOPSIS

  my $zs = Zimbra::SMTP->new;
  $zs->send(
      to      => 'abc@zimbra.com',
      from    => 'xyz@zimbra.com',
      subject => 'testing',
      message => 'test'
  );

=head1 DESCRIPTION

Perl API for sending SMTP messages through Zimbra MTA.

=head1 CONSTRUCTOR

=head2 new

Creates new instance of Zimbra::SMTP.

  my $zs = Zimbra::SMTP->new;

=cut

sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;
    return unless ( $self->ldap );
    return $self;
}

=head1 PROPERTIES

=head2 error

Returns last error message.

  print Zimbra::SMTP->error, "\n";
  print $zs->error,          "\n";

=cut

sub error {
    $ERROR = $_[1] if ($#_);
    return $ERROR;
}

=head2 ldap

Returns the Zimbra::LDAP object.

  print $zs->ldap->config->get("ldap_url"), "\n";

=cut

sub ldap {
    unless ( exists( $_[0]->{_ldap} ) ) {
        unless ( $_[0]->{_ldap} = Zimbra::LDAP->new ) {
            $_[0]->error( "failed to connect to LDAP: " . Zimbra::LDAP->error );
            return;
        }
    }
    return $_[0]->{_ldap};
}

=head2 smtp

Returns the Net::SMTP object.

We try to find the most appropriate MTA to use with Net::SMTP in this order:

=over

=item servers zimbra ldap zimbraSmtpHostname and zimbraSmtpPort

=item global zimbra ldap zimbraSmtpHostname and zimbraSmtpPort

=item localhost port 25

=item DNS MX record for destination domain

=back

  print $zs->smtp->domain, "\n";

=cut

sub smtp {
    unless ( exists( $_[0]->{_smtp} ) ) {

        foreach my $try ( "_server", "_global", "_local", "_domain" ) {
            my ( $server, $port ) = $_[0]->$try( $_[1] );
            if ( $_[0]->{_smtp} =
                Net::SMTP->new( Host => $server, Port => $port, Timeout => 10 )
              )
            {
                #print "SMTP ", $try, " ", $server, " ", $port, "\n";
                return $_[0]->{_smtp};
            }
        }
        delete( $_[0]->{_smtp} );
        $_[0]->error("failed to find available SMTP server");
        return;
    }
    return $_[0]->{_smtp};
}

sub _server {
    my $ls =
      $_[0]->ldap->server( $_[0]->ldap->config->get("zimbra_server_hostname") );
    my $server = $ls->get_value("zimbraSmtpHostname");
    my $port = $ls->get_value("zimbraSmtpPort") || 25;
    return $server, $port;
}

sub _global {
    return $_[0]->ldap->global->get_value("zimbraSmtpHostname"),
      $_[0]->ldap->global->get_value("zimbraSmtpPort") || 25;
}

sub _local {
    return "localhost", 25;
}

sub _domain {
    my $server = undef;
    my $dns    = new Net::DNS::Resolver;
    if ( my $mx = $dns->query( $_[1], 'MX' ) ) {
        if ( my $rr = ( $mx->answer )[0] ) {
            $server = $rr->exchange;
        }
    }
    return $server, 25;
}

=head1 METHODS

=head2 send

Send email message using smtp.

Send support the following named arguments:

=over

=item to

Specifies e-mail address to send message to.

=item from

Specifies e-mail address the message is from.

=item subject

Specifies e-mail subject.

=item message

Specifies e-mail content.

=back

  $zs->send(
      to      => 'abc@zimbra.com',
      from    => 'xyz@zimbra.com',
      subject => 'testing',
      message => 'test'
  );

=cut

sub send {
    my ( $self, %args ) = @_;
    my $domain = $args{to};
    $domain =~ s/^[^\@]+\@//;
    unless ( $self->smtp($domain) ) {
        return;
    }
    if ( $self->smtp ) {
        $self->smtp->mail( $args{from} );
        $self->smtp->to( $args{to} );
        my @message = "To: $args{to}\n";
        push( @message, "From: $args{from}\n" );
        push( @message, "Subject: ", $args{subject}, "\n" )
          if ( exists( $args{subject} ) );
        push( @message, "\n" );
        push( @message, $args{message}, "\n" ) if ( exists( $args{message} ) );
        $self->smtp->data(@message);
        return 1;
    }
    return;
}

=head2 SEE ALSO

L<Zimbra::LDAP>, L<Net::SMTP>, L<Net::DNS>

=cut

1;
