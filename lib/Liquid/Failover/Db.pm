package Liquid::Failover::Db;

use strict;
use DBI;
use Liquid::Failover::Bootstrap;

my $LIQUID_HOME = $ENV{LIQUID_HOME} || $ENV{HOME} || '/opt/liquid';

sub connect {
    my $class = shift;
    my $data_source = "dbi:mysql:database=liquid;mysql_read_default_file=$LIQUID_HOME/conf/my.cnf";
    my $username = Liquid::Failover::Bootstrap::getDbUsername();
    my $password = Liquid::Failover::Bootstrap::getDbPassword();
    my $dbh = DBI->connect($data_source, $username, $password);
    if (!$dbh) {
        print STDERR "Unable to connect to DB $data_source: $DBI::errstr";
        return undef;
    }
    my $self = {CONN => $dbh};
    bless($self, $class);
    return $self;
}

sub disconnect($) {
    my $self = shift;
    if (defined($self->{CONN})) {
        $self->{CONN}->disconnect();
        $self->{CONN} = undef;
    }
}

sub setConfigKey($$$) {
    my ($self, $name, $value) = @_;
    my $stmt = "INSERT INTO config (name, value, modified) VALUES (?, ?, NOW()) ON DUPLICATE KEY UPDATE value = ?, modified = NOW()";
    my $sth = $self->{CONN}->prepare($stmt);
    $sth->bind_param(1, $name);
    $sth->bind_param(2, $value);
    $sth->bind_param(3, $value);
    my $rv = $sth->execute();
    if (!$rv) {
        print STDERR "Unable to update config key '$name' to '$value': $DBI::errstr\n";
        return 0;
    }
    return 1;
}

sub deleteConfigKey($$) {
    my ($self, $name) = @_;
    my $stmt = "DELETE FROM config WHERE name = ?";
    my $sth = $self->{CONN}->prepare($stmt);
    $sth->bind_param(1, $name);
    my $rv = $sth->execute();
    if (!$rv) {
        print STDERR "Unable to delete config key '$name': $DBI::errstr\n";
        return 0;
    }
    return 1;
}

sub getConfigKey($$) {
    my ($self, $name) = @_;
    my $stmt = "SELECT value FROM config WHERE name = ?";
    my $sth = $self->{CONN}->prepare($stmt);
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
