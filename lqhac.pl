#!/usr/bin/perl -w

# Failover client running on replication slave host

use strict;
use lib "$ENV{LIQUID_HOME}/liquidmon/lib";
use Getopt::Std;
use Liquid::Failover::Debug qw(setDebug debugOn);
use Liquid::Failover::Config;
use Liquid::Failover::IPUtil qw(isPingable);
use Liquid::Failover::Tcp;
use Liquid::Failover::Serial;
use Liquid::Failover::Pid;

my $config = Liquid::Failover::Config->getConfig();

sub usage() {
    print "Failover Client\n";
    print "Usage: lqhac.pl [-D]\n";
    print "-D: debug mode\n";
    exit(-1);
}

my ($serial, $tcp);

sub checkAlreadyRunning() {
    my $pid = Liquid::Failover::Pid::readPidFile('lqhac');
    if (Liquid::Failover::Pid::isRunning($pid)) {
        print STDERR "lqhac is already running (pid = $pid)\n";
        exit(-2);
    }
}

sub exitScript() {
    if (defined($serial)) {
        undef($serial);
    }
    if (defined($tcp)) {
        Liquid::Failover::Tcp::disconnect($tcp);
    }
    Liquid::Failover::Pid::deletePidFile('lqhac');
    exit(0);
}

#
# Heartbeat over serial/TCP may fail due to heartbeat daemon not running.
# We need to ping the peer host to see if we have this situation.
#
sub peerHostUp($) {
    my $peerIP = shift;
    return isPingable($config->getLocalIP(), $peerIP);
}

#
# peerHostUp() test may fail due to problems with local NIC or cable, or
# even the common router/hub/switch the local host and peer are connected to.
# Pinging the router will tell us if there are any network issues on the
# local host side, as opposed to peer side.
#
sub routerPingable() {
    my $localIP = $config->getLocalIP();
    my $routerIP = $config->getRouterIP();
    return isPingable($config->getLocalIP(), $config->getRouterIP());
}

#
# Tells the peer host to relinquish service IP address and stop the
# application processes, so it won't interfere when local host takes over
# as new master.
#
sub softSTONITH($$) {
    my ($serial, $tcp) = @_;

    my $ipRelinquishCmd = 'relinquish';
    my $masterStopCmd = 'abort';
    my $ipRelinquished = 0;
    my $masterStopped = 0;
    my $resp;

    # Tell peer to release service IP.

    if (defined($tcp)) {
        $resp = Liquid::Failover::Tcp::postRequest($tcp, $ipRelinquishCmd);
        if (defined($resp) && $resp eq 'OK') {
            $ipRelinquished = 1;
        }
    }
    if (!$ipRelinquished && defined($serial)) {
        $resp = Liquid::Failover::Serial::postRequest($serial,
                                                      $ipRelinquishCmd);
        if (defined($resp) && $resp eq 'OK') {
            $ipRelinquished = 1;
        }
    }
    if (!$ipRelinquished) {
        print STDERR "Unable to tell peer host to relinquish service IP\n";
    }

    # Tell peer to stop Tomcat process.

    if (defined($tcp)) {
        $resp = Liquid::Failover::Tcp::postRequest($tcp, $masterStopCmd);
        if (defined($resp) && $resp eq 'OK') {
            $masterStopped = 1;
        }
    }
    if (!$masterStopped && defined($serial)) {
        $resp = Liquid::Failover::Serial::postRequest($serial,
                                                      $masterStopCmd);
        if (defined($resp) && $resp eq 'OK') {
            $masterStopped = 1;
        }
    }
    if (!$masterStopped) {
        print STDERR "Unable to send service stop command to peer host\n";
    }

    # TODO: Detect and deal with errors.  If we can't shutdown master host
    # for sure, consider not doing automatic failover.
}

#
# Real STONITH (Shoot-The-Other-Node-In-The-Head).  Depends on hardware type.
#
sub hardSTONITH() {
    # TODO
    print "hardSTONITH(); Implement me...\n";
}

sub spawnFailoverDaemon() {

    # Delete pid file since we're exiting current script with exec.
    Liquid::Failover::Pid::deletePidFile('lqhac');

    print "Spawning failover daemon\n";
    my $cmd = $config->getLiquidHome() . "/liquidmon/lqhad.pl";
    if (debugOn()) {
        $cmd .= ' -D';
    }
    exec($cmd);
}

sub doFailover($$) {
    my ($serial, $tcp) = @_;

    # Refresh config to see if current host is still replication slave.
    # If it became a master, it means someone did a manual failover, and
    # this script should not attempt to do another failover.
    $config->refresh();
    my $role = $config->getCurrentRole();
    if ($role ne 'slave') {
        print "It appears there was a manual failover.  Skipping automatic failover.\n";
        print "FAILOVER DONE\n";
        spawnFailoverDaemon();
    }

    # TODO: Use config to choose soft/hard STONITH?
    softSTONITH($serial, $tcp);
    hardSTONITH();

    if (defined($serial)) {
        undef($serial);
    }
    if (defined($tcp)) {
        Liquid::Failover::Tcp::disconnect($tcp);
    }

    if (Liquid::Failover::Control::becomeMaster()) {
        print "FAILOVER DONE\n";
        spawnFailoverDaemon();
    } else {
        print "FAILOVER MAY NOT HAVE WORKED!!!\n";
    }

    exitScript();
}

sub signal_handler {
    my $signal = shift;
    if (debugOn()) {
        print "lqhac.pl received SIG$signal (pid=$$)\n";
    }
    exitScript();
}
$SIG{INT} = 'signal_handler';
$SIG{TERM} = 'signal_handler';
$SIG{QUIT} = 'signal_handler';


my %opts;
getopts("D", \%opts) or usage();
setDebug($opts{D});

checkAlreadyRunning();

my $role = $config->getCurrentRole();
if ($role ne 'slave') {
    print STDERR "Current role of host is not replication slave.\n";
    exit(-1);
}

my $use_tcp = $config->tcpHeartbeatEnabled();
my $use_serial = $config->serialHeartbeatEnabled();
if (!$use_tcp && !$use_serial) {
    print STDERR "Heartbeat disabled\n";
    exit(-1);
}


Liquid::Failover::Pid::createPidFile('lqhac');


my ($tcp_host, $tcp_port) = ($config->getPeerIP(),
                             $config->getHeartbeatTcpPort());
my $serial_device = $config->getSerialDevice();
my $interval = $config->getHeartbeatInterval();
my $max_failures = $config->getHeartbeatMaxFailures();
my $num_failures = 0;

my ($reported_tcp_link_down, $reported_serial_link_down) = (0, 0);
my $serial_skip_count = 0;
while (1) {
    my ($tcp_tried, $serial_tried) = (0, 0);
    my $tcp_up = undef;  # 1/0 = service up/down; under = failover daemon down
    if ($use_tcp) {
        $tcp_tried = 1;
        if (debugOn()) {
            print "Sending TCP heartbeat...\n";
        }
        if (!defined($tcp)) {
            $tcp = Liquid::Failover::Tcp::connectTo($tcp_host, $tcp_port);
        }
        if (defined($tcp)) {
            $tcp_up = Liquid::Failover::Tcp::isUp($tcp);
        }
        if (defined($tcp_up)) {
            $reported_tcp_link_down = 0;
        } elsif (!$reported_tcp_link_down) {
            print STDERR
                "TCP HA daemon is not running on peer host $tcp_host\n";
            $reported_tcp_link_down = 1;
        }
    }

    # Try serial link if we don't have an answer on TCP link.  Even when
    # we have positive answer from TCP, try serial link every now and then,
    # so we can report problems with that connection.
    my $serial_up = undef;
    $serial_skip_count = (++$serial_skip_count) % 10;
    if ($use_serial && (!defined($tcp_up) || $serial_skip_count == 0)) {
        $serial_tried = 1;
        if (debugOn()) {
            print "Sending serial heartbeat...\n";
        }
        if (!defined($serial)) {
            $serial = Liquid::Failover::Serial::openSerialPort($serial_device);
        }
        if (defined($serial)) {
            $serial_up = Liquid::Failover::Serial::isUp($serial);
        }
        if (defined($serial_up)) {
            $reported_serial_link_down = 0;
        } elsif (!$reported_serial_link_down) {
            print STDERR
                "Serial HA daemon is not running on peer host $tcp_host\n";
            $reported_serial_link_down = 1;
        }
    }

    if (debugOn()) {
        my ($tcp_result, $serial_result) = ('not tried', 'not tried');
        if ($tcp_tried) {
            if (!defined($tcp_up)) {
                $tcp_result = 'link down';
            } else {
                $tcp_result = $tcp_up ? 'service up' : 'service down';
            }
        }
        if ($serial_tried) {
            if (!defined($serial_up)) {
                $serial_result = 'link down';
            } else {
                $serial_result = $serial_up ? 'service up' : 'service down';
            }
        }
        if ($use_tcp && $use_serial) {
            print "TCP: $tcp_result, Serial: $serial_result\n";
        } elsif ($use_tcp) {
            print "TCP: $tcp_result\n";
        } elsif ($use_serial) {
            print "Serial: $serial_result\n";
        }
    }

    my $is_failure = !$serial_up && !$tcp_up;

    # the common case; things are okay
    if ($tcp_up || $serial_up) {
        goto SLEEP_AND_NEXT;
    }

    # deal with heartbeat daemons being down (but host is okay)
    if (!defined($serial_up) && !defined($tcp_up)) {
        #if (peerHostUp($tcp_host)) {
        if (0) {  # We don't care if peer host is up or not.
                  # If it's up but there's no heartbeat, assume the box is
                  # hosed.  Watchdog on peer should be restarting heartbeat
                  # daemon as necessary, so if it's not getting restarted,
                  # the box is practically dead.
            print STDERR
                "All HA daemons are down!  " .
                "Failover disabled until HA daemons are started\n";
            $is_failure = 0;
            goto SLEEP_AND_NEXT;
        } else {
            if (routerPingable()) {
                # peer host is down; count as heartbeat failure
                $is_failure = 1;
            } else {
                # Can't ping the router either.  We may have a network issue
                # on the local side.  Peer may be healthy, but we have no way
                # to check.  Just report the problem but don't trigger
                # failover.
                $is_failure = 0;
                print STDERR "Unable to ping router.  Local host may have a network problem.  Failover disabled until this problem is cleared.\n";
            }
        }
    }

    if (!$is_failure) {
        print "Heartbeat succeeded partially.  Not counting as failure.\n";
        $num_failures = 0;
    } else {
        $num_failures++;
        if (debugOn()) {
            print 'Heartbeat failure #' . $num_failures . "\n";
        }
        if ($num_failures >= $max_failures) {
            if ($config->autoFailoverEnabled()) {
                print "Exceeded failure limit.  Initiating failover.\n";
                $num_failures = 0;
                doFailover($serial, $tcp);
            } else {
                print "Exceeded failure limit.  Failover needed.\n";
                $num_failures = 0;
                # TODO: Alert the administrator.
            }
        }
    }

  SLEEP_AND_NEXT:
    if (debugOn()) {
        print "Failure count = $num_failures\n\n";
    }
    if (!$is_failure) {
        $num_failures = 0;
    }
    sleep($interval);
}

exitScript();
