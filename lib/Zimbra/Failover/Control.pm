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
package Zimbra::Failover::Control;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(relinquish
                stopFailedMaster
                abortFailedMaster
                zmcontrol
                isServiceRunning);

use strict;
use Zimbra::Failover::Debug qw(debugOn);
use Zimbra::Failover::Config;
use Zimbra::Failover::IPUtil;
use Zimbra::Failover::SoapToTomcat;
use Zimbra::Failover::Db;

sub zmcontrol(;$) {
    my $args = shift || '';
    my $cmd = Zimbra::Failover::Config::getZimbraHome() . "/zimbramon/zmcontrol $args";
print "ZMCONTROL: Invoking $cmd\n";
    `$cmd`;
    return $? >> 8 == 0 ? 1 : 0;
}

sub startService() {
    if (debugOn()) {
        print "Starting service...\n";
    }
    zmcontrol('start');
    # TODO: Wait until startup is complete.
    return 1;
}

sub stopService() {
    if (debugOn()) {
        print "Stopping service...\n";
    }
    zmcontrol('stop');
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
        Zimbra::Failover::Config::getZimbraHome() . "/log/tomcat.pid";
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
    my $ip = Zimbra::Failover::Config::getServiceIP();
    Zimbra::Failover::IPUtil::relinquishIP($ip);
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
        Zimbra::Failover::Config::getZimbraHome() .
        "/libexec/zmreplcmd -c takeover";
    my $rc = system($cmd);
    if ($rc != 0) {
        $rc >>= 8;
        print STDERR "Unable to send BecomeMaster command to tomcat: $!\n";
        print STDERR "(zmreplcmd returned with $rc)\n";
        return 0;
    }

    # Tomcat will do IP takeover as part of BecomeMaster procedure,
    # so there is no need for this script to takeover IP.

    return 1;
}

1;
