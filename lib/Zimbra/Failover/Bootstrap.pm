package Zimbra::Failover::Bootstrap;

use strict;

my $LIQUID_HOME = $ENV{LIQUID_HOME} || $ENV{HOME} || '/opt/zimbra';

my %DATA = (
    DB_USERNAME => '',
    DB_PASSWORD => '',
    HOSTNAME => 'localhost',
    LDAP_HOST => 'localhost',
    LDAP_BIND_USERNAME => '',
    LDAP_BIND_PASSWORD => '',
);

sub getDbUsername() {
    _init();
    return $DATA{DB_USERNAME};
}

sub getDbPassword() {
    _init();
    return $DATA{DB_PASSWORD};
}

sub getHostname() {
    _init();
    return $DATA{HOSTNAME};
}

sub getLDAPHost() {
    _init();
    return $DATA{LDAP_HOST};
}

sub getLDAPBindUsername() {
    _init();
    return $DATA{LDAP_BIND_USERNAME};
}

sub getLDAPBindPassword() {
    _init();
    return $DATA{LDAP_BIND_PASSWORD};
}

my $INITIALIZED = 0;
sub _init() {
    if (!$INITIALIZED) {
	_readBootstrapFile();
    }
}

sub _readBootstrapFile() {
    # TODO: Put real implementation.

    $DATA{DB_USERNAME} = 'zimbra';
    $DATA{DB_PASSWORD} = 'zimbra';

    my $dbh = _dbConnect() or die "Can't connect to db!";
    $DATA{HOSTNAME} = _dbGetConfigKey($dbh, 'server.hostname');
    $DATA{LDAP_HOST} = _dbGetConfigKey($dbh, 'ldap.host');
    $dbh->disconnect();

    $DATA{LDAP_BIND_USERNAME} = 'uid=zimbra,cn=admins,cn=zimbra';
    $DATA{LDAP_BIND_PASSWORD} = 'zimbra';

    $INITIALIZED = 1;
}


# Temporary code until bootstrap file is implemented

use DBI;

sub _dbConnect() {
    my $data_source = "dbi:mysql:database=zimbra;host=localhost";
    my $username = $DATA{DB_USERNAME};
    my $password = $DATA{DB_PASSWORD};
    my $dbh = DBI->connect($data_source, $username, $password);
    if (!$dbh) {
        print STDERR "Unable to connect to DB $data_source: $DBI::errstr";
        return undef;
    }
    return $dbh;
}

sub _dbGetConfigKey($$) {
    my ($dbh, $name) = @_;
    my $stmt = "SELECT value FROM config WHERE name = ?";
    my $sth = $dbh->prepare($stmt);
    $sth->bind_param(1, $name);
    my $rv = $sth->execute();
    if (!$rv) {
        print STDERR "Unable to get config key '$name': $DBI::errstr\n";
        return 0;
    }
    my $value;
    my @data;
    if (@data = $sth->fetchrow_array()) {
        $value = $data[0];
    }
    $sth->finish();
    return $value;
}

1;
