package Liquid::Failover::Monitoring;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(isServiceAvailable);

use strict;
use DBI;
use SOAP::Lite;
use Liquid::Failover::LDAP;
use Liquid::Failover::Config;
use Liquid::Failover::Control qw(lqcontrol isServiceRunning);
use Liquid::Failover::SoapToTomcat;

sub isServiceAvailable() {
    #return lqcontrol('status');
    #return isServiceRunning();
    return checkAll();
}

sub checkAll() {
    my $ldap = checkLDAP();
    my $db = checkDB();
    my $tomcat = checkTomcat();
    my $network = checkServiceIP();
    if ($ldap && $db && $tomcat && $network) {
        return 1;
    }
    my $msg = sprintf("STATUS: ldap=%s, db=%s, tomcat=%s, network=%s\n",
                      $ldap ? 'up' : 'down',
                      $db ? 'up' : 'down',
                      $tomcat ? 'up' : 'down',
                      $network ? 'up' : 'down');
    print $msg;
    return 0;
}

#
# Tries to connect to LDAP server and search for default admin account entry.
# Returns 1 if successful, 0 if error.
#
sub checkLDAP() {
    my $ldap = new Liquid::Failover::LDAP();
    $ldap->bind() or return 0;
    my %conf = ();
    my $success = $ldap->getGlobalServerConfig(\%conf);
    $ldap->unbind();
    return $success;

    my $attr = 'uid';
    my $search = $ldap->getDirContext()->search(
        base => 'cn=admins,cn=liquid',
        scope => 'one',
        filter => "(&($attr=liquid)(objectClass=liquidAccount))",
        attrs => [$attr]
    );
    if ($search->code()) {
        print STDERR "LDAP search failed: " . $search->error() . "\n";
        $ldap->unbind();
        return 0;
    }
    my $entry = $search->entry(0);
    if (!defined($entry)) {
        print STDERR "LDAP search returned no entry\n";
        $ldap->unbind();
        return 0;
    }
    my $uid = $entry->get_value($attr);
    if (!defined($uid)) {
        print STDERR "LDAP search result missing $attr attribute\n";
       $ldap->unbind();
        return 0;
    }

    $ldap->unbind();
    return 1;
}

#
# Tries to connect to database and run a simple query.
# Returns 1 if successful, 0 if error.
#
sub checkDB() {

    my $db = Liquid::Failover::Db->connect();
    if (!$db) {
        print STDERR "Unable to connect to database\n";
        return 0;
    }

    my $foo = 'foo';
    my $stmt = "SELECT '$foo' AS TEST";
    my $sth = $db->{CONN}->prepare($stmt);
    my $rv = $sth->execute();
    if (!$rv) {
        print STDERR "Unable to execute query: $DBI::errstr\n";
        $db->disconnect();
        return 0;
    }
    my $value;
    my @data;
    if (@data = $sth->fetchrow_array()) {
        $value = $data[0];
    } else {
        print STDERR "Unable to fetch row: $DBI::errstr\n";
        $sth->finish();
        $db->disconnect();
        return 0;
    }
    $sth->finish();
    $db->disconnect();

    if ($value ne $foo) {
        print STDERR
            "Retrieved value ($value) is different from original ($foo).\n";
        return 0;
    }
    return 1;
}

sub checkTomcat() {
    my $resp = Liquid::Failover::SoapToTomcat::checkHealth();
    if (!defined($resp)) {
        print STDERR "No positive ping response from Tomcat\n";
        return 0;
    }
    my $healthy = $resp->attr('healthy');
    return $healthy ? 1 : 0;
}

#
# Checks connectivity to the outside world, by pinging the router between
# service IP and end users.
#
sub checkServiceIP() {
    my $role = Liquid::Failover::Config::getCurrentRole();
    if (defined($role) && $role eq 'slave') {
        # Don't check on slave host, which doesn't own the service IP.
        return 1;
    }
    my $serviceIP = Liquid::Failover::Config::getServiceIP();
    my $routerIP = Liquid::Failover::Config::getRouterIP();
    if (!defined($serviceIP) || !defined($routerIP)) {
        print STDERR
            "No local and/or router IP defined; Network check skipped.\n";
        return 1;
    }
    return Liquid::Failover::IPUtil::isPingable($serviceIP, $routerIP);
}

1;
