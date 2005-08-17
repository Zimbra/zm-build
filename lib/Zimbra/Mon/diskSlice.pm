#!/usr/bin/perl

package Zimbra::diskSlice;

use strict;

use Zimbra::Logger;

require Exporter;

my @ISA = qw(Exporter);

sub new
{
	#new Zimbra::diskSlice($dev, $blk, $used, $avail, $cap, $mt);
	my ($class, $dev, $blk, $used, $avail, $cap, $mt) = @_;
	return $class if ref ($class);
	
	my $self = bless {},  $class;
	
	$self->{dev} = $dev;
	$self->{blk} = $blk;
	$self->{used} = $used;
	$self->{avail} = $avail;
	$self->{cap} = $cap;
	$self->{mt} = $mt;
	
	#Zimbra::Logger::Log ("info","Created Zimbra::diskSlice: $dev, $blk, $used, $avail, $cap, $mt");
	return $self;
}

sub prettyPrint
{
	my $self = shift;
	
	my $str = "$self->{dev} $self->{blk} $self->{used} $self->{avail} $self->{cap}  $self->{mt}";
	
	return $str;
}


1

