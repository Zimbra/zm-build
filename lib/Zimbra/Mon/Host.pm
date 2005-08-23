# 
# ***** BEGIN LICENSE BLOCK *****
# Version: ZPL 1.1
# 
# The contents of this file are subject to the Zimbra Public License
# Version 1.1 ("License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://www.zimbra.com/license
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations
# under the License.
# 
# The Original Code is: Zimbra Collaboration Suite.
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

package host;

use strict;

use Zimbra::Mon::Logger;

require Exporter;

my @ISA = qw(Exporter);

sub new
{
	my ($class, $name, $ip ) = @_;
	return $class if ref ($class);
	
	my $self = bless {},  $class;
	
	$self->{name} = $name;
	$self->{ip} = $ip;
	#Zimbra::Mon::Logger::Log ("debug","Created host $name");
	return $self;
}

sub prettyPrint
{
	my $self = shift;
	return "$self->{name} $self->{ip} $self->{isMonitor}";
}

sub isMonitor {

	my $self = shift;

	my $isMonitor = `zmprov gs $self->{name} 2> /dev/null | grep zimbraIsMonitorHost`;

	chomp $isMonitor;

	$self->{isMonitor} = $isMonitor;

	if ($isMonitor eq "zimbraIsMonitorHost: TRUE") {
		return "yes";
	} else {
		return undef;
	}
}

1

