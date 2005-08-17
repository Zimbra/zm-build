package Liquid::Failover::Pid;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(createPidFile appendPidFile deletePidFile);
use strict;
use Liquid::Failover::Config;

sub createPidFile($) {
    my $appname = shift;
    my $pidfile = _getPidFilePath($appname);
    if (-e $pidfile) {
        print STDERR "Overwriting existing pid file for $appname\n";
    }
    open(PIDFILE, "> $pidfile") or die "Unable to create pid file $pidfile";
    print PIDFILE $$ . "\n";
    close(PIDFILE);
}

sub appendPidFile($) {
    my $appname = shift;
    my $pidfile = _getPidFilePath($appname);
    open(PIDFILE, ">> $pidfile")
        or die "Unable to open pid file $pidfile for append";
    print PIDFILE $$ . "\n";
    close(PIDFILE);
}

sub deletePidFile($) {
    my $appname = shift;
    my $pidfile = _getPidFilePath($appname);
    if (-e $pidfile) {
        unlink($pidfile);
    }
}

sub readPidFile($) {
    my $appname = shift;
    my $pidfile = _getPidFilePath($appname);
    my @pids;
    if (! -e $pidfile) {
        return wantarray ? @pids : undef;
    }

    if (open(PIDFILE, "< $pidfile")) {
        my $pid;
        while (defined($pid = <PIDFILE>)) {
            chomp($pid);
            if ($pid =~ /^\d+$/) {
                push(@pids, $pid);
            }
        }
        close(PIDFILE);
        return wantarray ? @pids : $pids[0];
    } else {
        print STDERR "Unable to read pid file $pidfile: $!\n";
        return wantarray ? @pids : undef;
    }
}

sub isRunning($) {
    my $pid = shift;
    if (defined($pid) && $pid =~ /^\d+$/) {
        my $cmd = "ps -ef | grep ' $pid ' | grep -v grep";
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

sub _getPidFilePath($) {
    my $appname = shift;
    my $lqhome = Liquid::Failover::Config::getLiquidHome();
    return "$lqhome/log/$appname.pid";
}

1;
