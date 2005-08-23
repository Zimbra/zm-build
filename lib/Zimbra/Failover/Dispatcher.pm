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
package Zimbra::Failover::Dispatcher;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(dispatch shutdownSignalled);
use strict;
use Zimbra::Failover::Monitoring qw(isServiceAvailable);
use Zimbra::Failover::Control qw(relinquish
                                 stopFailedMaster
                                 abortFailedMaster);

my $SHUTDOWN = 0;

sub dispatch($) {
    my $req = shift;
    my $resp;
    if ($req eq 'heartbeat') {
        my $avail = isServiceAvailable();
        $resp = $avail ? "Yes" : "No";
    } elsif ($req eq 'relinquish') {
        relinquish();
        $resp = "OK";
    } elsif ($req eq 'stop') {
        stopFailedMaster();
        $resp = "OK";
        $SHUTDOWN = 1;
    } elsif ($req eq 'abort') {
        abortFailedMaster();
        $resp = "OK";
        $SHUTDOWN = 1;
    } else {
        $resp = "Unknown request: $req";
    }
    return $resp;
}

sub shutdownSignalled() {
    return $SHUTDOWN;
}

1;
