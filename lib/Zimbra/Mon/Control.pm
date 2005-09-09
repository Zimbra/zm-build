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
#!/usr/bin/perl

package Zimbra::Mon::Control;

use strict;

use lib "/opt/zimbra/zimbramon/lib";
use lib "/opt/zimbra/zimbramon/lib/Zimbra/Mon";

use Zimbra::Mon::Logger;
use Zimbra::Mon::Cluster;
use Zimbra::Mon::Host;
use Zimbra::Mon::Service;
use Zimbra::Mon::Application;
use Net::Telnet;

require Exporter;

my @ISA = qw(Exporter);

my %servicestartorder = (
	'maintenance'		=>  0,
	'ldap'      		=>  1,
	'logger'   			=>  2,
	'snmp'    			=>  3,
	'antivirus' 		=>	4,
	'antispam'  		=>	5,
	'mailbox'   		=>  6,
	'mta'     			=>  7
);

my %startorder = (
	'ldap'      	=>  1,
	'swatch'    	=>  2,
	'mysql'     	=>  3,
	'logmysql'     	=>  4,
	'amavisd'		=>	5,
	'clamd'			=>	6,
	'spamassassin'	=>	7,
	'convertd'  	=>  8,
	'tomcat'    	=>  9,
	'saslauthd'   	=>  10,
	'mtaconfig'   	=>  11,
	'postfix'   	=>  12
);

sub killChildren {
	Zimbra::Mon::Logger::Log( "info", "SIGINT - kill children" );
	$SIG{CHLD} = 'IGNORE';
	kill( 15, 0 );
}

sub ldapRunsHere {
	my $ldaphost = `zmlocalconfig -m nokey ldap_host`;
	my $hostname = `zmlocalconfig -m nokey zimbra_server_hostname`;
	chomp $ldaphost;
	chomp $hostname;

	return ($hostname eq $ldaphost);
}

sub getLocalServices {
	my $hostname = `zmlocalconfig -m nokey zimbra_server_hostname`;
	chomp $hostname;
	my $services = `zmprov gs $hostname 2> /dev/null | grep zimbraServiceEnabled: `;
	$services =~ s/zimbraServiceEnabled://g;
	@::localservices = split (' ', $services);
	@::localservices = sort { $servicestartorder{$a} <=> $servicestartorder{$b}} @::localservices;
}

sub setLocalServices {
	my $hostname = `zmlocalconfig -m nokey zimbra_server_hostname`;
	chomp $hostname;
	my $serstr = join " zimbraServiceEnabled ", @::localservices;
	$serstr = "zimbraServiceEnabled ".$serstr;
	`zmprov ms $hostname $serstr 2> /dev/null`;
}

sub isMaintenanceMode {
	my $ret;

	my $maint = `zmlocalconfig -m nokey zimbra_maintenance_mode 2> /dev/null`;
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
		`zmlocalconfig -e zimbra_maintenance_mode=true`;
		push @::localservices, "maintenance";
	} elsif ($mode eq "off" || $mode eq "false" || $mode == 0) {
		`zmlocalconfig -e zimbra_maintenance_mode=false`;
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
		Zimbra::Mon::Logger::Log( "info", "STARTING ldap" );
		if (startOneService("ldap")) {
			$r = $r." ldap";
		}
		else {
			$t = $t." ldap";
			Zimbra::Mon::Logger::Log( "crit", "ldap FAILED to start - exiting" );
			exit 1;
		}
		sleep 3;
	}
	getLocalServices();
	Zimbra::Mon::Logger::Log( "info", "STARTING services" );
	foreach $s (@::localservices) {
		if ($s eq "maintenance" || $s eq "ldap") { next; }
		Zimbra::Mon::Logger::Log( "info", "STARTING $s" );
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
	Zimbra::Mon::Logger::Log( "info", "STOPPING services" );
	my $r = "Stopped";
	my $t = "Not Stopped";
	getLocalServices();
	foreach my $n (reverse @::localservices) {
		my $s = getServiceByName ($n);
		stopOneService( $s->{name} );
		Zimbra::Mon::Logger::Log( "debug", "Waiting for $s->{name} to stop" );
	}
}

sub isAppRunning {
	my $appName = shift;
	my $status  = $::StatusStopped;

	my $retval = runSyntaxCommand( "zimbrasyntax", "$appName" . "_status" );
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
	Zimbra::Mon::Logger::Log( "info", "kill app $name" );

	#	if ( isAppRunning($name) ) {
	my $t = getDateStamp();
	$::children{$name}{STOP} = $t;
	delete $::children{$name}{START};

	if (exists ($::syntaxes{"zimbrasyntax"}{$name."_kill"})) {
		runSyntaxCommand( "zimbrasyntax", "$name" . "_kill" );
	} else {
		Zimbra::Mon::Logger::Log( "err", "No kill command defined for $name" );
		stopOneApplication ($name);
	}

}

sub stopOneApplication {
	my ($s) = (@_);

	my $name;
	if ( ref($s) ) { $name = $s->{name}; }
	else { $name = $s }
	Zimbra::Mon::Logger::Log( "info", "stop app $name" );

	#	if ( isAppRunning($name) ) {
	my $t = getDateStamp();
	$::children{$name}{STOP} = $t;
	delete $::children{$name}{START};

	runSyntaxCommand( "zimbrasyntax", "$name" . "_stop" );
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
	Zimbra::Mon::Logger::Log( "info", "stop service $name" );
	foreach my $a (reverse @{$s->{apps}}) {
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
			Zimbra::Mon::Logger::Log( "info", "$a successfully stopped" );
		} else {
			Zimbra::Mon::Logger::Log( "err", "FAILED to stop $a" );
		}
	}
	return 1;
}

sub startOneService {
	my ($s) = (@_);

	my $name;
	if ( ref($s) ) { $name = $s->{name}; }
	else { $name = $s; $s = getServiceByName ($name); }
	Zimbra::Mon::Logger::Log( "info", "start service $name" );
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
	Zimbra::Mon::Logger::Log( "info", "start app $name" );
	if ( isAppRunning($name) ) {
		Zimbra::Mon::Logger::Log( "err", "Can't start running app $name" );
		return;
	}

	my $t = getDateStamp();
	Zimbra::Mon::Logger::Log( "info", "Starting child $name: ($t)" );
	my $re = runSyntaxCommand( "zimbrasyntax", "$name" . "_start" );
	for (my $i = 0; $i < 100; $i++) {
		if (isAppRunning($name)) {
			return 1;
		}
		sleep 2;
	}

	return (isAppRunning($name));
}

sub removePid {
	my $pfile = "$::FifoDir/zm.pid";
	if ( -f $pfile ) {
		unlink $pfile;
	}
}

sub runSyntaxCommand {
	my $syn = shift;
	my $cmd = shift;

	my $monitorHost = shift;

	Zimbra::Mon::Logger::Log( "debug", "::runSyntaxCommand $syn $cmd" );
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

		# Separate items by newline
		if ( $retval ne "" ) { $retval .= "\n"; }

		# Possible parsing:
		if ( $syscmd =~ /^HTTP/ ) {
			my ( undef, $method, $host, $path, $sregex, $realm, $user, $pass ) =
			  split( ' ', $syscmd );
			if (defined $monitorHost) { $host =~ s/localhost/$monitorHost/; }
			$realm =~ s/_/ /g;
			my $uri = "http://$host$path";
			Zimbra::Mon::Logger::Log( "debug", "HTTP REQUEST: $uri as $user with $pass in $realm");

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
					Zimbra::Mon::Logger::Log( "err",
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
					Zimbra::Mon::Logger::Log( "err",
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
					Zimbra::Mon::Logger::Log( "err",
						"SMTP RESPONSE: FAILURE from $h: " . $t->errmsg() );
				} else {
					$t->print("quit\n");
					$retval = $::StatusRunning;
				}

		} else {
			if (defined ($monitorHost) ) {
				return undef;
			}
			# This overrides the handler in Zimbra::Mon::Daemon.pm
			local $SIG{CHLD} = 'DEFAULT';
			local $SIG{ALRM} = \&handleSignal;
			alarm(23);
			my $f = 256;
			$f = system("$syscmd > /dev/null 2>&1");
			alarm(0);

			$retval .= $f >> 8;
		}
	}
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

			# Should have used a hash...
			my $found = 0;
			for (my $S = 0; $S <= $#::services; $S++) {
				if ($::services[$S]->{name} eq $s->{name}) {
					$::services[$S] = $s;
					$found = 1;
					last;
				}
			}
			if (!$found) {
				push( @::services, $s );
			}

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
			Zimbra::Mon::Logger::Log( "err", "Unknown config directive: $_" );
		}
	}
	@::applications = sort { $startorder{lc($a->{name})} <=> $startorder{lc($b->{name})} } @::applications;
	foreach my $s (@::services) {
		@{$s->{apps}} = sort  { $startorder{$a} <=> $startorder{$b}} @{$s->{apps}};
	}
}

1
