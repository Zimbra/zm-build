package Liquid::Failover::Control;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(relinquish
                stopFailedMaster
                abortFailedMaster
                lqcontrol
                isServiceRunning);

use strict;
use Liquid::Failover::Debug qw(debugOn);
use Liquid::Failover::Config;
use Liquid::Failover::IPUtil;
use Liquid::Failover::SoapToTomcat;
use Liquid::Failover::Db;

sub lqcontrol(;$) {
    my $args = shift || '';
    my $cmd = Liquid::Failover::Config::getLiquidHome() . "/liquidmon/lqcontrol $args";
print "LQCONTROL: Invoking $cmd\n";
    `$cmd`;
    return $? >> 8 == 0 ? 1 : 0;
}

sub startService() {
    if (debugOn()) {
        print "Starting service...\n";
    }
    lqcontrol('start');
    # TODO: Wait until startup is complete.
    return 1;
}

sub stopService() {
    if (debugOn()) {
        print "Stopping service...\n";
    }
    lqcontrol('stop');
    # TODO: Wait until service shutdown is complete.
    return 1;
}

sub abortService() {
    if (debugOn()) {
        print "Aborting service...\n";
    }
    my $pid = getServicePid();
    if ($pid) {
        kill(9, $pid);
        if (isServiceRunning()) {
            print STDERR "Unable to abort service (pid=$pid)\n";
        }
    }
    return 1;
}

sub getServicePid() {
    my $pidfile =
        Liquid::Failover::Config::getLiquidHome() . "/log/tomcat.pid";
    my $pid;
    if (open(FH, "< $pidfile")) {
        my $line = <FH>;
        close(FH);
        chomp($line);
        if ($line) {
            $pid = $line;
        }
    }
    return $pid;
}

sub isServiceRunning() {
    my $pid = getServicePid();
    if ($pid) {
        my $cmd = "ps -ef | grep $pid | grep -v grep";
        my $output = `$cmd`;
        if (defined($output)) {
            chomp($output);
            if ($output ne '') {
                return 1;
            }
        }
    }
    return 0;
}

sub relinquish() {
    my $ip = Liquid::Failover::Config::getServiceIP();
    Liquid::Failover::IPUtil::relinquishIP($ip);
    print "Released IP $ip\n";
}

sub stopFailedMaster() {
    relinquish();
    stopService();
}

sub abortFailedMaster() {
    relinquish();
    abortService();
}

sub becomeMaster() {
    if (debugOn()) {
        print "Sending BecomeMaster command to tomcat...\n";
    }
    my $cmd =
        Liquid::Failover::Config::getLiquidHome() .
        "/libexec/lqreplcmd -c takeover";
    my $rc = system($cmd);
    if ($rc != 0) {
        $rc >>= 8;
        print STDERR "Unable to send BecomeMaster command to tomcat: $!\n";
        print STDERR "(lqreplcmd returned with $rc)\n";
        return 0;
    }

    # Tomcat will do IP takeover as part of BecomeMaster procedure,
    # so there is no need for this script to takeover IP.

    return 1;
}

1;
