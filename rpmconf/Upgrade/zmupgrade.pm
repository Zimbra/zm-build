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
# Portions created by Zimbra are Copyright (C) 2005, 2006 Zimbra, Inc.
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
my $hiVersion = 25;
my $hiLoggerVersion = 5;

my $hn = `su - zimbra -c "zmlocalconfig -m nokey zimbra_server_hostname"`;
chomp $hn;

my $ZMPROV = "/opt/zimbra/bin/zmprov -l";

my %updateScripts = (
	'UniqueVolume' => "migrate20051021-UniqueVolume.pl",
	'18' => "migrate20050916-Volume.pl",
	'19' => "migrate20050920-CompressionThreshold.pl",
	'20' => "migrate20050927-DropRedologSequence.pl",
	'21' => "migrate20060412-NotebookFolder.pl",
	'22' => "migrate20060515-AddImapId.pl",
	'23' => "migrate20060518-EmailedContactsFolder.pl",
	'24' => "migrate20060708-FlagCalendarFolder.pl",
);

my %loggerUpdateScripts = (
	'0' => "migrateLogger1-index.pl",
	'1' => "migrateLogger2-config.pl",
	'2' => "migrateLogger3-diskindex.pl",
	'3' => "migrateLogger4-loghostname.pl",
	'4' => "migrateLogger5-qid.pl",
);

my %updateFuncs = (
	"3.0.M1" => \&upgradeBM1,
	"3.0.0_M2" => \&upgradeBM2,
	"3.0.0_M3" => \&upgradeBM3,
	"3.0.0_M4" => \&upgradeBM4,
	"3.0.0_GA" => \&upgradeBGA,
	"3.0.1_GA" => \&upgrade301GA,
	"3.1.0_GA" => \&upgrade310GA,
	"3.1.1_GA" => \&upgrade311GA,
	"3.1.2_GA" => \&upgrade312GA,
	"3.1.3_GA" => \&upgrade313GA,
	"3.1.4_GA" => \&upgrade314GA,
	"3.2.0_M1" => \&upgrade32M1,
	"3.2.0_M2" => \&upgrade32M2,
	"3.5.0_M1" => \&upgrade35M1,  #Hack for missed version change
);

my @versionOrder = (
	"3.0.M1", 
	"3.0.0_M2", 
	"3.0.0_M3", 
	"3.0.0_M4", 
	"3.0.0_GA", 
	"3.0.1_GA", 
	"3.1.0_GA", 
	"3.1.1_GA", 
	"3.1.2_GA", 
	"3.1.3_GA", 
	"3.1.4_GA", 
	"3.2.0_M1",
	"3.2.0_M2",
	"3.5.0_M1"  #Hack for missed version change
);

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
my $platform = `/opt/zimbra/libexec/get_plat_tag.sh`;
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

	my $needVolumeHack = 0;

	getInstalledPackages();

	if (stopZimbra()) { return 1; }

	my $curSchemaVersion;
	my $curLoggerSchemaVersion;

	if (isInstalled("zimbra-store")) {
		if (startSql()) { return 1; }
		$curSchemaVersion = Migrate::getSchemaVersion();
	}

	if (isInstalled("zimbra-logger") && -d "/opt/zimbra/logger/db/data/zimbra_logger/") {
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

	if ($startVersion eq "3.0.0_GA") {
		print "This appears to be 3.0.0_GA\n";
	} elsif ($startVersion eq "3.0.1_GA") {
		print "This appears to be 3.0.1_GA\n";
		$needVolumeHack = 1;
	} elsif ($startVersion eq "3.1.0_GA") {
		print "This appears to be 3.1.0_GA\n";
	} elsif ($startVersion eq "3.1.1_GA") {
		print "This appears to be 3.1.1_GA\n";
	} elsif ($startVersion eq "3.1.2_GA") {
		print "This appears to be 3.1.2_GA\n";
	} elsif ($startVersion eq "3.1.3_GA") {
		print "This appears to be 3.1.3_GA\n";
	} elsif ($startVersion eq "3.1.4_GA") {
		print "This appears to be 3.1.4_GA\n";
	} elsif ($startVersion eq "3.2.0_M1") {
		print "This appears to be 3.2.0_M1\n";
	} elsif ($startVersion eq "3.2.0_M2") {
		print "This appears to be 3.2.0_M2\n";
	} elsif ($startVersion eq "3.5.0_M1") {
		print "This appears to be 3.5.0_M1\n";
	} else {
		print "I can't upgrade version $startVersion\n\n";
		return 1;
	}

	if (isInstalled("zimbra-store")) {

		if ($curSchemaVersion < $hiVersion) {
			print "Schema upgrade required\n";
		}

		while ($curSchemaVersion >= $lowVersion && $curSchemaVersion < $hiVersion) {
			if (($curSchemaVersion == 21) && $needVolumeHack) {
				if (runSchemaUpgrade ("UniqueVolume")) { return 1; }
			} 
			if (runSchemaUpgrade ($curSchemaVersion)) { return 1; }
			$curSchemaVersion++;
		}
		stopSql();
	}

	if (isInstalled ("zimbra-logger") && -d "/opt/zimbra/logger/db/data/zimbra_logger/") {
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
		if (-f "/opt/zimbra/openldap-data/ldap.bak") {
			Migrate::log("Migrating ldap data");
			if (-d "/opt/zimbra/openldap-data.prev") {
				`mv /opt/zimbra/openldap-data.prev /opt/zimbra/openldap-data.prev.$$`;
			}
			`mv /opt/zimbra/openldap-data /opt/zimbra/openldap-data.prev`;
			`mkdir /opt/zimbra/openldap-data`;
			`touch /opt/zimbra/openldap-data/DB_CONFIG`;
			`chown -R zimbra:zimbra /opt/zimbra/openldap-data`;
			`su - zimbra -c "/opt/zimbra/openldap/sbin/slapadd -f /opt/zimbra/conf/slapd.conf -l /opt/zimbra/openldap-data.prev/ldap.bak"`;
		}
		`su - zimbra -c "/opt/zimbra/openldap/sbin/slapindex -f /opt/zimbra/conf/slapd.conf"`;
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

	movePostfixQueue ("2.2.3","2.2.5");

	return 0;
}

sub upgradeBM3 {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 3.0.0_M3");

	# $startBuild -> $targetBuild
	if ($startVersion eq "3.0.0_M2" || $startVersion eq "3.0.M1" || $startBuild <= 346) {
		# Set mode and authhost
		`su - zimbra -c "$ZMPROV ms $hn zimbraMailMode http"`;
		`su - zimbra -c "$ZMPROV ms $hn zimbraMtaAuthHost $hn"`;
	}
	if (($startVersion eq "3.0.0_M2" || $startVersion eq "3.0.M1" || $startBuild <= 427) &&
		isInstalled ("zimbra-ldap")) {

		Migrate::log ("Updating ldap GAL attributes");
		`su - zimbra -c "$ZMPROV mcf +zimbraGalLdapAttrMap zimbraId=zimbraId +zimbraGalLdapAttrMap objectClass=objectClass +zimbraGalLdapAttrMap zimbraMailForwardingAddress=zimbraMailForwardingAddress"`;

		Migrate::log ("Updating ldap CLIENT attributes");
		`su - zimbra -c "$ZMPROV mcf +zimbraAccountClientAttr zimbraIsDomainAdminAccount +zimbraAccountClientAttr zimbraFeatureIMEnabled"`;
		`su - zimbra -c "$ZMPROV mcf +zimbraCOSInheritedAttr zimbraFeatureIMEnabled"`;
		Migrate::log ("Updating ldap domain admin attributes");
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraAccountStatus"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr company"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr cn"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr co"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr displayName"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr gn"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr description"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr initials"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr l"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraAttachmentsBlocked"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraAttachmentsIndexingEnabled"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraAttachmentsViewInHtmlOnly"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraAuthTokenLifetime"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraAuthLdapExternalDn"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraAdminAuthTokenLifetime"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraContactMaxNumEntries"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureContactsEnabled"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureGalEnabled"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureHtmlComposeEnabled"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureCalendarEnabled"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureIMEnabled"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureTaggingEnabled"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureAdvancedSearchEnabled"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureSavedSearchesEnabled"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureConversationsEnabled"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureChangePasswordEnabled"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureInitialSearchPreferenceEnabled"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureFiltersEnabled"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraForeignPrincipal"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraImapEnabled"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraIsDomainAdminAccount"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraMailIdleSessionTimeout"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraMailMessageLifetime"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraMailMinPollingInterval"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraMailSpamLifetime"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraMailTrashLifetime"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraNotes"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPasswordLocked"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPasswordMinLength"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPasswordMaxLength"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPasswordMinAge"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPasswordMaxAge"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPasswordEnforceHistory"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPasswordMustChange"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPop3Enabled"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefTimeZoneId"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefUseTimeZoneListInCalendar"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefComposeInNewWindow"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefComposeFormat"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefHtmlEditorDefaultFontColor"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefHtmlEditorDefaultFontFamily"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefHtmlEditorDefaultFontSize"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefForwardReplyInOriginalFormat"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefAutoAddAddressEnabled"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefShowFragments"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefShowSearchString"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarFirstDayOfWeek"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarInitialView"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarInitialCheckedCalendars"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarUseQuickAdd"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarAlwaysShowMiniCal"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarNotifyDelegatedChanges"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefContactsInitialView"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefDedupeMessagesSentToSelf"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefForwardIncludeOriginalText"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefForwardReplyPrefixChar"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefGroupMailBy"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefImapSearchFoldersEnabled"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefIncludeSpamInSearch"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefIncludeTrashInSearch"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailInitialSearch"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailItemsPerPage"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefContactsPerPage"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefMessageViewHtmlPreferred"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailPollingInterval"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailSignature"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailSignatureEnabled"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailSignatureStyle"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefNewMailNotificationAddress"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefNewMailNotificationEnabled"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefOutOfOfficeReply"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefOutOfOfficeReplyEnabled"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefReplyIncludeOriginalText"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefReplyToAddress"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefSaveToSent"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefSentMailFolder"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefUseKeyboardShortcuts"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraZimletAvailableZimlets"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraZimletUserProperties"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr o"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr ou"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr physicalDeliveryOfficeName"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr postalAddress"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr postalCode"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr sn"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr st"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr telephoneNumber"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr title"`;
		print ".";
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraMailStatus"`;
		print "\n";

		Migrate::log ("Updating ldap server attributes");

		`su - zimbra -c "$ZMPROV mcf zimbraLmtpNumThreads 20 "`;
		`su - zimbra -c "$ZMPROV mcf zimbraMessageCacheSize 1671168 "`;
		`su - zimbra -c "$ZMPROV mcf +zimbraServerInheritedAttr zimbraMessageCacheSize +zimbraServerInheritedAttr zimbraMtaAuthHost +zimbraServerInheritedAttr zimbraMtaAuthURL +zimbraServerInheritedAttr zimbraMailMode"`;
		`su - zimbra -c "$ZMPROV mcf -zimbraMtaRestriction reject_non_fqdn_hostname"`;
	}
	if ($startVersion eq "3.0.0_M2" || $startVersion eq "3.0.M1" || $startBuild <= 436) {
		if (isInstalled("zimbra-store")) {
			if (startSql()) { return 1; }
			`su - zimbra -c "perl -I${scriptDir} ${scriptDir}/fixConversationCounts.pl"`;
			stopSql();
		}

		if (isInstalled("zimbra-ldap")) {
			Migrate::log ("Updating ldap domain admin attributes");
			`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr givenName"`;
			`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraMailForwardingAddress"`;
			`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraNewMailNotificationSubject"`;
			`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraNewMailNotificationFrom"`;
			`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraNewMailNotificationBody"`;
			`su - zimbra -c "$ZMPROV mcf +zimbraServerInheritedAttr zimbraMtaMyNetworks"`;
		}
	}
	return 0;
}

sub upgradeBM4 {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 3.0.0_M4");
	if (isInstalled("zimbra-ldap")) {
		`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraMailStatus"`;
		if ($startVersion eq "3.0.0_M2" || $startVersion eq "3.0.M1" || $startVersion eq "3.0.0_M3" ||
			$startBuild <= 41) {
			`su - zimbra -c "$ZMPROV mcf +zimbraAccountClientAttr zimbraFeatureViewInHtmlEnabled"`;
			`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureViewInHtmlEnabled"`;
			`su - zimbra -c "$ZMPROV mcf +zimbraCOSInheritedAttr zimbraFeatureViewInHtmlEnabled"`;
			`su - zimbra -c "$ZMPROV mc default zimbraFeatureViewInHtmlEnabled FALSE"`;
		}
	}
	if ($startVersion eq "3.0.0_M4" && $startBuild == 41) {
		if (isInstalled("zimbra-store")) {
			if (startSql()) { return 1; }
			`su - zimbra -c "perl -I${scriptDir} ${scriptDir}/migrate20060120-Appointment.pl"`;
			stopSql();
		}
	}

	return 0;
}

sub upgradeBGA {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 3.0.0_GA");
	return 0;

	if ( -d "/opt/zimbra/clamav-0.87.1/db" && -d "/opt/zimbra/clamav-0.88" &&
		! -d "/opt/zimbra/clamav-0.88/db" )  {
			`cp -fR /opt/zimbra/clamav-0.87.1/db /opt/zimbra/clamav-0.88`;
	}

	movePostfixQueue ("2.2.5","2.2.8");


}

sub upgrade301GA {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 3.0.1_GA");

	open (G, "$ZMPROV gcf zimbraGalLdapFilterDef |") or die "Can't open zmprov: $!";
	`$ZMPROV mcf zimbraGalLdapFilterDef ''`;
	while (<G>) {
		chomp;
		s/\(zimbraMailAddress=\*%s\*\)//;
		s/zimbraGalLdapFilterDef: //;
		`$ZMPROV mcf +zimbraGalLdapFilterDef \'$_\'`;
	}

	# This change was made in both main and CRAY
	# CRAY build 202
	# MAIN build 223
	if ( ($startVersion eq "3.0.0_GA" && $startBuild <= 202) ||
		($startVersion eq "3.0.0_M2" || $startVersion eq "3.0.M1" || 
		$startVersion eq "3.0.0_M3" || $startVersion eq "3.0.0_M4")
		) {
		`su - zimbra -c "zmlocalconfig -e postfix_version=2.2.9"`;
		movePostfixQueue ("2.2.8","2.2.9");

	}
	`su - zimbra -c "$ZMPROV mcf +zimbraCOSInheritedAttr zimbraFeatureSharingEnabled"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraDomainInheritedAttr zimbraFeatureSharingEnabled"`;
	`su - zimbra -c "$ZMPROV mc default zimbraFeatureSharingEnabled TRUE"`;

	return 0;
}

sub upgrade310GA {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 3.1.0_GA");
	`su - zimbra -c "$ZMPROV mcf +zimbraCOSInheritedAttr zimbraFeatureSharingEnabled"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraDomainInheritedAttr zimbraFeatureSharingEnabled"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraAccountClientAttr zimbraFeatureSharingEnabled"`;
	`su - zimbra -c "$ZMPROV mc default zimbraFeatureSharingEnabled TRUE"`;

	`su - zimbra -c "$ZMPROV mcf -zimbraGalLdapFilterDef 'zimbra:(&(|(cn=*%s*)(sn=*%s*)(gn=*%s*)(mail=*%s*)(zimbraMailDeliveryAddress=*%s*)(zimbraMailAlias=*%s*))(|(objectclass=zimbraAccount)(objectclass=zimbraDistributionList)))'"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraGalLdapFilterDef 'zimbraAccounts:(&(|(cn=*%s*)(sn=*%s*)(gn=*%s*)(mail=*%s*)(zimbraMailDeliveryAddress=*%s*)(zimbraMailAlias=*%s*)(zimbraMailAddress=*%s*))(|(objectclass=zimbraAccount)(objectclass=zimbraDistributionList))(!(objectclass=zimbraCalendarResource)))'"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraGalLdapFilterDef 'zimbraResources:(&(|(cn=*%s*)(sn=*%s*)(gn=*%s*)(mail=*%s*)(zimbraMailDeliveryAddress=*%s*)(zimbraMailAlias=*%s*)(zimbraMailAddress=*%s*))(objectclass=zimbraCalendarResource))'"`;

	# Bug 6077
	`su - zimbra -c "$ZMPROV mcf -zimbraGalLdapAttrMap 'givenName=firstName'"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraGalLdapAttrMap 'gn=firstName'"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraGalLdapAttrMap 'description=notes'"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraGalLdapAttrMap 'zimbraCalResType=zimbraCalResType'"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraGalLdapAttrMap 'zimbraCalResLocationDisplayName=zimbraCalResLocationDisplayName'"`;

	# bug: 2799
	`su - zimbra -c "$ZMPROV mcf +zimbraCOSInheritedAttr zimbraPrefCalendarApptReminderWarningTime"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarApptReminderWarningTime"`;
	`su - zimbra -c "$ZMPROV mc default zimbraPrefCalendarApptReminderWarningTime 5"`;

	`su - zimbra -c "$ZMPROV mcf +zimbraAccountClientAttr zimbraFeatureMailForwardingEnabled"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraCOSInheritedAttr zimbraFeatureMailForwardingEnabled"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureMailForwardingEnabled"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailForwardingAddress"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailLocalDeliveryDisabled"`;
	`su - zimbra -c "$ZMPROV mc default zimbraFeatureMailForwardingEnabled TRUE"`;

	# bug 6077
	`su - zimbra -c "$ZMPROV mcf +zimbraAccountClientAttr zimbraLocale"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraCOSInheritedAttr zimbraLocale"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraLocale"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraServerInheritedAttr zimbraLocale"`;

	# bug 6834
	`su - zimbra -c "$ZMPROV mcf +zimbraServerInheritedAttr zimbraRemoteManagementCommand"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraServerInheritedAttr zimbraRemoteManagementUser"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraServerInheritedAttr zimbraRemoteManagementPrivateKeyPath"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraServerInheritedAttr zimbraRemoteManagementPort"`;
	`su - zimbra -c "$ZMPROV ms $hn zimbraRemoteManagementCommand /opt/zimbra/libexec/zmrcd"`;
	`su - zimbra -c "$ZMPROV ms $hn zimbraRemoteManagementUser zimbra"`;
	`su - zimbra -c "$ZMPROV ms $hn zimbraRemoteManagementPrivateKeyPath /opt/zimbra/.ssh/zimbra_identity"`;
	`su - zimbra -c "$ZMPROV ms $hn zimbraRemoteManagementPort 22"`;

	# bug: 6828
	`su - zimbra -c "$ZMPROV mcf -zimbraGalLdapAttrMap zimbraMailAlias=email2"`;

	if ( ($startVersion eq "3.1.0_GA" && $startBuild <= 303) ||
		($startVersion eq "3.0.0_GA" || $startVersion eq "3.0.0_M2" || $startVersion eq "3.0.M1" || 
		$startVersion eq "3.0.0_M3" || $startVersion eq "3.0.0_M4")
		) {
		if (-f "/opt/zimbra/redolog/redo.log") {
			`mv /opt/zimbra/redolog/redo.log /opt/zimbra/redolog/redo.log.preupgrade`;
		}
		if (-d "/opt/zimbra/redolog/archive") {
			`mv /opt/zimbra/redolog/archive /opt/zimbra/redolog/archive.preupgrade`;
		}
	}

	# bug 7241
	`su - zimbra -c "/opt/zimbra/bin/zmsshkeygen"`;

	return 0;
}

sub upgrade311GA {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 3.1.1_GA");

	return 0;
}

sub upgrade312GA {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 3.1.2_GA");
	return 0;
}

sub upgrade313GA {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 3.1.3_GA");
	my @accounts = `su - zimbra -c "$ZMPROV gaa"`;
	foreach (@accounts) {
		chomp;
		`su - zimbra -c "$ZMPROV ma $_ zimbraPrefMailLocalDeliveryDisabled FALSE"`;
	}
	return 0;
}

sub upgrade314GA {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 3.1.4_GA");
  my $a = <<EOF;
# parse text/plain internally
dn: cn=text/plain,cn=mime,cn=config,cn=zimbra
changetype: add
zimbraMimeType: text/plain
cn: text/plain
objectClass: zimbraMimeEntry
zimbraMimeIndexingEnabled: TRUE
zimbraMimeHandlerClass: TextPlainHandler
zimbraMimeFileExtension: text
zimbraMimeFileExtension: txt
description: Plain Text Document
EOF

  open L, ">/tmp/text-plain.ldif";
  print L $a;
  close L;
  my $ldap_pass = `su - zimbra -c "zmlocalconfig -s -m nokey ldap_root_password"`;
  chomp $ldap_pass;
  `su - zimbra -c "ldapmodify -c -D uid=zimbra,cn=admins,cn=zimbra -x -w $ldap_pass -f /tmp/text-plain.ldif"`;
	return 0;
}

sub upgrade32M1 {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 3.2.0_M1");

	`su - zimbra -c "$ZMPROV mcf +zimbraCOSInheritedAttr zimbraFeatureSharingEnabled"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraDomainInheritedAttr zimbraFeatureSharingEnabled"`;
	`su - zimbra -c "$ZMPROV mc default zimbraFeatureSharingEnabled TRUE"`;

	`su - zimbra -c "$ZMPROV mcf zimbraGalLdapFilterDef 'zimbraAccounts:(&(|(cn=*%s*)(sn=*%s*)(gn=*%s*)(mail=*%s*)(zimbraMailDeliveryAddress=*%s*)(zimbraMailAlias=*%s*)(zimbraMailAddress=*%s*))(|(objectclass=zimbraAccount)(objectclass=zimbraDistributionList))(!(objectclass=zimbraCalendarResource)))'"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraGalLdapFilterDef 'zimbraResources:(&(|(cn=*%s*)(sn=*%s*)(gn=*%s*)(mail=*%s*)(zimbraMailDeliveryAddress=*%s*)(zimbraMailAlias=*%s*)(zimbraMailAddress=*%s*))(objectclass=zimbraCalendarResource))'"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraGalLdapFilterDef 'ad:(&(|(cn=*%s*)(sn=*%s*)(gn=*%s*)(mail=*%s*))(!(msExchHideFromAddressLists=TRUE))(mailnickname=*)(|(&(objectCategory=person)(objectClass=user)(!(homeMDB=*))(!(msExchHomeServerName=*)))(&(objectCategory=person)(objectClass=user)(|(homeMDB=*)(msExchHomeServerName=*)))(&(objectCategory=person)(objectClass=contact))(objectCategory=group)(objectCategory=publicFolder)(objectCategory=msExchDynamicDistributionList)))'"`;

	# Bug 6077
	`su - zimbra -c "$ZMPROV mcf -zimbraGalLdapAttrMap 'givenName=firstName'"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraGalLdapAttrMap 'gn=firstName'"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraGalLdapAttrMap 'description=notes'"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraGalLdapAttrMap 'zimbraCalResType=zimbraCalResType'"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraGalLdapAttrMap 'zimbraCalResLocationDisplayName=zimbraCalResLocationDisplayName'"`;

	# bug: 2799
	`su - zimbra -c "$ZMPROV mcf +zimbraCOSInheritedAttr zimbraPrefCalendarApptReminderWarningTime"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarApptReminderWarningTime"`;
	`su - zimbra -c "$ZMPROV mc default zimbraPrefCalendarApptReminderWarningTime 5"`;

	# Bug 7590
	my @coses = `su - zimbra -c "$ZMPROV gac"`;
	foreach my $cos (@coses) {
		chomp $cos;
		`su - zimbra -c "$ZMPROV mc $cos zimbraFeatureSkinChangeEnabled TRUE zimbraPrefSkin steel zimbraFeatureNotebookEnabled TRUE"`;
	}

	# Bug 7590
	# The existing one whose default we flipped, someone else who cares about it
	# should yes/no the flip.  The attribute is zimbraPrefAutoAddAddressEnabled which
	# used to be FALSE by default and as of Edison we are going TRUE by default for
	# all new installs.

	# bug 7588

	`su - zimbra -c "$ZMPROV mcf -zimbraGalLdapAttrMap gn=firstName"`;
	`su - zimbra -c "$ZMPROV mcf +zimbraGalLdapAttrMap givenName,gn=firstName "`;

	# Bug 5466
	my $acct = `su - zimbra -c "$ZMPROV gcf zimbraSpamIsSpamAccount"`;
	chomp $acct;
	$acct =~ s/.* //;
	if ($acct ne "") {
		`su - zimbra -c "$ZMPROV ma $acct zimbraHideInGal TRUE"`;
	}
	$acct = `su - zimbra -c "$ZMPROV gcf zimbraSpamIsNotSpamAccount"`;
	chomp $acct;
	$acct =~ s/.* //;
	if ($acct ne "") {
		`su - zimbra -c "$ZMPROV ma $acct zimbraHideInGal TRUE"`;
	}

	# Bug 7723
	`su - zimbra -c "$ZMPROV -zimbraLdapGalAttrMap zimbraMailDeliveryAddress,mail=email"`;

	`su - zimbra -c "$ZMPROV zimbraLdapGalAttrMap zimbraMailDeliveryAddress,zimbraMailAlias,mail=email,email2,email3,email4,email5,email6"`;

	# bug 7391
	# Notebook
	my $nbacct = `su - zimbra -c "$ZMPROV gcf zimbraNotebookAccount | sed -e 's/zimbraNotebookAccount: //'"`;
	if ($nbacct eq "") {

		open DOMAINS, "$ZMPROV gad |" or die "Can't get domain list!";
		my $domain = <DOMAINS>;
		close DOMAINS;
		chomp $domain;
		open RP, "/opt/zimbra/bin/zmjava com.zimbra.cs.util.RandomPassword 8 10|" or
			die "Can't generate random account name: $!\n";
		$nbacct = <RP>;
		close RP;
		chomp $nbacct;
		$nbacct .= '@'.$domain;

		open RP, "/opt/zimbra/bin/zmjava com.zimbra.cs.util.RandomPassword 8 10|" or
		die "Can't generate random account name: $!\n";
		my $nbpass = <RP>;
		close RP;
		chomp $nbpass;

		`su - zimbra -c "$ZMPROV ca $nbacct \'$nbpass\' amavisBypassSpamChecks TRUE zimbraAttachmentsIndexingEnabled FALSE zimbraHideInGal TRUE zimbraMailQuota 0 description \'Global notebook account\'"`;

		`su - zimbra -c "$ZMPROV mcf zimbraNotebookAccount $nbacct"`;
	  `su - zimbra -c "$ZMPROV in $nbacct \'$nbpass\' /opt/zimbra/wiki Template"`;
	}
	`su - zimbra -c "$ZMPROV mc default zimbraFeatureNotebookEnabled TRUE"`;

	if ( -d "/opt/zimbra/amavisd-new-2.3.3/db" && -d "/opt/zimbra/amavisd-new-2.4.1" && ! -d "/opt/zimbra/amavisd-new-2.4.1/db" ) {
		`mv /opt/zimbra/amavisd-new-2.3.3/db /opt/zimbra/amavisd-new-2.4.1/db`;
		`chown -R zimbra:zimbra /opt/zimbra/amavisd-new-2.4.1/db`;
	}
	if ( -d "/opt/zimbra/amavisd-new-2.3.3/.spamassassin" && -d "/opt/zimbra/amavisd-new-2.4.1" && ! -d "/opt/zimbra/amavisd-new-2.4.1/.spamassassin" ) {
		`mv /opt/zimbra/amavisd-new-2.3.3/.spamassassin /opt/zimbra/amavisd-new-2.4.1/.spamassassin`;
		`chown -R zimbra:zimbra /opt/zimbra/amavisd-new-2.4.1/.spamassassin`;
	}


	return 0;
}

sub upgrade32M2 {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 3.2.0_M2");

  # bug 8121
  if ( -e "/opt/zimbra/conf/my.cnf" ) {
    `mv /opt/zimbra/conf/my.cnf /opt/zimbra/conf/my.cnf-pre3.2.0`;
    `su - zimbra /opt/zimbra/libexec/zmmycnf > /opt/zimbra/conf/my.cnf`;
    `chmod 644 /opt/zimbra/conf/my.cnf`; 
  }

	# Bug 9096
	my $acct = `su - zimbra -c "$ZMPROV gcf zimbraSpamIsSpamAccount"`;
	chomp $acct;
	$acct =~ s/.* //;
	if ($acct ne "") {
		`su - zimbra -c "$ZMPROV ma $acct zimbraIsSystemResource TRUE"`;
	}
	$acct = `su - zimbra -c "$ZMPROV gcf zimbraSpamIsNotSpamAccount"`;
	chomp $acct;
	$acct =~ s/.* //;
	if ($acct ne "") {
		`su - zimbra -c "$ZMPROV ma $acct zimbraIsSystemResource TRUE"`;
	}

  # Bug 7850
	my @coses = `su - zimbra -c "$ZMPROV gac"`;
	foreach my $cos (@coses) {
		chomp $cos;
		`su - zimbra -c "$ZMPROV mc $cos zimbraFeatureNewMailNotificationEnabled TRUE zimbraFeatureOutOfOfficeReplyEnabled TRUE"`;
	}

	return 0;
}

sub upgrade35M1 {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 3.5.0_M1");
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
		$rc = 0xffff & system("su - zimbra -c \"/opt/zimbra/libexec/zmldapapplyldif > /dev/null 2>&1\"");
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
	} elsif ($platform =~ /MACOSX/) {
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

sub movePostfixQueue {

	my $fromVersion = shift;
	my $toVersion = shift;

	if ( -d "/opt/zimbra/postfix-$fromVersion/spool" ) {
		Migrate::log("Moving postfix queues");
		my @dirs = qw /active bounce corrupt defer deferred flush hold incoming maildrop/;
		`mkdir -p /opt/zimbra/postfix-$toVersion/spool`;
		foreach my $d (@dirs) {
			if (-d "/opt/zimbra/postfix-$fromVersion/spool/$d/") {
				Migrate::log("Moving $d");
				`cp -Rf /opt/zimbra/postfix-$fromVersion/spool/$d/* /opt/zimbra/postfix-$toVersion/spool/$d`;
				`chown -R postfix:postdrop /opt/zimbra/postfix-$toVersion/spool/$d`;
			}
		}
	}

	`/opt/zimbra/bin/zmfixperms.sh`;
}

1
