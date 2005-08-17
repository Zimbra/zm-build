package Liquid::Failover::IPUtil;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(getIPStatus takeoverIP relinquishIP
                getEntryByDevice getEntryByIP getEntryByMAC
                getRemoteMACByARP isPingable);
use strict;
use Liquid::Failover::Debug qw(debugOn);
use Liquid::Failover::Config;

my %LOCAL_ADDRESSES = ();

my $IFCONFIG = 'ifconfig';
my $ARPING = 'arping';
my $SEND_ARP = Liquid::Failover::Config::getLiquidHome() . '/libexec/send_arp';
my $PING = 'ping';

#
# Returns hash of ([device], {MAC => [MAC], IP => [IP]}) for all local IPv4
# addresses.  Loopback address (127.0.0.1) is excluded.
# e.g. ("eth0", {MAC => "00:01:02:03:04:05", IP => "192.168.0.1"})
#
sub getLocalAddresses() {
    if (scalar(keys %LOCAL_ADDRESSES) > 0) {
        return %LOCAL_ADDRESSES;
    }

    if (!open(IFCONFIG, "$IFCONFIG |")) {
        print STDERR "Unable to run $IFCONFIG\n";
        return %LOCAL_ADDRESSES;
    }
    my $line;
    my ($device, $MAC);
    while (defined($line = <IFCONFIG>)) {
        if ($line =~ /^([^\s]+)/) {
            $device = $1;
            if ($line =~ /HWaddr ([\da-fA-F:]+)/) {
                $MAC = uc($1);
            }
        } elsif ($line =~ /^\s+inet addr:([\d\.]+)/) {
            my $ip = $1;
            if ($ip ne '127.0.0.1' && defined($device) && defined($MAC)) {
		$LOCAL_ADDRESSES{$device} = {MAC => $MAC, IP => $1};
		($device, $MAC) = (undef, undef);
	    }
        }
    }
    close(IFCONFIG);
    return %LOCAL_ADDRESSES;
}

#
# Returns local address entry matching the lookup key.  Lookup can be done
# by device name, MAC address, or IP address.
#
# Examples:
#
# $entry = getLocalAddressEntry(DEVICE => 'eth0');
# $entry = getLocalAddressEntry(MAC => '01:02:03:04:05:06');
# $entry = getLocalAddressEntry(IP => '192.168.0.1');
#
# Returned entry is a reference to a hash whose keys are DEVICE, MAC, and IP.
# Returns undef if no entry is found.
#
sub getLocalAddressEntry($$) {
    my ($lookupType, $key) = @_;
    my %addrs = getLocalAddresses();
    if ($lookupType eq 'DEVICE') {
        my $entry = $addrs{$key};
        if (defined($entry)) {
            return {DEVICE=> $key,
                    MAC => $entry->{MAC},
                    IP => $entry->{IP}};
        }
    } elsif ($lookupType eq 'MAC' || $lookupType eq 'IP') {
        $key = uc($key);
        foreach my $device (keys %addrs) {
            my $entry = $addrs{$device};
            if ($entry->{$lookupType} eq $key) {
                return {DEVICE => $device,
                        MAC => $entry->{MAC},
                        IP => $entry->{IP}};
            }
        }
    }
    return undef;
}

#
# Returns MAC address for given IP, looked up via ARP.  Must be root to call
# this subroutine, which invokes arping command.
#
sub getRemoteMACByARP($$$) {
    my ($srcdevice, $srcip, $destip) = @_;
    my $cmd = "sudo $ARPING -c 1 -I $srcdevice -s $srcip $destip | grep '^Unicast reply from '";
    my $output = `$cmd`;
    my $mac;
    if ($output =~ /\[([\da-fA-F:]+)\]/) {
        $mac = $1;
    }
    return $mac;
}

#
# Is host alive and pingable?
#
sub isPingable($$) {
    my ($srcIP, $targetIP) = @_;
    my $cmd = "$PING -c 1 -W 1 -I $srcIP $targetIP > /dev/null";
    my $rc = system($cmd);
    return $rc == 0 ? 1 : 0;
}

#
# Reports the status of IP address.  Returns status string as follows:
#
# "local" - local host owns IP address
# "remote" - another host on subnet claims IP address
# "conflict" - both local host and another host on subnet claim IP address
# "non-subnet" - IP is alive and is not on subnet
# "offline" - IP is not alive and no one claims it
#
# Must be root to call this subroutine.
#
sub getIPStatus($) {
    my $serviceIP = shift;
    my ($ifconfigSaysLocal, $arpSaysRemote, $pingable) = (0, 0, 0);

    # Repeat the check with each local interface as source interface.
    my %addresses = getLocalAddresses();
    foreach my $device (keys %addresses) {
	my $ip = $addresses{$device}->{IP};

	if (!$ifconfigSaysLocal && $ip eq $serviceIP) {
	    $ifconfigSaysLocal = 1;
	}

	# ARP will tell you either IP is remote or not.  Non-remote means
	# either IP is local or no one has a claim on the IP.
	if (!$arpSaysRemote) {
	    my $ownerMAC_arp = getRemoteMACByARP($device, $ip, $serviceIP);
	    if (defined($ownerMAC_arp) &&
		!defined(getLocalAddressEntry(MAC => $ownerMAC_arp))) {
		$arpSaysRemote = 1;
	    }
	}

	if (!$pingable) {
	    $pingable = isPingable($ip, $serviceIP);
	}
    }

    if ($pingable) {
        if ($ifconfigSaysLocal && !$arpSaysRemote) {
            return 'local';
        } elsif (!$ifconfigSaysLocal && $arpSaysRemote) {
            return 'remote';
        } elsif ($ifconfigSaysLocal && $arpSaysRemote) {
            return 'conflict';
        } else {
            return 'non-subnet';
        }
    } else {
        return 'offline';
    }
}

sub takeoverIP($$$) {
    my ($device, $serviceIP, $routerIP) = @_;

    # Bring up the interface with service IP.
    my $ifconfig = "sudo $IFCONFIG $device $serviceIP";
    if (debugOn()) {
        print "$ifconfig\n";
    }
    `$ifconfig`;

    # Update ARP cache of hosts on the subnet with gratuitous ARP.
    my $entry = getLocalAddressEntry(DEVICE => $device);
    my $mac = $entry->{MAC};
    $mac =~ s/://g;
    my $send_arp = "sudo $SEND_ARP -i 1000 -r 2 -p /tmp/send_arp.pid $device $serviceIP $mac $serviceIP ffffffffffff";
    if (debugOn()) {
        print "$send_arp\n";
    }
    `$send_arp`;

    # Ping the router.  Hopefully ICMP will update its ARP cache if
    # gratuitous ARP was blocked as a security measure.
    my $srcIP = $entry->{IP};
    my $ping = "$PING -c 1 -W 5 -I $serviceIP $routerIP";
    if (debugOn()) {
        print "$ping\n";
    }
    `$ping`;
}

sub relinquishIP($) {
    my $serviceIP = shift;
    my $entry = getLocalAddressEntry(IP => $serviceIP);
    if (defined($entry)) {
        my $device = $entry->{DEVICE};
        my $ifconfig = "sudo $IFCONFIG $device down";
        if (debugOn()) {
            print "$ifconfig\n";
        }
        `$ifconfig`;
    } else {
        if (debugOn()) {
            print "IP $serviceIP is not up\n";
        }
    }
}

1;
