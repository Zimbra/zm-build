# 
# ***** BEGIN LICENSE BLOCK *****
# Version: MPL 1.1
# 
# The contents of this file are subject to the Mozilla Public License
# Version 1.1 ("License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://www.zimbra.com/license
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations
# under the License.
# 
# The Original Code is: Zimbra Collaboration Suite Server.
# 
# The Initial Developer of the Original Code is Zimbra, Inc.
# Portions created by Zimbra are Copyright (C) 2005 Zimbra, Inc.
# All Rights Reserved.
# 
# Contributor(s):
# 
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

