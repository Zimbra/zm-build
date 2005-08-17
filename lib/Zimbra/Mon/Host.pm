#!/usr/bin/perl

package host;

use strict;

use Zimbra::Mon::Logger;

require Exporter;

my @ISA = qw(Exporter);

sub new
{
	my ($class, $name, $ip ) = @_;
	return $class if ref ($class);
	
	my $self = bless {},  $class;
	
	$self->{name} = $name;
	$self->{ip} = $ip;
	#Zimbra::Mon::Logger::Log ("debug","Created host $name");
	return $self;
}

sub prettyPrint
{
	my $self = shift;
	return "$self->{name} $self->{ip} $self->{isMonitor}";
}

sub isMonitor {

	my $self = shift;

	my $isMonitor = `zmprov gs $self->{name} 2> /dev/null | grep zimbraIsMonitorHost`;

	chomp $isMonitor;

	$self->{isMonitor} = $isMonitor;

	if ($isMonitor eq "zimbraIsMonitorHost: TRUE") {
		return "yes";
	} else {
		return undef;
	}
}

1

