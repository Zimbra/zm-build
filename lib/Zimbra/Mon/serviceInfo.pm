#!/usr/bin/perl

package Zimbra::serviceInfo;

use strict;

use Zimbra::Logger;

use FileHandle;

my $NUM_ITEMS = 50;

require Exporter;

my @ISA = qw(Exporter);

sub new
{
	my ($class, $host) = @_;
	return $class if ref ($class);
	
	my $self = bless {},  $class;
	
	if (defined $host) {
		if (ref ($host)) {
			$self->{host} = $host;
		} else {
			$self->{host} = $::Cluster->getHostByName($host);
		}
	}
	
	$self->{uts} = 0;

	$self->{serviceDir} = "$::Basedir/service";
	
	$self->{lastFileName} = "";
	
#	if (defined $host) {
#		Zimbra::Logger::Log ("debug","Created Zimbra::serviceInfo for host ".$self->{host}->{name});
#	} else {
#		Zimbra::Logger::Log ("debug","Created Zimbra::serviceInfo");
#	}
	return $self;
}

sub readServiceInfo
{
#	Zimbra::Logger::Log ("debug","readServiceInfo");
	# readServiceInfo reads info written by Zimbra::StatusMon
	my $self = shift;
	
	# Race condition fun - make sure the file we're reading doesn't get wiped.
	my $done = 0;
	while (! $done)
	{
		my $fn = $self->getLastFileName();
		
		my @lines;
		
		if (rename $fn, "$fn.reading")
		{
			$done = 1;

			my $fh = new FileHandle;
			
			$fh->open ("$fn.reading");
			
			@lines = <$fh>;

			$fh->close();

			rename "$fn.reading", $fn;
		} else {
			return;
		}
		
		foreach (@lines)
		{
			chomp;
			my ($key, $val) = split ':', $_, 2;
			# TODO MEM fix special cases for services
			# $s .= "ServiceStatus:".$_.":$service ".$self->{ServiceStatus}{$service}."\n";	
			if ($key eq 'ServiceStatus')
			{
				my ($service, $stuff) = split ' ', $val, 2;
				$self->{ServiceStatus}{$service} = $stuff;
			} else {
				$self->{$key} = $val; 
			}
		}
			
	}
}

sub getLastFileName
{
	my $self = shift;
	
	my $fileName;
	
	opendir DIR, $self->{serviceDir};
	
	my @fns = grep !/tmp/, sort map {"$self->{serviceDir}/$_"} readdir DIR;
	
	closedir DIR;
	
#	foreach (@fns) {
#		Zimbra::Logger::Log ("debug","getLastFileName ".$_);
#	}

#	Zimbra::Logger::Log ("debug","getLastFileName ".$fns[$#fns]);
	
	return $fns[$#fns];
}

sub writeServiceInfo
{
	my $self = shift;
	
	my $t = time();
	
	my $serviceFileName = $self->getServiceFilename($t)."tmp";
	Zimbra::Logger::Log ("info","writeServiceInfo ".$serviceFileName);
	
	my $fh = new FileHandle;
	
	$fh->open (">$serviceFileName");
	
	my $s = $self->prettyPrint();
	
	print $fh $s;
	
	$fh->close();
	
	rename ($serviceFileName, $self->{serviceFileName});
	
	$self->cleanupServiceDir();
}

sub getServiceFilename
{
	my $self = shift;
	my $t = shift;
	my $fn = $self->{serviceDir};
	$fn .= "/service.".$t.".".$$;
#	Zimbra::Logger::Log ("debug","getServiceFilename ".$fn);
	
	$self->{serviceFileName} = $fn;
	
	return $fn;
}

sub cleanupServiceDir
{
	my $self = shift;
#	Zimbra::Logger::Log ("debug","cleanupServiceDir ".$self->{lastFileName});

	if ($self->{lastFileName} ne "")
	{
		unlink ($self->{lastFileName});	
	}
	$self->{lastFileName} = $self->{serviceFileName};
}

sub prettyPrint
{
#	Zimbra::Logger::Log ("debug","prettyPrint");
	# getServiceInfo gets info to be written by Zimbra::StatusMon
	my $self = shift;
	
	my $s;
	# TODO MEM fix special cases
	foreach (keys %{$self})
	{
		if (	/^service/ 
			|| /^lastFile/ 
			|| /^host$/ 
			|| /^load/) 
		{next;}
		if (	/^ServiceStatus$/)
		{
			my $service;
			foreach $service (keys %{$self->{ServiceStatus}}) {
				$s .= "ServiceStatus:".$service." ".$self->{ServiceStatus}{$service}."\n";	
			}
			next;
		}
		$s .= $_.":".$self->{$_}."\n";	
	}
	
	return $s;
}

sub getServiceInfo
{
#	Zimbra::Logger::Log ("debug","getServiceInfo");
	my $self = shift;

	$self->{uts} = time();
	
	$self->{ts} = `date +%Y%m%d%H%M%S`;
	
	chomp $self->{ts};
	
	my $s;
	
	Zimbra::Control::getLocalServices();
	
	foreach $s (@::localservices)
	{
		$s = Zimbra::Control::getServiceByName($s);
##		Zimbra::Logger::Log ("debug", "getServiceInfo: ".$s->prettyPrint());
		$self->getServiceStatus(\$s);
	}
	
	# No longer write service info, get current status every time.	
	#$self->writeServiceInfo();
		
}

sub getServiceStatus
{
	my $self = shift;
	my $service = shift;
	
	my $sname = $$service->{name};
	
	my $syntax = $$service->{syntax};
	
	####
	# instead of talking to the main server, we'll poll the apps directly
	####
#	Zimbra::Logger::Log ("debug", "STATUS: Zimbra::serviceInfo::getServiceStatus $sname from app directly");
	my @apps = ::getAppByServiceName ($sname);
	my $status = $::StatusStopped;
	my $info = "";
	%{$self->{ServiceStatus}{$sname}} = ();

	if (defined (@apps)) {
		foreach (@apps) {
			my $name;
			if (ref ($_)) {$name = $_->{name};}
			else {$name = $_;}

			Zimbra::Logger::Log("debug", 
			"STATUS: $name monitor for $self->{host}->{name} from $::Cluster->{LocalHost}{name}");

			my $hn = undef;
			if (defined $self->{host} && $self->{host}{name} ne $::Cluster->{LocalHost}{name}) {
				$hn = $self->{host}{name};
			}

			my $retval = Zimbra::Control::runSyntaxCommand("zimbrasyntax", "$name"."_status", $hn);
			if ($retval) {
				$status = $::StatusStopped;
			} elsif (defined ($retval)) {
				$status = $::StatusRunning;
			} else {
				$status = undef;
				Zimbra::Logger::Log("debug", "STATUS: No network monitor for $name defined");
			}
			if ($self->{ServiceStatus}{$sname}{status} != $::StatusStopped) {
					$self->{ServiceStatus}{$sname}{status} = $status;
			}

			$info = Zimbra::Control::runSyntaxCommand("zimbrasyntax", "$name"."_info", $hn);
#			Zimbra::Logger::Log("debug", "STATUS: Reporting info for $sname: $info");
			if (defined $info) {
				$self->{ServiceStatus}{$sname}{info} = $info;
			} else {
				Zimbra::Logger::Log("debug", "STATUS: No network info command for $name defined");
			}
#			Zimbra::Logger::Log("debug", "STATUS: Reporting info for $sname:".$self->{ServiceStatus}{$sname}{info});
		}
	}
#	Zimbra::Logger::Log("debug", "STATUS: Reporting status for $sname: $status");
#	Zimbra::Logger::Log("debug", "STATUS: Reporting info for $sname: $info");
}

1

