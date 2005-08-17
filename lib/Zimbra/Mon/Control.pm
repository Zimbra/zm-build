#!/usr/bin/perl

package liquidControl;

use strict;

use lib "/opt/liquid/liquidmon/lib";
use lib "/opt/liquid/liquidmon/lib/liquidpm";

use liquidlog;
use liquidCluster;
use host;
use service;
use application;
use Net::Telnet;

require Exporter;

my @ISA = qw(Exporter);

my %servicestartorder = (
	'maintenance'		=>  0,
	'ldap'      		=>  1,
	'snmp'    			=>  2,
	'antivirus' 		=>	3,
	'antispam'  		=>	4,
	'mailbox'   		=>  5,
	'mta'     			=>  6
);

my %startorder = (
	'ldap'      	=>  1,
	'swatch'    	=>  2,
	'mysql'     	=>  3,
	'amavisd'		=>	4,
	'clamd'			=>	5,
	'spamassassin'	=>	6,
	'convertd'  	=>  7,
	'tomcat'    	=>  8,
	'saslauthd'   	=>  9,
	'mtaconfig'   	=>  10,
	'postfix'   	=>  11
);

sub killChildren {
	liquidlog::Log( "info", "SIGINT - kill children" );
	$SIG{CHLD} = 'IGNORE';
	kill( 15, 0 );
}

sub ldapRunsHere {
	my $ldaphost = `lqlocalconfig -m nokey ldap_host`;
	my $hostname = `lqlocalconfig -m nokey liquid_server_hostname`;
	chomp $ldaphost;
	chomp $hostname;

	return ($hostname eq $ldaphost);
}

sub getLocalServices {
	my $hostname = `lqlocalconfig -m nokey liquid_server_hostname`;
	chomp $hostname;
	my $services = `lqprov gs $hostname 2> /dev/null | grep liquidServiceEnabled: `;
	$services =~ s/liquidServiceEnabled://g;
	@::localservices = split (' ', $services);
	@::localservices = sort { $servicestartorder{$a} <=> $servicestartorder{$b}} @::localservices;
}

sub setLocalServices {
	my $hostname = `lqlocalconfig -m nokey liquid_server_hostname`;
	chomp $hostname;
	my $serstr = join " liquidServiceEnabled ", @::localservices;
	$serstr = "liquidServiceEnabled ".$serstr;
	`lqprov ms $hostname $serstr 2> /dev/null`;
}

sub isMaintenanceMode {
	my $ret;

	my $maint = `lqlocalconfig -m nokey liquid_maintenance_mode 2> /dev/null`;
	chomp $maint;
	if ($maint eq "" || $maint eq "false" ) {
		$ret = 0;
	} else {
		$ret = 1;
	}
	getLocalServices();
	if ($#::localservices < 0) {
		# LDAP probably not available, stick with local info.
		return $ret;
	}
	$maint = grep /maintenance/, @::localservices;
	return $maint;
}

sub setMaintenance {
	getLocalServices();
	my $mode = shift;
	if ($mode eq "on" || $mode eq "true" || $mode == 1) {
		`lqlocalconfig -e liquid_maintenance_mode=true`;
		push @::localservices, "maintenance";
	} elsif ($mode eq "off" || $mode eq "false" || $mode == 0) {
		`lqlocalconfig -e liquid_maintenance_mode=false`;
		@::localservices = grep !/maintenance/, @::localservices;
	} else {
		return 1;
	}
	@::localservices = sort { $servicestartorder{$a} <=> $servicestartorder{$b}} @::localservices;
	setLocalServices();
	return 0;
}

sub startServices {
	my $s;
	my $r = "Started";
	my $t = "Not Started";

	if (ldapRunsHere()) {
		liquidlog::Log( "crit", "STARTING ldap" );
		if (startOneService("ldap")) {
			$r = $r." ldap";
		}
		else {
			$t = $t." ldap";
			liquidlog::Log( "crit", "ldap FAILED to start - exiting" );
			exit 1;
		}
		sleep 3;
	}
	getLocalServices();
	liquidlog::Log( "crit", "STARTING services" );
	foreach $s (@::localservices) {
		if ($s eq "maintenance" || $s eq "ldap") { next; }
		liquidlog::Log( "crit", "STARTING $s" );
		if (startOneService($s)) {
			$r = $r." ".$s;
		}
		else {
			$t = $t." ".$s;
		}
	}
	if ($r eq "Started") {
		return $t;
	} elsif ($t eq "Not Started") {
		return $r;
	} else {
		return "$r - $t";
	}
	# update when everything is running.
	$::Cluster->getHostsFromLdap();
}

sub stopServices {
	liquidlog::Log( "crit", "STOPPING services" );
	my $r = "Stopped";
	my $t = "Not Stopped";
	getLocalServices();
	foreach my $n (reverse @::localservices) {
		my $s = getServiceByName ($n);
		stopOneService( $s->{name} );
		# liquidlog::Log( "crit", "Waiting for $s->{name} to stop" );
	}
}

sub isAppRunning {
	my $appName = shift;
	my $status  = $::StatusStopped;

	my $retval = runSyntaxCommand( "liquidsyntax", "$appName" . "_status" );
	if ($retval) {
		$status = $::StatusStopped;
	}
	else {
		$status = $::StatusRunning;
	}

	return ( $status == $::StatusRunning );
}

sub killOneApplication {
	my ($s) = (@_);

	my $name;
	if ( ref($s) ) { $name = $s->{name}; }
	else { $name = $s }
	liquidlog::Log( "info", "kill app $name" );

	#	if ( isAppRunning($name) ) {
	my $t = getDateStamp();
	$::children{$name}{STOP} = $t;
	delete $::children{$name}{START};

	if (exists ($::syntaxes{"liquidsyntax"}{$name."_kill"})) {
		runSyntaxCommand( "liquidsyntax", "$name" . "_kill" );
	} else {
		liquidlog::Log( "err", "No kill command defined for $name" );
		stopOneApplication ($name);
	}

	#	}
	#	else {
	#		liquidlog::Log( "err", "Can't stop unstarted app $name" );
	#	}
}

sub stopOneApplication {
	my ($s) = (@_);

	my $name;
	if ( ref($s) ) { $name = $s->{name}; }
	else { $name = $s }
	liquidlog::Log( "info", "stop app $name" );

	#	if ( isAppRunning($name) ) {
	my $t = getDateStamp();
	$::children{$name}{STOP} = $t;
	delete $::children{$name}{START};

	runSyntaxCommand( "liquidsyntax", "$name" . "_stop" );
}

sub getServiceByName {
	my $s = shift;

	foreach (@::services) {
		if ($_->{name} eq $s) {return $_;}
	}
	return undef;
}

sub stopOneService {
	my ($s) = (@_);

	my $name;
	if ( ref($s) ) { $name = $s->{name}; }
	else { $name = $s; $s = getServiceByName ($name); }
	liquidlog::Log( "info", "stop service $name" );
	foreach my $a (@{$s->{apps}}) {
		stopOneApplication ($a);
		if ( isAppRunning( $a ) ) {
			sleep 2;
			if ( isAppRunning( $a ) ) {
				stopOneApplication ($a);
				if ( isAppRunning( $a ) ) {
					sleep 4;
					if ( isAppRunning( $a ) ) {
						killOneApplication($a);
					}
				}
			}
		}
		if (! isAppRunning( $a ) ) {
			liquidlog::Log( "crit", "$a successfully stopped" );
		} else {
			liquidlog::Log( "crit", "FAILED to stop $a" );
		}
	}
	return 1;
}

sub startOneService {
	my ($s) = (@_);

	my $name;
	if ( ref($s) ) { $name = $s->{name}; }
	else { $name = $s; $s = getServiceByName ($name); }
	liquidlog::Log( "info", "start service $name" );
	foreach my $a (@{$s->{apps}}) {
		startOneApplication ($a);
	}
	return 1;
}

sub startOneApplication {
	my ($s) = (@_);

	my $name;
	if ( ref($s) ) { $name = $s->{name}; }
	else { $name = $s }
	liquidlog::Log( "info", "start app $name" );
	if ( isAppRunning($name) ) {
		liquidlog::Log( "err", "Can't start running app $name" );
		return;
	}

	my $t = getDateStamp();
	liquidlog::Log( "info", "Starting child $name: ($t)" );
	my $re = runSyntaxCommand( "liquidsyntax", "$name" . "_start" );
	for (my $i = 0; $i < 100; $i++) {
		if (isAppRunning($name)) {
			return 1;
		}
		sleep 2;
	}

	return (isAppRunning($name));
}

sub removePid {
	my $pfile = "$::FifoDir/lq.pid";
	if ( -f $pfile ) {
		unlink $pfile;
	}
}

sub runSyntaxCommand {
	my $syn = shift;
	my $cmd = shift;

	my $monitorHost = shift;

	liquidlog::Log( "debug", "::runSyntaxCommand $syn $cmd" );
	my @syscmds = ();
	my $retval  = "";

	if ( $cmd =~ /_info$/ ) {
		foreach ( @{ $::syntaxes{$syn}{$cmd} } ) {
			push @syscmds, $_;
		}
	}
	else {
		$syscmds[0] = $::syntaxes{$syn}{$cmd};
	}

	my $syscmd;
	foreach $syscmd (@syscmds) {

		# liquidlog::Log ("crit", "RUN: $syscmd");
		# Separate items by newline
		if ( $retval ne "" ) { $retval .= "\n"; }

		# Possible parsing:
		if ( $syscmd =~ /^HTTP/ ) {
			my ( undef, $method, $host, $path, $sregex, $realm, $user, $pass ) =
			  split( ' ', $syscmd );
			if (defined $monitorHost) { $host =~ s/localhost/$monitorHost/; }
			$realm =~ s/_/ /g;
			my $uri = "http://$host$path";
			liquidlog::Log( "debug", "HTTP REQUEST: $uri as $user with $pass in $realm");

			my $r = HTTP::Request->new( $method, $uri );
			my $ua = LWP::UserAgent->new();
			$ua->credentials( $host, "$realm", $user, $pass );
			my $resp = $ua->request($r);
			if ( $cmd =~ /_status$/ ) {
				$retval = $::StatusStopped;
				if ( $resp->is_success ) {
					my @resplines = split '\n', $resp->content;

					foreach (@resplines) {
						if (/$sregex/) { $retval = $::StatusRunning; last; }
					}
				}
				else {
					liquidlog::Log( "debug",
						"HTTP RESPONSE: FAILURE: " . $resp->status_line );
					$retval = $::StatusStopped;
				}
			}
			elsif ( $cmd =~ /_info$/ ) {
				if ( $resp->is_success ) {
					my $good = 0;
					my @resplines = split '\n', $resp->content;
					foreach (@resplines) {
						if (/$sregex/) { $good = 1; last; }
					}
					if ($good) {
						$retval .= $resp->content;
						chomp $retval;
					}
				}
				else {
					liquidlog::Log( "debug",
						"HTTP RESPONSE: FAILURE: " . $resp->status_line );
				}
			}
		} elsif ($syscmd  =~ /^SMTP/ ) {
				$retval = $::StatusStopped;
				my $h = 'localhost';
				if (defined $monitorHost) {$h = $monitorHost;}

				my $t = new Net::Telnet (Timeout => 10, Port=>25);
				$t->errmode("return");
				$t->open($h);
				my ($prematch, $match) = $t->waitfor('/^220/');

				if ($t->errmsg() ne "") {
					liquidlog::Log( "err",
						"SMTP RESPONSE: FAILURE from $h: " . $t->errmsg() );
				} else {
					$t->print("quit\n");
					$retval = $::StatusRunning;
				}

		} else {
			if (defined ($monitorHost) ) {
				return undef;
			}
			# This overrides the handler in liquidDaemon.pm
			local $SIG{CHLD} = 'DEFAULT';
			local $SIG{ALRM} = \&handleSignal;
			alarm(23);
			my $f = 256;
			$f = system("$syscmd > /dev/null 2>&1");
			alarm(0);

			$retval .= $f >> 8;
		}
	}
		# liquidlog::Log ("crit", "RUN: $syscmd $retval");
	return $retval;
}

sub getDateStamp {
    my $ds = `date +%Y%m%d%H%M%S`;
	chomp $ds;
	return $ds;
}

sub loadConfig {
	my $configfile = shift;
	my @lines;
	open CF, $configfile or die "Can't open $configfile: $!";
	@lines = <CF>;
	close CF;
	foreach (@lines) {
		(/^\s*$/)   && next;
		(/^\s*#.*/) && next;

		if (/^APPLICATION/) {
			my %app;
			( $app{NAME}, $app{EXE}, $app{ARGS}, $app{MD}, $app{LBL} ) = 
				( m/^APPLICATION\s+(\S+)\s+(\S+)\s+"([^"]+)"\s+(\S+)\s+"([^"]+)".*$/);
			my $a =
				new application( $app{NAME}, $app{EXE}, $app{ARGS}, $app{MD}, $app{LBL} );
			push( @::applications, $a );
		}
		elsif (/^SERVICE/) {
			my ( $name, $label, $app) =
				(m/^SERVICE\s+(\S+)\s+"([^"]+)"\s+(\S+)/);
			my $s = new service( $name, $label, $app);
			push( @::services, $s );
		}
		elsif (/^CONTROL_SYNTAX/) {
			my ( $name, $cmd, $args ) =
			(m/^CONTROL_SYNTAX\s+(\S+)\s+(\S+)\s+"([^"]+)"/);
			if ( $cmd =~ /_info$/ ) {
				push @{ $::syntaxes{$name}{$cmd} }, $args;
			}
			else {
				$::syntaxes{$name}{$cmd} = $args;
			}
		}
		elsif (/^PORT/) {
			( undef, $::controlport ) = split;
		}
		else {
			liquidlog::Log( "err", "Unknown config directive: $_" );
		}
	}
	@::applications = sort { $startorder{lc($a->{name})} <=> $startorder{lc($b->{name})} } @::applications;
	foreach my $s (@::services) {
		@{$s->{apps}} = sort  { $startorder{$a} <=> $startorder{$b}} @{$s->{apps}};
	}
}

1
