# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2004, 2005, 2006, 2007 Zimbra, Inc.
# 
# The contents of this file are subject to the Yahoo! Public License
# Version 1.0 ("License"); you may not use this file except in
# compliance with the License.  You may obtain a copy of the License at
# http://www.zimbra.com/license.
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied.
# ***** END LICENSE BLOCK *****
# 
#!/usr/bin/perl

package Zimbra::Mon::Logger;

use strict;

use Sys::Syslog qw(:DEFAULT setlogsock);;

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
    setlogsock('unix');
		openlog($ident, "pid,ndelay,nowait", $facility);
		syslog($level, "$$:$level: $msg");
		if ($::DEBUG) {
			print STDERR scalar localtime().":$$:$level: $msg\n";
		}
		closelog();
	}
}

1

