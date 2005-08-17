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
