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

package account;

use strict;

use Zimbra::Mon::Logger;

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

