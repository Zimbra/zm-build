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


use strict;
use lib "./scripts";
use Migrate;

my $me = `id -un`;
chomp $me;

if ($me ne "zimbra") {
	die "Run as the zimbra user!";
}

my $installedVersion = getInstalledVersion();

my $type = `zmlocalconfig -m nokey convertd_stub_name 2> /dev/null`;
chomp $type;
if ($type eq "") {$type = "FOSS";}
else {$type = "NETWORK";}

my $rundir = `dirname $0`;
chomp $rundir;
my $scriptDir = "$rundir/scripts";

my %updateScripts = (
	'18' => "migrate20050916-Volume.pl",
	'19' => "migrate20050920-CompressionThreshold.pl",
	'20' => "migrate20050927-DropRedologSequence.pl",
	'21' => "migrate20051021-UniqueVolume.pl",
);

stopZimbra();

startSql();

my $curSchemaVersion = Migrate::getSchemaVersion();

if ($installedVersion eq "M1" && $curSchemaVersion < 21) {
	print "This appears to be an non-upgraded version of M1\n";
} elsif ($installedVersion eq "M1" && $curSchemaVersion >= 21) {
	print "This appears to be M1, with no schema upgrade needed\n";
	$curSchemaVersion = 22;
} elsif ($installedVersion eq "M2" && $curSchemaVersion < 21) {
	print "This appears to be M2, needing a schema upgrade\n";
} elsif ($installedVersion eq "M2" && $curSchemaVersion >= 21) {
	print "This appears to be M2, with no schema upgrade needed\n";
	$curSchemaVersion = 22;
} else {
	print "I can't upgrade this version\n\n";
	exit 1;
}

print "Press 'Y' to upgrade, or 'X' to exit ";
while (<>) {
	if (/^[yY]/) {last;}
	if (/^[xX]/) {exit 1;}
	print "Press 'Y' to upgrade, or 'X' to exit ";
}

while ($curSchemaVersion >= 18 && $curSchemaVersion <= 21) {
	runSchemaUpgrade ($curSchemaVersion);
	$curSchemaVersion++;
}

stopSql();

# Update the config keys

my $t = time()+(60*60*24*60);
my @d = localtime($t);
my $expiry = sprintf ("%04d%02d%02d",$d[5]+1900,$d[4]+1,$d[3]);
`zmlocalconfig -e trial_expiration_date=$expiry`;

my $ldh = `zmlocalconfig -m nokey ldap_host`;
chomp $ldh;
my $ldp = `zmlocalconfig -m nokey ldap_port`;
chomp $ldp;

Migrate::log("Updating ldap url configuration");
`zmlocalconfig -e ldap_url=ldap://${ldh}:${ldp}`;
`zmlocalconfig -e ldap_master_url=ldap://${ldh}:${ldp}`;

my $hn = `zmlocalconfig -m nokey zimbra_server_hostname`;
chomp $hn;
if ($hn eq $ldh) {
	Migrate::log("Setting ldap master to true");
	`zmlocalconfig -e ldap_is_master=true`;
}

Migrate::log("Updating index configuration");
`zmlocalconfig -e zimbra_index_idle_flush_time=600`;
`zmlocalconfig -e zimbra_index_lru_size=100`;
`zmlocalconfig -e zimbra_index_max_uncommitted_operations=200`;

Migrate::log("Updating zimbra user configuration");
`zmlocalconfig -e zimbra_user=zimbra`;
my $UID = `id -u`;
chomp $UID;
my $GID = `id -g`;
chomp $GID;
`zmlocalconfig -e zimbra_uid=${UID}`;
`zmlocalconfig -e zimbra_gid=${GID}`;

exit(0);

#####################

sub stopZimbra {
	Migrate::log("Stopping zimbra services");
	my $rc = 0xffff & system("/opt/zimbra/bin/zmcontrol stop > /dev/null 2>&1");
	$rc = $rc >> 8;
	if ($rc) {
		Migrate::log("Stop failed - exiting");
		exit $rc;
	}
}

sub stopSql {
	Migrate::log("Stopping mysql");
	my $rc = 0xffff & system("/opt/zimbra/bin/mysql.server stop > /dev/null 2>&1");
	$rc = $rc >> 8;
	if ($rc) {
		Migrate::log("mysql stop failed with exit code $rc");
		exit $rc;
	}
}

sub startSql {
	Migrate::log("Checking mysql status");
	my $rc = 0xffff & system("/opt/zimbra/bin/mysqladmin status > /dev/null 2>&1");
	$rc = $rc >> 8;
	if ($rc) {
		Migrate::log("Starting mysql");
		$rc = 0xffff & system("/opt/zimbra/bin/mysql.server start > /dev/null 2>&1");
		$rc = $rc >> 8;
		if ($rc) {
			Migrate::log("mysql startup failed with exit code $rc");
			exit $rc;
		}
	}
}

sub runSchemaUpgrade {
	my $curVersion = shift;

	if (! defined ($updateScripts{$curVersion})) {
		Migrate::log ("Can't upgrade from version $curVersion - no script!");
		exit 1;
	}

	if (! -x "${scriptDir}/$updateScripts{$curVersion}" ) {
		Migrate::log ("Can't run ${scriptDir}/$updateScripts{$curVersion} - no script!");
		exit 1;
	}

	Migrate::log ("Running ${scriptDir}/$updateScripts{$curVersion}");
	my $rc = 0xffff & system("perl -I${scriptDir} ${scriptDir}/$updateScripts{$curVersion}");
	$rc = $rc >> 8;
	if ($rc) {
		Migrate::log ("Script failed with code $rc - exiting");
		exit $rc;
	}
}

sub getInstalledVersion {
	Migrate::log("Finding installed version of ZCS");
	my $version = `rpm -q zimbra-core`;
	chomp $version;
	if ($version =~ /zimbra-core-3.0.M1_/) {
		return "M1";
	}
	if ($version =~ /zimbra-core-3.0.0_M2_/) {
		return "M2";
	}
	Migrate::log("Can't determine ZCS version!");
	exit 1;
}
