#!/usr/bin/perl
# vim: ts=2
# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013 VMware, Inc.
# 
# The contents of this file are subject to the Zimbra Public License
# Version 1.3 ("License"); you may not use this file except in
# compliance with the License.  You may obtain a copy of the License at
# http://www.zimbra.com/license.
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied.
# ***** END LICENSE BLOCK *****
# 

package zmupgrade;

use strict;
use lib "/opt/zimbra/libexec/scripts";
use lib "/opt/zimbra/zimbramon/lib";
use Migrate;
use Net::LDAP;
use IPC::Open3;
use FileHandle;
use File::Grep qw (fgrep);
use File::Path;
my $zmlocalconfig="/opt/zimbra/bin/zmlocalconfig";
my $type = qx(${zmlocalconfig} -m nokey convertd_stub_name 2> /dev/null);
chomp $type;
if ($type eq "") {$type = "FOSS";}
else {$type = "NETWORK";}

my $rundir = qx(dirname $0);
chomp $rundir;
my $scriptDir = "/opt/zimbra/libexec/scripts";

my $lowVersion = 18;
my $hiVersion = 100; # this should be set to the DB version expected by current server code

# Variables for the combo schema updater
my $comboLowVersion = 20;
my $comboHiVersion  = 27;
my $needSlapIndexing = 0;
my $mysqlcnfUpdated = 0;

my $platform = qx(/opt/zimbra/libexec/get_plat_tag.sh);
chomp $platform;
my $addr_space = (($platform =~ m/\w+_(\d+)/) ? "$1" : "32");
my $su;
if ($platform =~ /MACOSXx86_10/) {
  $su = "su - zimbra -c -l";
} else {
  $su = "su - zimbra -c";
}

my $hn = qx($su "${zmlocalconfig} -m nokey zimbra_server_hostname");
chomp $hn;

my $isLdapMaster = qx($su "${zmlocalconfig} -m nokey ldap_is_master");
chomp($isLdapMaster);
if (lc($isLdapMaster) eq "true" ) {
   $isLdapMaster = 1;
} else {
   $isLdapMaster = 0;
}

my $ZMPROV = "/opt/zimbra/bin/zmprov -r -m -l --";

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
  '27' => "migrate20060911-MailboxGroup.pl",           # 4.5.0_BETA1
  '28' => "migrate20060929-TypedTombstones.pl",
  '29' => "migrate20061101-IMFolder.pl",               # 4.5.0_RC1
  '30' => "migrate20061117-TasksFolder.pl",            # 4.5.0_RC1
  '31' => "migrate20061120-AddNameColumn.pl",          # 4.5.0_RC1
  '32' => "migrate20061204-CreatePop3MessageTable.pl", # 4.5.0_RC1
  '33' => "migrate20061205-UniqueAppointmentIndex.pl", # 4.5.0_RC1
  '34' => "migrate20061212-RepairMutableIndexIds.pl",  # 4.5.0_RC1
  '35' => "migrate20061221-RecalculateFolderSizes.pl", # 4.5.0_GA
  '36' => "migrate20070306-Pop3MessageUid.pl",         # 5.0.0_BETA1
  '37' => "migrate20070606-WidenMetadata.pl",          # 5.0.0_BETA2
  '38' => "migrate20070614-BriefcaseFolder.pl",        # 5.0.0_BETA2
  '39' => "migrate20070627-BackupTime.pl",             # 5.0.0_BETA2
  '40' => "migrate20070629-IMTables.pl",               # 5.0.0_BETA2
  '41' => "migrate20070630-LastSoapAccess.pl",         # 5.0.0_BETA2
  '42' => "migrate20070703-ScheduledTask.pl",          # 5.0.0_BETA2
  '43' => "migrate20070706-DeletedAccount.pl",         # 5.0.0_BETA2
  '44' => "migrate20070725-CreateRevisionTable.pl",     # 5.0.0_BETA3
  '45' => "migrate20070726-ImapDataSource.pl",          # 5.0.0_BETA3
  '46' => "migrate20070921-ImapDataSourceUidValidity.pl", # 5.0.0_RC1
  '47' => "migrate20070928-ScheduledTaskIndex.pl",     # 5.0.0_RC2
  '48' => "migrate20071128-AccountId.pl",              # 5.0.0_RC3
  '49' => "migrate20071206-WidenSizeColumns.pl",       # 5.0.0_GA
  '50' => "migrate20080130-ImapFlags.pl",              # 5.0.3_GA
  '51' => "migrate20080213-IndexDeferredColumn.pl",    # 5.0.3_GA
  '52' => "migrate20080909-DataSourceItemTable.pl",    # 5.0.10_GA
  '53' => "migrate20080930-MucService.pl",             # this upgrades to 60 for 6_0_0 GA
   # 54-59 skipped for possible FRANKLIN use
  '60' => "migrate20090315-MobileDevices.pl",
  '61' => "migrate20090406-DataSourceItemTable.pl",    # 6.0.0_BETA1
  '62' => "migrate20090430-highestindexed.pl",         # 6.0.0_BETA2
  '63' => "migrate20100106-MobileDevices.pl",          # 6.0.5_GA
  '64' => "migrate20100926-Dumpster.pl",               # 7.0.0_BETA1
  #'65' => "migrate20101123-MobileDevices.pl",          # this upgrades to 80 for 8.0.0_BETA1
  # Consolidating the scripts which updates the db.version to 80..90
  '65' => "migrate20120611_7to8_bundle.pl",             # this upgrades to 90 for 8_0_0_BETA
  # 66-79 skipped for possible HELIX use
  '80' => "migrate20110314-MobileDevices.pl",          # 8.0.0_BETA1
  '81' => "migrate20110330-RecipientsColumn.pl",       # 8.0.0_BETA1
  '82' => "migrate20110705-PendingAclPush.pl",         # 8.0.0_BETA1
  '83' => "migrate20110810-TagTable.pl",               # 8.0.0_BETA1
  '84' => "migrate20110928-MobileDevices.pl",          # 8.0.0_BETA2
  '85' => "migrate20110929-VersionColumn.pl",          # 8.0.0_BETA2
  '86' => "migrate20120125-uuidAndDigest.pl",          # 8.0.0_BETA2
  '87' => "migrate20120222-LastPurgeAtColumn.pl",      # 8.0.0_BETA2
  '88' => "migrate20120229-DropIMTables.pl",           # 8.0.0_BETA2
  '89' => "migrate20120319-Name255Chars.pl",
  '90' => "migrate20120410-BlobLocator.pl",
  '91' => "migrate20121009-VolumeBlobs.pl",	       # 8.0.1
  '92' => "migrate20130226_alwayson.pl",	       # 9.0.0
  # 93-99 skipped for possible IRONMAIDEN use
);

my %updateFuncs = (
  "6.0.0_GA" => \&upgrade600GA,
  "6.0.1_GA" => \&upgrade601GA,
  "6.0.2_GA" => \&upgrade602GA,
  "6.0.3_GA" => \&upgrade603GA,
  "6.0.4_GA" => \&upgrade604GA,
  "6.0.5_GA" => \&upgrade605GA,
  "6.0.6_GA" => \&upgrade606GA,
  "6.0.7_GA" => \&upgrade607GA,
  "6.0.8_GA" => \&upgrade608GA,
  "6.0.9_GA" => \&upgrade609GA,
  "6.0.10_GA" => \&upgrade6010GA,
  "6.0.11_GA" => \&upgrade6011GA,
  "6.0.13_GA" => \&upgrade6013GA,
  "6.0.14_GA" => \&upgrade6014GA,
  "6.0.15_GA" => \&upgrade6015GA,
  "6.0.16_GA" => \&upgrade6016GA,
  "7.0.0_BETA1" => \&upgrade700BETA1,
  "7.0.0_BETA2" => \&upgrade700BETA2,
  "7.0.0_BETA3" => \&upgrade700BETA3,
  "7.0.0_RC1" => \&upgrade700RC1,
  "7.0.0_GA" => \&upgrade700GA,
  "7.0.1_GA" => \&upgrade701GA,
  "7.1.0_GA" => \&upgrade710GA,
  "7.1.1_GA" => \&upgrade711GA,
  "7.1.2_GA" => \&upgrade712GA,
  "7.1.3_GA" => \&upgrade713GA,
  "7.1.4_GA" => \&upgrade714GA,
  "7.2.0_GA" => \&upgrade720GA,
  "7.2.1_GA" => \&upgrade721GA,
  "7.2.2_GA" => \&upgrade722GA,
  "7.2.3_GA" => \&upgrade723GA,
  "7.2.4_GA" => \&upgrade724GA,
  "7.2.5_GA" => \&upgrade725GA,
  "8.0.0_BETA1" => \&upgrade800BETA1,
  "8.0.0_BETA2" => \&upgrade800BETA2,
  "8.0.0_BETA3" => \&upgrade800BETA3,
  "8.0.0_BETA4" => \&upgrade800BETA4,
  "8.0.0_BETA5" => \&upgrade800BETA5,
  "8.0.0_GA" => \&upgrade800GA,
  "8.0.1_GA" => \&upgrade801GA,
  "8.0.2_GA" => \&upgrade802GA,
  "8.0.3_GA" => \&upgrade803GA,
  "8.0.4_GA" => \&upgrade804GA,
  "8.0.5_GA" => \&upgrade805GA,
  "9.0.0_BETA1" => \&upgrade900BETA1,
);

my @versionOrder = (
  "6.0.0_GA",
  "6.0.1_GA",
  "6.0.2_GA",
  "6.0.3_GA",
  "6.0.4_GA",
  "6.0.5_GA",
  "6.0.6_GA",
  "6.0.7_GA",
  "6.0.8_GA",
  "6.0.9_GA",
  "6.0.10_GA",
  "6.0.11_GA",
  "6.0.13_GA",
  "6.0.14_GA",
  "6.0.15_GA",
  "6.0.16_GA",
  "7.0.0_BETA1",
  "7.0.0_BETA2",
  "7.0.0_BETA3",
  "7.0.0_RC1",
  "7.0.0_GA",
  "7.0.1_GA",
  "7.1.0_GA",
  "7.1.1_GA",
  "7.1.2_GA",
  "7.1.3_GA",
  "7.1.4_GA",
  "7.2.0_GA",
  "7.2.1_GA",
  "7.2.2_GA",
  "7.2.3_GA",
  "7.2.4_GA",
  "7.2.5_GA",
  "8.0.0_BETA1",
  "8.0.0_BETA2",
  "8.0.0_BETA3",
  "8.0.0_BETA4",
  "8.0.0_BETA5",
  "8.0.0_GA",
  "8.0.1_GA",
  "8.0.2_GA",
  "8.0.3_GA",
  "8.0.4_GA",
  "8.0.5_GA",
  "9.0.0_BETA1",
);

my ($startVersion,$startMajor,$startMinor,$startMicro);
my ($targetVersion,$targetMajor,$targetMinor,$targetMicro);

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

#####################

sub upgrade {
  $startVersion = shift;
  $targetVersion = shift;
  $main::config{HOSTNAME}=$hn;
  my ($startBuild,$targetBuild);
  ($startVersion,$startBuild) = $startVersion =~ /(\d\.\d\.\d+_[^_]*)_(\d+)/;  
  ($targetVersion,$targetBuild) = $targetVersion =~ m/(\d\.\d\.\d+_[^_]*)_(\d+)/;
  ($startMajor,$startMinor,$startMicro) =
    $startVersion =~ /(\d+)\.(\d+)\.(\d+_[^_]*)/;
  ($targetMajor,$targetMinor,$targetMicro) =
    $targetVersion =~ /(\d+)\.(\d+)\.(\d+_[^_]*)/;

  my $needVolumeHack = 0;
  my $needMysqlTableCheck = 0;
  my $needMysqlUpgrade = 0;

  getInstalledPackages();

  # Bug #73840 - need to delete /opt/zimbra/keyview before we try stopping services
  if ((! main::isInstalled("zimbra-convertd")) && (-l "/opt/zimbra/keyview")) {
    unlink("/opt/zimbra/keyview");
  }

  if (stopZimbra()) { return 1; }

  my $curSchemaVersion;

  if (main::isInstalled("zimbra-store")) {

    my $found = 0;
    foreach my $v (@versionOrder) {
      $found = 1 if ($v eq $startVersion);
      if ($found) {
        &doMysql51Upgrade if ($v eq "7.0.0_BETA1");
        &doMysql55Upgrade if ($v eq "8.0.0_BETA1");
        &doMysql56Upgrade if ($v eq "9.0.0_BETA1");
      }
      last if ($v eq $targetVersion);
    }

    if (startSql()) { return 1; };

    $curSchemaVersion = Migrate::getSchemaVersion();
  }
 
  if ($startVersion eq "3.0.0_GA") {
    main::progress("This appears to be 3.0.0_GA\n");
  } elsif ($startVersion eq "3.0.1_GA") {
    main::progress("This appears to be 3.0.1_GA\n");
  } elsif ($startVersion eq "3.1.0_GA") {
    main::progress("This appears to be 3.1.0_GA\n");
    #$needVolumeHack = 1;
  } elsif ($startVersion eq "3.1.1_GA") {
    main::progress("This appears to be 3.1.1_GA\n");
  } elsif ($startVersion eq "3.1.2_GA") {
    main::progress("This appears to be 3.1.2_GA\n");
  } elsif ($startVersion eq "3.1.3_GA") {
    main::progress("This appears to be 3.1.3_GA\n");
  } elsif ($startVersion eq "3.1.4_GA") {
    main::progress("This appears to be 3.1.4_GA\n");
  } elsif ($startVersion eq "3.2.0_M1") {
    main::progress("This appears to be 3.2.0_M1\n");
  } elsif ($startVersion eq "3.2.0_M2") {
    main::progress("This appears to be 3.2.0_M2\n");
  } elsif ($startVersion eq "4.0.0_RC1") {
    main::progress("This appears to be 4.0.0_RC1\n");
  } elsif ($startVersion eq "4.0.0_GA") {
    main::progress("This appears to be 4.0.0_GA\n");
  } elsif ($startVersion eq "4.0.1_GA") {
    main::progress("This appears to be 4.0.1_GA\n");
  } elsif ($startVersion eq "4.0.2_GA") {
    main::progress("This appears to be 4.0.2_GA\n");
  } elsif ($startVersion eq "4.0.3_GA") {
    main::progress("This appears to be 4.0.3_GA\n");
  } elsif ($startVersion eq "4.0.4_GA") {
    main::progress("This appears to be 4.0.4_GA\n");
  } elsif ($startVersion eq "4.0.5_GA") {
    main::progress("This appears to be 4.0.5_GA\n");
  } elsif ($startVersion eq "4.1.0_BETA1") {
    main::progress("This appears to be 4.1.0_BETA1\n");
  } elsif ($startVersion eq "4.5.0_BETA1") {
    main::progress("This appears to be 4.5.0_BETA1\n");
  } elsif ($startVersion eq "4.5.0_BETA2") {
    main::progress("This appears to be 4.5.0_BETA2\n");
  } elsif ($startVersion eq "4.5.0_RC1") {
    main::progress("This appears to be 4.5.0_RC1\n");
  } elsif ($startVersion eq "4.5.0_RC2") {
    main::progress("This appears to be 4.5.0_RC2\n");
  } elsif ($startVersion eq "4.5.0_GA") {
    main::progress("This appears to be 4.5.0_GA\n");
  } elsif ($startVersion eq "4.5.1_GA") {
    main::progress("This appears to be 4.5.1_GA\n");
  } elsif ($startVersion eq "4.5.2_GA") {
    main::progress("This appears to be 4.5.2_GA\n");
  } elsif ($startVersion eq "4.5.3_GA") {
    main::progress("This appears to be 4.5.3_GA\n");
  } elsif ($startVersion eq "4.5.4_GA") {
    main::progress("This appears to be 4.5.4_GA\n");
  } elsif ($startVersion eq "4.5.5_GA") {
    main::progress("This appears to be 4.5.5_GA\n");
  } elsif ($startVersion eq "4.5.6_GA") {
    main::progress("This appears to be 4.5.6_GA\n");
  } elsif ($startVersion eq "4.5.7_GA") {
    main::progress("This appears to be 4.5.7_GA\n");
  } elsif ($startVersion eq "4.5.8_GA") {
    main::progress("This appears to be 4.5.8_GA\n");
  } elsif ($startVersion eq "4.5.9_GA") {
    main::progress("This appears to be 4.5.9_GA\n");
  } elsif ($startVersion eq "4.5.10_GA") {
    main::progress("This appears to be 4.5.10_GA\n");
  } elsif ($startVersion eq "4.5.11_GA") {
    main::progress("This appears to be 4.5.11_GA\n");
  } elsif ($startVersion eq "4.6.0_BETA") {
    main::progress("This appears to be 4.6.0_BETA\n");
  } elsif ($startVersion eq "4.6.0_RC1") {
    main::progress("This appears to be 4.6.0_RC1\n");
  } elsif ($startVersion eq "4.6.0_GA") {
    main::progress("This appears to be 4.6.0_GA\n");
  } elsif ($startVersion eq "5.0.0_BETA1") {
    main::progress("This appears to be 5.0.0_BETA1\n");
  } elsif ($startVersion eq "5.0.0_BETA2") {
    main::progress("This appears to be 5.0.0_BETA2\n");
  } elsif ($startVersion eq "5.0.0_BETA3") {
    main::progress("This appears to be 5.0.0_BETA3\n");
  } elsif ($startVersion eq "5.0.0_BETA4") {
    main::progress("This appears to be 5.0.0_BETA4\n");
  } elsif ($startVersion eq "5.0.0_RC1") {
    main::progress("This appears to be 5.0.0_RC1\n");
  } elsif ($startVersion eq "5.0.0_RC2") {
    main::progress("This appears to be 5.0.0_RC2\n");
  } elsif ($startVersion eq "5.0.0_RC3") {
    main::progress("This appears to be 5.0.0_RC3\n");
  } elsif ($startVersion eq "5.0.0_GA") {
    main::progress("This appears to be 5.0.0_GA\n");
  } elsif ($startVersion eq "5.0.1_GA") {
    main::progress("This appears to be 5.0.1_GA\n");
  } elsif ($startVersion eq "5.0.2_GA") {
    main::progress("This appears to be 5.0.2_GA\n");
  } elsif ($startVersion eq "5.0.3_GA") {
    main::progress("This appears to be 5.0.3_GA\n");
  } elsif ($startVersion eq "5.0.4_GA") {
    main::progress("This appears to be 5.0.4_GA\n");
  } elsif ($startVersion eq "5.0.5_GA") {
    main::progress("This appears to be 5.0.5_GA\n");
  } elsif ($startVersion eq "5.0.6_GA") {
    main::progress("This appears to be 5.0.6_GA\n");
  } elsif ($startVersion eq "5.0.7_GA") {
    main::progress("This appears to be 5.0.7_GA\n");
  } elsif ($startVersion eq "5.0.8_GA") {
    main::progress("This appears to be 5.0.8_GA\n");
  } elsif ($startVersion eq "5.0.9_GA") {
    main::progress("This appears to be 5.0.9_GA\n");
  } elsif ($startVersion eq "5.0.10_GA") {
    main::progress("This appears to be 5.0.10_GA\n");
  } elsif ($startVersion eq "5.0.11_GA") {
    main::progress("This appears to be 5.0.11_GA\n");
  } elsif ($startVersion eq "5.0.12_GA") {
    main::progress("This appears to be 5.0.12_GA\n");
  } elsif ($startVersion eq "5.0.13_GA") {
    main::progress("This appears to be 5.0.13_GA\n");
  } elsif ($startVersion eq "5.0.14_GA") {
    main::progress("This appears to be 5.0.14_GA\n");
  } elsif ($startVersion eq "5.0.15_GA") {
    main::progress("This appears to be 5.0.15_GA\n");
  } elsif ($startVersion eq "5.0.16_GA") {
    main::progress("This appears to be 5.0.16_GA\n");
  } elsif ($startVersion eq "5.0.17_GA") {
    main::progress("This appears to be 5.0.17_GA\n");
  } elsif ($startVersion eq "5.0.18_GA") {
    main::progress("This appears to be 5.0.18_GA\n");
  } elsif ($startVersion eq "5.0.19_GA") {
    main::progress("This appears to be 5.0.19_GA\n");
  } elsif ($startVersion eq "5.0.20_GA") {
    main::progress("This appears to be 5.0.20_GA\n");
  } elsif ($startVersion eq "5.0.21_GA") {
    main::progress("This appears to be 5.0.21_GA\n");
  } elsif ($startVersion eq "5.0.22_GA") {
    main::progress("This appears to be 5.0.22_GA\n");
  } elsif ($startVersion eq "5.0.23_GA") {
    main::progress("This appears to be 5.0.23_GA\n");
  } elsif ($startVersion eq "5.0.24_GA") {
    main::progress("This appears to be 5.0.24_GA\n");
  } elsif ($startVersion eq "5.0.25_GA") {
    main::progress("This appears to be 5.0.25_GA\n");
  } elsif ($startVersion eq "5.0.26_GA") {
    main::progress("This appears to be 5.0.26_GA\n");
  } elsif ($startVersion eq "5.0.27_GA") {
    main::progress("This appears to be 5.0.27_GA\n");
  } elsif ($startVersion eq "6.0.0_BETA1") {
    main::progress("This appears to be 6.0.0_BETA1\n");
  } elsif ($startVersion eq "6.0.0_BETA2") {
    main::progress("This appears to be 6.0.0_BETA2\n");
  } elsif ($startVersion eq "6.0.0_RC1") {
    main::progress("This appears to be 6.0.0_RC1\n");
  } elsif ($startVersion eq "6.0.0_RC2") {
    main::progress("This appears to be 6.0.0_RC2\n");
  } elsif ($startVersion eq "6.0.0_GA") {
    main::progress("This appears to be 6.0.0_GA\n");
  } elsif ($startVersion eq "6.0.1_GA") {
    main::progress("This appears to be 6.0.1_GA\n");
  } elsif ($startVersion eq "6.0.2_GA") {
    main::progress("This appears to be 6.0.2_GA\n");
  } elsif ($startVersion eq "6.0.3_GA") {
    main::progress("This appears to be 6.0.3_GA\n");
  } elsif ($startVersion eq "6.0.4_GA") {
    main::progress("This appears to be 6.0.4_GA\n");
  } elsif ($startVersion eq "6.0.5_GA") {
    main::progress("This appears to be 6.0.5_GA\n");
  } elsif ($startVersion eq "6.0.6_GA") {
    main::progress("This appears to be 6.0.6_GA\n");
  } elsif ($startVersion eq "6.0.7_GA") {
    main::progress("This appears to be 6.0.7_GA\n");
  } elsif ($startVersion eq "6.0.8_GA") {
    main::progress("This appears to be 6.0.8_GA\n");
  } elsif ($startVersion eq "6.0.9_GA") {
    main::progress("This appears to be 6.0.9_GA\n");
  } elsif ($startVersion eq "6.0.10_GA") {
    main::progress("This appears to be 6.0.10_GA\n");
  } elsif ($startVersion eq "6.0.11_GA") {
    main::progress("This appears to be 6.0.11_GA\n");
  } elsif ($startVersion eq "6.0.13_GA") {
    main::progress("This appears to be 6.0.13_GA\n");
  } elsif ($startVersion eq "6.0.14_GA") {
    main::progress("This appears to be 6.0.14_GA\n");
  } elsif ($startVersion eq "6.0.15_GA") {
    main::progress("This appears to be 6.0.15_GA\n");
  } elsif ($startVersion eq "6.0.16_GA") {
    main::progress("This appears to be 6.0.16_GA\n");
  } elsif ($startVersion eq "7.0.0_BETA1") {
    main::progress("This appears to be 7.0.0_BETA1\n");
  } elsif ($startVersion eq "7.0.0_BETA2") {
    main::progress("This appears to be 7.0.0_BETA2\n");
  } elsif ($startVersion eq "7.0.0_BETA3") {
    main::progress("This appears to be 7.0.0_BETA3\n");
  } elsif ($startVersion eq "7.0.0_RC1") {
    main::progress("This appears to be 7.0.0_RC1\n");
  } elsif ($startVersion eq "7.0.0_GA") {
    main::progress("This appears to be 7.0.0_GA\n");
  } elsif ($startVersion eq "7.0.1_GA") {
    main::progress("This appears to be 7.0.1_GA\n");
  } elsif ($startVersion eq "7.1.0_GA") {
    main::progress("This appears to be 7.1.0_GA\n");
  } elsif ($startVersion eq "7.1.1_GA") {
    main::progress("This appears to be 7.1.1_GA\n");
  } elsif ($startVersion eq "7.1.2_GA") {
    main::progress("This appears to be 7.1.2_GA\n");
  } elsif ($startVersion eq "7.1.3_GA") {
    main::progress("This appears to be 7.1.3_GA\n");
  } elsif ($startVersion eq "7.1.4_GA") {
    main::progress("This appears to be 7.1.4_GA\n");
  } elsif ($startVersion eq "7.2.0_GA") {
    main::progress("This appears to be 7.2.0_GA\n");
  } elsif ($startVersion eq "7.2.1_GA") {
    main::progress("This appears to be 7.2.1_GA\n");
  } elsif ($startVersion eq "7.2.2_GA") {
    main::progress("This appears to be 7.2.2_GA\n");
  } elsif ($startVersion eq "7.2.3_GA") {
    main::progress("This appears to be 7.2.3_GA\n");
  } elsif ($startVersion eq "7.2.4_GA") {
    main::progress("This appears to be 7.2.4_GA\n");
  } elsif ($startVersion eq "7.2.5_GA") {
    main::progress("This appears to be 7.2.5_GA\n");
  } elsif ($startVersion eq "8.0.0_BETA1") {
    main::progress("This appears to be 8.0.0_BETA1\n");
  } elsif ($startVersion eq "8.0.0_BETA2") {
    main::progress("This appears to be 8.0.0_BETA2\n");
  } elsif ($startVersion eq "8.0.0_BETA3") {
    main::progress("This appears to be 8.0.0_BETA3\n");
  } elsif ($startVersion eq "8.0.0_BETA4") {
    main::progress("This appears to be 8.0.0_BETA4\n");
  } elsif ($startVersion eq "8.0.0_BETA5") {
    main::progress("This appears to be 8.0.0_BETA5\n");
  } elsif ($startVersion eq "8.0.0_GA") {
    main::progress("This appears to be 8.0.0_GA\n");
  } elsif ($startVersion eq "8.0.1_GA") {
    main::progress("This appears to be 8.0.1_GA\n");
  } elsif ($startVersion eq "8.0.2_GA") {
    main::progress("This appears to be 8.0.2_GA\n");
  } elsif ($startVersion eq "8.0.3_GA") {
    main::progress("This appears to be 8.0.3_GA\n");
  } elsif ($startVersion eq "8.0.4_GA") {
    main::progress("This appears to be 8.0.4_GA\n");
  } elsif ($startVersion eq "8.0.5_GA") {
    main::progress("This appears to be 8.0.5_GA\n");
  } elsif ($startVersion eq "9.0.0_BETA1") {
    main::progress("This appears to be 9.0.0_BETA1\n");
  } else {
    main::progress("I can't upgrade version $startVersion\n\n");
    return 1;
  }

  
  my $found = 0;
  foreach my $v (@versionOrder) {
    $found = 1 if ($v eq $startVersion);
    if ($found) {
      $needMysqlTableCheck=1 if ($v eq "4.5.2_GA");
      $needMysqlUpgrade=1 if ($v eq "7.0.0_BETA1");
      $needMysqlUpgrade=1 if ($v eq "8.0.0_GA");
      $needMysqlUpgrade=1 if ($v eq "9.0.0_BETA1");
    }
    last if ($v eq $targetVersion);
  }
  main::setLocalConfig("ssl_allow_untrusted_certs", "true") if ($startMajor <= 7 && $targetMajor >= 8);
  # start ldap
  if (main::isInstalled ("zimbra-ldap")) {
    if($startMajor < 6 && $targetMajor >= 6) {
      my $rc=&migrateLdap("8.0.0_BETA3");
      if ($rc) { return 1; }
    } elsif($startMajor < 8) {
      my $rc=&upgradeLdap("8.0.0_BETA3");
      if ($rc) { return 1; }
    } elsif($startMajor < 9) {
      my $rc=&upgradeLdap("9.0.0_BETA1");
      if ($rc) { return 1; }
    } elsif ($startMajor == 8 && $startMinor == 0 && $startMicro < 3) {
      my $rc=&reloadLdap("8.0.3_GA");
      if ($rc) { return 1; }
    }
    if (startLdap()) {return 1;} 
  }

  if (main::isInstalled("zimbra-store")) {

    doMysqlTableCheck() if ($needMysqlTableCheck);
    doMysqlUpgrade() if ($needMysqlUpgrade);
  
    doBackupRestoreVersionUpdate($startVersion);

    if ($curSchemaVersion < $hiVersion) {
      main::progress("Schema upgrade required from version $curSchemaVersion to $hiVersion.\n");
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
      $curSchemaVersion = Migrate::getSchemaVersion();
    }
     if ( $startMajor = 7 && $targetMajor >= 8) {
       # Bug #78297
       my $zimbra_home = main::getLocalConfig("zimbra_home") || "/opt/zimbra";
       my $imap_cache_data_files = $zimbra_home . "/data/mailboxd/imap-*";
       system("/bin/rm -f ${imap_cache_data_files} 2> /dev/null");
     }
    stopSql();
  }

  $found = 0;
  foreach my $v (@versionOrder) {
    #main::progress("Checking $v\n");
    if ($v eq $startVersion) {
      $found = 1;
      # skip startVersion func unless we are on the same version and build increments
      next unless ($startVersion eq $targetVersion && $targetBuild > $startBuild);
    }
    if ($found) {
      if (defined ($updateFuncs{$v}) ) {
        if (&{$updateFuncs{$v}}($startBuild, $targetVersion, $targetBuild)) {
          return 1;
        }
      } else {
        main::progress("I don't know how to update $v - exiting\n");
        return 1;
      }
    }
    if ($v eq $targetVersion) {
      last;
    }
  }
  if ($isLdapMaster) {
    main::progress("Updating global config and COS's with attributes introduced after $startVersion...");
    main::progress((&runAttributeUpgrade($startVersion)) ? "failed.\n" : "done.\n");
    main::setLdapGlobalConfig("zimbraVersionCheckLastResponse", "");
  }
  if ($needSlapIndexing) {
    main::detail("Updating slapd indices\n");
    &indexLdap();
        }
  if (main::isInstalled ("zimbra-ldap")) {
    stopLdap();
  }

  return 0;
}

sub upgrade600GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 6.0.0_GA\n");
  if (main::isInstalled("zimbra-mta")) {
    my @mtalist = main::getAllServers("mta");
    my $servername = main::getLocalConfig("zimbra_server_hostname");
    main::setLocalConfig("zmtrainsa_cleanup_host", "true")
      if ("$servername" eq "$mtalist[0]");
  }
  return 0;
}

sub upgrade601GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 6.0.1_GA\n");
  return 0;
}

sub upgrade602GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 6.0.2_GA\n");
  if (main::isInstalled("zimbra-ldap") && $isLdapMaster) {
    main::runAsZimbra("zmjava com.zimbra.cs.account.ldap.upgrade.LdapUpgrade -b 41000 -v");
    main::setLdapGlobalConfig("zimbraHttpDebugHandlerEnabled", "TRUE");
  }
  if (main::isInstalled("zimbra-store")) {
    # 40536
    my $zimbra_home=main::getLocalConfig("zimbra_home");
    system("rm -rf ${zimbra_home}/zimlets-deployed/zimlet")
      if ( -d "${zimbra_home}/zimlets-deployed/zimlet");
    system("rm -rf ${zimbra_home}/mailboxd/webapps/service/zimlet")
      if ( -d "${zimbra_home}/mailboxd/webapps/service/zimlet");
    # 40839
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-pid-file-fixup --section=mysqld_safe --key=pid-file --unset /opt/zimbra/conf/my.cnf");
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.post-${targetVersion}-pid-file-fixup --section=mysqld_safe --key=pid-file --set --value=/opt/zimbra/db/mysql.pid /opt/zimbra/conf/my.cnf");
  }
  return 0;
}

sub upgrade603GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 6.0.3_GA\n");
  return 0;
}

sub upgrade604GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 6.0.4_GA\n");
  return 0;
}

sub upgrade605GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 6.0.5_GA\n");
  &cleanPostfixLC;
  if (main::isInstalled("zimbra-store")) {
    my $servername = main::getLocalConfig("zimbra_server_hostname");
    my $serverId = main::getLdapServerValue("zimbraId", $servername);
    upgradeLdapConfigValue("zimbraVersionCheckServer", $serverId, "");
  }

  if (main::isInstalled("zimbra-ldap")) {
    if ($isLdapMaster) {
      main::runAsZimbra("zmjava com.zimbra.cs.account.ldap.upgrade.LdapUpgrade -b 42877 -v");
      main::runAsZimbra("zmjava com.zimbra.cs.account.ldap.upgrade.LdapUpgrade -b 43147 -v");
    }
    # 43040, must be done on all LDAP servers
    my $ldap_pass = qx($su "zmlocalconfig -s -m nokey ldap_root_password");
    my $ldap;
    chomp($ldap_pass);
    unless($ldap = Net::LDAP->new('ldapi://%2fopt%2fzimbra%2fdata%2fldap%2fstate%2frun%2fldapi/')) {
       main::progress("Unable to contact to ldapi: $!\n");
    }
    my $result = $ldap->bind("cn=config", password => $ldap_pass);
    unless($result->code()) {
      $result = $ldap->modify( "cn=config", add => { 'olcWriteTimeout' => '0'});
    }
    # 43701, replica's only
    if (!$isLdapMaster) {
      $result = $ldap->search(
        base => "olcDatabase={2}mdb,cn=config",
        filter => "(olcSyncrepl=*)",
        attrs => ['olcSyncrepl']
      );
      my $entry=$result->entry(0);
      my $attr = $entry->get_value("olcSyncrepl");
      if ($attr !~ /tls_cacertdir/) {
        $attr =  $attr . " tls_cacertdir=/opt/zimbra/conf/ca";
      }

      $result = $ldap->modify(
        $entry->dn,
        replace => {
          olcSyncrepl => "$attr",
        }
      );
    }
    $result = $ldap->unbind;
  }
  return 0;
}

sub upgrade606GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 6.0.6_GA\n");
  
  # 42877 - Fix ACLs for new attrs for local GAL access
  if (main::isInstalled("zimbra-ldap")) {
    my $ldap_pass = qx($su "zmlocalconfig -s -m nokey ldap_root_password");
    chomp($ldap_pass);
    my $ldap;
    unless($ldap = Net::LDAP->new('ldapi://%2fopt%2fzimbra%2fdata%2fldap%2fstate%2frun%2fldapi/')) {
       main::progress("Unable to contact to ldapi: $!\n");
    }
    my $result = $ldap->bind("cn=config", password => $ldap_pass);
    my $dn="olcDatabase={2}mdb,cn=config";
    if ($isLdapMaster) {
      $result = $ldap->search(
                        base=> "cn=accesslog",
                        filter=>"(objectClass=*)",
                        scope => "base",
                        attrs => ['1.1'],
      );
      my $size = $result->count;
      if ($size > 0 ) {
        $dn="olcDatabase={3}mdb,cn=config";
      }
    }
    $result = $ldap->search(
      base=> "$dn",
      filter=>"(objectClass=*)",
      scope => "base",
      attrs => ['olcAccess'],
    );
    my $entry=$result->entry($result->count-1);
    my @attrvals=$entry->get_value("olcAccess");
    my $aclNumber=-1;
    my $attrMod="";

    foreach my $attr (@attrvals) {
      if ($attr =~ /telephoneNumber/) {
        if ($attr !~ /homePhone/) {
          ($aclNumber) = $attr =~ /^\{(\d+)\}*/;
          $attrMod=$attr;
        }
      }
    }

    if ($aclNumber != -1 && $attrMod ne "") {
      $attrMod =~ s/uid/uid,homePhone,pager,mobile/;
      $result = $ldap->modify(
          $dn,
          delete => {olcAccess => "{$aclNumber}"},
      );
      $result = $ldap->modify(
          $dn,
          add =>{olcAccess=>"$attrMod"},
      );
    }
    $ldap->unbind;
  }
  return 0;
}

sub upgrade607GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 6.0.7_GA\n");

  if (main::isInstalled("zimbra-core")) {
    #46801
    my ($micro) = $startMicro =~ /(\d+)_.*/;
    if ($startMajor < 6 || ($startMajor == 6 && $micro < 5) ) {
      main::setLocalConfig("migrate_user_zimlet_prefs", "true");
    } else {
      main::setLocalConfig("migrate_user_zimlet_prefs", "false");
    }
    # 46840
    upgradeLocalConfigValue("ldap_cache_group_maxsize", "2000", "200");
  }

  if (main::isInstalled("zimbra-mta")) {
    my $zimbra_home = main::getLocalConfig("zimbra_home");
    $zimbra_home = "/opt/zimbra" if ($zimbra_home eq "");
    #bug 27165
    if ( -f "${zimbra_home}/data/clamav/db/daily.cvd" ) {
     unlink("${zimbra_home}/data/clamav/db/daily.cvd");
    }
    if ( -f "${zimbra_home}/data/clamav/db/main.cvd" ) {
     unlink("${zimbra_home}/data/clamav/db/main.cvd");
    } 
    # bug 47066
    main::setLocalConfig("postfix_always_add_missing_headers", "yes");
  }
  if (main::isInstalled("zimbra-ldap")) {
    if (!$isLdapMaster) {
      # 46508 upgrade step for keepalive setting
      my $ldap_pass = qx($su "zmlocalconfig -s -m nokey ldap_root_password");
      my $ldap;
      chomp($ldap_pass);
      unless($ldap = Net::LDAP->new('ldapi://%2fopt%2fzimbra%2fdata%2fldap%2fstate%2frun%2fldapi/')) {
         main::progress("Unable to contact to ldapi: $!\n");
      }
      my $result = $ldap->bind("cn=config", password => $ldap_pass);
      $result = $ldap->search(
        base => "olcDatabase={2}mdb,cn=config",
        filter => "(olcSyncrepl=*)",
        attrs => ['olcSyncrepl']
      );
      my $entry=$result->entry(0);
      my $attr = $entry->get_value("olcSyncrepl");
      if ($attr !~ /keepalive=/) {
        $attr =  $attr . " keepalive=240:10:30";
      }

      $result = $ldap->modify(
        $entry->dn,
        replace => {
          olcSyncrepl => "$attr",
        }
      );
      $result = $ldap->unbind;
    } else {
      runLdapAttributeUpgrade("46297");
    }
  }
  if (main::isInstalled("zimbra-store")) {
    my $mailboxd_java_options = main::getLocalConfigRaw("mailboxd_java_options");
    $mailboxd_java_options .= " -Dsun.net.inetaddr.ttl=\${networkaddress_cache_ttl}"
      unless ($mailboxd_java_options =~ /sun.net.inetaddr.ttl/);
    main::detail("Modified mailboxd_java_options=$mailboxd_java_options");
    main::setLocalConfig("mailboxd_java_options", "$mailboxd_java_options");
    #45891
    my $imap_max_request_size = main::getLocalConfig("imap_max_request_size");
    if ($imap_max_request_size ne "" and $imap_max_request_size ne "10240") {
      main::runAsZimbra("$ZMPROV ms $hn zimbraImapMaxRequestSize $imap_max_request_size");
    }
  }
  return 0;
}

sub upgrade608GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 6.0.8_GA\n");
  main::deleteLocalConfig("zimlet_properties_directory"); 
  if ($isLdapMaster) {
    runLdapAttributeUpgrade("46883");
    runLdapAttributeUpgrade("46961");
  }
  return 0;
}

sub upgrade609GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 6.0.9_GA\n");
  return 0;
}

sub upgrade6010GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 6.0.10_GA\n");
  return 0;
}

sub upgrade6011GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 6.0.11_GA\n");
  if (main::isInstalled("zimbra-ldap")) {
    if($isLdapMaster) {
      runLdapAttributeUpgrade("50458");
    }
    my $ldap_pass = qx($su "zmlocalconfig -s -m nokey ldap_root_password");
    chomp($ldap_pass);
    my $ldap;
    unless($ldap = Net::LDAP->new('ldapi://%2fopt%2fzimbra%2fdata%2fldap%2fstate%2frun%2fldapi/')) {
       main::progress("Unable to contact to ldapi: $!\n");
    }
    my $result = $ldap->bind("cn=config", password => $ldap_pass);
    my $dn="olcDatabase={2}mdb,cn=config";
    if ($isLdapMaster) {
      $result = $ldap->search(
                        base=> "cn=accesslog",
                        filter=>"(objectClass=*)",
                        scope => "base",
                        attrs => ['1.1'],
      );
      my $size = $result->count;
      if ($size > 0 ) {
        $dn="olcDatabase={3}mdb,cn=config";
      }
    }
    $result = $ldap->search(
      base=> "$dn",
      filter=>"(objectClass=*)",
      scope => "base",
      attrs => ['olcDbIndex'],
    );
    my $entry=$result->entry($result->count-1);
    my @attrvals=$entry->get_value("olcDbIndex");
    my $needModify=1;

    foreach my $attr (@attrvals) {
      if ($attr =~ /zimbraMailHost/) {
        $needModify=0;
      }
    }

    if ($needModify) {
      $result = $ldap->modify(
          $dn,
          add =>{olcDbIndex=>"zimbraMailHost eq"},
      );
    }
    $ldap->unbind;
    if ($needModify) {
      &indexLdapAttribute("zimbraMailHost");
    }
  }
  if (main::isInstalled("zimbra-store")) {
    my $mailboxd_java_options=main::getLocalConfigRaw("mailboxd_java_options");
    if ($mailboxd_java_options =~ /-Dsun.net.inetaddr.ttl=$/) {
      my $new_mailboxd_options;
      foreach my $option (split(/\s+/, $mailboxd_java_options)) {
        $new_mailboxd_options.=" $option" if ($option !~ /^-Dsun.net.inetaddr.ttl=/); 
      }
      $new_mailboxd_options =~ s/^\s+//;
      main::setLocalConfig("mailboxd_java_options", $new_mailboxd_options)
        if ($new_mailboxd_options ne "");
    }
    main::setLocalConfig("calendar_outlook_compatible_allday_events", "false");

    #56318
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-allowed-packet --section=mysqld --key=max_allowed_packet --set --value=16777216 /opt/zimbra/conf/my.cnf");
  }
  return 0;
}

sub upgrade6012GA {                                                                                                                                                                                                   
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 6.0.12_GA\n");                                                                                                                                                                        
  return 0;
}                                                                                                                                                                                                                     

sub upgrade6013GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 6.0.13_GA\n");
  if (main::isInstalled("zimbra-ldap")) {
    if($isLdapMaster) {
      runLdapAttributeUpgrade("58084");
    }
  }
  return 0;
}

sub upgrade6014GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 6.0.14_GA\n");
  return 0;
}

sub upgrade6015GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 6.0.15_GA\n");
  if (main::isInstalled("zimbra-ldap")) {
    # 43040, must be done on all LDAP servers
    my $ldap_pass = qx($su "zmlocalconfig -s -m nokey ldap_root_password");
    my $ldap;
    chomp($ldap_pass);
    unless($ldap = Net::LDAP->new('ldapi://%2fopt%2fzimbra%2fdata%2fldap%2fstate%2frun%2fldapi/')) {
       main::progress("Unable to contact to ldapi: $!\n");
    }
    my $result = $ldap->bind("cn=config", password => $ldap_pass);
    unless($result->code()) {
      $result = $ldap->modify( "cn=config", add => { 'olcTLSCACertificatePath' => '/opt/zimbra/conf/ca'});
    }
    $result = $ldap->unbind;
  }
  return 0;
}

sub upgrade6016GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 6.0.16_GA\n");
  main::setLocalConfig("ldap_read_timeout", "0"); #70437
  return 0;
}

sub upgrade700BETA1 {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 7.0.0_BETA1\n");
  if($isLdapMaster) {
    #runLdapAttributeUpgrade("10287");
    runLdapAttributeUpgrade("42828");
    runLdapAttributeUpgrade("43779");
    runLdapAttributeUpgrade("50258");
    runLdapAttributeUpgrade("50465");
  }
  if (main::isInstalled("zimbra-store")) {
    # 43140
    my $mailboxd_java_heap_memory_percent =
      main::getLocalConfig("mailboxd_java_heap_memory_percent");
    $mailboxd_java_heap_memory_percent = 30
      if ($mailboxd_java_heap_memory_percent eq "");
    my $systemMemorySize = main::getSystemMemory();
    main::setLocalConfig("mailboxd_java_heap_size",
      int($systemMemorySize*1024*$mailboxd_java_heap_memory_percent/100));
    main::deleteLocalConfig("mailboxd_java_heap_memory_percent"); 
  }
  return 0;
}

sub upgrade700BETA2 {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 7.0.0_BETA2\n");
  if (main::isInstalled("zimbra-ldap")) {
    if($isLdapMaster) {
      runLdapAttributeUpgrade("50458");
    }

    my $ldap_pass = qx($su "zmlocalconfig -s -m nokey ldap_root_password");
    chomp($ldap_pass);
    my $ldap;
    unless($ldap = Net::LDAP->new('ldapi://%2fopt%2fzimbra%2fdata%2fldap%2fstate%2frun%2fldapi/')) {
       main::progress("Unable to contact to ldapi: $!\n");
    }
    my $result = $ldap->bind("cn=config", password => $ldap_pass);
    my $dn="olcDatabase={2}mdb,cn=config";
    if ($isLdapMaster) {
      $result = $ldap->search(
                        base=> "cn=accesslog",
                        filter=>"(objectClass=*)",
                        scope => "base",
                        attrs => ['1.1'],
      );
      my $size = $result->count;
      if ($size > 0 ) {
        $dn="olcDatabase={3}mdb,cn=config";
      }
    }
    $result = $ldap->search(
      base=> "$dn",
      filter=>"(objectClass=*)",
      scope => "base",
      attrs => ['olcAccess'],
    );
    my $entry=$result->entry($result->count-1);
    my @attrvals=$entry->get_value("olcAccess");
    my $aclNumber=-1;
    my $attrMod="";

    foreach my $attr (@attrvals) {
      if ($attr =~ /zimbraDomainName/) {
        ($aclNumber) = $attr =~ /^\{(\d+)\}*/;
        if ($attr !~ /uid=zmamavis,cn=appaccts,cn=zimbra/) {
          $attrMod=$attr;
          $attrMod =~ s/by \* none/by dn.base="uid=zmamavis,cn=appaccts,cn=zimbra" read  by \* none/;
        }
      }
    }

    if ($aclNumber != -1 && $attrMod ne "") {
      $result = $ldap->modify(
          $dn,
          delete => {olcAccess => "{$aclNumber}"},
      );
      $result = $ldap->modify(
          $dn,
          add =>{olcAccess=>"$attrMod"},
      );
    }
    $ldap->unbind;
  }
  return 0;
}

sub upgrade700BETA3 {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 7.0.0_BETA3\n");
  if (main::isInstalled("zimbra-ldap")) {
    runLdapAttributeUpgrade("47934") if ($isLdapMaster);
  }
  if (main::isInstalled("zimbra-store")) {
    my $mailboxd_java_options=main::getLocalConfigRaw("mailboxd_java_options");
    if ($mailboxd_java_options =~ /-Dsun.net.inetaddr.ttl=$/) {
      my $new_mailboxd_options;
      foreach my $option (split(/\s+/, $mailboxd_java_options)) {
        $new_mailboxd_options.=" $option" if ($option !~ /^-Dsun.net.inetaddr.ttl=/); 
      }
      $new_mailboxd_options =~ s/^\s+//;
      main::setLocalConfig("mailboxd_java_options", $new_mailboxd_options)
        if ($new_mailboxd_options ne "");
    }
  }
  return 0;
}

sub upgrade700RC1 {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 7.0.0_RC1\n");

  if (main::isInstalled("zimbra-ldap")) {
    my $ldap_pass = qx($su "zmlocalconfig -s -m nokey ldap_root_password");
    chomp($ldap_pass);
    my $ldap;
    unless($ldap = Net::LDAP->new('ldapi://%2fopt%2fzimbra%2fdata%2fldap%2fstate%2frun%2fldapi/')) {
       main::progress("Unable to contact to ldapi: $!\n");
    }
    my $result = $ldap->bind("cn=config", password => $ldap_pass);
    my $dn="olcDatabase={2}mdb,cn=config";
    if ($isLdapMaster) {
      $result = $ldap->search(
                        base=> "cn=accesslog",
                        filter=>"(objectClass=*)",
                        scope => "base",
                        attrs => ['1.1'],
      );
      my $size = $result->count;
      if ($size > 0 ) {
        $dn="olcDatabase={3}mdb,cn=config";
      }
    }
    $result = $ldap->search(
      base=> "$dn",
      filter=>"(objectClass=*)",
      scope => "base",
      attrs => ['olcDbIndex'],
    );
    my $entry=$result->entry($result->count-1);
    my @attrvals=$entry->get_value("olcDbIndex");
    my $needModify=1;

    foreach my $attr (@attrvals) {
      if ($attr =~ /zimbraMailHost/) {
        $needModify=0;
      }
    }

    if ($needModify) {
      $result = $ldap->modify(
          $dn,
          add =>{olcDbIndex=>"zimbraMailHost eq"},
      );
    }
    $ldap->unbind;
    if ($needModify) {
      &indexLdapAttribute("zimbraMailHost");
    }
  }
  if (main::isInstalled("zimbra-store")) {
    # Bug #53821
    my $mailboxd_java_options=main::getLocalConfigRaw("mailboxd_java_options");

    $mailboxd_java_options .= " -XX:-OmitStackTraceInFastThrow"
      unless ($mailboxd_java_options =~ /OmitStackTraceInFastThrow/);
    main::detail("Modified mailboxd_java_options=$mailboxd_java_options");
    main::setLocalConfig("mailboxd_java_options", "$mailboxd_java_options");
    
    
  }

  return 0;
}

sub upgrade700GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 7.0.0_GA\n");
  if (main::isInstalled("zimbra-store")) {
    main::deleteLocalConfig("calendar_outlook_compatible_allday_events");
  }
  return 0;
}

sub upgrade701GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 7.0.1_GA\n");
  if (main::isInstalled("zimbra-store")) {
    #56318
    my $mysql_mycnf = main::getLocalConfig("mysql_mycnf"); 
    if (!fgrep { /^max_allowed_packet/ } ${mysql_mycnf}) {
      main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-allowed-packet --section=mysqld --key=max_allowed_packet --set --value=16777216 ${mysql_mycnf}");
    }
    if ( -d "/opt/zimbra/data/mailboxd/imap/cache" ) {
      system("/bin/rm -rf /opt/zimbra/data/mailboxd/imap/cache/* 2> /dev/null");
    }
  }
  return 0;
}

sub upgrade710GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 7.1.0_GA\n");
  my $zimbra_home = main::getLocalConfig("zimbra_home") || "/opt/zimbra";
  my $mysql_data_directory = 
    main::getLocalConfig("mysql_data_directory") || "${zimbra_home}/db/data";
  my $zimbra_tmp_directory = 
    main::getLocalConfig("zimbra_tmp_directory") || "${zimbra_home}/data/tmp";
  my $mysql_mycnf = 
    main::getLocalConfig("mysql_mycnf") || "${zimbra_home}/conf/my.cnf";

  if (main::isInstalled("zimbra-ldap")) {
    if ($isLdapMaster) {
      runLdapAttributeUpgrade("53745");
      runLdapAttributeUpgrade("55649");
      runLdapAttributeUpgrade("57039");
      runLdapAttributeUpgrade("57425");
    }
  }
  if (main::isInstalled("zimbra-store")) {
    foreach my $i (qw(ib_logfile0 ib_logfile1)) {
      my $dbfile="${mysql_data_directory}/${i}";
      main::detail("Moving $dbfile to ${zimbra_tmp_directory}/$i");
      system("mv -f ${dbfile} ${zimbra_tmp_directory}/$i")
        if (-f ${dbfile});
    }
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-log_file_size --section=mysqld --key=innodb_log_file_size --set --value=524288000 ${mysql_mycnf}");
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-dirty-pages --section=mysqld --key=innodb_max_dirty_pages_pct --set --value=30 ${mysql_mycnf}");
     
  }
  return 0;
}

sub upgrade711GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 7.1.1_GA\n");
  if (main::isInstalled("zimbra-ldap")) {
    if ($isLdapMaster) {
      runLdapAttributeUpgrade("57855");
      runLdapAttributeUpgrade("58084");
      runLdapAttributeUpgrade("58481");
      runLdapAttributeUpgrade("58514");
      runLdapAttributeUpgrade("59720");
    }
  }
  if (main::isInstalled("zimbra-store")) {
    # 53272
    if (-d "/opt/zimbra/jetty/webapps/spnego") {
      system("rm -rf /opt/zimbra/jetty/webapps/spnego");
    }
    if (-d "/opt/zimbra/jetty/work/spnego") {
      system("rm -rf /opt/zimbra/jetty/work/spnego");
    }
  }
  return 0;
}

sub upgrade712GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 7.1.2_GA\n");
  return 0;
}

sub upgrade713GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 7.1.3_GA\n");
  if (main::isInstalled("zimbra-ldap")) {
    if ($isLdapMaster) {
      runLdapAttributeUpgrade("11562");
      runLdapAttributeUpgrade("63475");
    }
    # 53301 - Fix ACLs for userCertificate for BES user and general usage
    my $ldap_pass = qx($su "zmlocalconfig -s -m nokey ldap_root_password");
    chomp($ldap_pass);
    my $ldap;
    unless($ldap = Net::LDAP->new('ldapi://%2fopt%2fzimbra%2fdata%2fldap%2fstate%2frun%2fldapi/')) {
       main::progress("Unable to contact to ldapi: $!\n");
    }
    my $result = $ldap->bind("cn=config", password => $ldap_pass);
    my $dn="olcDatabase={2}mdb,cn=config";
    if ($isLdapMaster) {
      $result = $ldap->search(
                        base=> "cn=accesslog",
                        filter=>"(objectClass=*)",
                        scope => "base",
                        attrs => ['1.1'],
      );
      my $size = $result->count;
      if ($size > 0 ) {
        $dn="olcDatabase={3}mdb,cn=config";
      }
    }
    $result = $ldap->search(
      base=> "$dn",
      filter=>"(objectClass=*)",
      scope => "base",
      attrs => ['olcAccess'],
    );
    my $entry=$result->entry($result->count-1);
    my @attrvals=$entry->get_value("olcAccess");
    my $aclNumber=-1;
    my $attrMod="";

    foreach my $attr (@attrvals) {
      if ($attr =~ /zimbraDomainName/) {
        ($aclNumber) = $attr =~ /^\{(\d+)\}*/;
        if ($attr !~ /uid=zmamavis,cn=appaccts,cn=zimbra/) {
          $attrMod=$attr;
          if ($attrMod =~ /by \* read/) {
            $attrMod =~ s/by \* read/by dn.base="uid=zmamavis,cn=appaccts,cn=zimbra" read  by \* read/;
          } else {
            $attrMod =~ s/by \* none/by dn.base="uid=zmamavis,cn=appaccts,cn=zimbra" read  by \* none/;
          }
        }
      }
    }

    if ($aclNumber != -1 && $attrMod ne "") {
      $result = $ldap->modify(
          $dn,
          delete => {olcAccess => "{$aclNumber}"},
      );
      $result = $ldap->modify(
          $dn,
          add =>{olcAccess=>"$attrMod"},
      );
    }
    $result = $ldap->search(
      base=> "$dn",
      filter=>"(objectClass=*)",
      scope => "base",
      attrs => ['olcAccess'],
    );
    my $entry=$result->entry($result->count-1);
    my @attrvals=$entry->get_value("olcAccess");
    my $aclNumber=-1;
    my $attrMod="";

    my $fixup=0;
    foreach my $attr (@attrvals) {
      if ($attr =~ /homePhone,pager,mobile/) {
        if ($attr !~ /userCertificate/) {
          ($aclNumber) = $attr =~ /^\{(\d+)\}*/;
          $attrMod=$attr;
        }
      }
      if ($attr =~ /homePhone,mobile,pager/) {
        if ($attr !~ /userCertificate/) {
          ($aclNumber) = $attr =~ /^\{(\d+)\}*/;
          $attrMod=$attr;
          $fixup=1;
        }
      }
    }

    if ($aclNumber != -1 && $attrMod ne "") {
      if ($fixup) {
        $attrMod =~ s/homePhone,mobile,pager/homePhone,pager,mobile,userCertificate/;
      } else {
        $attrMod =~ s/homePhone,pager,mobile/homePhone,pager,mobile,userCertificate/;
      }
      $result = $ldap->modify(
          $dn,
          delete => {olcAccess => "{$aclNumber}"},
      );
      $result = $ldap->modify(
          $dn,
          add =>{olcAccess=>"$attrMod"},
      );
    }
    $ldap->unbind;
  }
  if (main::isInstalled("zimbra-mta")) {
    my $mtaNetworks=main::getLdapServerValue("zimbraMtaMyNetworks");
    $mtaNetworks =~ s/,/ /g;
    if ($mtaNetworks =~ m/127\.0\.0\.0\/8/) {
      $mtaNetworks =~ s/ $//;
      $mtaNetworks=$mtaNetworks . " [::1]/128";
    }
    main::setLdapServerConfig("zimbraMtaMyNetworks", "$mtaNetworks");
  }
  return 0;
}

sub upgrade714GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 7.1.4_GA\n");
  if (main::isInstalled("zimbra-ldap")) {
    # 43040, must be done on all LDAP servers
    my $ldap_pass = qx($su "zmlocalconfig -s -m nokey ldap_root_password");
    my $ldap;
    chomp($ldap_pass);
    unless($ldap = Net::LDAP->new('ldapi://%2fopt%2fzimbra%2fdata%2fldap%2fstate%2frun%2fldapi/')) {
       main::progress("Unable to contact to ldapi: $!\n");
    }
    my $result = $ldap->bind("cn=config", password => $ldap_pass);
    unless($result->code()) {
      $result = $ldap->modify( "cn=config", add => { 'olcTLSCACertificatePath' => '/opt/zimbra/conf/ca'});
    }
    $result = $ldap->unbind;
  }
  if (main::isInstalled("zimbra-mta")) {
    my @zimbraMtaRestriction = qx($su "$ZMPROV gacf zimbraMtaRestriction");
    foreach my $restriction (@zimbraMtaRestriction) {
      $restriction =~ s/zimbraMtaRestriction: //;
      chomp $restriction;
      if ($restriction =~ /^reject_invalid_hostname$/) {
        main::runAsZimbra("$ZMPROV mcf -zimbraMtaRestriction reject_invalid_hostname");
        main::runAsZimbra("$ZMPROV mcf +zimbraMtaRestriction reject_invalid_helo_hostname");
      }
      if ($restriction =~ /^reject_non_fqdn_hostname$/) {
        main::runAsZimbra("$ZMPROV mcf -zimbraMtaRestriction reject_non_fqdn_hostname");
        main::runAsZimbra("$ZMPROV mcf +zimbraMtaRestriction reject_non_fqdn_helo_hostname");
      }
      if ($restriction =~ /^reject_unknown_client$/) {
        main::runAsZimbra("$ZMPROV mcf -zimbraMtaRestriction reject_unknown_client");
        main::runAsZimbra("$ZMPROV mcf +zimbraMtaRestriction reject_unknown_client_hostname");
      }
      if ($restriction =~ /^reject_unknown_hostname$/) {
        main::runAsZimbra("$ZMPROV mcf -zimbraMtaRestriction reject_unknown_hostname");
        main::runAsZimbra("$ZMPROV mcf +zimbraMtaRestriction reject_unknown_helo_hostname");
      }
    }
  }
  if (main::isInstalled("zimbra-store")) {
    main::setLocalConfig("calendar_cache_enabled", "true"); #66307
  }
  return 0;
}

sub upgrade720GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 7.2.0_GA\n");
  main::setLocalConfig("ldap_read_timeout", "0"); #70437
  if (main::isInstalled("zimbra-store")) {
    # Bug #64466
    my $zimbra_home = main::getLocalConfig("zimbra_home") || "/opt/zimbra";
    my $imap_cache_data_directory = $zimbra_home . "/data/mailboxd/imap";
    rmtree("${imap_cache_data_directory}")
      if ( -d "${imap_cache_data_directory}/");
  }
  return 0;
}

sub upgrade721GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 7.2.1_GA\n");
  return 0;
}

sub upgrade722GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 7.2.2_GA\n");
  return 0;
}

sub upgrade723GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 7.2.3_GA\n");
  return 0;
}

sub upgrade724GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 7.2.4_GA\n");
  return 0;
}

sub upgrade725GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 7.2.5_GA\n");
  return 0;
}

sub upgrade800BETA1 {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.0.0_BETA1\n");
  # bug 59607 - migrate old zmmtaconfig variables to zmconfigd
  foreach my $lc_var (qw(enable_config_restarts interval log_level listen_port debug watchdog watchdog_services)) {
    my $val = main::getLocalConfig("zmmtaconfig_${lc_var}");
    if ($val ne "") {
      main::setLocalConfig("zmconfigd_${lc_var}", "$val");
      main::deleteLocalConfig("zmmtaconfig_${lc_var}");
    }
  }
  if (main::isInstalled("zimbra-ldap")) {
    if ($isLdapMaster) {
      runLdapAttributeUpgrade("57866");
      runLdapAttributeUpgrade("57205");
      runLdapAttributeUpgrade("57875");
    }
    # 3884
    main::progress("Adding dynamic group configuration\n");
    main::runAsZimbra("perl -I${scriptDir} ${scriptDir}/migrate20110615-AddDynlist.pl");
    main::runAsZimbra("perl -I${scriptDir} ${scriptDir}/migrate20110721-AddUnique.pl");
    my $ldap_pass = qx($su "zmlocalconfig -s -m nokey ldap_root_password");
    chomp($ldap_pass);
    my $ldap;
    unless($ldap = Net::LDAP->new('ldapi://%2fopt%2fzimbra%2fdata%2fldap%2fstate%2frun%2fldapi/')) {
       main::progress("Unable to contact to ldapi: $!\n");
    }
    my $result = $ldap->bind("cn=config", password => $ldap_pass);
    my $dn="olcDatabase={2}mdb,cn=config";
    if ($isLdapMaster) {
      $result = $ldap->search(
                        base=> "cn=accesslog",
                        filter=>"(objectClass=*)",
                        scope => "base",
                        attrs => ['1.1'],
      );
      my $size = $result->count;
      if ($size > 0 ) {
        $dn="olcDatabase={3}mdb,cn=config";
      }
    }
    $result = $ldap->search(
      base=> "$dn",
      filter=>"(objectClass=*)",
      scope => "base",
      attrs => ['olcDbIndex'],
    );
    my $entry=$result->entry($result->count-1);
    my @attrvals=$entry->get_value("olcDbIndex");
    my $MzimbraMemberOf=1;
    my $MzimbraSharedItem=1;

    foreach my $attr (@attrvals) {
      if ($attr =~ /zimbraMemberOf/) {
        $MzimbraMemberOf=0;
      }
      if ($attr =~ /zimbraSharedItem/) {
        $MzimbraSharedItem=0;
      }
    }

    if ($MzimbraMemberOf) {
      $result = $ldap->modify(
          $dn,
          add =>{olcDbIndex=>"zimbraMemberOf eq"},
      );
    }
    if ($MzimbraSharedItem) {
      $result = $ldap->modify(
          $dn,
          add =>{olcDbIndex=>"zimbraSharedItem eq,sub"},
      );
    }
    $ldap->unbind;
    if ($MzimbraMemberOf) {
      &indexLdapAttribute("zimbraMemberOf");
    }
    if ($MzimbraSharedItem) {
      &indexLdapAttribute("zimbraSharedItem");
    }
  }
  return 0;
}

sub upgrade800BETA2 {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.0.0_BETA2\n");
  if (main::isInstalled("zimbra-ldap")) {
    if ($isLdapMaster) {
      runLdapAttributeUpgrade("63722");
      runLdapAttributeUpgrade("64380");
      runLdapAttributeUpgrade("65070");
      runLdapAttributeUpgrade("66001");
      runLdapAttributeUpgrade("60640");
    }
    main::runAsZimbra("perl -I${scriptDir} ${scriptDir}/migrate20111019-UniqueZimbraId.pl");
  }
  if (main::isEnabled("zimbra-store")) {
    if (startSql()) { return 1; }
      main::runAsZimbra("perl -I${scriptDir} ${scriptDir}/migrate20111005-ItemIdCheckpoint.pl");

    # Bug: 60011
    my $mysql_root_password=qx(/opt/zimbra/bin/zmlocalconfig -s -x -m nokey mysql_root_password);
    my $mysql_socket=qx(/opt/zimbra/bin/zmlocalconfig -s -x -m nokey mysql_socket);
    my $host=qx(hostname);
    chomp $mysql_root_password;
    chomp $mysql_socket;
    chomp $host;

    my $sql = <<FIX_RIGHTS_EOF;
      SET PASSWORD FOR 'root'\@'localhost' = PASSWORD('${mysql_root_password}');
      SET PASSWORD FOR 'root'\@'${host}' = PASSWORD('${mysql_root_password}');
      SET PASSWORD FOR 'root'\@'127.0.0.1' = PASSWORD('${mysql_root_password}');
      SET PASSWORD FOR 'root'\@'localhost.localdomain' = PASSWORD('${mysql_root_password}');
FIX_RIGHTS_EOF

    qx(/opt/zimbra/mysql/bin/mysql -S '$mysql_socket' -u root --password='$mysql_root_password' -e "$sql");
    qx(/opt/zimbra/mysql/bin/mysql -S '$mysql_socket' -u root --password='$mysql_root_password' -e "DROP USER ''\@'localhost'; DROP USER ''\@'${host}'");
    stopSql();

    # 66663
    my $cache_dir = main::getLocalConfig("calendar_cache_directory");
    system("rm -rf ${cache_dir}/* 2> /dev/null")
      if (-d ${cache_dir});
  }
  if (main::isInstalled("zimbra-proxy")) {
      main::runAsZimbra("$ZMPROV ms $hn -zimbraServiceInstalled imapproxy");
      main::runAsZimbra("$ZMPROV ms $hn +zimbraServiceInstalled proxy");
    if (main::isEnabled("zimbra-proxy")) {
      main::setLdapServerConfig($hn, '-zimbraServiceEnabled', 'imapproxy');
      main::setLdapServerConfig($hn, '+zimbraServiceEnabled', 'proxy');
    }
  }

  return 0;
}

sub upgrade800BETA3 {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.0.0_BETA3\n");
  main::setLocalConfig("ldap_read_timeout", "0"); #70437
  main::detail("Removing /opt/zimbra/ssl/zimbra/{ca,server} to force creation or download of new ca and certificates.");
  system("rm -rf /opt/zimbra/ssl/zimbra/ca > /dev/null 2>&1");
  system("rm -rf /opt/zimbra/ssl/zimbra/server > /dev/null 2>&1");
  main::setLocalConfig("ssl_allow_untrusted_certs", "true");
  if (main::isInstalled("zimbra-ldap")) {
    # Delete unused BDB DB keys
    foreach my $lc_var (qw(ldap_db_cachefree ldap_db_cachesize ldap_db_dncachesize ldap_db_idlcachesize ldap_db_shmkey ldap_overlay_syncprov_sessionlog)) {
      my $val = main::getLocalConfig("${lc_var}");
      if ($val ne "") {
        main::deleteLocalConfig("${lc_var}");
      }
    }
    foreach my $lc_var (qw(ldap_accesslog_cachefree ldap_accesslog_cachesize ldap_accesslog_dncachesize ldap_accesslog_idlcachesize ldap_accesslog_shmkey)) {
      my $val = main::getLocalConfig("${lc_var}");
      if ($val ne "") {
        main::deleteLocalConfig("${lc_var}");
      }
    }
    if ($isLdapMaster) {
      runLdapAttributeUpgrade("68831");
      runLdapAttributeUpgrade("68891");
    }
    main::runAsZimbra("perl -I${scriptDir} ${scriptDir}/migrate20120210-AddSearchNoOp.pl");
  }
  if (main::isInstalled("zimbra-store")) {
    my $zimbra_home = main::getLocalConfig("zimbra_home") || "/opt/zimbra";
    if (-e "${zimbra_home}/jetty-6.1.22.z6/etc/jetty.keytab") {
      qx(mkdir -p ${zimbra_home}/data/mailboxd/spnego);
      qx(cp -pf ${zimbra_home}/jetty-6.1.22.z6/etc/jetty.keytab ${zimbra_home}/data/mailboxd/spnego/jetty.keytab);
    }
  }
  if (main::isInstalled("zimbra-octopus")) {
    if (startSql()) { return 1; }
    main::runAsZimbra("perl -I${scriptDir} ${scriptDir}/migrate20120209-octopusEvent.pl");
    stopSql();
  }
    
  return 0;
}

sub upgrade800BETA4 {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.0.0_BETA4\n");
  if (main::isInstalled("zimbra-ldap")) {
    if ($isLdapMaster) {
        runLdapAttributeUpgrade("68190");
        runLdapAttributeUpgrade("68394");
        runLdapAttributeUpgrade("72007");
    }
    my $doIndex = &addLdapIndex("zimbraDomainAliasTargetID","eq");
    if ($doIndex) {
      &indexLdapAttribute("zimbraDomainAliasTargetID");
    }
    $doIndex = &addLdapIndex("zimbraUCServiceId","eq");
    if ($doIndex) {
      &indexLdapAttribute("zimbraUCServiceId");
    }
    $doIndex = &addLdapIndex("DKIMIdentity", "eq");
    if ($doIndex) {
      &indexLdapAttribute("DKIMIdentity");
    }
    $doIndex = &addLdapIndex("DKIMSelector", "eq");
    if ($doIndex) {
      &indexLdapAttribute("DKIMSelector");
    }
    my $ldap_pass = qx($su "zmlocalconfig -s -m nokey ldap_root_password");
    chomp($ldap_pass);
    my $ldap;
    unless($ldap = Net::LDAP->new('ldapi://%2fopt%2fzimbra%2fdata%2fldap%2fstate%2frun%2fldapi/')) {
       main::progress("Unable to contact to ldapi: $!\n");
    }
    my $result = $ldap->bind("cn=config", password => $ldap_pass);
    my $dn="olcDatabase={2}mdb,cn=config";
    if ($isLdapMaster) {
      $result = $ldap->search(
                        base=> "cn=accesslog",
                        filter=>"(objectClass=*)",
                        scope => "base",
                        attrs => ['1.1'],
      );
      my $size = $result->count;
      if ($size > 0 ) {
        $dn="olcDatabase={3}mdb,cn=config";
      }
    }
    $result = $ldap->search(
      base=> "$dn",
      filter=>"(objectClass=*)",
      scope => "base",
      attrs => ['olcAccess'],
    );
    my $entry=$result->entry($result->count-1);
    my @attrvals=$entry->get_value("olcAccess");
    my $aclNumber=-1;
    my $attrMod="";

    foreach my $attr (@attrvals) {
      if ($attr =~ /zimbraAllowFromAddress/) {
        if ($attr !~ /DKIMIdentity/) {
          ($aclNumber) = $attr =~ /^\{(\d+)\}*/;
          $attrMod=$attr;
        }
      }
    }

    if ($aclNumber != -1 && $attrMod ne "") {
      $attrMod =~ s/zimbraAllowFromAddress/zimbraAllowFromAddress,DKIMIdentity,DKIMSelector,DKIMDomain,DKIMKey/;
      $result = $ldap->modify(
          $dn,
          delete => {olcAccess => "{$aclNumber}"},
      );
      $result = $ldap->modify(
          $dn,
          add =>{olcAccess=>"$attrMod"},
      );
    }
    $ldap->unbind;

    my $toolthreads = main::getLocalConfig("ldap_common_toolthreads");
    if ($toolthreads == 1) {
       main::setLocalConfig("ldap_common_toolthreads", "2");
    }
    main::runAsZimbra("perl -I${scriptDir} ${scriptDir}/migrate20120507-UniqueDKIMSelector.pl");
  }
  if (main::isInstalled("zimbra-proxy")) {
    # bug 32683
    main::setLdapGlobalConfig("zimbraReverseProxySSLToUpstreamEnabled", "FALSE");
  }
  foreach my $lc_var (qw(cbpolicyd_bind_host logger_mysql_bind_address logger_mysql_directory logger_mysql_data_directory logger_mysql_socket logger_mysql_pidfile logger_mysql_mycnf logger_mysql_errlogfile logger_mysql_port zimbra_logger_mysql_password)) {
    main::deleteLocalConfig("$lc_var");
  }
  return 0;
}

sub upgrade800BETA5 {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.0.0_BETA5\n");
  if (main::isInstalled("zimbra-ldap")) {
    if ($isLdapMaster) {
        runLdapAttributeUpgrade("67237");
    }
  }
  if (main::isInstalled("zimbra-mta")) {
    if (-f "/opt/zimbra/conf/sauser.cf") {
      qx(mv /opt/zimbra/conf/sauser.cf /opt/zimbra/conf/sa/sauser.cf);
    }
  }
  return 0;
}

sub upgrade800GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.0.0_GA\n");
  if (main::isInstalled("zimbra-ldap")) {
    if ($isLdapMaster) {
        runLdapAttributeUpgrade("75450");
        runLdapAttributeUpgrade("76427");
    }
  }
  if (main::isInstalled("zimbra-mta")) {
    my $cbpdb="/opt/zimbra/data/cbpolicyd/db/cbpolicyd.sqlitedb";
    if (-f $cbpdb) {
      main::runAsZimbra("sqlite3 $cbpdb < ${scriptDir}/migrate20130227-UpgradeCBPolicyDSchema.sql >/dev/null 2>&1");
    }
  }
  return 0;
}

sub upgrade801GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.0.1_GA\n");
  if (main::isInstalled("zimbra-ldap")) {
    my $ldap_pass = qx($su "zmlocalconfig -s -m nokey ldap_root_password");
    chomp($ldap_pass);
    my $ldap;
    unless($ldap = Net::LDAP->new('ldapi://%2fopt%2fzimbra%2fdata%2fldap%2fstate%2frun%2fldapi/')) {
       main::progress("Unable to contact to ldapi: $!\n");
    }
    my $result = $ldap->bind("cn=config", password => $ldap_pass);
    my $dn="olcDatabase={2}mdb,cn=config";
    my $alog=0;
    if ($isLdapMaster) {
      $result = $ldap->search(
                        base=> "cn=accesslog",
                        filter=>"(objectClass=*)",
                        scope => "base",
                        attrs => ['1.1'],
      );
      my $size = $result->count;
      if ($size > 0 ) {
        $dn="olcDatabase={3}mdb,cn=config";
        $alog=1;
      }
    }
    $result = $ldap->search(
      base=> "$dn",
      filter=>"(objectClass=*)",
      scope => "base",
      attrs => ['olcDbEnvFlags'],
    );
    my $entry=$result->entry($result->count-1);
    my @attrvals=$entry->get_value("olcDbEnvFlags");

    if (!(@attrvals)) {
      $result = $ldap->modify(
          $dn,
          add =>{olcDbEnvFlags=>["writemap","nometasync"]},
      );
    }
    if ($isLdapMaster && $alog == 1) {
      $result = $ldap->search(
        base=> "olcDatabase={2}mdb,cn=config",
        filter=>"(objectClass=*)",
        scope => "base",
        attrs => ['olcDbEnvFlags'],
      );
      my $entry=$result->entry($result->count-1);
      my @attrvals=$entry->get_value("olcDbEnvFlags");
  
      if (!(@attrvals)) {
        $result = $ldap->modify(
            "olcDatabase={2}mdb,cn=config",
            add =>{olcDbEnvFlags=>["writemap","nometasync"]},
        );
      }
    }
    $ldap->unbind;
  }
  return 0;
}

sub upgrade802GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.0.2_GA\n");
  if (main::isInstalled("zimbra-ldap")) {
    if ($isLdapMaster) {
      my $ldap_pass = qx($su "zmlocalconfig -s -m nokey ldap_root_password");
      chomp($ldap_pass);
      my $ldap;
      unless($ldap = Net::LDAP->new('ldapi://%2fopt%2fzimbra%2fdata%2fldap%2fstate%2frun%2fldapi/')) {
         main::progress("Unable to contact to ldapi: $!\n");
      }
      my $result = $ldap->bind("cn=config", password => $ldap_pass);
      $result = $ldap->modify(
        "uid=zmpostfix,cn=appaccts,cn=zimbra",
        replace => {
          zimbraId => "a8255e5f-142b-4aa0-8aab-f8591b6455ba",
        }
      );
      $ldap->unbind;
    }
  }

  if (main::isInstalled("zimbra-mta")) {
    doAntiSpamMysql55Upgrade();
    my $mtamilter = main::getLdapServerValue("zimbraMtaSmtpdMilters");
    my $miltervalue="inet:localhost:8465";
    if ($mtamilter ne "")  {
      if ($mtamilter =~ /$miltervalue/) {
        $mtamilter =~ s/$miltervalue//;
        main::setLdapServerConfig("zimbraMtaSmtpdMilters", "$mtamilter");
      }
    }
  }
  return 0;
}

sub upgrade803GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.0.3_GA\n");
  if (main::isInstalled("zimbra-ldap")) {
     main::setLocalConfig("ldap_common_toolthreads", "2");
  }
  if (main::isInstalled("zimbra-store")) {
    my $mailboxd_java_options=main::getLocalConfigRaw("mailboxd_java_options");
    if ($mailboxd_java_options =~ /-XX:MaxPermSize=128m/) {
      $mailboxd_java_options =~ s/-XX:MaxPermSize=128m/-XX:MaxPermSize=350m/;
      main::detail("Modified mailboxd_java_options=$mailboxd_java_options");
      main::setLocalConfig("mailboxd_java_options", $mailboxd_java_options)
    }
  }
  main::deleteLocalConfig("zimbra_dos_filter_max_requests_per_sec");
  return 0;
}

sub upgrade804GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.0.4_GA\n");
  if (main::isInstalled("zimbra-ldap")) {
    my $ldap_pass = qx($su "zmlocalconfig -s -m nokey ldap_root_password");
    chomp($ldap_pass);
    my $ldap;
    unless($ldap = Net::LDAP->new('ldapi://%2fopt%2fzimbra%2fdata%2fldap%2fstate%2frun%2fldapi/')) {
       main::progress("Unable to contact to ldapi: $!\n");
    }
    my $result = $ldap->bind("cn=config", password => $ldap_pass);
    $result = $ldap->modify(
      "olcDatabase={2}mdb,cn=config",
      replace => {
        olcDbCheckpoint => "0 0",
      }
    );
    if ($isLdapMaster) {
      $result = $ldap->modify(
        "olcDatabase={3}mdb,cn=config",
        replace => {
          olcDbCheckpoint => "0 0",
        }
      );
    }
    $ldap->unbind;
    main::deleteLocalConfig("ldap_db_checkpoint");
    main::deleteLocalConfig("ldap_accesslog_checkpoint");
    if ($isLdapMaster) {
        runLdapAttributeUpgrade("75650");
    }
  }
  if (main::isInstalled("zimbra-mta")) {
    main::setLdapServerConfig($hn, '+zimbraServiceInstalled', 'opendkim');
    main::setLdapServerConfig($hn, '+zimbraServiceEnabled', 'opendkim');
    main::deleteLocalConfig("cbpolicyd_timeout");
  }
  if (main::isInstalled("zimbra-store")) {
    my $zimbraIPMode=main::getLdapServerValue("zimbraIPMode");
    my $mysql_mycnf = main::getLocalConfig("mysql_mycnf"); 
    if ($zimbraIPMode eq "ipv4") {
        main::setLocalConfig("mysql_bind_address", "127.0.0.1");
        main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-bind --section=mysqld --key=bind-address --unset ${mysql_mycnf}");
        main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-bind --section=mysqld --key=bind-address --set --value=127.0.0.1 ${mysql_mycnf}");
    } elsif ($zimbraIPMode eq "both") {
        main::setLocalConfig("mysql_bind_address", "::1");
        main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-bind --section=mysqld --key=bind-address --unset ${mysql_mycnf}");
        main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-bind --section=mysqld --key=bind-address --set --value=::1 ${mysql_mycnf}");
    } elsif ($zimbraIPMode eq "ipv6") {
        main::setLocalConfig("mysql_bind_address", "::1");
        main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-bind --section=mysqld --key=bind-address --unset ${mysql_mycnf}");
        main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-bind --section=mysqld --key=bind-address --set --value=::1 ${mysql_mycnf}");
    }
    my $mailboxd_java_options=main::getLocalConfigRaw("mailboxd_java_options");
    if ($mailboxd_java_options !~ /-Dorg.apache.jasper.compiler.disablejsr199/) {
      $mailboxd_java_options = $mailboxd_java_options." -Dorg.apache.jasper.compiler.disablejsr199=true";
      main::detail("Modified mailboxd_java_options=$mailboxd_java_options");
      main::setLocalConfig("mailboxd_java_options", $mailboxd_java_options)
    }
  }
  return 0;
}

sub upgrade805GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.0.5_GA\n");
  if (main::isInstalled("zimbra-mta")) {
    my $cbpdb="/opt/zimbra/data/cbpolicyd/db/cbpolicyd.sqlitedb";
    if (-f $cbpdb) {
      main::runAsZimbra("sqlite3 $cbpdb < ${scriptDir}/migrate20130606-UpdateCBPolicydSchema.sql >/dev/null 2>&1");
    }
  }
  return 0;
}

sub upgrade900BETA1 {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 9.0.0_BETA1\n");
  if (main::isInstalled("zimbra-ldap")) {
    if ($isLdapMaster) {
        runLdapAttributeUpgrade("81385");
    }
  }
  if (main::isInstalled("zimbra-mta")) {
    my $antispam_mysql_mycnf = main::getLocalConfig("antispam_mysql_mycnf"); 
    if ( -e ${antispam_mysql_mycnf} ) {
      main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-as-table_cache-fixup --section=mysqld --key=table_cache --unset ${antispam_mysql_mycnf}");
      main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-as-table_open_cache-fixup --section=mysqld --key=table_open_cache --setmin --value=1200 ${antispam_mysql_mycnf}");
    }
  }
  my $mysql_class = main::getLocalConfig("zimbra_class_database");
  if ($mysql_class =~ /com.zimbra.cs.db.MySQL/) {
    main::setLocalConfig("zimbra_class_database", "com.zimbra.cs.db.MariaDB");
  }
  return 0;
}

sub stopZimbra {
  main::progress("Stopping zimbra services...");
  my $rc = main::runAsZimbra("/opt/zimbra/bin/zmcontrol stop");
  main::progress(($rc == 0) ? "done.\n" : "failed. exiting.\n");
  return $rc;
}

sub startLdap {
  main::progress("Checking ldap status...");
  my $rc = main::runAsZimbra("/opt/zimbra/bin/ldap status");
  main::progress(($rc == 0) ? "already running.\n" : "not running.\n");

  if ($rc) {
    main::progress("Running zmldapapplyldif...");
    $rc = main::runAsZimbra("/opt/zimbra/libexec/zmldapapplyldif");
    main::progress(($rc == 0) ? "done.\n" : "failed.\n");

    main::progress("Checking ldap status...");
    $rc = main::runAsZimbra("/opt/zimbra/bin/ldap status");
    main::progress(($rc == 0) ? "already running.\n" : "not running.\n");

    if ($rc) {
      main::progress("Starting ldap...");
      my $rc = main::runAsZimbra("/opt/zimbra/bin/ldap start");
      main::progress(($rc == 0) ? "done.\n" : "failed with exit code: $rc.\n");
      if ($rc) {
        system("$su \"/opt/zimbra/bin/ldap start 2>&1 | grep failed\"");
        return $rc;
      }
    }
  }
  return 0;
}

sub stopLdap {
  main::progress("Stopping ldap...");
  my $rc = main::runAsZimbra("/opt/zimbra/bin/ldap stop");
  main::progress(($rc == 0) ? "done.\n" : "failed. ldap had exit status: $rc.\n");
  sleep 5 unless $rc; # give it a chance to shutdown.
  return $rc;
}

sub isSqlRunning {
  my $rc = 0xffff & system("$su \"/opt/zimbra/bin/mysqladmin status > /dev/null 2>&1\"");
  $rc = $rc >> 8;
  return($rc ? undef : 1);
}

sub startSql {

  unless (isSqlRunning()) {
    main::progress("Starting mysql...");
    my $rc = main::runAsZimbra("/opt/zimbra/bin/mysql.server start");
    my $timeout = sleep 10;
    while (!isSqlRunning() && $timeout <= 1200 ) {
      $rc = main::runAsZimbra("/opt/zimbra/bin/mysql.server start");
      $timeout += sleep 10;
    }
    main::progress(($rc == 0) ? "done.\n" : "failed.\n");
    return $rc if $rc;
  }
  return(isSqlRunning() ? 0 : 1);
}

sub stopSql {
  if (isSqlRunning()) {
    main::progress("Stopping mysql...");
    my $rc = main::runAsZimbra("/opt/zimbra/bin/mysql.server stop");
    my $timeout = sleep 10;
    while (isSqlRunning() && $timeout <= 120 ) {
      $rc = main::runAsZimbra("/opt/zimbra/bin/mysql.server stop");
      $timeout += sleep 10;
    }
    main::progress(($rc == 0) ? "done.\n" : "failed.\n");
    return $rc if $rc;
  }
  return(isSqlRunning() ? 1 : 0);
}

sub isLoggerSqlRunning {
  my $rc = main::runAsZimbra("/opt/zimbra/bin/logmysqladmin status > /dev/null 2>&1");
  return($rc ? undef : 1);
}

sub startLoggerSql {
  unless (isLoggerSqlRunning()) {
    main::progress("Starting logger mysql...");
    my $rc = main::runAsZimbra("/opt/zimbra/bin/logmysql.server start");
    my $timeout = sleep 10;
    while (!isLoggerSqlRunning() && $timeout <= 120 ) {
      $rc = main::runAsZimbra("/opt/zimbra/bin/logmysql.server start");
      $timeout += sleep 10;
    }
    main::progress(($rc == 0) ? "done.\n" : "failed.\n");
    return $rc if $rc;
  }
  return(isLoggerSqlRunning() ? 0 : 1);
}

sub stopLoggerSql {
  if (isLoggerSqlRunning()) {
    main::progress("Stopping logger mysql...");
    my $rc = main::runAsZimbra("/opt/zimbra/bin/logmysql.server stop");
    my $timeout = sleep 10;
    while (isLoggerSqlRunning() && $timeout <= 120 ) {
      $rc = main::runAsZimbra("/opt/zimbra/bin/logmysql.server stop");
      $timeout += sleep 10;
    }
    main::progress(($rc == 0) ? "done.\n" : "failed.\n");
    return $rc if $rc;
  }
  return(isLoggerSqlRunning() ? 1 : 0);
}


sub runSchemaUpgrade {
  my $curVersion = shift;

  if (! defined ($updateScripts{$curVersion})) {
    main::progress ("Can't upgrade from version $curVersion - no script!\n");
    return 1;
  }

  if (! -x "${scriptDir}/$updateScripts{$curVersion}" ) {
    main::progress ("Can't run ${scriptDir}/$updateScripts{$curVersion} - not executable!\n");
    return 1;
  }

  main::progress ("Running ${scriptDir}/$updateScripts{$curVersion}\n");
  open(MIG, "$su \"/usr/bin/perl -I${scriptDir} ${scriptDir}/$updateScripts{$curVersion}\" 2>&1|");
  while (<MIG>) {
    main::progress($_);
  }
  close(MIG);
  my $rc = $?;
  if ($rc != 0) {
    main::progress ("Script failed with code $rc: $! - exiting\n");
    return $rc;
  }
  return 0;
}

sub getInstalledPackages {

  foreach my $p (@packageList) {
    if (main::isInstalled($p)) {
      $installedPackages{$p} = $p;
    }
  }

}
sub cleanPostfixLC {

  my ($var,$val);
  foreach $var (qw(command_directory daemon_directory mailq_path manpage_directory newaliases_path queue_directory sendmail_path)) {

    $val = main::getLocalConfig("postfix_${var}");
    if ($val =~ /postfix-(\d.*)\//) {
      main::detail("Removing $1 from postfix_${var}");
      $val =~ s/postfix-\d.*\//postfix\//;
      main::setLocalConfig("postfix_${var}", "$val");
    }
  }
}

sub updatePostfixLC {
  my ($fromVersion, $toVersion) = @_;

  # update localconfig vars
  my ($var,$val);
  foreach $var (qw(version command_directory daemon_directory mailq_path manpage_directory newaliases_path queue_directory sendmail_path)) {
    if ($var eq "version") {
      $val = $toVersion;
      main::setLocalConfig("postfix_${var}", "$val");
      next;
    }

    $val = main::getLocalConfig("postfix_${var}");
    $val =~ s/postfix-$fromVersion/postfix/;
    $val =~ s/postfix-$toVersion/postfix/;
    main::setLocalConfig("postfix_${var}", "$val");
  }
}

sub movePostfixQueue {
  my ($fromVersion,$toVersion) = @_;

  # update localconfig vars
  my ($var,$val);
  foreach $var (qw(version command_directory daemon_directory mailq_path manpage_directory newaliases_path queue_directory sendmail_path)) {
    $val = main::getLocalConfig("postfix_${var}");
    if ($val eq $toVersion) {
      next;
    }
    if ($val =~ m/postfix-$toVersion/) {
      next;
    }
    $val =~ s/$fromVersion/$toVersion/;
    $val = $toVersion if ($var eq "version");
    main::setLocalConfig("postfix_${var}", "$val"); 
  }

  # move the spool files
  if ( -d "/opt/zimbra/postfix-${fromVersion}/spool" ) {
    main::progress("Moving postfix queues from $fromVersion to $toVersion\n");
    my @dirs = qw /active bounce corrupt defer deferred flush hold incoming maildrop/;
    qx(mkdir -p /opt/zimbra/postfix-${toVersion}/spool);
    foreach my $d (@dirs) {
      if (-d "/opt/zimbra/postfix-${fromVersion}/spool/${d}/") {
        main::progress("Moving $d\n");
        qx(mkdir -p /opt/zimbra/postfix-${toVersion}/spool/${d});
        qx(cp -Rf /opt/zimbra/postfix-${fromVersion}/spool/${d}/* /opt/zimbra/postfix-${toVersion}/spool/${d});
        qx(chown -R postfix:postdrop /opt/zimbra/postfix-${toVersion}/spool/${d});
      }
    }
  }

  main::runAsRoot("/opt/zimbra/libexec/zmfixperms");
}

sub relocatePostfixQueue {
  my $toDir="/opt/zimbra/data/postfix";
  my $fromDir="/opt/zimbra/postfix-2.4.3.4z";
  my $curDir=main::getcwd();

  main::progress("Migrating Postfix spool directory\n");
  mkdir -p "$toDir/spool";
  if ( -d "$fromDir/spool" && ! -d "$toDir/spool/active") {
    chdir($fromDir);
    qx(tar cf - spool 1>/dev/null 2>&1 | (cd $toDir; tar xfp -) >/dev/null 2>&1);
    chdir($curDir);
  }
  main::runAsRoot("/opt/zimbra/libexec/zmfixperms");
}

sub updateLoggerMySQLcnf {

  my $mycnf = "/opt/zimbra/conf/my.logger.cnf";

  return unless (-f $mycnf);
  my $mysql_pidfile = main::getLocalConfig("logger_mysql_pidfile");
  $mysql_pidfile = "/opt/zimbra/logger/db/mysql.pid" if ($mysql_pidfile eq "");
  if (-e "$mycnf") {
    unless (open(MYCNF, "$mycnf")) {
      Migrate::myquit(1, "${mycnf}: $!\n");
    }
    my @CNF = <MYCNF>;
    close(MYCNF);
    my $i=0;
    my $mycnfChanged = 0;
    my $tmpfile = "/tmp/my.cnf.$$";;
    my $zimbra_user = qx(${zmlocalconfig} -m nokey zimbra_user 2> /dev/null) || "zimbra";;
    open(TMP, ">$tmpfile");
    foreach (@CNF) {
      if (/^port/ && $CNF[$i+1] !~ m/^user/) {
        print TMP;
        print TMP "user         = $zimbra_user\n";
        $mycnfChanged=1;
        next;
      } elsif (/^err-log/ && $CNF[$i+1] !~ m/^pid-file/) {
        print TMP;
        print TMP "pid-file = ${mysql_pidfile}\n";
        $mycnfChanged=1;
        next;
      } elsif (/^thread_cache\s/) {
        # 29475 fix thread_cache_size
        s/^thread_cache/thread_cache_size/g;
        print TMP;
        $mycnfChanged=1;
        next;
      } elsif (/^skip-external-locking/) {
        # 19749 remove skip-external-locking
        print TMP "external-locking\n";
        $mycnfChanged=1;
        next;
      }
      print TMP;
      $i++;
    }
    close(TMP);
  
    if ($mycnfChanged) {
      qx(mv $mycnf ${mycnf}.${startVersion});
      qx(cp -f $tmpfile $mycnf);
      qx(chmod 644 $mycnf);
    } 
  }
}
sub updateMySQLcnf {

  return if ($mysqlcnfUpdated == 1);
  my $mycnf = "/opt/zimbra/conf/my.cnf";
  my $mysql_pidfile = main::getLocalConfig("mysql_pidfile");
  $mysql_pidfile = "/opt/zimbra/db/mysql.pid" if ($mysql_pidfile eq "");
  if (-e "$mycnf") {
    unless (open(MYCNF, "$mycnf")) {
      Migrate::myquit(1, "${mycnf}: $!\n");
    }
    my @CNF = <MYCNF>;
    close(MYCNF);
    my $i=0;
    my $mycnfChanged = 0;
    my $tmpfile = "/tmp/my.cnf.$$";;
    my $zimbra_user = qx(${zmlocalconfig} -m nokey zimbra_user 2> /dev/null) || "zimbra";;
    my $zimbra_tmp_directory = qx(${zmlocalconfig} -m nokey zimbra_tmp_directory 2> /dev/null) || "zimbra";;
    open(TMP, ">$tmpfile");
    foreach (@CNF) {
      if (/^port/ && $CNF[$i+1] !~ m/^user/) {
        print TMP;
        print TMP "user         = $zimbra_user\n";
        $mycnfChanged=1;
        next;
      } elsif (/^err-log/ && $CNF[$i+1] !~ m/^pid-file/) {
        print TMP;
        print TMP "pid-file = ${mysql_pidfile}\n";
        $mycnfChanged=1;
        next;
      } elsif (/^thread_cache\s+=\s+(\d+)$/) {
        # 29475 fix thread_cache_size
        if ($1 > 110) {
          s/^thread_cache/thread_cache_size/g;
          print TMP;
        } else {
          print TMP "thread_cache_size = 110\n";
          next;
        }
        $mycnfChanged=1;
        next;
      } elsif (/^thread_cache_size\s+=\s+(\d+)$/) {
        if ($1 < 110) {
          $mycnfChanged=1;
          print TMP "thread_cache_size = 110\n";
          next;
        }
      } elsif (/^max_connections\s+=\s+(\d+)$/) {
        if ($1 < 110) {
          $mycnfChanged=1;
          print TMP "max_connections = 110\n";
          next;
        }
      } elsif (/^skip-external-locking/) {
        # 19749 remove skip-external-locking
        print TMP "external-locking\n";
        $mycnfChanged=1;
        next;
     } elsif (/^innodb_open_files/) {
        # 24906
        print TMP;
        print TMP "innodb_max_dirty_pages_pct = 10\n"
          unless(grep(/^innodb_max_dirty_pages_pct/, @CNF));
        print TMP "innodb_flush_method = O_DIRECT\n"
          unless(grep(/^innodb_flush_method/, @CNF));
        $mycnfChanged=1;
        next;
      } elsif (/^user/ && $CNF[$i+1] !~ m/^tmpdir/) {
        print TMP;
        print TMP "tmpdir       = $zimbra_tmp_directory\n";
        $mycnfChanged=1;
        next;
      }
      print TMP;
      $i++;
    }
    close(TMP);
  
    if ($mycnfChanged) {
      qx(mv $mycnf ${mycnf}.${startVersion});
      qx(cp -f $tmpfile $mycnf);
      qx(chmod 644 $mycnf);
    } 
  }
}

sub clearTomcatWorkDir {

  my $workDir = "/opt/zimbra/tomcat/work";
  return unless (-d "$workDir");
  system("find $workDir -type f -exec rm -f {} \\\;");

}

sub clearRedologDir($$) {
  my ($redologDir, $version) = @_;
  if (-d "$redologDir" && ! -e "${redologDir}/${version}") {
    qx(mkdir ${redologDir}/${version});
    qx(mv ${redologDir}/* ${redologDir}/${version}/ > /dev/null 2>&1);
    qx(chown zimbra:zimbra $redologDir > /dev/null 2>&1);
  }
  return;
}

sub clearBackupDir($$) {
  my ($backupDir, $version) = @_;
  if (-e "$backupDir" && ! -e "${backupDir}/${version}") {
    qx(mkdir ${backupDir}/${version});
    qx(mv ${backupDir}/* ${backupDir}/${version} > /dev/null 2>&1);
    qx(chown zimbra:zimbra $backupDir > /dev/null 2>&1);
  }
  return;
}

sub doMysqlTableCheck {

  my $updateSQL = "/opt/zimbra/mysql/share/mysql/mysql_fix_privilege_tables.sql";
  if (-e "$updateSQL") {
    main::progress("Verifying mysql tables\n");
    my $db_pass = main::getLocalConfig("mysql_root_password");
    my $mysql = "/opt/zimbra/bin/mysql";
    my $cmd = "$mysql --force --user=root --password=$db_pass --database=mysql --batch < $updateSQL";
    main::progress("Executing $cmd\n");
    main::runAsZimbra("$cmd > /tmp/mysql_fix_perms.out 2>&1");
  }
}

sub doMysql51Upgrade {
    my $zimbra_home = main::getLocalConfig("zimbra_home") || "/opt/zimbra";
    my $mysql_mycnf = main::getLocalConfig("mysql_mycnf"); 
    my $zimbra_log_directory = main::getLocalConfig("zimbra_log_directory") || "${zimbra_home}/log"; 

    main::runAsZimbra("${zimbra_home}/libexec/zminiutil --backup=.pre-${targetVersion} --section=mysqld --key=ignore-builtin-innodb --set ${mysql_mycnf}");
    main::runAsZimbra("${zimbra_home}/libexec/zminiutil --backup=.pre-${targetVersion} --section=mysqld --set --key=plugin-load --value='innodb=ha_innodb_plugin.so;innodb_trx=ha_innodb_plugin.so;innodb_locks=ha_innodb_plugin.so;innodb_lock_waits=ha_innodb_plugin.so;innodb_cmp=ha_innodb_plugin.so;innodb_cmp_reset=ha_innodb_plugin.so;innodb_cmpmem=ha_innodb_plugin.so;innodb_cmpmem_reset=ha_innodb_plugin.so' ${mysql_mycnf}");
    main::runAsZimbra("${zimbra_home}/libexec/zminiutil --backup=.pre-${targetVersion} --section=mysqld --unset --key=log-long-format ${mysql_mycnf}");
    main::runAsZimbra("${zimbra_home}/libexec/zminiutil --backup=.pre-${targetVersion} --section=mysqld --unset --key=log-slow-queries ${mysql_mycnf}");
    main::runAsZimbra("${zimbra_home}/libexec/zminiutil --backup=.pre-${targetVersion} --section=mysqld --set --key=slow_query_log --value=1 ${mysql_mycnf}");
    main::runAsZimbra("${zimbra_home}/libexec/zminiutil --backup=.pre-${targetVersion} --section=mysqld --set --key=slow_query_log_file --value=${zimbra_log_directory}/myslow.log ${mysql_mycnf}");
    if (fgrep { /^log-bin/ } ${mysql_mycnf}) {
      main::runAsZimbra("${zimbra_home}/libexec/zminiutil --backup=.pre-${targetVersion} --section=mysqld --set --key=binlog-format --value=MIXED ${mysql_mycnf}");
    }
}

sub doMysql55Upgrade {
    my $zimbra_home = main::getLocalConfig("zimbra_home") || "/opt/zimbra";
    my $mysql_mycnf = main::getLocalConfig("mysql_mycnf"); 
    my $zimbra_log_directory = main::getLocalConfig("zimbra_log_directory") || "${zimbra_home}/log"; 
    main::runAsZimbra("${zimbra_home}/libexec/zminiutil --backup=.pre-${targetVersion} --section=mysqld --unset --key=ignore-builtin-innodb ${mysql_mycnf}");
    main::runAsZimbra("${zimbra_home}/libexec/zminiutil --backup=.pre-${targetVersion} --section=mysqld --unset --key=plugin-load ${mysql_mycnf}");
}

sub doAntiSpamMysql55Upgrade {
    my $zimbra_home = main::getLocalConfig("zimbra_home") || "/opt/zimbra";
    my $antispam_mysql_mycnf = main::getLocalConfig("antispam_mysql_mycnf"); 
    my $zimbra_log_directory = main::getLocalConfig("zimbra_log_directory") || "${zimbra_home}/log"; 
    if ( -e ${antispam_mysql_mycnf} ) {
        main::runAsZimbra("${zimbra_home}/libexec/zminiutil --backup=.pre-${targetVersion} --section=mysqld --unset --key=ignore-builtin-innodb ${antispam_mysql_mycnf}");
        main::runAsZimbra("${zimbra_home}/libexec/zminiutil --backup=.pre-${targetVersion} --section=mysqld --unset --key=plugin-load ${antispam_mysql_mycnf}");
    }
}

sub doMysql56Upgrade {
    my $zimbra_home = main::getLocalConfig("zimbra_home") || "/opt/zimbra";
    my $mysql_mycnf = main::getLocalConfig("mysql_mycnf"); 
    my $zimbra_log_directory = main::getLocalConfig("zimbra_log_directory") || "${zimbra_home}/log"; 
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-table_cache-fixup --section=mysqld --key=table_cache --unset ${mysql_mycnf}");
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-table_open_cache-fixup --section=mysqld --key=table_open_cache --setmin --value=1200 ${mysql_mycnf}");
}

sub doMysqlUpgrade {
    my $db_pass = main::getLocalConfig("mysql_root_password");
    my $zimbra_tmp = main::getLocalConfig("zimbra_tmp_directory") || "/tmp";
    my $zimbra_home = main::getLocalConfig("zimbra_home") || "/opt/zimbra";
    my $mysql_socket = main::getLocalConfig("mysql_socket");
    my $mysql_mycnf = main::getLocalConfig("mysql_mycnf"); 
    my $mysqlUpgrade = "${zimbra_home}/mysql/bin/mysql_upgrade";
    my $cmd = "$mysqlUpgrade --defaults-file=$mysql_mycnf -S $mysql_socket --user=root --password=$db_pass";
    main::progress("Running mysql_upgrade...");
    main::runAsZimbra("$cmd > ${zimbra_tmp}/mysql_upgrade.out 2>&1");
    main::progress("done.\n");
}

sub doBackupRestoreVersionUpdate($) {
  my ($startVersion) = @_;

  my ($prevRedologVersion,$currentRedologVersion,$prevBackupVersion,$currentBackupVersion);
  $prevRedologVersion = &Migrate::getRedologVersion;
  $currentRedologVersion = qx($su "zmjava com.zimbra.cs.redolog.util.GetVersion");
  chomp($currentRedologVersion);

  return unless ($currentRedologVersion);

  Migrate::insertRedologVersion($currentRedologVersion)
    if ($prevRedologVersion eq "");

  if ($prevRedologVersion != $currentRedologVersion) {
    main::progress("Redolog version update required.\n");
    Migrate::updateRedologVersion($prevRedologVersion,$currentRedologVersion);
    main::progress("Redolog version update finished.\n");
  }

  if (-f "/opt/zimbra/lib/ext/backup/zimbrabackup.jar") {
    $prevBackupVersion = &Migrate::getBackupVersion; 
    $currentBackupVersion = qx($su "zmjava com.zimbra.cs.backup.util.GetVersion");
    chomp($currentBackupVersion);

    return unless ($currentBackupVersion);

    Migrate::insertBackupVersion($currentBackupVersion)
      if ($prevBackupVersion eq "");

    if ($prevBackupVersion != $currentBackupVersion) {
      main::progress("Backup version update required.\n");
      Migrate::updateBackupVersion($prevBackupVersion,$currentBackupVersion);
      main::progress("Backup version update finished.\n");
    }
  }
  my ($currentMajorBackupVersion,$currentMinorBackupVersion) = split(/\./, $currentBackupVersion);
  my ($prevMajorBackupVersion,$prevMinorBackupVersion) = split(/\./, $prevBackupVersion);

  # clear both directories only if the major backup version changed.  
  # backups are backwards compatible between minor versions
  return if ($prevBackupVersion == $currentBackupVersion);
  return if ($prevMajorBackupVersion >= $currentMajorBackupVersion);

  main::progress("Moving /opt/zimbra/backup/* to /opt/zimbra/backup/${startVersion}-${currentBackupVersion}.\n");
  clearBackupDir("/opt/zimbra/backup", "${startVersion}-${currentBackupVersion}");
  main::progress("Moving /opt/zimbra/redolog/* to /opt/zimbra/redolog/${startVersion}-${currentRedologVersion}.\n");
  clearRedologDir("/opt/zimbra/redolog", "${startVersion}-${currentRedologVersion}");

}

sub migrateTomcatLCKey {
  my ($key,$defVal) = @_;
  $defVal="" unless $defVal;
  my ($oldKey,$newKey,$oldVal); 
  $oldKey="tomcat_${key}";
  $newKey="mailboxd_${key}";
  $oldVal = main::getLocalConfig($oldKey);
  if ($oldVal ne "") {
    main::setLocalConfig("$newKey", "$oldVal");
  } elsif ($defVal ne "") {
    main::setLocalConfig("$newKey", "$defVal");
  }
  main::deleteLocalConfig("$oldKey");
}

sub indexLdap {
  if (main::isInstalled ("zimbra-ldap")) {
    stopLdap();
    main::runAsZimbra ("/opt/zimbra/libexec/zmslapindex");
    if (startLdap()) {return 1;}
  }
  return;
}

sub indexLdapAttribute {
  my ($key) = @_;
  if (main::isInstalled ("zimbra-ldap")) {
    stopLdap();
    main::runAsZimbra ("/opt/zimbra/libexec/zmslapindex $key");
    if (startLdap()) {return 1;}
  }
  return;
}

sub reloadLdap($) {
  my ($upgradeVersion) = @_;
  if (main::isInstalled ("zimbra-ldap")) {
    if($main::migratedStatus{"LdapReloaded$upgradeVersion"} ne "CONFIGURED") {
      my $ldifFile="/opt/zimbra/data/ldap/ldap-accesslog.bak";
      if (-d '/opt/zimbra/data/ldap/config/cn=config/olcDatabase={3}mdb') {
        if (-f $ldifFile && -s $ldifFile) {
          if (-d "/opt/zimbra/data/ldap/accesslog") { 
            main::progress("Loading accesslog DB..."); 
            if (-d "/opt/zimbra/data/ldap/accesslog.prev") {
              qx(mv /opt/zimbra/data/ldap/accesslog.prev /opt/zimbra/data/ldap/accesslog.prev.$$);
            }
            qx(mv /opt/zimbra/data/ldap/accesslog /opt/zimbra/data/ldap/accesslog.prev);
            qx(mkdir -p /opt/zimbra/data/ldap/accesslog/db);
            qx(chown -R zimbra:zimbra /opt/zimbra/data/ldap);
            my $rc;
            $rc=main::runAsZimbra("/opt/zimbra/libexec/zmslapadd -a $ldifFile");
            if ($rc != 0) {
              main::progress("slapadd import of accesslog db failed.\n");
              return 1;
            }
            main::progress("done.\n");
          }
        } else {
          main::progress("Creating new accesslog DB...");
          if (-d "/opt/zimbra/data/ldap/accesslog.prev") {
            qx(mv /opt/zimbra/data/ldap/accesslog.prev /opt/zimbra/data/ldap/accesslog.prev.$$);
          }
          qx(mv /opt/zimbra/data/ldap/accesslog /opt/zimbra/data/ldap/accesslog.prev);
          qx(mkdir -p /opt/zimbra/data/ldap/accesslog/db);
          qx(chown -R zimbra:zimbra /opt/zimbra/data/ldap);
          main::progress("done.\n");
        }
      }
      $ldifFile="/opt/zimbra/data/ldap/ldap.bak";
      if (-f $ldifFile && -s $ldifFile) {
        main::progress("Loading database..."); 
        if (-d "/opt/zimbra/data/ldap/mdb.prev") {
          qx(mv /opt/zimbra/data/ldap/mdb.prev /opt/zimbra/data/ldap/mdb.prev.$$);
        }
        qx(mv /opt/zimbra/data/ldap/mdb /opt/zimbra/data/ldap/mdb.prev);
        qx(mkdir -p /opt/zimbra/data/ldap/mdb/db);
        qx(chown -R zimbra:zimbra /opt/zimbra/data/ldap);
        my $rc;
        $rc=main::runAsZimbra("/opt/zimbra/libexec/zmslapadd $ldifFile");
        if ($rc != 0) {
          main::progress("slapadd import failed.\n");
          return 1;
        }
	chmod 0640, $ldifFile;
        main::progress("done.\n");
      } else {
        if (! -f $ldifFile) {
          main::progress("Error: Unable to find /opt/zimbra/data/ldap/ldap.bak\n");
        } else {
          main::progress("Error: /opt/zimbra/data/ldap/ldap.bak is empty\n");
        }
        return 1;
      }
      main::configLog("LdapUpgraded$upgradeVersion");
    }
    if (startLdap()) {return 1;} 
  }
  return 0;
}

sub upgradeLdap($) {
  my ($upgradeVersion) = @_;
  if (main::isInstalled ("zimbra-ldap")) {
    if($upgradeVersion eq "9.0.0_BETA1") {
      if($main::migratedStatus{"LdapUpgraded$upgradeVersion"} ne "CONFIGURED") {
        if (-f '/opt/zimbra/data/ldap/config/cn=config.ldif') {
          my $infile="/opt/zimbra/data/ldap/config/cn\=config.ldif";
          my $outfile="/tmp/config.ldif.$$";
          open(IN,"<$infile");
          open(OUT,">$outfile");
          while(<IN>) {
            if ($_ =~ /^olcPidFile: /) {
              print OUT "olcPidFile: /opt/zimbra/data/ldap/state/run/slapd.pid\n";
              next;
            }
            if ($_ =~ /^olcArgsFile: /) {
              print OUT "olcArgsFile: /opt/zimbra/data/ldap/state/run/slapd.args\n";
              next;
            }
            if ($_ =~ /^# CRC32/) {
              next;
            }
            print OUT $_;
          }
          close(OUT);
          close(IN);
          qx(mv $outfile $infile);
        }
        main::configLog("LdapUpgraded$upgradeVersion");
      }
    } else {
      if($main::migratedStatus{"LdapUpgraded$upgradeVersion"} ne "CONFIGURED") {
        # Fix LDAP schema for bug#62443
        unlink("/opt/zimbra/data/ldap/config/cn\=config/cn\=schema/cn\=\{3\}zimbra.ldif");
        unlink("/opt/zimbra/data/ldap/config/cn\=config/cn\=schema/cn\=\{4\}amavisd.ldif");
        my $ldifFile="/opt/zimbra/data/ldap/ldap.bak";
        if (-f $ldifFile && -s $ldifFile) {
          chmod 0644, $ldifFile;
          my $slapinfile = "$ldifFile";
          my $slapoutfile = "/opt/zimbra/data/ldap/ldap.80";
          main::progress("Upgrading ldap data...");
          open(IN,"<$slapinfile");
          open(OUT,">$slapoutfile");
          while(<IN>) {
            if ($_ =~ /^zimbraChildAccount:/) {next;}
            if ($_ =~ /^zimbraChildVisibleAccount:/) {next;}
            if ($_ =~ /^zimbraPrefChildVisibleAccount:/) {next;}
            if ($_ =~ /^zimbraPrefStandardClientAccessilbityMode:/) {next;}
            if ($_ =~ /^objectClass: zimbraHsmGlobalConfig/) {next;}
            if ($_ =~ /^objectClass: zimbraHsmServer/) {next;}
            if ($_ =~ /^objectClass: organizationalPerson/) {
              print OUT $_;
              print OUT "objectClass: inetOrgPerson\n";
              next;
            }
            if ($_ =~ /^structuralObjectClass: organizationalPerson/) {
              $_ =~ s/organizationalPerson/inetOrgPerson/;
            }
            print OUT $_;
          }
          close(IN);
          close(OUT);
          main::progress("done.\n");
          my $infile;
          my $outfile;
          main::progress("Upgrading LDAP configuration database...");
          if (-d '/opt/zimbra/data/ldap/config/cn=config/olcDatabase={2}hdb') {
            qx(mv /opt/zimbra/data/ldap/config/cn\=config/olcDatabase\=\{2\}hdb /opt/zimbra/data/ldap/config/cn\=config/olcDatabase\=\{2\}mdb);
          }
          if (-d '/opt/zimbra/data/ldap/config/cn=config/olcDatabase={3}hdb') {
            qx(mv /opt/zimbra/data/ldap/config/cn\=config/olcDatabase\=\{3\}hdb /opt/zimbra/data/ldap/config/cn\=config/olcDatabase\=\{3\}mdb);
            $infile=glob("/opt/zimbra/data/ldap/config/cn=config/olcDatabase=\\{3\\}mdb/olcOverlay=\\{*\\}syncprov.ldif");
            $outfile="/tmp/3syncprov.ldif.$$";
            open(IN,"<$infile");
            open(OUT,">$outfile");
            while(<IN>) {
              if ($_ =~ /olcSpSessionlog:/) {
                next;
              }
              print OUT $_;
            }
            close(OUT);
            close(IN);
            qx(mv $outfile $infile);
          }
          if (-f '/opt/zimbra/data/ldap/config/cn=config/cn=module{0}.ldif') {
            $infile="/opt/zimbra/data/ldap/config/cn\=config/cn\=module\{0\}.ldif";
            $outfile="/tmp/mod0.ldif.$$";
            open(IN,"<$infile");
            open(OUT,">$outfile");
            while(<IN>) {
              if ($_ =~ /^olcModuleLoad: \{0\}back_hdb.la/) {
                print OUT "olcModuleLoad: {0}back_mdb.la\n";
                next;
              }
              print OUT $_;
            }
            close(OUT);
            close(IN);
            qx(mv $outfile $infile);
          }
          if (-f '/opt/zimbra/data/ldap/config/cn=config.ldif') {
            $infile="/opt/zimbra/data/ldap/config/cn\=config.ldif";
            $outfile="/tmp/config.ldif.$$";
            open(IN,"<$infile");
            open(OUT,">$outfile");
            while(<IN>) {
              if ($_ =~ /^olcToolThreads: /) {
                print OUT "olcToolThreads: 2\n";
                next;
              }
              if ($_ =~ /^olcPidFile: /) {
                print OUT "olcPidFile: /opt/zimbra/data/ldap/state/run/slapd.pid\n";
                next;
              }
              if ($_ =~ /^olcArgsFile: /) {
                print OUT "olcArgsFile: /opt/zimbra/data/ldap/state/run/slapd.args\n";
                next;
              }
              if ($_ =~ /^# CRC32/) {
                next;
              }
              print OUT $_;
            }
            close(OUT);
            close(IN);
            qx(mv $outfile $infile);
          }
          if (-f '/opt/zimbra/data/ldap/config/cn=config/olcDatabase={3}hdb.ldif') {
            qx(mv /opt/zimbra/data/ldap/config/cn\=config/olcDatabase\=\{3\}hdb.ldif /opt/zimbra/data/ldap/config/cn\=config/olcDatabase=\{3\}mdb.ldif);
            $infile="/opt/zimbra/data/ldap/config/cn\=config/olcDatabase\=\{3\}mdb.ldif";
            $outfile="/tmp/3mdb.ldif.$$";
            open(IN,"<$infile");
            open(OUT,">$outfile");
            while(<IN>) {
              if ($_ =~ /^dn: olcDatabase=\{3\}hdb/) {
                print OUT "dn: olcDatabase={3}mdb\n";
                next;
              }
              if ($_ =~ /^objectClass: olcHdbConfig/) {
                print OUT "objectClass: olcMdbConfig\n";
                next;
              }
              if ($_ =~ /^olcDatabase: \{3\}hdb/) {
                print OUT "olcDatabase: {3}mdb\n";
                next;
              }
              if ($_ =~ /^olcDbDirectory: \/opt\/zimbra\/data\/ldap\/hdb\/db/) {
                print OUT "olcDbDirectory: /opt/zimbra/data/ldap/mdb/db\n";
                next;
              }
              if ($_ =~ /^structuralObjectClass: olcHdbConfig/) {
                print OUT "structuralObjectClass: olcMdbConfig\n";
                next;
              }
              if ($_ =~ /^olcDbMode:/) {
                print OUT $_;
                print OUT "olcDbMaxsize: 85899345920\n";
                next;
              }
              if ($_ =~ /^olcDbCheckpoint:/) {
                print OUT "olcDbCheckpoint: 0 0\n";
                print OUT "olcDbEnvFlags: writemap\n";
                print OUT "olcDbEnvFlags: nometasync\n";
                next;
              }
              if ($_ =~ /olcDbNoSync:/) {
                print OUT "olcDbNoSync: TRUE\n";
                next;
              }
              if ($_ =~ /olcDbCacheSize:/) {
                next;
              }
              if ($_ =~ /^olcDbConfig:/) {
                next;
              }
              if ($_ =~ /^olcDbDirtyRead:/) {
                next;
              }
              if ($_ =~ /^olcDbIDLcacheSize:/) {
                next;
              }
              if ($_ =~ /^olcDbLinearIndex:/) {
                next;
              }
              if ($_ =~ /^olcDbShmKey:/) {
                next;
              }
              if ($_ =~ /^olcDbCacheFree:/) {
                next;
              }
              if ($_ =~ /^olcDbDNcacheSize:/) {
                next;
              }
              print OUT $_;
            }
            close(OUT);
            close(IN);
            qx(mv $outfile $infile);
          }
          if (-f '/opt/zimbra/data/ldap/config/cn=config/olcDatabase={2}hdb.ldif') {
            qx(mv /opt/zimbra/data/ldap/config/cn\=config/olcDatabase\=\{2\}hdb.ldif /opt/zimbra/data/ldap/config/cn\=config/olcDatabase\=\{2\}mdb.ldif);
            $infile="/opt/zimbra/data/ldap/config/cn\=config/olcDatabase\=\{2\}mdb.ldif";
            $outfile="/tmp/2mdb.ldif.$$";
            open(IN,"<$infile");
            open(OUT,">$outfile");
            while(<IN>) {
              if ($_ =~ /^dn: olcDatabase=\{2\}hdb/) {
                print OUT "dn: olcDatabase={2}mdb\n";
                next;
              }
              if ($_ =~ /^objectClass: olcHdbConfig/) {
                print OUT "objectClass: olcMdbConfig\n";
                next;
              }
              if ($_ =~ /^olcDatabase: \{2\}hdb/) {
                print OUT "olcDatabase: {2}mdb\n";
                next;
              }
              if ($_ =~ /^olcDbDirectory: \/opt\/zimbra\/data\/ldap\/hdb\/db/) {
                print OUT "olcDbDirectory: /opt/zimbra/data/ldap/mdb/db\n";
                next;
              }
              if ($_ =~ /^structuralObjectClass: olcHdbConfig/) {
                print OUT "structuralObjectClass: olcMdbConfig\n";
                next;
              }
              if ($_ =~ /^olcDbMode:/) {
                print OUT $_;
                print OUT "olcDbMaxsize: 85899345920\n";
                next;
              }
              if ($_ =~ /^olcDbCheckpoint:/) {
                print OUT "olcDbCheckpoint: 0 0\n";
                print OUT "olcDbEnvFlags: writemap\n";
                print OUT "olcDbEnvFlags: nometasync\n";
                next;
              }
              if ($_ =~ /olcDbNoSync:/) {
                print OUT "olcDbNoSync: TRUE\n";
                next;
              }
              if ($_ =~ /olcDbCacheSize:/) {
                next;
              }
              if ($_ =~ /^olcDbConfig:/) {
                next;
              }
              if ($_ =~ /^olcDbDirtyRead:/) {
                next;
              }
              if ($_ =~ /^olcDbIDLcacheSize:/) {
                next;
              }
              if ($_ =~ /^olcDbLinearIndex:/) {
                next;
              }
              if ($_ =~ /^olcDbShmKey:/) {
                next;
              }
              if ($_ =~ /^olcDbCacheFree:/) {
                next;
              }
              if ($_ =~ /^olcDbDNcacheSize:/) {
                next;
              }
              print OUT $_;
            }
            close(OUT);
            close(IN);
            qx(mv $outfile $infile);
          }
          main::progress("done.\n");
  
          if (-d "/opt/zimbra/data/ldap/accesslog") { 
            main::progress("Creating new accesslog DB..."); 
            if (-d "/opt/zimbra/data/ldap/accesslog.prev") {
              qx(mv /opt/zimbra/data/ldap/accesslog.prev /opt/zimbra/data/ldap/accesslog.prev.$$);
            }
            qx(mv /opt/zimbra/data/ldap/accesslog /opt/zimbra/data/ldap/accesslog.prev);
            qx(mkdir -p /opt/zimbra/data/ldap/accesslog/db);
            qx(chown -R zimbra:zimbra /opt/zimbra/data/ldap);
            main::progress("done.\n");
          }
  
          main::progress("Loading database..."); 
          if (-d "/opt/zimbra/data/ldap/mdb.prev") {
            qx(mv /opt/zimbra/data/ldap/mdb.prev /opt/zimbra/data/ldap/mdb.prev.$$);
          }
          qx(mv /opt/zimbra/data/ldap/mdb /opt/zimbra/data/ldap/mdb.prev);
          qx(mkdir -p /opt/zimbra/data/ldap/mdb/db);
          qx(chown -R zimbra:zimbra /opt/zimbra/data/ldap);
          my $rc;
          $rc=main::runAsZimbra("/opt/zimbra/libexec/zmslapadd $slapoutfile");
          if ($rc != 0) {
            main::progress("slapadd import failed.\n");
            return 1;
          }
  	chmod 0640, $ldifFile;
          main::progress("done.\n");
        } else {
          if (! -f $ldifFile) {
            main::progress("Error: Unable to find /opt/zimbra/data/ldap/ldap.bak\n");
          } else {
            main::progress("Error: /opt/zimbra/data/ldap/ldap.bak is empty\n");
          }
          return 1;
        }
        main::configLog("LdapUpgraded$upgradeVersion");
      }
    }
    if (startLdap()) {return 1;} 
  }
  return 0;
}

sub migrateLdap($) {
  my ($migrateVersion) = @_;
  if (main::isInstalled ("zimbra-ldap")) {
    if($main::migratedStatus{"LdapUpgraded$migrateVersion"} ne "CONFIGURED") {
      if (-f "/opt/zimbra/data/ldap/ldap.bak") {
        my $infile = "/opt/zimbra/data/ldap/ldap.bak";
        my $outfile = "/opt/zimbra/data/ldap/ldap.80";
        if ( -s $infile ) {
          open(IN,"<$infile");
          open(OUT,">$outfile");
          while(<IN>) {
            if ($_ =~ /^zimbraChildAccount:/) {next;}
            if ($_ =~ /^zimbraChildVisibleAccount:/) {next;}
            if ($_ =~ /^zimbraPrefChildVisibleAccount:/) {next;}
            if ($_ =~ /^zimbraPrefStandardClientAccessilbityMode:/) {next;}
            if ($_ =~ /^objectClass: zimbraHsmGlobalConfig/) {next;}
            if ($_ =~ /^objectClass: zimbraHsmServer/) {next;}
            if ($_ =~ /^objectClass: organizationalPerson/) {
              print OUT $_;
              print OUT "objectClass: inetOrgPerson\n";
              next;
            }
            if ($_ =~ /^structuralObjectClass: organizationalPerson/) {
              $_ =~ s/organizationalPerson/inetOrgPerson/;
            }
            print OUT $_;
          }
          close(IN);
          close(OUT);
        } else {
          main::progress("LDAP backup file /opt/zimbra/data/ldap/ldap.bak is empty.\n");
          main::progress("Valid LDAP backup file not found, exiting.\n");
          return 1;
        }
        chmod 0644, $outfile if ( -s $outfile );

        main::installLdapConfig();

        main::progress("Migrating ldap data...");
        if (-d "/opt/zimbra/data/ldap/mdb.prev") {
          qx(mv /opt/zimbra/data/ldap/mdb.prev /opt/zimbra/data/ldap/mdb.prev.$$);
        }

        qx(mv /opt/zimbra/data/ldap/mdb /opt/zimbra/data/ldap/mdb.prev);
        qx(mkdir -p /opt/zimbra/data/ldap/mdb/db);
        qx(chown -R zimbra:zimbra /opt/zimbra/data/ldap);
        my $rc;
        $rc=main::runAsZimbra("/opt/zimbra/libexec/zmslapadd $outfile");
        if ($rc != 0) {
          main::progress("slapadd import failed.\n");
          return 1;
        }
        chmod 0640, "/opt/zimbra/data/ldap/ldap.bak";
        main::progress("done.\n");
      } else {
        stopLdap();
        main::progress("Running slapindex...");
        my $rc = main::runAsZimbra("/opt/zimbra/libexec/zmslapindex");
        main::progress(($rc == 0) ? "done.\n" : "failed.\n");
      }
      main::configLog("LdapUpgraded$migrateVersion");
    }
    if (startLdap()) {return 1;} 
  }
  return 0;
}

# DeleteLdapTree
# Requires Net::LDAP ref and DN
# Returns Net::LDAP::Search ref
sub DeleteLdapTree {
  my ($handle, $dn) = @_;
    
  # make sure it exists and get all the entries
  my $result = $handle->search( base => $dn, scope => 'one', filter => "(objectclass=*)");
  return $result if ($result->code());

  # loop through the entries and recursively delete them
  foreach my $entry($result->all_entries) {
    my $ref = DeleteLdapTree($handle, $entry->dn());
    return $ref if ($ref->code());
  }

  $result = $handle->delete($dn);
  return $result;
}

sub migrateAmavisDB($) {
  my ($toVersion) = @_;
  my $amavisdBase = "/opt/zimbra/amavisd-new";
  my $toDir = "${amavisdBase}-$toVersion";
  main::progress("Migrating amavisd-new to version $toVersion\n");
  foreach my $fromVersion (qw(2.5.2 2.4.3 2.4.1 2.3.3 2.3.1)) {
    next if ($toVersion eq $fromVersion);
    my $fromDir = "${amavisdBase}-$fromVersion";
    main::progress("Checking $fromDir/db\n");
    if ( -d "$fromDir/db" && -d "$toDir" && ! -e "$toDir/db/cache.db") {
      main::progress("Migrating amavis-new db from version $fromVersion to $toVersion\n");
      qx(rm -rf $toDir/db > /dev/null 2>&1);
      qx(mv $fromDir/db $toDir/db);
      qx(chown zimbra:zimbra $toDir/db); 
    }
    main::progress("Checking $fromDir/.spamassassin\n");
    if (-d "$fromDir/.spamassassin/" && -d "$toDir" && ! -e "$toDir/.spamassassin/bayes_toks" ) {
      main::progress("Migrating amavis-new .spamassassin from version $fromVersion to $toVersion\n");
      qx(rm -rf $toDir/.spamassassin > /dev/null 2>&1);
      qx(mv $fromDir/.spamassassin $toDir/.spamassassin);
      qx(chown zimbra:zimbra $toDir/.spamassassin); 
    }
  }
}

sub relocateAmavisDB() {
  my $toDir = "/opt/zimbra/data/amavisd";
  my $fromDir = "/opt/zimbra/amavisd-new-2.5.2";
  main::progress("Migrating Amavis database directory\n");
  if ( -d "$fromDir/db" && -d "$toDir" && ! -e "$toDir/db/cache.db") {
    qx(rm -rf $toDir/db > /dev/null 2>&1);
    qx(mv $fromDir/db $toDir/db);
    qx(chown zimbra:zimbra $toDir/db); 
  } 
  if (-d "$fromDir/.spamassassin/" && -d "$toDir" && ! -e "$toDir/.spamassassain/bayes_toks" ) {
    qx(rm -rf $toDir/.spamassassin > /dev/null 2>&1);
    qx(mv $fromDir/.spamassassin $toDir/.spamassassin);
    qx(chown zimbra:zimbra $toDir/.spamassassin); 
  }
}

sub verifyDatabaseIntegrity {
  if (-x "/opt/zimbra/libexec/zmdbintegrityreport") {
    main::progress("Verifying integrity of databases.\n");
    main::runAsZimbra("/opt/zimbra/libexec/zmdbintegrityreport -v -r");
  }
  return;
}

sub upgradeAllGlobalAdminAccounts {

  my @admins = qx($su "$ZMPROV gaaa");
  main::detail("Upgrading ACLs for all admin accounts.\n");
  my @adminUpgrades;
  foreach my $admin (@admins) {
    chomp $admin;
    my $val = main::getLdapAccountValue("zimbraIsAdminAccount",$admin);
    if (lc($val) eq "true") {
      push(@adminUpgrades,$admin);
      next;
    }
  }
  main::progress("Upgrading global admin accounts...");
  my $wfh= new FileHandle;
  my $efh= new FileHandle;
  my @errors;
  main::detail("Executing $su $ZMPROV");
  if (my $pid = open3($wfh,undef,$efh,"$su \"$ZMPROV\"")) {
    foreach my $admin (@adminUpgrades) {
      main::detail("$ZMPROV ma $admin zimbraAdminConsoleUIComponents cartBlancheUI");
      print $wfh "ma $admin zimbraAdminConsoleUIComponents cartBlancheUI\n";
    }
    print $wfh "exit\n";
    @errors = <$efh>;
    main::detail("@errors") if (scalar(@errors) != 0) ;
    close($wfh);
    close($efh);
    waitpid $pid, 0;
  }
  main::progress(($? == 0 && scalar(@errors) == 0) ? "done.\n" : "failed.\n");
}

sub upgradeLdapConfigValue($$$) {
  my ($key,$new_value,$cmp_value) = @_;
  my $current_value = main::getLdapConfigValue($key);
  if ($new_value eq "") {
      $new_value="\'\'";
  }
  main::setLdapGlobalConfig($key, $new_value)
    if ($current_value eq $cmp_value);
}

sub addLdapIndex($$$) {
  my ($index, $type) = @_;
  my $ldap_pass = qx($su "zmlocalconfig -s -m nokey ldap_root_password");
  chomp($ldap_pass);
  my $ldap;
  unless($ldap = Net::LDAP->new('ldapi://%2fopt%2fzimbra%2fdata%2fldap%2fstate%2frun%2fldapi/')) {
    main::progress("Unable to contact to ldapi: $!\n");
  }
  my $result = $ldap->bind("cn=config", password => $ldap_pass);
  my $dn="olcDatabase={2}mdb,cn=config";
  if ($isLdapMaster) {
    $result = $ldap->search(
                      base=> "cn=accesslog",
                      filter=>"(objectClass=*)",
                      scope => "base",
                      attrs => ['1.1'],
    );
    my $size = $result->count;
    if ($size > 0 ) {
      $dn="olcDatabase={3}mdb,cn=config";
    }
  }
  $result = $ldap->search(
    base=> "$dn",
    filter=>"(objectClass=*)",
    scope => "base",
    attrs => ['olcDbIndex'],
  );
  my $entry=$result->entry($result->count-1);
  my @attrvals=$entry->get_value("olcDbIndex");
  my $hasIndex=0;

  foreach my $attr (@attrvals) {
    if ($attr =~ /$index/) {
      $hasIndex=1;
    }
  }
  if (!$hasIndex) {
    $result = $ldap->modify(
        $dn,
        add =>{olcDbIndex=>"$index $type"},
    );
  }
  $ldap->unbind;
  return !$hasIndex;
}

sub upgradeLocalConfigValue($$$) {
  my ($key,$new_value,$cmp_value) = @_;
  my $current_value = main::getLocalConfig($key);
  main::setLocalConfig("$key", "$new_value")
    if ($current_value eq $cmp_value);
}

sub runAttributeUpgrade($) {
  my ($startVersion) = @_;
  my $rc = main::runAsZimbra("zmjava com.zimbra.cs.account.ldap.upgrade.LdapUpgrade -b 27075 -v $startVersion");
  return $rc;
}

sub runLdapAttributeUpgrade($) {
  my ($bug) = @_;
  return if ($bug eq "");
  my $rc = main::runAsZimbra("zmjava com.zimbra.cs.account.ldap.upgrade.LdapUpgrade -b $bug -v");
  return $rc;
}
    

1
