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
package Zimbra::Mon::ProvTool;

use strict;

use Zimbra::Mon::Logger;
use Zimbra::Mon::Host;

my $provTool = "$::Basedir/../bin/zmprov";

our $AUTOLOAD;

sub new {
	my ( $class ) = @_;

	my $self = bless {}, $class;

	Zimbra::Mon::Logger::Log( "debug", "Created ProvTool" );

	return $self;
}

sub AUTOLOAD {
	my $self = shift;
	my $name = $AUTOLOAD;
	$name =~ s/.*:://;
	return $self->doProv($name, @_);
}

sub doProv {
	my $self = shift;
	my $cmd = shift;

	local $SIG{CHLD} = 'IGNORE';

	my $cmdline = "$provTool $cmd @_";
	if (!open(PT, "$cmdline |")) {
		Zimbra::Mon::Logger::Log( "crit", "Unable to invoke \"$cmdline\": $!" );
		return undef;
	}

	my @lines = <PT>;
	close PT;
	return \@lines;
}

1
