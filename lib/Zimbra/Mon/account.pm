#!/usr/bin/perl

package account;

use strict;

use liquidlog;

require Exporter;

my @ISA = qw(Exporter);

sub new
{

	my ($class, $id, $name, $foreign_id, $server_id, $created, $deleted) = @_;
	return $class if ref ($class);
	
	my $self = bless {},  $class;
	
	$self->{id} = $id;
	$self->{name} = $name;
	$self->{foreign_id} = $foreign_id;
	$self->{server_id} = $server_id;
	$self->{created} = $created;
	$self->{deleted} = $deleted;
	return $self;
}

sub create
{
	# STATIC FACTORY METHOD to create from db return
	my $hsh = shift;
	return new account($$hsh{id}, $$hsh{name}, $$hsh{foreign_id}, $$hsh{server_id}, $$hsh{created}, $$hsh{deleted});
}

sub prettyPrint
{
	my $self = shift;
	return "$self->{id} $self->{name} $self->{foreign_id} $self->{server_id} $self->{created} $self->{deleted} ";
}

1

