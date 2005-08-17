#!/usr/bin/perl

use IO::Socket::INET;
use strict;

my $port = $ARGV[0];

my $server = IO::Socket::INET->new(LocalPort	=> $port,
								Type		=> SOCK_STREAM,
								Reuse		=> 1,
								Listen		=> SOMAXCONN)
or die "SHIT: $!";


die "Crap" unless $server;

my $client;

while ($client = $server->accept())
{
	while (<$client>) 
	{
		/^exit/ && exit (2);
		/^quit/ && exit (0);
		print;
	}
}
