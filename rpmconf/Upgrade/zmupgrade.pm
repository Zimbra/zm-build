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
my $scriptDir = "/opt/zimbra/libexec/scripts";

my $lowVersion = 18;
my $hiVersion = 21;
my $hiLoggerVersion = 2;

my $hn = `su - zimbra -c "zmlocalconfig -m nokey zimbra_server_hostname"`;
chomp $hn;

my %updateScripts = (
	'18' => "migrate20050916-Volume.pl",
	'19' => "migrate20050920-CompressionThreshold.pl",
	'20' => "migrate20050927-DropRedologSequence.pl",
	'21' => "migrate20051021-UniqueVolume.pl",
);

my %loggerUpdateScripts = (
	'0' => "migrateLogger1-index.pl",
	'1' => "migrateLogger2-config.pl",
);

my %updateFuncs = (
	"3.0.M1" => \&upgradeBM1,
	"3.0.0_M2" => \&upgradeBM2,
	"3.0.0_M3" => \&upgradeBM3,
	"3.0.0_M4" => \&upgradeBM4,
);

my @versionOrder = ("3.0.M1", "3.0.0_M2", "3.0.0_M3", "3.0.0_M4");

my $startVersion;
my $targetVersion;

my @packageList = (
	"zimbra-core",
	"zimbra-ldap",
	"zimbra-store",
	"zimbra-mta",
	"zimbra-snmp",
	"zimbra-logger",
	"zimbra-apache",
	"zimbra-spell",
	);

my %installedPackages = ();
my $platform = `/opt/zimbra/bin/get_plat_tag.sh`;
chomp $platform;

#####################

sub upgrade {
	$startVersion = shift;
	$targetVersion = shift;
	my $startBuild = $startVersion;
	$startBuild =~ s/.*_//;
	my $targetBuild = $targetVersion;
	$targetBuild =~ s/.*_//;

	$startVersion =~ s/_$startBuild//;
	$targetVersion =~ s/_$targetBuild//;

	getInstalledPackages();

	if (stopZimbra()) { return 1; }

	my $curSchemaVersion;
	my $curLoggerSchemaVersion;

	if (isInstalled("zimbra-store")) {
		if (startSql()) { return 1; }
		$curSchemaVersion = Migrate::getSchemaVersion();
	}

	if (isInstalled("zimbra-logger")) {
		if (startLoggerSql()) { return 1; }

		if ($startVersion eq "3.0.0_M2") {
			$curLoggerSchemaVersion = 0;
		} elsif ($startVersion eq "3.0.0_M3" && $startBuild < 285) {
			$curLoggerSchemaVersion = 1;
		} else {
			$curLoggerSchemaVersion = Migrate::getLoggerSchemaVersion();
		}

		if ($curLoggerSchemaVersion eq "") {
			$curLoggerSchemaVersion = 1;
		}
	}

	if ($startVersion eq "3.0.M1") {
		print "This appears to be an non-upgraded version of 3.0.M1\n";
	} elsif ($startVersion eq "3.0.M1") {
		print "This appears to be 3.0.M1\n";
		$curSchemaVersion = 22;
	} elsif ($startVersion eq "3.0.0_M2") {
		print "This appears to be 3.0.0_M2\n";
	} elsif ($startVersion eq "3.0.0_M2") {
		print "This appears to be 3.0.0_M2\n";
		$curSchemaVersion = 22;
	} elsif ($startVersion eq "3.0.0_M3") {
		print "This appears to be 3.0.0_M3\n";
		if ($curSchemaVersion < 22) {
			$curSchemaVersion = 22;
		}
	} elsif ($startVersion eq "3.0.0_M4") {
		print "This appears to be 3.0.0_M4\n";
		if ($curSchemaVersion < 22) {
			$curSchemaVersion = 22;
		}
	} else {
		print "I can't upgrade version $startVersion\n\n";
		return 1;
	}

	if (isInstalled("zimbra-store")) {

		if ($startVersion eq "3.0.M1" && $curSchemaVersion >= 21) {
			print "No schema upgrade needed\n";
			$curSchemaVersion = 22;
		} elsif ($startVersion eq "3.0.0_M2" && $curSchemaVersion < 21) {
			print "Schema upgrade required\n";
		} elsif ($startVersion eq "3.0.0_M2" && $curSchemaVersion >= 21) {
			print "No schema upgrade needed\n";
			$curSchemaVersion = 22;
		} elsif ($startVersion eq "3.0.0_M3") {
			print "No schema upgrade needed\n";
			if ($curSchemaVersion < 22) {
				$curSchemaVersion = 22;
			}
		} elsif ($startVersion eq "3.0.0_M4") {
			print "No schema upgrade needed\n";
			if ($curSchemaVersion < 22) {
				$curSchemaVersion = 22;
			}
		} else {
			print "I can't upgrade version $startVersion\n\n";
			return 1;
		}

		while ($curSchemaVersion >= $lowVersion && $curSchemaVersion <= $hiVersion) {
			if (runSchemaUpgrade ($curSchemaVersion)) { return 1; }
			$curSchemaVersion++;
		}
		stopSql();
	}

	if (isInstalled ("zimbra-logger")) {
		if ($curLoggerSchemaVersion < $hiLoggerVersion) {
			print "An upgrade of the logger schema is necessary from version $curLoggerSchemaVersion\n";
		}

		while ($curLoggerSchemaVersion < $hiLoggerVersion) {
			if (runLoggerSchemaUpgrade ($curLoggerSchemaVersion)) { return 1; }
			$curLoggerSchemaVersion++;
		}
		stopLoggerSql();
	}

	my $found = 0;

	if (isInstalled ("zimbra-ldap")) {
		if (startLdap()) {return 1;}
	}
	foreach my $v (@versionOrder) {
		print "Checking $v\n\n";
		if ($v eq $startVersion) {
			$found = 1;
		}
		if ($found) {
			if (defined ($updateFuncs{$v}) ) {
				if (&{$updateFuncs{$v}}($startBuild, $targetVersion, $targetBuild)) {
					return 1;
				}
			} else {
				Migrate::log("I don't know how to update $v - exiting");
				return 1;
			}
		}
		if ($v eq $targetVersion) {
			last;
		}
	}
	if (isInstalled ("zimbra-ldap")) {
		stopLdap();
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

	if ($hn eq $ldh) {
		Migrate::log("Setting ldap master to true");
		`su - zimbra -c "zmlocalconfig -e ldap_is_master=true"`;
	}

	Migrate::log("Updating index configuration");
	`su - zimbra -c "zmlocalconfig -e zimbra_index_idle_flush_time=600"`;
	`su - zimbra -c "zmlocalconfig -e zimbra_index_lru_size=100"`;
	`su - zimbra -c "zmlocalconfig -e zimbra_index_max_uncommitted_operations=200"`;
	`su - zimbra -c "zmlocalconfig -e logger_mysql_port=7307"`;

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

	if ( -d "/opt/zimbra/postfix-2.2.3/spool" ) {
		Migrate::log("Moving postfix queues");
		my @dirs = qw /active bounce corrupt defer deferred flush hold incoming maildrop/;
		foreach my $d (@dirs) {
			if (-d "/opt/zimbra/postfix-2.2.3/spool/$d/") {
				Migrate::log("Moving $d");
				`cp -Rf /opt/zimbra/postfix-2.2.3/spool/$d/* /opt/zimbra/postfix-2.2.5/spool/$d`;
				`chown -R postfix:postdrop /opt/zimbra/postfix-2.2.5/spool/$d`;
			}
		}

	}

	return 0;
}

sub upgradeBM3 {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 3.0.0_M3");

	# $startBuild -> $targetBuild
	if ($startVersion eq "3.0.0_M2" || $startVersion eq "3.0.M1" || $startBuild <= 346) {
		# Set mode and authhost
		`su - zimbra -c "/opt/zimbra/bin/zmprov ms $hn zimbraMailMode http"`;
		`su - zimbra -c "/opt/zimbra/bin/zmprov ms $hn zimbraMtaAuthHost $hn"`;
	}
	if (($startVersion eq "3.0.0_M2" || $startVersion eq "3.0.M1" || $startBuild <= 427) &&
		isInstalled ("zimbra-ldap")) {

		Migrate::log ("Updating ldap GAL attributes");
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraGalLdapAttrMap zimbraId=zimbraId +zimbraGalLdapAttrMap objectClass=objectClass +zimbraGalLdapAttrMap zimbraMailForwardingAddress=zimbraMailForwardingAddress"`;

		Migrate::log ("Updating ldap CLIENT attributes");
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraAccountClientAttr zimbraIsDomainAdminAccount +zimbraAccountClientAttr zimbraFeatureIMEnabled"`;
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraCOSInheritedAttr zimbraFeatureIMEnabled"`;
		Migrate::log ("Updating ldap domain admin attributes");
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraAccountStatus"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr company"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr cn"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr co"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr displayName"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr gn"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr description"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr initials"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr l"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraAttachmentsBlocked"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraAttachmentsIndexingEnabled"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraAttachmentsViewInHtmlOnly"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraAuthTokenLifetime"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraAuthLdapExternalDn"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraAdminAuthTokenLifetime"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraContactMaxNumEntries"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraFeatureContactsEnabled"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraFeatureGalEnabled"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraFeatureHtmlComposeEnabled"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraFeatureCalendarEnabled"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraFeatureIMEnabled"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraFeatureTaggingEnabled"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraFeatureAdvancedSearchEnabled"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraFeatureSavedSearchesEnabled"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraFeatureConversationsEnabled"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraFeatureChangePasswordEnabled"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraFeatureInitialSearchPreferenceEnabled"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraFeatureFiltersEnabled"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraForeignPrincipal"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraImapEnabled"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraIsDomainAdminAccount"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraMailIdleSessionTimeout"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraMailMessageLifetime"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraMailMinPollingInterval"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraMailSpamLifetime"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraMailTrashLifetime"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraNotes"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPasswordLocked"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPasswordMinLength"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPasswordMaxLength"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPasswordMinAge"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPasswordMaxAge"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPasswordEnforceHistory"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPasswordMustChange"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPop3Enabled"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefTimeZoneId"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefUseTimeZoneListInCalendar"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefComposeInNewWindow"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefComposeFormat"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefHtmlEditorDefaultFontColor"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefHtmlEditorDefaultFontFamily"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefHtmlEditorDefaultFontSize"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefForwardReplyInOriginalFormat"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefAutoAddAddressEnabled"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefShowFragments"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefShowSearchString"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarFirstDayOfWeek"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarInitialView"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarInitialCheckedCalendars"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarUseQuickAdd"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarAlwaysShowMiniCal"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarNotifyDelegatedChanges"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefContactsInitialView"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefDedupeMessagesSentToSelf"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefForwardIncludeOriginalText"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefForwardReplyPrefixChar"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefGroupMailBy"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefImapSearchFoldersEnabled"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefIncludeSpamInSearch"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefIncludeTrashInSearch"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailInitialSearch"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailItemsPerPage"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefContactsPerPage"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefMessageViewHtmlPreferred"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailPollingInterval"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailSignature"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailSignatureEnabled"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailSignatureStyle"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefNewMailNotificationAddress"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefNewMailNotificationEnabled"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefOutOfOfficeReply"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefOutOfOfficeReplyEnabled"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefReplyIncludeOriginalText"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefReplyToAddress"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefSaveToSent"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefSentMailFolder"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraPrefUseKeyboardShortcuts"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraZimletAvailableZimlets"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraZimletUserProperties"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr o"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr ou"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr physicalDeliveryOfficeName"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr postalAddress"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr postalCode"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr sn"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr st"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr telephoneNumber"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr title"`;
		print ".";
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraMailStatus"`;
		print "\n";

		Migrate::log ("Updating ldap server attributes");

		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf zimbraLmtpNumThreads 20 "`;
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf zimbraMessageCacheSize 1671168 "`;
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraServerInheritedAttr zimbraMessageCacheSize +zimbraServerInheritedAttr zimbraMtaAuthHost +zimbraServerInheritedAttr zimbraMtaAuthURL +zimbraServerInheritedAttr zimbraMailMode"`;
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf -zimbraMtaRestriction reject_non_fqdn_hostname"`;
	}
	if ($startVersion eq "3.0.0_M2" || $startVersion eq "3.0.M1" || $startBuild <= 436) {
		if (isInstalled("zimbra-store")) {
			if (startSql()) { return 1; }
			`su - zimbra -c "perl -I${scriptDir} ${scriptDir}/fixConversationCounts.pl"`;
			stopSql();
		}

		if (isInstalled("zimbra-ldap")) {
			Migrate::log ("Updating ldap domain admin attributes");
			`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr givenName"`;
			`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraMailForwardingAddress"`;
			`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraNewMailNotificationSubject"`;
			`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraNewMailNotificationFrom"`;
			`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraNewMailNotificationBody"`;
			`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraServerInheritedAttr zimbraMtaMyNetworks"`;
		}
	}
	return 0;
}

sub upgradeBM4 {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 3.0.0_M4");
	if (isInstalled("zimbra-ldap")) {
		`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraMailStatus"`;
		if ($startVersion eq "3.0.0_M2" || $startVersion eq "3.0.M1" || $startVersion eq "3.0.0_M3" ||
			$startBuild <= 41) {
			`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraAccountClientAttr zimbraFeatureViewInHtmlEnabled"`;
			`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraDomainAdminModifiableAttr zimbraFeatureViewInHtmlEnabled"`;
			`su - zimbra -c "/opt/zimbra/bin/zmprov mcf +zimbraCOSInheritedAttr zimbraFeatureViewInHtmlEnabled"`;
			`su - zimbra -c "/opt/zimbra/bin/zmprov mc default zimbraFeatureViewInHtmlEnabled FALSE"`;
		}
	}

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

sub stopLoggerSql {
	Migrate::log("Stopping logger mysql");
	my $rc = 0xffff & system("su - zimbra -c \"/opt/zimbra/bin/logmysql.server stop > /dev/null 2>&1\"");
	$rc = $rc >> 8;
	if ($rc) {
		Migrate::log("logger mysql stop failed with exit code $rc");
		return $rc;
	}
	return 0;
}

sub startLdap {
	Migrate::log("Checking ldap status");
	my $rc = 0xffff & system("su - zimbra -c \"/opt/zimbra/bin/ldap status > /dev/null 2>&1\"");
	$rc = $rc >> 8;
	if ($rc) {
		Migrate::log("Starting ldap");
		$rc = 0xffff & system("su - zimbra -c \"/opt/zimbra/bin/zmldapapplyldif > /dev/null 2>&1\"");
		$rc = 0xffff & system("su - zimbra -c \"/opt/zimbra/bin/ldap status > /dev/null 2>&1\"");
		$rc = $rc >> 8;
		if ($rc) {
			$rc = 0xffff & system("su - zimbra -c \"/opt/zimbra/bin/ldap start > /dev/null 2>&1\"");
			$rc = $rc >> 8;
			if ($rc) {
				Migrate::log("ldap startup failed with exit code $rc");
				return $rc;
			}
		}
	}
	return 0;
}

sub stopLdap {
	Migrate::log("Stopping ldap");
	my $rc = 0xffff & system("su - zimbra -c \"/opt/zimbra/bin/ldap stop > /dev/null 2>&1\"");
	$rc = $rc >> 8;
	if ($rc) {
		Migrate::log("LDAP stop failed with exit code $rc");
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

sub startLoggerSql {
	Migrate::log("Checking logger mysql status");
	my $rc = 0xffff & system("su - zimbra -c \"/opt/zimbra/bin/logmysqladmin status > /dev/null 2>&1\"");
	$rc = $rc >> 8;
	if ($rc) {
		Migrate::log("Starting logger mysql");
		$rc = 0xffff & system("su - zimbra -c \"/opt/zimbra/bin/logmysql.server start > /dev/null 2>&1\"");
		$rc = $rc >> 8;
		if ($rc) {
			Migrate::log("logger mysql startup failed with exit code $rc");
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

sub runLoggerSchemaUpgrade {
	my $curVersion = shift;

	if (! defined ($loggerUpdateScripts{$curVersion})) {
		Migrate::log ("Can't upgrade from version $curVersion - no script!");
		return 1;
	}

	if (! -x "${scriptDir}/$loggerUpdateScripts{$curVersion}" ) {
		Migrate::log ("Can't run ${scriptDir}/$loggerUpdateScripts{$curVersion} - no script!");
		return 1;
	}

	Migrate::log ("Running ${scriptDir}/$loggerUpdateScripts{$curVersion}");
	my $rc = 0xffff & system("su - zimbra -c \"perl -I${scriptDir} ${scriptDir}/$loggerUpdateScripts{$curVersion}\"");
	$rc = $rc >> 8;
	if ($rc) {
		Migrate::log ("Script failed with code $rc - exiting");
		return $rc;
	}
	return 0;
}

sub getInstalledPackages {

	foreach my $p (@packageList) {
		if (isInstalled($p)) {
			$installedPackages{$p} = $p;
		}
	}

}

sub isInstalled {
	my $pkg = shift;

	my $pkgQuery;

	my $good = 1;
	if ($platform eq "DEBIAN3.1") {
		$pkgQuery = "dpkg -s $pkg | egrep '^Status: ' | grep 'not-installed'";
	} elsif ($platform eq "MACOSX") {
		my @l = sort glob ("/Library/Receipts/${pkg}*");
		if ( $#l < 0 ) { return 0; }
		$pkgQuery = "test -d $l[$#l]";
		$good = 0;
	} else {
		$pkgQuery = "rpm -q $pkg";
		$good = 0;
	}

	my $rc = 0xffff & system ("$pkgQuery > /dev/null 2>&1");
	$rc >>= 8;
	return ($rc == $good);

}


1
