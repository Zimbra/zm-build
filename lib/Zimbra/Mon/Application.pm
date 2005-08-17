#!/usr/bin/perl

package application;

use strict;

use Zimbra::Logger;

require Exporter;

my @ISA = qw(Exporter);

sub new
{
	my ($class, $name, $exe, $args, $md, $lbl) = @_;
	return $class if ref ($class);
	
	my $self = 	bless {},  $class;
	
	$self->{name} = $name;
	$self->{exe} = $exe;
	$self->{args} = $args;
	$self->{md} = $md;
	$self->{lbl} = $lbl;
	#Zimbra::Logger::Log ("info","Created application $name");
	return $self;
}

sub prettyPrint
{
	my $self = shift;
	return "$self->{name} $self->{exe} $self->{args} $self->{md} $self->{lbl}";
}

1

