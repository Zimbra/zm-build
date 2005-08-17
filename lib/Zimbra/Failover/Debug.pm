package Zimbra::Failover::Debug;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(setDebug debugOn);

use strict;

my $DEBUG = 0;

sub setDebug($) {
    my $flag = shift;
    $DEBUG = $flag ? 1 : 0;
}

sub debugOn() {
    return $DEBUG;
}

1;
