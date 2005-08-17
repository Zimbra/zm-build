#!/usr/bin/perl

package service;

use strict;

use Zimbra::Logger;

require Exporter;

my @ISA = qw(Exporter);

# new service ($name, $label, $app, $monport, $syntax);

sub new
{
	my ($class, $name, $label, $app) = @_;
	return $class if ref ($class);
	
	my $self = 	bless {},  $class;
	
	$self->{name} = $name;
	$self->{label} = $label;

	@{$self->{apps}} = split ",", $app;

	$self->{syntax} = "zimbrasyntax";
#	Zimbra::Logger::Log ("debug","Created service $name $label $app $monport $syntax ");
	return $self;
}

sub prettyPrint
{
	my $self = shift;
	return "$self->{name} $self->{label} $self->{app} $self->{monport} $self->{syntax}";
}

1

