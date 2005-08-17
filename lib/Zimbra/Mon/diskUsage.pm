#!/usr/bin/perl

package Zimbra::Mon::diskUsage;

use strict;

use Zimbra::Mon::Logger;
use Zimbra::Mon::diskSlice;

require Exporter;

my @ISA = qw(Exporter);

sub new
{
	my ($class, $name) = @_;
	return $class if ref ($class);
	
	my $self = bless {},  $class;
	
	$self->{slices} = ();
	
	#Zimbra::Mon::Logger::Log ("info","Created Zimbra::Mon::diskUsage");
	return $self;
}

sub get
{
	my $self = shift;
	
	#Filesystem              1K-blocks     Used    Avail Capacity  Mounted on
	#/dev/disk0s5             58599900 44845764 13498136    77%    /

	#Zimbra::Mon::Logger::Log ("debug","Zimbra::Mon::diskUsage->get");
	
	my $cmd = "df -Pm ";
	my @mounts = ("/opt/zimbra","/opt/zimbra/db","/opt/zimbra/log","/opt/zimbra/redolog","/opt/zimbra/store","/opt/zimbra/index");
	
	#Zimbra::Mon::Logger::Log ("debug", "Zimbra::Mon::diskUsage->get: @$dfStr");
	
	foreach my $m (@mounts)
	{
		my $dfStr = main::runShellCmd ($cmd, $m);

		foreach (@$dfStr) {
			if (/^\//)
			{
				my ($dev, $blk, $used, $avail, $cap, $mt) = split;
				$cap =~ s/%//;
				push (@{$self->{slices}}, 
					new Zimbra::Mon::diskSlice($dev, $blk, $used, $avail, $cap, $m) );
			}
		}
	}
}

sub prettyPrint
{
	my $self = shift;
	my $str = "";
	foreach (@{$self->{slices}})
	{
		$str .= $_->prettyPrint();
		$str .= "\n";
	}
	
	return $str;
}

1

