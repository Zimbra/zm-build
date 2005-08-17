#!/usr/bin/perl

package Zimbra::Mon::Logger;

use strict;

use Sys::Syslog;

require Exporter;

my @ISA = qw(Exporter);

my $ident="zimbramon";
my $facility="local0";

my @EXPORT = qw (Log);

our %loglevels = ('debug' => 0, 'info' => 1, 'err' => 3, 'crit' => 4);

my $LOG_LEVEL = $loglevels{'info'};

sub Log
{
	my ($level,$msg) = (@_);
	if ($loglevels{$level} >= $LOG_LEVEL) {
		openlog($ident, "pid,ndelay,nowait", $facility);
		syslog($level, "$$:$level: $msg");
		if ($::DEBUG) {
			print STDERR scalar localtime().":$$:$level: $msg\n";
		}
		closelog();
	}
}

1

