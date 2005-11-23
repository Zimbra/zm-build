#!/usr/bin/perl
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
# 
# ***** END LICENSE BLOCK *****
# 

package zmupgrade;

use strict;
use lib "/opt/zimbra/libexec/scripts";
use Migrate;

my $type = `zmlocalconfig -m nokey convertd_stub_name 2> /dev/null`;
chomp $type;
if ($type eq "") {$type = "FOSS";}
else {$type = "NETWORK";}

my $rundir = `dirname $0`;
chomp $rundir;
my $scriptDir = "$rundir/scripts";

my $lowVersion = 18;
my $hiVersion = 21;

my %updateScripts = (
	'18' => "migrate20050916-Volume.pl",
	'19' => "migrate20050920-CompressionThreshold.pl",
	'20' => "migrate20050927-DropRedologSequence.pl",
	'21' => "migrate20051021-UniqueVolume.pl",
);

my %updateFuncs = (
	"3.0.M1" => \&upgradeBM1,
	"3.0.0_M2" => \&upgradeBM2,
);

my @versionOrder = ("3.0.M1", "3.0.0_M2");

my $startVersion;
my $targetVersion;

#####################

sub upgrade {
	$startVersion = shift;
	$targetVersion = shift;

	if (stopZimbra()) { return 1; }

	if (startSql()) { return 1; }

	my $curSchemaVersion = Migrate::getSchemaVersion();

	if ($startVersion eq "3.0.M1" && $curSchemaVersion < 21) {
		print "This appears to be an non-upgraded version of 3.0.M1\n";
	} elsif ($startVersion eq "3.0.M1" && $curSchemaVersion >= 21) {
		print "This appears to be 3.0.M1, with no schema upgrade needed\n";
		$curSchemaVersion = 22;
	} elsif ($startVersion eq "3.0.0_M2" && $curSchemaVersion < 21) {
		print "This appears to be 3.0.0_M2, needing a schema upgrade\n";
	} elsif ($startVersion eq "3.0.0_M2" && $curSchemaVersion >= 21) {
		print "This appears to be 3.0.0_M2, with no schema upgrade needed\n";
		$curSchemaVersion = 22;
	} else {
		print "I can't upgrade this version\n\n";
		return 1;
	}

	while ($curSchemaVersion >= $lowVersion && $curSchemaVersion <= $hiVersion) {
		if (runSchemaUpgrade ($curSchemaVersion)) { return 1; }
		$curSchemaVersion++;
	}

	stopSql();

	my $found = 0;

	foreach my $v (@versionOrder) {
		print "Checking $v\n\n";
		if ($v eq $startVersion) {
			$found = 1;
		}
		if ($v eq $targetVersion) {
			last;
		}
		if ($found) {
			if (defined ($updateFuncs{$v}) ) {
				if (&{$updateFuncs{$v}}()) {
					return 1;
				}
			} else {
				Migrate::log("I don't know how to update $v - exiting");
				return 1;
			}
		}
	}

	return 0;
}

sub upgradeBM1 {
	Migrate::log("Updating from 3.0.M1");

	my $t = time()+(60*60*24*60);
	my @d = localtime($t);
	my $expiry = sprintf ("%04d%02d%02d",$d[5]+1900,$d[4]+1,$d[3]);
	`su - zimbra -c "zmlocalconfig -e trial_expiration_date=$expiry"`;

	my $ldh = `su - zimbra -c "zmlocalconfig -m nokey ldap_host"`;
	chomp $ldh;
	my $ldp = `su - zimbra -c "zmlocalconfig -m nokey ldap_port"`;
	chomp $ldp;

	Migrate::log("Updating ldap url configuration");
	`su - zimbra -c "zmlocalconfig -e ldap_url=ldap://${ldh}:${ldp}"`;
	`su - zimbra -c "zmlocalconfig -e ldap_master_url=ldap://${ldh}:${ldp}"`;

	my $hn = `su - zimbra -c "zmlocalconfig -m nokey zimbra_server_hostname"`;
	chomp $hn;
	if ($hn eq $ldh) {
		Migrate::log("Setting ldap master to true");
		`su - zimbra -c "zmlocalconfig -e ldap_is_master=true"`;
	}

	Migrate::log("Updating index configuration");
	`su - zimbra -c "zmlocalconfig -e zimbra_index_idle_flush_time=600"`;
	`su - zimbra -c "zmlocalconfig -e zimbra_index_lru_size=100"`;
	`su - zimbra -c "zmlocalconfig -e zimbra_index_max_uncommitted_operations=200"`;

	Migrate::log("Updating zimbra user configuration");
	`su - zimbra -c "zmlocalconfig -e zimbra_user=zimbra"`;
	my $UID = `id -u zimbra`;
	chomp $UID;
	my $GID = `id -g zimbra`;
	chomp $GID;
	`su - zimbra -c "zmlocalconfig -e zimbra_uid=${UID}"`;
	`su - zimbra -c "zmlocalconfig -e zimbra_gid=${GID}"`;
	`su - zimbra -c "zmcreatecert"`;

	return 0;
}

sub upgradeBM2 {
	Migrate::log("Updating from 3.0.0_M2");

	return 0;
}

sub stopZimbra {
	Migrate::log("Stopping zimbra services");
	my $rc = 0xffff & system("su - zimbra -c \"/opt/zimbra/bin/zmcontrol stop > /dev/null 2>&1\"");
	$rc = $rc >> 8;
	if ($rc) {
		Migrate::log("Stop failed - exiting");
		return $rc;
	}
	return 0;
}

sub stopSql {
	Migrate::log("Stopping mysql");
	my $rc = 0xffff & system("su - zimbra -c \"/opt/zimbra/bin/mysql.server stop > /dev/null 2>&1\"");
	$rc = $rc >> 8;
	if ($rc) {
		Migrate::log("mysql stop failed with exit code $rc");
		return $rc;
	}
	return 0;
}

sub startSql {
	Migrate::log("Checking mysql status");
	my $rc = 0xffff & system("su - zimbra -c \"/opt/zimbra/bin/mysqladmin status > /dev/null 2>&1\"");
	$rc = $rc >> 8;
	if ($rc) {
		Migrate::log("Starting mysql");
		$rc = 0xffff & system("su - zimbra -c \"/opt/zimbra/bin/mysql.server start > /dev/null 2>&1\"");
		$rc = $rc >> 8;
		if ($rc) {
			Migrate::log("mysql startup failed with exit code $rc");
			return $rc;
		}
	}
	return 0;
}

sub runSchemaUpgrade {
	my $curVersion = shift;

	if (! defined ($updateScripts{$curVersion})) {
		Migrate::log ("Can't upgrade from version $curVersion - no script!");
		return 1;
	}

	if (! -x "${scriptDir}/$updateScripts{$curVersion}" ) {
		Migrate::log ("Can't run ${scriptDir}/$updateScripts{$curVersion} - no script!");
		return 1;
	}

	Migrate::log ("Running ${scriptDir}/$updateScripts{$curVersion}");
	my $rc = 0xffff & system("su - zimbra -c \"perl -I${scriptDir} ${scriptDir}/$updateScripts{$curVersion}\"");
	$rc = $rc >> 8;
	if ($rc) {
		Migrate::log ("Script failed with code $rc - exiting");
		return $rc;
	}
	return 0;
}

1
