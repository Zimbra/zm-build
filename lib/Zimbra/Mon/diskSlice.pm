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

package Zimbra::Mon::diskSlice;

use strict;

use Zimbra::Mon::Logger;

require Exporter;

my @ISA = qw(Exporter);

sub new
{
	#new Zimbra::Mon::diskSlice($dev, $blk, $used, $avail, $cap, $mt);
	my ($class, $dev, $blk, $used, $avail, $cap, $mt) = @_;
	return $class if ref ($class);
	
	my $self = bless {},  $class;
	
	$self->{dev} = $dev;
	$self->{blk} = $blk;
	$self->{used} = $used;
	$self->{avail} = $avail;
	$self->{cap} = $cap;
	$self->{mt} = $mt;
	
	#Zimbra::Mon::Logger::Log ("info","Created Zimbra::Mon::diskSlice: $dev, $blk, $used, $avail, $cap, $mt");
	return $self;
}

sub prettyPrint
{
	my $self = shift;
	
	my $str = "$self->{dev} $self->{blk} $self->{used} $self->{avail} $self->{cap}  $self->{mt}";
	
	return $str;
}


1

