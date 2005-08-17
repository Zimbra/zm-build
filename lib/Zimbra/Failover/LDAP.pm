package Zimbra::Failover::LDAP;

use strict;
use Net::LDAP;
use Zimbra::Failover::Bootstrap;

my $CONFIG_BASE = 'cn=config,cn=zimbra';
my $SERVER_BASE = 'cn=servers,cn=zimbra';

sub new {
    my $class = shift;
    my $self = {LDAP => undef};
    bless($self, $class);
    return $self;
}

sub getDirContext($) {
    my $self = shift;
    return $self->{LDAP};
}

sub bind($) {
    my $self = shift;
    my $host = Zimbra::Failover::Bootstrap::getLDAPHost();
    my $username = Zimbra::Failover::Bootstrap::getLDAPBindUsername();
    my $password = Zimbra::Failover::Bootstrap::getLDAPBindPassword();
    my $ldap = Net::LDAP->new($host);
    if (!$ldap) {
        print STDERR "Unable to create LDAP object: $@\n";
        return 0;
    }
    my $mesg = $ldap->bind($username, password => $password);
    if (!$mesg) {
        print STDERR "Unable to bind to LDAP server\n";
        eval { $ldap->unbind(); };
        return 0;
    }
    if ($mesg->code()) {
        print STDERR "Unable to bind to LDAP server: " . $mesg->error() . "\n";
        eval { $ldap->unbind(); };
        return 0;
    }
    $self->{LDAP} = $ldap;
    return 1;
}

sub unbind($) {
    my $self = shift;
    if (!defined($self->{LDAP})) {
        return;
    }
    my $mesg;
    eval { $mesg = $self->{LDAP}->unbind(); };
    $self->{LDAP} = undef;
    if (!$mesg) {
        print STDERR "Error unbinding from LDAP server\n";
    }
    if ($mesg->code()) {
        print STDERR
            "Error unbinding from LDAP server: " . $mesg->error() . "\n";
    }
}

#
# Read global config object and return it in the provided hash, passed in
# as reference.  Returns 1 if successful, 0 if error.
#
sub getGlobalServerConfig($%) {
    my ($self, $attrsref) = @_;
    
    my $search = $self->{LDAP}->search(
        base => $CONFIG_BASE,
        scope => 'base',
        filter => '(objectClass=zimbraGlobalConfig)',
        attrs => ['*']
    );
    if ($search->code()) {
        print STDERR "LDAP search failed: " . $search->error() . "\n";
        return 0;
    }
    my $entry = $search->entry(0);
    if (!defined($entry)) {
        print STDERR "LDAP search returned no global config entry\n";
        return 0;
    }

    my $inherits = $entry->get_value('zimbraServerInheritedAttr', asref => 1);
    if (!defined($inherits)) {
        return 1;
    }
    foreach my $attr (@$inherits) {
        my @vals = $entry->get_value($attr);
        my $num = scalar(@vals);
        if ($num == 1) {
            $attrsref->{uc($attr)} = $vals[0];
        } elsif ($num > 1) {
            # Multi-valued attribute is stored as reference to array.
            $attrsref->{uc($attr)} = \@vals;
        }
    }
    return 1;
}

#
# Returns reference to hash containing attributes for a server object.
# Includes inherited attributes from global config object.
# Returns undef if unsuccessful.
#
sub getServerByName($$) {
    my ($self, $server) = @_;
    my %retval = ();
    if (!$self->getGlobalServerConfig(\%retval)) {
        return undef;
    }

    my $search = $self->{LDAP}->search(
        base => "cn=$server,$SERVER_BASE",
        scope => 'base',
        filter => "(objectClass=zimbraServer)",
        attrs => ['*']
    );
    if (_fetchServerAttrs($search, \%retval)) {
        return \%retval;
    } else {
        return undef;
    }
}

sub getServerById($$) {
    my ($self, $zimbraId) = @_;
    my %retval = ();
    if (!$self->getGlobalServerConfig(\%retval)) {
        return undef;
    }

    my $search = $self->{LDAP}->search(
        base => $SERVER_BASE,
        scope => 'one',
        filter => "(&(zimbraId=$zimbraId)(objectClass=zimbraServer))",
        attrs => ['*']
    );
    if (_fetchServerAttrs($search, \%retval)) {
        return \%retval;
    } else {
        return undef;
    }
}

sub _fetchServerAttrs($$) {
    my ($search, $outhashref) = @_;
    if ($search->code()) {
        print STDERR "LDAP search failed: " . $search->error() . "\n";
        return 0;
    }
    my $entry = $search->entry(0);
    if (!defined($entry)) {
        print STDERR "LDAP search returned no server entry\n";
        return 0;
    }

    my @attrs = $entry->attributes();
    foreach my $attr ($entry->attributes()) {
        my @vals = $entry->get_value($attr);
        my $num = scalar(@vals);
        if ($num == 1) {
            # scalar
            $outhashref->{uc($attr)} = $vals[0];
        } elsif ($num > 1) {
            # array ref
            $outhashref->{uc($attr)} = \@vals;
        }
    }
    return 1;
}

1;
