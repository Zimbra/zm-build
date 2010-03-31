#!/usr/bin/perl

package ZmClient;

use IPC::Open2;
use IO::Handle;
use Net::HTTP;
use LWP::UserAgent;
use HTTP::Request;

$SIG{CHLD} = 'IGNORE'; # PvZ ftw

my $zmprov_exe = '/opt/zimbra/bin/zmprov';
my %zmprov = ();
my %zmprovl = ();
my $zmmailbox_exe = '/opt/zimbra/bin/zmmailbox';
my %zmmailbox = ();
my %authTokens = ();

sub init() {
    $zmprov_exe = '/opt/zimbra/bin/zmprov';
    %zmprov = ();
    $zmmailbox_exe = '/opt/zimbra/bin/zmmailbox';
    %zmmailbox = ();
    %authTokens = ();
}

sub initZmprovSoap() {
    my $buf;
    return if (exists $zmprov{'pid'} && kill(0, $zmprov{'pid'}));
    $zmprov{'pid'} = open2(
            $zmprov{'in'}, $zmprov{'out'}, "$zmprov_exe 2>&1 ") || die "$!";

	eval {
		local $SIG{ALRM} = sub { die "alarm\n" };
		alarm(60); # avoid timeouts when mailstore is down
		do { # this part, we can ignore
			sysread($zmprov{'in'}, $buf, 8192);
		} while ($buf !~ /^prov> $/osm);
		alarm(0); 
	};
}

sub initZmprovLdap() {
    my $buf;
    return if (exists $zmprovl{'pid'} && kill(0, $zmprovl{'pid'}));
    $zmprovl{'pid'} = open2(
            $zmprovl{'in'}, $zmprovl{'out'}, "$zmprov_exe -l 2>&1 ") || die "$!";

	eval {
		local $SIG{ALRM} = sub { die "alarm\n" };
		alarm(60); # avoid timeouts when ldap is down
		do { # this part, we can ignore
			sysread($zmprovl{'in'}, $buf, 8192);
		} while ($buf !~ /^prov> $/osm);
		alarm(0); 
	};
}

sub initZmprov() {
	initZmprovSoap();
	initZmprovLdap();
}

sub sendZmprovRequestSoap($) {
    my $cmd = shift @_;
    my $buf;
    initZmprovSoap unless (exists $zmprov{'pid'} && kill(0, $zmprov{'pid'}));
    die "zmprov not initialized" if (!exists $zmprov{'out'});
    $zmprov{'out'}->print($cmd . "\n");
    my @lines = ();
    my $needs_join = 0;

    do {
        sysread($zmprov{'in'}, $buf, 8192);
        my @newlines = split(/\n/, $buf);

        if ($needs_join) {
            $lines[$#lines] .= shift @newlines if @newlines > 0;
            $needs_join = 0;
        }

        $needs_join = 1 if ($buf !~ /\n$/osm);

        push(@lines, @newlines);
    } while ($buf !~ /^prov> $/osm);
    pop @lines if ($lines[$#lines] =~ /^prov> $/osm);
    wantarray ? @lines : join("\n", @lines);
}

sub sendZmprovRequestLdap($) {
    my $cmd = shift @_;
    my $buf;
    initZmprovLdap unless (exists $zmprovl{'pid'} && kill(0, $zmprovl{'pid'}));
    die "zmprovl not initialized" if (!exists $zmprovl{'out'});
    $zmprovl{'out'}->print($cmd . "\n");
    my @lines = ();
    my $needs_join = 0;

    do {
        sysread($zmprovl{'in'}, $buf, 8192);
        my @newlines = split(/\n/, $buf);

        if ($needs_join) {
            $lines[$#lines] .= shift @newlines if @newlines > 0;
            $needs_join = 0;
        }

        $needs_join = 1 if ($buf !~ /\n$/osm);

        push(@lines, @newlines);
    } while ($buf !~ /^prov> $/osm);
    pop @lines if ($lines[$#lines] =~ /^prov> $/osm);
    wantarray ? @lines : join("\n", @lines);
}

sub sendZmprovRequest($) {
    my $cmd = shift @_;
	my @lines;
	if ($cmd =~ m/\s*-l/) {
		$cmd =~ s/\s*-l//;
		@lines = sendZmprovRequestLdap($cmd);
	} else {
		@lines = sendZmprovRequestSoap($cmd);
	}
    wantarray ? @lines : join("\n", @lines);
}

1;
