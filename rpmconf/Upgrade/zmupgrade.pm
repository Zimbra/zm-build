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
my $hiVersion = 29;
my $hiLoggerVersion = 5;

# Variables for the combo schema updater
my $comboLowVersion = 20;
my $comboHiVersion  = 27;

my $hn = `su - zimbra -c "zmlocalconfig -m nokey zimbra_server_hostname"`;
chomp $hn;

my $ZMPROV = "/opt/zimbra/bin/zmprov -l --";

my %updateScripts = (
  'ComboUpdater' => "migrate-ComboUpdater.pl",
	'UniqueVolume' => "migrate20051021-UniqueVolume.pl",
	'18' => "migrate20050916-Volume.pl",
	'19' => "migrate20050920-CompressionThreshold.pl",
	'20' => "migrate20050927-DropRedologSequence.pl",    # 3.1.2
	'21' => "migrate20060412-NotebookFolder.pl",
	'22' => "migrate20060515-AddImapId.pl",
	'23' => "migrate20060518-EmailedContactsFolder.pl",
	'24' => "migrate20060708-FlagCalendarFolder.pl",
	'25' => "migrate20060803-CreateMailboxMetadata.pl",
	'26' => "migrate20060810-PersistFolderCounts.pl",    # 4.0.2
	'27' => "migrate20060911-MailboxGroup.pl",           # 4.1.0
	'28' => "migrate20060929-TypedTombstones.pl",
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
	"4.0.0_RC1" => \&upgrade400RC1,
	"4.0.0_GA" => \&upgrade400GA,
	"4.0.1_GA" => \&upgrade401GA,
	"4.0.2_GA" => \&upgrade402GA,
	"4.0.3_GA" => \&upgrade403GA,
	"4.1.0_BETA1" => \&upgrade410BETA1,
	"4.1.0_RC1" => \&upgrade410RC1,
	"4.1.0_RC2" => \&upgrade410RC2,
	"4.1.0_GA" => \&upgrade410GA,
	"5.0.0_BETA1" => \&upgrade500BETA1,
	"5.0.0_GA" => \&upgrade500GA,
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
	"4.0.0_RC1",
	"4.0.0_GA",
	"4.0.1_GA",
	"4.0.2_GA",
	"4.0.3_GA",
	"4.1.0_BETA1",
	"4.1.0_RC1",
	"4.1.0_RC2",
	"4.1.0_GA",
  "5.0.0_BETA1",
  "5.0.0_GA",
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

    if (startSql()) { return 1; };

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
	} elsif ($startVersion eq "3.1.0_GA") {
		print "This appears to be 3.1.0_GA\n";
		#$needVolumeHack = 1;
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
	} elsif ($startVersion eq "4.0.0_RC1") {
		print "This appears to be 4.0.0_RC1\n";
	} elsif ($startVersion eq "4.0.0_GA") {
		print "This appears to be 4.0.0_GA\n";
	} elsif ($startVersion eq "4.0.1_GA") {
		print "This appears to be 4.0.1_GA\n";
	} elsif ($startVersion eq "4.0.2_GA") {
		print "This appears to be 4.0.2_GA\n";
	} elsif ($startVersion eq "4.0.3_GA") {
		print "This appears to be 4.0.3_GA\n";
	} elsif ($startVersion eq "4.1.0_BETA1") {
		print "This appears to be 4.1.0_BETA1\n";
	} elsif ($startVersion eq "4.1.0_RC1") {
		print "This appears to be 4.1.0_RC1\n";
	} elsif ($startVersion eq "4.1.0_RC2") {
		print "This appears to be 4.1.0_RC2\n";
	} elsif ($startVersion eq "4.1.0_GA") {
		print "This appears to be 4.1.0_GA\n";
	} elsif ($startVersion eq "5.0.0_BETA1") {
		print "This appears to be 5.0.0_BETA1\n";
	} elsif ($startVersion eq "5.0.0_GA") {
		print "This appears to be 5.0.0_GA\n";
	} else {
		print "I can't upgrade version $startVersion\n\n";
		return 1;
	}

	if (isInstalled("zimbra-store")) {

		if ($curSchemaVersion < $hiVersion) {
			print "Schema upgrade required\n";
		}

    # fast tracked updater (ie invoke mysql once)
    if ($curSchemaVersion >= $comboLowVersion && $curSchemaVersion < $comboHiVersion) {
      if (runSchemaUpgrade("ComboUpdater")) { return 1; }
      $curSchemaVersion = Migrate::getSchemaVersion();
    }

    # the old slow painful way (ie lots of mysql invocations)
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
			main::runAsZimbra("/opt/zimbra/openldap/sbin/slapadd -f /opt/zimbra/conf/slapd.conf -l /opt/zimbra/openldap-data.prev/ldap.bak");
		}
		main::runAsZimbra("/opt/zimbra/openldap/sbin/slapindex -f /opt/zimbra/conf/slapd.conf");
		if (startLdap()) {return 1;} 
	}

	foreach my $v (@versionOrder) {
		print "Checking $v\n\n";
	  Migrate::log("Checking $v\n");
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
	main::runAsZimbra("zmlocalconfig -e trial_expiration_date=$expiry");

	my $ldh = main::runAsZimbra("zmlocalconfig -m nokey ldap_host");
	chomp $ldh;
	my $ldp = main::runAsZimbra("zmlocalconfig -m nokey ldap_port");
	chomp $ldp;

	Migrate::log("Updating ldap url configuration");
	main::runAsZimbra("zmlocalconfig -e ldap_url=ldap://${ldh}:${ldp}");
	main::runAsZimbra("zmlocalconfig -e ldap_master_url=ldap://${ldh}:${ldp}");

	if ($hn eq $ldh) {
		Migrate::log("Setting ldap master to true");
		main::runAsZimbra("zmlocalconfig -e ldap_is_master=true");
	}

	Migrate::log("Updating index configuration");
	main::runAsZimbra("zmlocalconfig -e zimbra_index_idle_flush_time=600");
	main::runAsZimbra("zmlocalconfig -e zimbra_index_lru_size=100");
	main::runAsZimbra("zmlocalconfig -e zimbra_index_max_uncommitted_operations=200");
	main::runAsZimbra("zmlocalconfig -e logger_mysql_port=7307");

	Migrate::log("Updating zimbra user configuration");
	main::runAsZimbra("zmlocalconfig -e zimbra_user=zimbra");
	my $UID = `id -u zimbra`;
	chomp $UID;
	my $GID = `id -g zimbra`;
	chomp $GID;
	main::runAsZimbra("zmlocalconfig -e zimbra_uid=${UID}");
	main::runAsZimbra("zmlocalconfig -e zimbra_gid=${GID}");
	main::runAsZimbra("zmcreatecert");

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
		main::runAsZimbra("$ZMPROV ms $hn zimbraMailMode http");
		main::runAsZimbra("$ZMPROV ms $hn zimbraMtaAuthHost $hn");
	}
	if (($startVersion eq "3.0.0_M2" || $startVersion eq "3.0.M1" || $startBuild <= 427) &&
		isInstalled ("zimbra-ldap")) {

		Migrate::log ("Updating ldap GAL attributes");
		main::runAsZimbra("$ZMPROV mcf +zimbraGalLdapAttrMap zimbraId=zimbraId +zimbraGalLdapAttrMap objectClass=objectClass +zimbraGalLdapAttrMap zimbraMailForwardingAddress=zimbraMailForwardingAddress");

		Migrate::log ("Updating ldap CLIENT attributes");
		main::runAsZimbra("$ZMPROV mcf +zimbraAccountClientAttr zimbraIsDomainAdminAccount +zimbraAccountClientAttr zimbraFeatureIMEnabled");
		main::runAsZimbra("$ZMPROV mcf +zimbraCOSInheritedAttr zimbraFeatureIMEnabled");
		Migrate::log ("Updating ldap domain admin attributes");
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraAccountStatus");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr company");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr cn");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr co");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr displayName");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr gn");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr description");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr initials");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr l");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraAttachmentsBlocked");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraAttachmentsIndexingEnabled");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraAttachmentsViewInHtmlOnly");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraAuthTokenLifetime");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraAuthLdapExternalDn");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraAdminAuthTokenLifetime");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraContactMaxNumEntries");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureContactsEnabled");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureGalEnabled");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureHtmlComposeEnabled");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureCalendarEnabled");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureIMEnabled");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureTaggingEnabled");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureAdvancedSearchEnabled");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureSavedSearchesEnabled");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureConversationsEnabled");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureChangePasswordEnabled");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureInitialSearchPreferenceEnabled");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureFiltersEnabled");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraForeignPrincipal");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraImapEnabled");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraIsDomainAdminAccount");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraMailIdleSessionTimeout");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraMailMessageLifetime");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraMailMinPollingInterval");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraMailSpamLifetime");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraMailTrashLifetime");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraNotes");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPasswordLocked");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPasswordMinLength");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPasswordMaxLength");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPasswordMinAge");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPasswordMaxAge");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPasswordEnforceHistory");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPasswordMustChange");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPop3Enabled");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefTimeZoneId");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefUseTimeZoneListInCalendar");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefComposeInNewWindow");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefComposeFormat");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefHtmlEditorDefaultFontColor");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefHtmlEditorDefaultFontFamily");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefHtmlEditorDefaultFontSize");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefForwardReplyInOriginalFormat");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefAutoAddAddressEnabled");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefShowFragments");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefShowSearchString");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarFirstDayOfWeek");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarInitialView");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarInitialCheckedCalendars");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarUseQuickAdd");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarAlwaysShowMiniCal");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarNotifyDelegatedChanges");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefContactsInitialView");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefDedupeMessagesSentToSelf");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefForwardIncludeOriginalText");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefForwardReplyPrefixChar");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefGroupMailBy");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefImapSearchFoldersEnabled");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefIncludeSpamInSearch");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefIncludeTrashInSearch");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailInitialSearch");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailItemsPerPage");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefContactsPerPage");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefMessageViewHtmlPreferred");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailPollingInterval");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailSignature");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailSignatureEnabled");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailSignatureStyle");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefNewMailNotificationAddress");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefNewMailNotificationEnabled");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefOutOfOfficeReply");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefOutOfOfficeReplyEnabled");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefReplyIncludeOriginalText");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefReplyToAddress");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefSaveToSent");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefSentMailFolder");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefUseKeyboardShortcuts");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraZimletAvailableZimlets");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraZimletUserProperties");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr o");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr ou");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr physicalDeliveryOfficeName");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr postalAddress");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr postalCode");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr sn");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr st");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr telephoneNumber");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr title");
		print ".";
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraMailStatus");
		print "\n";

		Migrate::log ("Updating ldap server attributes");

		main::runAsZimbra("$ZMPROV mcf zimbraLmtpNumThreads 20 ");
		main::runAsZimbra("$ZMPROV mcf zimbraMessageCacheSize 1671168 ");
		main::runAsZimbra("$ZMPROV mcf +zimbraServerInheritedAttr zimbraMessageCacheSize +zimbraServerInheritedAttr zimbraMtaAuthHost +zimbraServerInheritedAttr zimbraMtaAuthURL +zimbraServerInheritedAttr zimbraMailMode");
		main::runAsZimbra("$ZMPROV mcf -zimbraMtaRestriction reject_non_fqdn_hostname");
	}
	if ($startVersion eq "3.0.0_M2" || $startVersion eq "3.0.M1" || $startBuild <= 436) {
		if (isInstalled("zimbra-store")) {
			if (startSql()) { return 1; }
			main::runAsZimbra("perl -I${scriptDir} ${scriptDir}/fixConversationCounts.pl");
			stopSql();
		}

		if (isInstalled("zimbra-ldap")) {
			Migrate::log ("Updating ldap domain admin attributes");
			main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr givenName");
			main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraMailForwardingAddress");
			main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraNewMailNotificationSubject");
			main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraNewMailNotificationFrom");
			main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraNewMailNotificationBody");
			main::runAsZimbra("$ZMPROV mcf +zimbraServerInheritedAttr zimbraMtaMyNetworks");
		}
	}
	return 0;
}

sub upgradeBM4 {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 3.0.0_M4");
	if (isInstalled("zimbra-ldap")) {
		main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraMailStatus");
		if ($startVersion eq "3.0.0_M2" || $startVersion eq "3.0.M1" || $startVersion eq "3.0.0_M3" ||
			$startBuild <= 41) {
			main::runAsZimbra("$ZMPROV mcf +zimbraAccountClientAttr zimbraFeatureViewInHtmlEnabled");
			main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureViewInHtmlEnabled");
			main::runAsZimbra("$ZMPROV mcf +zimbraCOSInheritedAttr zimbraFeatureViewInHtmlEnabled");
			main::runAsZimbra("$ZMPROV mc default zimbraFeatureViewInHtmlEnabled FALSE");
		}
	}
	if ($startVersion eq "3.0.0_M4" && $startBuild == 41) {
		if (isInstalled("zimbra-store")) {
			if (startSql()) { return 1; }
			main::runAsZimbra("perl -I${scriptDir} ${scriptDir}/migrate20060120-Appointment.pl");
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
		main::runAsZimbra("zmlocalconfig -e postfix_version=2.2.9");
		movePostfixQueue ("2.2.8","2.2.9");

	}
	main::runAsZimbra("$ZMPROV mcf +zimbraCOSInheritedAttr zimbraFeatureSharingEnabled");
	main::runAsZimbra("$ZMPROV mcf +zimbraDomainInheritedAttr zimbraFeatureSharingEnabled");
	main::runAsZimbra("$ZMPROV mc default zimbraFeatureSharingEnabled TRUE");

	return 0;
}

sub upgrade310GA {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 3.1.0_GA");
	main::runAsZimbra("$ZMPROV mcf +zimbraCOSInheritedAttr zimbraFeatureSharingEnabled");
	main::runAsZimbra("$ZMPROV mcf +zimbraDomainInheritedAttr zimbraFeatureSharingEnabled");
	main::runAsZimbra("$ZMPROV mcf +zimbraAccountClientAttr zimbraFeatureSharingEnabled");
	main::runAsZimbra("$ZMPROV mc default zimbraFeatureSharingEnabled TRUE");

	main::runAsZimbra("$ZMPROV mcf -zimbraGalLdapFilterDef 'zimbra:(&(|(cn=*%s*)(sn=*%s*)(gn=*%s*)(mail=*%s*)(zimbraMailDeliveryAddress=*%s*)(zimbraMailAlias=*%s*))(|(objectclass=zimbraAccount)(objectclass=zimbraDistributionList)))'");
	main::runAsZimbra("$ZMPROV mcf +zimbraGalLdapFilterDef 'zimbraAccounts:(&(|(cn=*%s*)(sn=*%s*)(gn=*%s*)(mail=*%s*)(zimbraMailDeliveryAddress=*%s*)(zimbraMailAlias=*%s*)(zimbraMailAddress=*%s*))(|(objectclass=zimbraAccount)(objectclass=zimbraDistributionList))(!(objectclass=zimbraCalendarResource)))'");
	main::runAsZimbra("$ZMPROV mcf +zimbraGalLdapFilterDef 'zimbraResources:(&(|(cn=*%s*)(sn=*%s*)(gn=*%s*)(mail=*%s*)(zimbraMailDeliveryAddress=*%s*)(zimbraMailAlias=*%s*)(zimbraMailAddress=*%s*))(objectclass=zimbraCalendarResource))'");

	# Bug 6077
	main::runAsZimbra("$ZMPROV mcf -zimbraGalLdapAttrMap 'givenName=firstName'");
	main::runAsZimbra("$ZMPROV mcf +zimbraGalLdapAttrMap 'gn=firstName'");
	main::runAsZimbra("$ZMPROV mcf +zimbraGalLdapAttrMap 'description=notes'");
	main::runAsZimbra("$ZMPROV mcf +zimbraGalLdapAttrMap 'zimbraCalResType=zimbraCalResType'");
	main::runAsZimbra("$ZMPROV mcf +zimbraGalLdapAttrMap 'zimbraCalResLocationDisplayName=zimbraCalResLocationDisplayName'");

	# bug: 2799
	main::runAsZimbra("$ZMPROV mcf +zimbraCOSInheritedAttr zimbraPrefCalendarApptReminderWarningTime");
	main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarApptReminderWarningTime");
	main::runAsZimbra("$ZMPROV mc default zimbraPrefCalendarApptReminderWarningTime 5");

	main::runAsZimbra("$ZMPROV mcf +zimbraAccountClientAttr zimbraFeatureMailForwardingEnabled");
	main::runAsZimbra("$ZMPROV mcf +zimbraCOSInheritedAttr zimbraFeatureMailForwardingEnabled");
	main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraFeatureMailForwardingEnabled");
	main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailForwardingAddress");
	main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefMailLocalDeliveryDisabled");
	main::runAsZimbra("$ZMPROV mc default zimbraFeatureMailForwardingEnabled TRUE");

	# bug 6077
	main::runAsZimbra("$ZMPROV mcf +zimbraAccountClientAttr zimbraLocale");
	main::runAsZimbra("$ZMPROV mcf +zimbraCOSInheritedAttr zimbraLocale");
	main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraLocale");
	main::runAsZimbra("$ZMPROV mcf +zimbraServerInheritedAttr zimbraLocale");

	# bug 6834
	main::runAsZimbra("$ZMPROV mcf +zimbraServerInheritedAttr zimbraRemoteManagementCommand");
	main::runAsZimbra("$ZMPROV mcf +zimbraServerInheritedAttr zimbraRemoteManagementUser");
	main::runAsZimbra("$ZMPROV mcf +zimbraServerInheritedAttr zimbraRemoteManagementPrivateKeyPath");
	main::runAsZimbra("$ZMPROV mcf +zimbraServerInheritedAttr zimbraRemoteManagementPort");
	main::runAsZimbra("$ZMPROV ms $hn zimbraRemoteManagementCommand /opt/zimbra/libexec/zmrcd");
	main::runAsZimbra("$ZMPROV ms $hn zimbraRemoteManagementUser zimbra");
	main::runAsZimbra("$ZMPROV ms $hn zimbraRemoteManagementPrivateKeyPath /opt/zimbra/.ssh/zimbra_identity");
	main::runAsZimbra("$ZMPROV ms $hn zimbraRemoteManagementPort 22");

	# bug: 6828
	main::runAsZimbra("$ZMPROV mcf -zimbraGalLdapAttrMap zimbraMailAlias=email2");

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
	main::runAsZimbra("/opt/zimbra/bin/zmsshkeygen");

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

  # removing this per bug 10901
	#my @accounts = `su - zimbra -c "$ZMPROV gaa"`;
	#open (G, "| $ZMPROV ") or die "Can't open zmprov: $!";
	#foreach (@accounts) {
	# chomp;
	# print G "ma $_ zimbraPrefMailLocalDeliveryDisabled FALSE\n";
	#}
	#close G;

	return 0;
}

sub upgrade314GA {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 3.1.4_GA");
	if (isInstalled ("zimbra-ldap")) {
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
  my $ldap_url = `su - zimbra -c "zmlocalconfig -s -m nokey ldap_url"`;
  chomp $ldap_pass;
  chomp $ldap_url;
  main::runAsZimbra("ldapmodify -c -H $ldap_url -D uid=zimbra,cn=admins,cn=zimbra -x -w $ldap_pass -f /tmp/text-plain.ldif");
	}
	return 0;
}

sub upgrade32M1 {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 3.2.0_M1");

	main::runAsZimbra("$ZMPROV mcf +zimbraCOSInheritedAttr zimbraFeatureSharingEnabled");
	main::runAsZimbra("$ZMPROV mcf +zimbraDomainInheritedAttr zimbraFeatureSharingEnabled");
	main::runAsZimbra("$ZMPROV mc default zimbraFeatureSharingEnabled TRUE");

	main::runAsZimbra("$ZMPROV mcf zimbraGalLdapFilterDef 'zimbraAccounts:(&(|(cn=*%s*)(sn=*%s*)(gn=*%s*)(mail=*%s*)(zimbraMailDeliveryAddress=*%s*)(zimbraMailAlias=*%s*)(zimbraMailAddress=*%s*))(|(objectclass=zimbraAccount)(objectclass=zimbraDistributionList))(!(objectclass=zimbraCalendarResource)))'");
	main::runAsZimbra("$ZMPROV mcf +zimbraGalLdapFilterDef 'zimbraResources:(&(|(cn=*%s*)(sn=*%s*)(gn=*%s*)(mail=*%s*)(zimbraMailDeliveryAddress=*%s*)(zimbraMailAlias=*%s*)(zimbraMailAddress=*%s*))(objectclass=zimbraCalendarResource))'");
	main::runAsZimbra("$ZMPROV mcf +zimbraGalLdapFilterDef 'ad:(&(|(cn=*%s*)(sn=*%s*)(gn=*%s*)(mail=*%s*))(!(msExchHideFromAddressLists=TRUE))(mailnickname=*)(|(&(objectCategory=person)(objectClass=user)(!(homeMDB=*))(!(msExchHomeServerName=*)))(&(objectCategory=person)(objectClass=user)(|(homeMDB=*)(msExchHomeServerName=*)))(&(objectCategory=person)(objectClass=contact))(objectCategory=group)(objectCategory=publicFolder)(objectCategory=msExchDynamicDistributionList)))'");

	# Bug 6077
	main::runAsZimbra("$ZMPROV mcf -zimbraGalLdapAttrMap 'givenName=firstName'");
	main::runAsZimbra("$ZMPROV mcf +zimbraGalLdapAttrMap 'gn=firstName'");
	main::runAsZimbra("$ZMPROV mcf +zimbraGalLdapAttrMap 'description=notes'");
	main::runAsZimbra("$ZMPROV mcf +zimbraGalLdapAttrMap 'zimbraCalResType=zimbraCalResType'");
	main::runAsZimbra("$ZMPROV mcf +zimbraGalLdapAttrMap 'zimbraCalResLocationDisplayName=zimbraCalResLocationDisplayName'");

	# bug: 2799
	main::runAsZimbra("$ZMPROV mcf +zimbraCOSInheritedAttr zimbraPrefCalendarApptReminderWarningTime");
	main::runAsZimbra("$ZMPROV mcf +zimbraDomainAdminModifiableAttr zimbraPrefCalendarApptReminderWarningTime");
	main::runAsZimbra("$ZMPROV mc default zimbraPrefCalendarApptReminderWarningTime 5");

	# Bug 7590
	my @coses = `su - zimbra -c "$ZMPROV gac"`;
	foreach my $cos (@coses) {
		chomp $cos;
		main::runAsZimbra("$ZMPROV mc $cos zimbraFeatureSkinChangeEnabled TRUE zimbraPrefSkin steel zimbraFeatureNotebookEnabled TRUE");
	}

	# Bug 7590
	# The existing one whose default we flipped, someone else who cares about it
	# should yes/no the flip.  The attribute is zimbraPrefAutoAddAddressEnabled which
	# used to be FALSE by default and as of Edison we are going TRUE by default for
	# all new installs.

	# bug 7588

	main::runAsZimbra("$ZMPROV mcf -zimbraGalLdapAttrMap gn=firstName");
	main::runAsZimbra("$ZMPROV mcf +zimbraGalLdapAttrMap givenName,gn=firstName ");

	# Bug 5466
  my $acct;
	$acct = (split(/\s+/, `su - zimbra -c "$ZMPROV gcf zimbraSpamIsSpamAccount"`))[-1];
  main::runAsZimbra("$ZMPROV ma $acct zimbraHideInGal TRUE")
	  if ($acct ne "");

	$acct = (split(/\s+/, `su - zimbra -c "$ZMPROV gcf zimbraSpamIsNotSpamAccount"`))[-1];
  main::runAsZimbra("$ZMPROV ma $acct zimbraHideInGal TRUE")
  	if ($acct ne "");

	# Bug 7723
	main::runAsZimbra("$ZMPROV mcf -zimbraGalLdapAttrMap zimbraMailDeliveryAddress,mail=email");

	main::runAsZimbra("$ZMPROV mcf +zimbraGalLdapAttrMap zimbraMailDeliveryAddress,zimbraMailAlias,mail=email,email2,email3,email4,email5,email6");


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
  updateMySQLcnf();

	# Bug 9096
	my $acct = `su - zimbra -c "$ZMPROV gcf zimbraSpamIsSpamAccount"`;
	chomp $acct;
	$acct =~ s/.* //;
	if ($acct ne "") {
		main::runAsZimbra("$ZMPROV ma $acct zimbraIsSystemResource TRUE");
	}
	$acct = `su - zimbra -c "$ZMPROV gcf zimbraSpamIsNotSpamAccount"`;
	chomp $acct;
	$acct =~ s/.* //;
	if ($acct ne "") {
		main::runAsZimbra("$ZMPROV ma $acct zimbraIsSystemResource TRUE");
	}

  # Bug 7850
	my @coses = `su - zimbra -c "$ZMPROV gac"`;
	foreach my $cos (@coses) {
		chomp $cos;
		main::runAsZimbra("$ZMPROV mc $cos zimbraFeatureNewMailNotificationEnabled TRUE zimbraFeatureOutOfOfficeReplyEnabled TRUE");
	}

	return 0;
}

sub upgrade400RC1 {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 4.0.0_RC1");

  # Bug 9504
  if (-d "/opt/zimbra/redolog" && ! -e "/opt/zimbra/redolog-pre-4.0") {
	  `mv /opt/zimbra/redolog /opt/zimbra/redolog-pre-4.0`;
    `mkdir /opt/zimbra/redolog`;
    `chown zimbra:zimbra /opt/zimbra/redolog`;
  }

  if (-e "/opt/zimbra/backup" && ! -e "/opt/zimbra/backup-pre-4.0") {
	  `mv /opt/zimbra/backup /opt/zimbra/backup-pre-4.0`;
    `mkdir /opt/zimbra/backup`;
    `chown zimbra:zimbra /opt/zimbra/backup`;
  }

  # Bug 9419
	main::runAsZimbra("$ZMPROV mcf +zimbraGalLdapFilterDef 'adAutoComplete:(&(|(cn=%s*)(sn=%s*)(gn=%s*)(mail=%s*))(!(msExchHideFromAddressLists=TRUE))(mailnickname=*)(|(&(objectCategory=person)(objectClass=user)(!(homeMDB=*))(!(msExchHomeServerName=*)))(&(objectCategory=person)(objectClass=user)(|(homeMDB=*)(msExchHomeServerName=*)))(&(objectCategory=person)(objectClass=contact))(objectCategory=group)(objectCategory=publicFolder)(objectCategory=msExchDynamicDistributionList)))'");
	main::runAsZimbra("$ZMPROV mcf +zimbraGalLdapFilterDef 'externalLdapAutoComplete:(|(cn=%s*)(sn=%s*)(gn=%s*)(mail=%s*)'");
	main::runAsZimbra("$ZMPROV mcf +zimbraGalLdapFilterDef 'zimbraAccountAutoComplete:(&(|(cn=%s*)(sn=%s*)(gn=%s*)(mail=%s*)(zimbraMailDeliveryAddress=%s*)(zimbraMailAlias=%s*))(|(objectclass=zimbraAccount)(objectclass=zimbraDistributionList))(!(objectclass=zimbraCalendarResource)))'");
	main::runAsZimbra("$ZMPROV mcf +zimbraGalLdapFilterDef 'zimbraResourceAutoComplete:(&(|(cn=%s*)(sn=%s*)(gn=%s*)(mail=%s*)(zimbraMailDeliveryAddress=%s*)(zimbraMailAlias=%s*))(objectclass=zimbraCalendarResource))'");

  # Bug 9693
	if ($startVersion eq "3.2.0_M1" || $startVersion eq "3.2.0_M2") {
		if (isInstalled("zimbra-store")) {
			if (startSql()) { return 1; }
			main::runAsZimbra("sh ${scriptDir}/migrate20060807-WikiDigestFixup.sh");
			stopSql();
		}
	}
  
	return 0;
}

sub upgrade400GA {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 4.0.0_GA");
	return 0;
}

sub upgrade401GA {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 4.0.1_GA");

  # bug 10346
  my $globalWikiAcct = main::getLdapConfigValue("zimbraNotebookAccount");
  next unless $globalWikiAcct;
  main::runAsZimbra("/opt/zimbra/bin/zmprov ma $globalWikiAcct zimbraFeatureNotebookEnabled TRUE");
  
  # bug 10388
  clearTomcatWorkDir();

	return 0;
}

sub upgrade402GA {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 4.0.2_GA");

  # bug 10401
	my @coses = `su - zimbra -c "$ZMPROV gac"`;
	foreach my $cos (@coses) {
		chomp $cos;
    my $cur_value = 
      main::getLdapCOSValue($cos,"zimbraFeatureMobileSyncEnabled");
		main::runAsZimbra("$ZMPROV mc $cos zimbraFeatureMobileSyncEnabled FALSE")
      if ($cur_value ne "TRUE");
	}

  # bug 10845
  main::runAsZimbra("$ZMPROV mcf zimbraMailURL /zimbra");

  return 0;
}

sub upgrade403GA {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 4.0.3_GA");

  #8081 remove amavis tmpfs
  if (-f "/etc/fstab") { 
    `egrep -q '/opt/zimbra/amavisd-new-2.4.1/tmp' /etc/fstab`;
    if ($? == 0 ) {
      `umount /opt/zimbra/amavisd-new-2.4.1/tmp > /dev/null 2>&1`;
      `sed -i.zimbra -e 's:\\(^/dev/shm\t/opt/zimbra.*\\):#\\1:' /etc/fstab`;
      if ($? != 0) {
        `mv /etc/fstab.zimbra /etc/fstab`;
      }
    }
  }

  # bug 
  my $remoteManagementUser = main::getLdapConfigValue("zimbraRemoteManagementUser");
	main::runAsZimbra("$ZMPROV mcf zimbraRemoteManagementUser=zimbra") 
    if ($remoteManagementUser eq "");
  my $remoteManagementPort = main::getLdapConfigValue("zimbraRemoteManagementPort");
	main::runAsZimbra("$ZMPROV mcf zimbraRemoteManagementPort=22") 
    if ($remoteManagementPort eq "");

  return 0;
}

sub upgrade410BETA1 {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 4.1.0_BETA1");
	return 0;
}
sub upgrade410RC1 {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 4.1.0_RC1");
	return 0;
}
sub upgrade410RC2 {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 4.1.0_RC2");
	return 0;
}
sub upgrade410GA {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 4.1.0_GA");
	return 0;
}
sub upgrade500BETA1 {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 5.0.0_BETA1");
	return 0;
}
sub upgrade500GA {
	my ($startBuild, $targetVersion, $targetBuild) = (@_);
	Migrate::log("Updating from 5.0.0_GA");
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

sub isSqlRunning {
	my $rc = 0xffff & system("su - zimbra -c \"/opt/zimbra/bin/mysqladmin status > /dev/null 2>&1\"");
	$rc = $rc >> 8;
  return($rc ? undef : 1);
}

sub startSql {

	unless (isSqlRunning()) {
		Migrate::log("Starting mysql");
		my $rc = 0xffff & system("su - zimbra -c \"/opt/zimbra/bin/mysql.server start > /dev/null 2>&1\"");
		$rc = $rc >> 8;
		if ($rc) {
			Migrate::log("mysql startup failed with exit code $rc");
			return $rc;
		}
    my $timeout = 0;
    while (!isSqlRunning() && $timeout <= 120 ) {
		  system("su - zimbra -c \"/opt/zimbra/bin/mysql.server start > /dev/null 2>&1\"");
      $timeout += sleep 10;
    }
	}
	return(isSqlRunning() ? 0 : 1);
}

sub stopSql {

  if (isSqlRunning()) {
	  Migrate::log("Stopping mysql");
	  my $rc = 0xffff & system("su - zimbra -c \"/opt/zimbra/bin/mysql.server stop > /dev/null 2>&1\"");
	  $rc = $rc >> 8;
	  if ($rc) {
		  Migrate::log("mysql stop failed with exit code $rc");
		  return $rc;
	  }
    my $timeout = 0;
    while (isSqlRunning() && $timeout <= 120 ) {
		  $rc = 0xffff & system("su - zimbra -c \"/opt/zimbra/bin/mysql.server stop > /dev/null 2>&1\"");
      $timeout += sleep 10;
    }
  }
  return(isSqlRunning() ? 1 : 0);
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
		Migrate::log ("Can't run ${scriptDir}/$updateScripts{$curVersion} - not executable!");
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

sub updateMySQLcnf {

  my $mycnf = "/opt/zimbra/conf/my.cnf";
  if (-e "$mycnf") {
    open(MYCNF, "$mycnf") or die "$!\n";
    my @CNF = <MYCNF>;
    close(MYCNF);
    my $i=0;
    my $mycnfChanged = 0;
    my $tmpfile = "/tmp/my.cnf.$$";;
    my $zimbra_user = `zmlocalconfig -m nokey zimbra_user 2> /dev/null` || "zmbra";;
    open(TMP, ">$tmpfile");
    foreach (@CNF) {
      if (/^port/ && $CNF[$i+1] !~ m/^user/) {
        print TMP;
        print TMP "user         = $zimbra_user\n";
        $mycnfChanged=1;
        next;
      }
      print TMP;
      $i++;
    }
    close(TMP);
  
    if ($mycnfChanged) {
      `mv $mycnf ${mycnf}.3.2.0_M2`;
      `cp -f $tmpfile $mycnf`;
      `chmod 644 $mycnf`;
    } 
  }
}

sub clearTomcatWorkDir {

  my $workDir = "/opt/zimbra/tomcat/work";
  return unless (-d "$workDir");
  system("find $workDir -type f -exec rm -f {} \\\;");

}

1
