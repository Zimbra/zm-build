#!/usr/bin/perl -w

# Failover daemon running on replication master host

use strict;
use lib "$ENV{LIQUID_HOME}/liquidmon/lib";
use Getopt::Std;
use Liquid::Failover::Debug qw(setDebug);
use Liquid::Failover::Config;
use Liquid::Failover::Tcp;
use Liquid::Failover::Serial;
use Liquid::Failover::Pid;

my $config = Liquid::Failover::Config->getConfig();

sub usage() {
    print "Failover Daemon\n";
    print "Usage: lqhad.pl [-D]\n";
    print "-D: debug mode\n";
    exit(-1);
}

sub checkAlreadyRunning() {
    my @pids = Liquid::Failover::Pid::readPidFile('lqhad');
    my $pid;
    foreach $pid (@pids) {
        if (Liquid::Failover::Pid::isRunning($pid)) {
            print STDERR "lqhad is already running (pids = " .
                         join(', ', @pids) . ")\n";
            exit(-2);
        }
    }
}

my $TCP_PID;
my $SERIAL_PID;

sub signal_handler {
    my $signal = shift;
    my ($other, $type);
    if (defined($TCP_PID) && $$ eq $TCP_PID) {
        $other = $SERIAL_PID;
        $type = 'TCP ';
    } elsif (defined($SERIAL_PID) && $$ eq $SERIAL_PID) {
        $other = $TCP_PID;
        $type = 'serial ';
    } else {
        $type = '';
    }
    print "${type}lqhad received SIG$signal (pid=$$)\n";
    if (defined($other)) {
        kill($signal, $other);
    }
    Liquid::Failover::Pid::deletePidFile('lqhad');
    exit(0);
}

my %opts;
getopts("D", \%opts) or usage();
setDebug($opts{D});

checkAlreadyRunning();

my $role = $config->getCurrentRole();
if ($role ne 'master') {
    print STDERR "Current role of host is not replication master.\n";
    exit(-1);
}

$SIG{INT} = 'signal_handler';
$SIG{TERM} = 'signal_handler';
$SIG{QUIT} = 'signal_handler';

my $use_tcp = $config->tcpHeartbeatEnabled();
my $use_serial = $config->serialHeartbeatEnabled();
if (!$use_tcp && !$use_serial) {
    print STDERR "Heartbeat disabled\n";
    exit(-1);
}


Liquid::Failover::Pid::createPidFile('lqhad');


my $port = $config->getHeartbeatTcpPort();
my $serial_device = $config->getSerialDevice();

if ($use_tcp && $use_serial) {
    # Parent runs TCP daemon, child runs serial port daemon.
    $TCP_PID = $$;
    if ($SERIAL_PID = fork()) {
        # parent
        print "Listening on TCP port $port\n";
        Liquid::Failover::Tcp::runServerLoop($port);
    } elsif (defined($SERIAL_PID)) {
        # child
        $SERIAL_PID = $$;
        Liquid::Failover::Pid::appendPidFile('lqhad');
        print "Listening on serial port device $serial_device\n";
        Liquid::Failover::Serial::runServerLoop($serial_device);
    } else {
        die("Unable to fork: $!");
    }
} elsif ($use_tcp) {
    $TCP_PID = $$;
    print "Listening on TCP port $port\n";
    Liquid::Failover::Tcp::runServerLoop($port);
} elsif ($use_serial) {
    $SERIAL_PID = $$;
    print "Listening on serial port device $serial_device\n";
    Liquid::Failover::Serial::runServerLoop($serial_device);
} else {
    print STDERR "Heartbeat disabled\n";
    exit(-1);
}

# Stop the other daemon, if any.
foreach my $p ($TCP_PID, $SERIAL_PID) {
    if (defined($p) && $p != $$) {
        kill('TERM', $p);
    }
}

Liquid::Failover::Pid::deletePidFile('lqhad');
