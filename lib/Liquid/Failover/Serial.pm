package Liquid::Failover::Serial;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(openSerialPort postRequest readRequest writeResponse
                runServerLoop);
use strict;
use Device::SerialPort;
use Liquid::Failover::Debug qw(debugOn);
use Liquid::Failover::Dispatcher qw(dispatch shutdownSignalled);

#
# Opens serial port at given device (e.g. /dev/ttyS0) for read/write.
# Returns Device::SerialPort object.  When done, call undef() on it.
#
sub openSerialPort($) {
    my $device = shift || '/dev/ttyS0';
    my $serial = new Device::SerialPort($device, 1, undef)             
        or die("Unable to open $device: $!");
    $serial->handshake("xoff");
    $serial->baudrate(9600);
    $serial->parity("odd");
    $serial->databits(8); 
    $serial->stopbits(1);
    $serial->buffers(4096, 4096);
    $serial->reset_error;
    #$serial->user_msg(ON);
    #$serial->error_msg(ON);
    #$serial->parity_enable(F);
    #$serial->debug(0);

    $serial->are_match("\n");
    return $serial;
}

sub readLine($$) {
    my ($serial, $timeout) = @_;
    if (!defined($timeout)) {
        $timeout = 5;    # default 5-second timeout
    }
    my $sleep_sec = 1;
    my $n = 0;
    my $max = $timeout / $sleep_sec;
    my $line;
    while (!$timeout || $n < $max) {
        $line = $serial->lookfor();
        if (!defined($line)) {
            print STDERR "Unable to read from serial port\n";
            return undef;
        } elsif ($line ne '') {
            last;
        }
        select(undef, undef, undef, $sleep_sec);
        $n++;
    }
    chomp($line);
    if (debugOn()) {
        print "$line\n";
    }
    return $line;
}

sub writeLine($$) {
    my ($serial, $msg) = @_;
    my $line = "$msg\n";
    my $bytes_written = $serial->write($line);
    if (!defined($bytes_written)) {
        print STDERR "Unable to write to serial port\n";
    } elsif ($bytes_written < length($line)) {
        print STDERR "Partial write to serial port: $bytes_written < " .
            length($line) . "\n";
    }
    if (debugOn()) {
        print $line;
    }
    return $bytes_written;
}

#
# Posts a request to server.  Returns response string sent by server.
#
sub postRequest($$;$) {
    my ($serial, $msg, $timeout) = @_;
    my $req = "REQUEST: $msg";
    my $bytes_written = writeLine($serial, $req);
    if (!defined($bytes_written)) {
        return undef;
    }
    my $n = 0;
    while ($n < 100) {
        my $line = readLine($serial, $timeout);
        if (!defined($line) || $line eq '') {
            return undef;
        } elsif ($line =~ /^RESPONSE: (.*)$/) {
            return $1;
        }
        $n++;
    }
    return undef;
}

#
# Posts a heartbeat request to server.  Returns 1 if service on server is up,
# 0 if server is running but service is down, undef if server didn't respond.
#
sub isUp($;$) {
    my ($serial, $msg, $timeout) = @_;
    my $resp = postRequest($serial, 'heartbeat', $timeout);
    if (defined($resp)) {
        if ($resp eq 'Yes') {
            return 1;
        } elsif ($resp eq 'No') {
            return 0;
        } else {
            print STDERR "Invalid serial heartbeat response: $resp\n";
        }
    }
    return undef;
}

#
# Reads a request sent by client.  Returns request content.
#
sub readRequest($) {
    my $serial = shift;
    while (1) {
        my $line = readLine($serial, 0);
        if (!defined($line)) {
            return undef;
        } elsif ($line =~ /^REQUEST: (.*)$/) {
            return $1;
        }
    }
}

#
# Writes a response to client.  Returns number of bytes written.
#
sub writeResponse($$) {
    my ($serial, $msg) = @_;
    my $resp = "RESPONSE: $msg";
    my $bytes_written = writeLine($serial, $resp);
    return $bytes_written;
}

sub runServerLoop($) {
    my $device = shift;
    my $serial = openSerialPort($device);
    while (1) {
        my $req = readRequest($serial);
        last if (!defined($req));
        my $resp = dispatch($req);
        writeResponse($serial, $resp);
        if (shutdownSignalled()) {
            last;
        }
    }
    undef($serial);
}

1;
