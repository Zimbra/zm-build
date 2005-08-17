#!/usr/bin/perl

#use strict;

use liquidlog;
use liquidCluster;
use host;
use server;
use liquidAdmin;
#use IO::Socket::INET;
use POSIX ":sys_wait_h";
use SOAP::Lite +trace;
#use SOAP::Lite +trace;
use SOAP::Transport::HTTP;

my $basedir=".";

my $configfile="$basedir/liquid.cf";

liquidlog::Log ("info","Liquid Monitor startup");

my @servers = ();
my %children = ();

my $soap_server;
my $controlport = 0;

our $Cluster;

sub bind_control_port
{

	liquidlog::Log ("debug","Creating soap server on port $controlport");

	$soap_server = SOAP::Transport::HTTP::Daemon->new(Reuse	=>1, LocalAddr	=>	localhost	=>	LocalPort	=>	$controlport)
		->serializer(MySerializer->new)
		->dispatch_to('liquidAdmin')
		->on_action(sub {@_[1]});
 
	BEGIN {
	
	    package MySerializer; @MySerializer::ISA = 'SOAP::Serializer';
	    sub envelope {
	      $_[2] =~ s/RequestResponse$/Response/ if $_[1] =~ /^(?:method|response)$/;
	      shift->SUPER::envelope(@_);
	    }
	}

	liquidlog::Log ("debug","Server created.");
	$soap_server->handle;
	liquidlog::Log ("debug","Server exited.");
		
}

sub make_client_call
{
         my $resp = SOAP::Lite
           -> proxy('http://localhost:7777/')
           -> uri('http://localhost:7777/liquidAdmin')
           -> GetHostListRequest();
           
#           print "r: ".$resp->result->{name}."\n";
           my @p = $resp->paramsall();
           foreach $p (@p)
           {
	           print "p: $p->{name}\n";
		         my $hr = SOAP::Lite
		           -> proxy('http://localhost:7777/')
		           -> uri('http://localhost:7777/liquidAdmin')
		           -> GetServicesRequest($p->{name});
		          my @s = $hr->paramsall();
		          foreach $s (@s)
		          {
		          		foreach $q (@{$s})
		          		{
		          			print "$q\n";
			          		my $S = new server($q->{name}, $q->{exe}, $q->{args}, $q->{md}, $q->{lbl});
			          		print "\ts: ".$S->prettyPrint()."\n";          		
		          		}
		          }
           }
}

make_client_call();

