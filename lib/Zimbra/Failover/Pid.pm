# 
# ***** BEGIN LICENSE BLOCK *****
# Version: ZPL 1.1
# 
# The contents of this file are subject to the Zimbra Public License
# Version 1.1 ("License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://www.zimbra.com/license
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations
# under the License.
# 
# The Original Code is: Zimbra Collaboration Suite.
# 
# The Initial Developer of the Original Code is Zimbra, Inc.
# Portions created by Zimbra are Copyright (C) 2005 Zimbra, Inc.
# All Rights Reserved.
# 
# Contributor(s):
# 
# ***** END LICENSE BLOCK *****
# 
package Zimbra::Failover::Pid;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(createPidFile appendPidFile deletePidFile);
use strict;
use Zimbra::Failover::Config;

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
    my $zmhome = Zimbra::Failover::Config::getZimbraHome();
    return "$zmhome/log/$appname.pid";
}

1;
