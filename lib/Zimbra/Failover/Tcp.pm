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
package Zimbra::Failover::Tcp;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(connectTo disconnect postRequest runServerLoop);
use strict;
use Net::Telnet();
use IO::Socket::INET;
use Zimbra::Failover::Debug qw(debugOn);
use Zimbra::Failover::Dispatcher qw(dispatch shutdownSignalled);

sub connectTo($$) {
    my ($host, $port) = @_;
    my $conn = new Net::Telnet(Host => $host,
                               Port => $port,
                               Timeout => 10,
                               Telnetmode => 0,
                               Binmode => 1,
                               Errmode => 'return');
    if (!$conn) {
        print STDERR "Unable to connect to $host:$port\n";
    }
    return $conn;
}

sub disconnect($) {
    my $conn = shift;
    if (defined($conn)) {
        $conn->close();
    }
}

sub reconnect($) {
    my $conn = shift;  # Net::Telnet object
    my $ok = $conn->open();
    if (!$ok) {
        print STDERR "Unable to reconnect to " . $conn->host() . ":" .
            $conn->port() . "\n";
    }
    return $ok;
}

sub postRequest($$) {
    my ($conn, $msg) = @_;
    my $req = "REQUEST: $msg";
    if (debugOn()) {
        print "$req\n";
    }

    my $ok = $conn->print($req);
    if (!$ok) {
        print STDERR "Unable to send command\n";
        $ok = reconnect($conn);
        if ($ok) {
            if (debugOn()) {
                print "Reconnected\n";
            }
            $ok = $conn->print($req);
        }
        if (!$ok) {
            return undef;
        }
    }
    my $resp = $conn->getline();
    if (!defined($resp)) {
        if ($conn->eof()) {
            print STDERR "Connection reset by server\n";
        } else {
            print STDERR "Error: " . $conn->errmsg() . "\n";
        }
        return undef;
    }
    chomp($resp);
    if (debugOn()) {
        print "$resp\n";
    }
    if ($resp =~ /^RESPONSE: (.*)/) {
        $resp = $1;
    } else {
        print STDERR "Invalid response $resp\n";
        $resp = undef;
    }
    return $resp;
}

#
# Posts a heartbeat request to server.  Returns 1 if service on server is up,
# 0 if server is running but service is down, undef if server didn't respond.
#
sub isUp($) {
    my $serial = shift;
    my $resp = postRequest($serial, 'heartbeat');
    if (defined($resp)) {
        if ($resp eq 'Yes') {
            return 1;
        } elsif ($resp eq 'No') {
            return 0;
        } else {
            print STDERR "Invalid TCP heartbeat response: $resp\n";
        }
    }
    return undef;
}

sub runServerLoop($) {
    my $port = shift;
    my $server = IO::Socket::INET->new(LocalPort=> $port,
                                       Type=> SOCK_STREAM,
                                       Reuse=> 1,
                                       Listen=> SOMAXCONN)
        or die("Unable to listen on port $port: $!");

    my $client;
    while ($client = $server->accept()) {
        if (debugOn()) {
            print "Accepted new connection from " . $client->peerhost() . "\n";
        }
        my $line;
        while (defined($line = <$client>)) {
            if (debugOn()) {
                print $line;
            }
            chomp($line);
            my $resp;
            if ($line =~ /^REQUEST: (.*)$/) {
                my $req = $1;
                $resp = dispatch($req);
            } else {
                $resp = "Invalid request line: $line";
            }
            print $client "RESPONSE: $resp\n";
            if (debugOn()) {
                print "RESPONSE: $resp\n";
            }
            if (shutdownSignalled()) {
                close($client);
                return;
            }
        }
        if (debugOn()) {
            print "Client disconnected\n";
        }
        close($client);
    }
}

1;
