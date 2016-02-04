#!/usr/bin/perl
# vim: ts=2
#
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014 Zimbra, Inc.
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software Foundation,
# version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with this program.
# If not, see <http://www.gnu.org/licenses/>.
# ***** END LICENSE BLOCK *****
#

package zmupgrade;

use strict;
use lib "/opt/zimbra/libexec/scripts";
use lib "/opt/zimbra/common/lib/perl5";
use Migrate;
use Net::LDAP;
use IPC::Open3;
use FileHandle;
use File::Grep qw (fgrep);
use File::Path;
use XML::Simple;

my $zmlocalconfig="/opt/zimbra/bin/zmlocalconfig";
my $type = qx(${zmlocalconfig} -m nokey convertd_stub_name 2> /dev/null);
chomp $type;
if ($type eq "") {$type = "FOSS";}
else {$type = "NETWORK";}

my $rundir = qx(dirname $0);
chomp $rundir;
my $scriptDir = "/opt/zimbra/libexec/scripts";

my $lowVersion = 52;
my $hiVersion = 122; # this should be set to the DB version expected by current server code

my $needSlapIndexing = 0;
my $mysqlcnfUpdated = 0;

my $platform = qx(/opt/zimbra/libexec/get_plat_tag.sh);
chomp $platform;
my $addr_space = (($platform =~ m/\w+_(\d+)/) ? "$1" : "32");
my $su = "su - zimbra -c";

my $hn = qx($su "${zmlocalconfig} -m nokey zimbra_server_hostname");
chomp $hn;

my $isLdapMaster = qx($su "${zmlocalconfig} -m nokey ldap_is_master");
chomp($isLdapMaster);

my $ZMPROV = "/opt/zimbra/bin/zmprov -r -m -l --";

my %updateScripts = (
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
  '91' => "migrate20121009-VolumeBlobs.pl",            # 8.0.1
  '92' => "migrate20130226_alwayson.pl",               # 8.5.0
  # 93-99 skipped for possible IRONMAIDEN use
  '100' => "migrate20140319-MailItemPrevFolders.pl",   # 8.5.0
  '101' => "migrate20140328-EnforceTableCharset.pl",   #8.5.0
  '102' => "migrate20140624-DropMysqlIndexes.pl",      #8.5.0
  '103' => "migrate20150401-ZmgDevices.pl",            #8.7.0
  '104' => "migrate20150515-DataSourcePurgeTables.pl", #8.7.0
  '105' => "migrate20150623-ZmgDevices.pl",            #8.7.0
  '106' => "migrate20150702-ZmgDevices.pl",            #8.7.0
  '107' => "migrate20141218-mailItemTimestampsToMilliseconds.pl",
  #104-119 skipped for JUDASPRIEST use
  '120' => "migrate20150428-DropCurrentSessions.pl",
  '121' => "migrate20150702-CreateDavNameTable.pl",
);

my %updateFuncs = (
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
  "7.2.6_GA" => \&upgrade726GA,
  "7.2.7_GA" => \&upgrade727GA,
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
  "8.0.6_GA" => \&upgrade806GA,
  "8.0.7_GA" => \&upgrade807GA,
  "8.0.8_GA" => \&upgrade808GA,
  "8.0.9_GA" => \&upgrade809GA,
  "8.5.0_BETA1" => \&upgrade850BETA1,
  "8.5.0_BETA2" => \&upgrade850BETA2,
  "8.5.0_BETA3" => \&upgrade850BETA3,
  "8.5.0_GA" => \&upgrade850GA,
  "8.5.1_GA" => \&upgrade851GA,
  "8.6.0_BETA1" => \&upgrade860BETA1,
  "8.6.0_BETA2" => \&upgrade860BETA2,
  "8.6.0_GA" => \&upgrade860GA,
  "8.7.0_BETA1" => \&upgrade870BETA1,
  "8.7.0_BETA2" => \&upgrade870BETA2,
  "9.0.0_BETA1" => \&upgrade900BETA1,
);

my @versionOrder = (
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
  "7.2.6_GA",
  "7.2.7_GA",
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
  "8.0.6_GA",
  "8.0.7_GA",
  "8.0.8_GA",
  "8.0.9_GA",
  "8.5.0_BETA1",
  "8.5.0_BETA2",
  "8.5.0_BETA3",
  "8.5.0_GA",
  "8.5.1_GA",
  "8.6.0_BETA1",
  "8.6.0_BETA2",
  "8.6.0_GA",
  "8.7.0_BETA1",
  "8.7.0_BETA2",
  "9.0.0_BETA1",
);

my ($startVersion,$startMajor,$startMinor,$startMicro);
my ($targetVersion,$targetMajor,$targetMinor,$targetMicro,$targetMicroMicro,$targetType);

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
  if (lc($isLdapMaster) eq "true" ) {
     if(main::isInstalled("zimbra-ldap")) {
       $isLdapMaster = 1;
     } else {
       $isLdapMaster = 0;
     }
  } else {
       $isLdapMaster = 0;
  }
  my ($startBuild,$targetBuild);
  ($startVersion,$startBuild) = $startVersion =~ /(\d\.\d\.\d+_[^_]*)_(\d+)/;
  ($targetVersion,$targetBuild) = $targetVersion =~ m/(\d\.\d\.\d+_[^_]*)_(\d+)/;
  ($startMajor,$startMinor,$startMicro) =
    $startVersion =~ /(\d+)\.(\d+)\.(\d+_[^_]*)/;
  ($targetMajor,$targetMinor,$targetMicro) =
    $targetVersion =~ /(\d+)\.(\d+)\.(\d+_[^_]*)/;
  ($targetMicroMicro, $targetType) = $targetMicro =~ /(\d+)_(.*)/;

  if ($startMajor < 7) {
    main::progress("ERROR: Upgrading from a ZCS version less than 7.0.0_GA is not supported\n");
    return 1;
  }

  getInstalledPackages();

  # Bug #73840 - need to delete /opt/zimbra/keyview before we try stopping services
  if ((! main::isInstalled("zimbra-convertd")) && (-l "/opt/zimbra/keyview")) {
    unlink("/opt/zimbra/keyview");
  }

  if (stopZimbra()) { return 1; }

  if ($startVersion eq "7.0.0_GA") {
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
  } elsif ($startVersion eq "7.2.6_GA") {
    main::progress("This appears to be 7.2.6_GA\n");
  } elsif ($startVersion eq "7.2.7_GA") {
    main::progress("This appears to be 7.2.7_GA\n");
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
  } elsif ($startVersion eq "8.0.6_GA") {
    main::progress("This appears to be 8.0.6_GA\n");
  } elsif ($startVersion eq "8.0.7_GA") {
    main::progress("This appears to be 8.0.7_GA\n");
  } elsif ($startVersion eq "8.0.8_GA") {
    main::progress("This appears to be 8.0.8_GA\n");
  } elsif ($startVersion eq "8.0.9_GA") {
    main::progress("This appears to be 8.0.9_GA\n");
  } elsif ($startVersion eq "8.5.0_BETA1") {
    main::progress("This appears to be 8.5.0_BETA1\n");
  } elsif ($startVersion eq "8.5.0_BETA2") {
      main::progress("This appears to be 8.5.0_BETA2\n");
  } elsif ($startVersion eq "8.5.0_BETA3") {
      main::progress("This appears to be 8.5.0_BETA3\n");
  } elsif ($startVersion eq "8.5.0_GA") {
      main::progress("This appears to be 8.5.0_GA\n");
  } elsif ($startVersion eq "8.5.1_GA") {
      main::progress("This appears to be 8.5.1_GA\n");
  } elsif ($startVersion eq "8.6.0_BETA1") {
      main::progress("This appears to be 8.6.0_BETA1\n");
  } elsif ($startVersion eq "8.6.0_BETA2") {
      main::progress("This appears to be 8.6.0_BETA2\n");
  } elsif ($startVersion eq "8.6.0_GA") {
      main::progress("This appears to be 8.6.0_GA\n");
  } elsif ($startVersion eq "8.7.0_BETA1") {
      main::progress("This appears to be 8.7.0_BETA1\n");
  } elsif ($startVersion eq "8.7.0_BETA2") {
      main::progress("This appears to be 8.7.0_BETA2\n");
  } elsif ($startVersion eq "9.0.0_BETA1") {
      main::progress("This appears to be 9.0.0_BETA1\n");
  } else {
    if ($startVersion eq "") {
      main::progress("ERROR: Unable to find initial version to upgrade from.\n");
      main::progress("       This indicates a corrupted /opt/zimbra/.install_history file.\n");
      main::progress("       DO NOT ATTEMPT UPGRADING AGAIN UNTIL THE FILE IS FIXED.\n");
    } else {
      main::progress("ERROR: I can't upgrade unknown version $startVersion\n\n");
      main::progress("       This indicates an attempt to upgrade to an out of date release.\n");
      main::progress("       Please download and install the latest release from Zimbra.\n");
    }
    return 1;
  }

  my $curSchemaVersion;
  my $needMysqlUpgrade = 0;

  if (main::isInstalled("zimbra-store")) {
    my $version_found = 0;
    if ($startMajor <= 7 || ($startMajor == 8 && $startMinor < 7))
    {
        # Bug 96857 - MySQL meta files (pid file, socket, ..) should not be placed in db directory
        # temporary symlinks for relocation of key mysql files
        symlink("/opt/zimbra/db/mysql.pid", "/opt/zimbra/log/mysql.pid");
        symlink("/opt/zimbra/db/mysql.sock", "/opt/zimbra/data/tmp/mysql/mysql.sock");
    }
    foreach my $v (@versionOrder) {
      $version_found = 1 if ($v eq $startVersion);
      if ($version_found) {
        &doMysql55Upgrade if ($v eq "8.0.0_BETA1");
        &doMysql56Upgrade if ($v eq "8.5.0_BETA3");
        &doMariaDB101Upgrade if ($v eq "8.7.0_BETA1");
      }
      last if ($v eq $targetVersion);
    }

    if (startSql()) { return 1; };

    $curSchemaVersion = Migrate::getSchemaVersion();

    my $schema_found = 0;
    foreach my $v (@versionOrder) {
      $schema_found = 1 if ($v eq $startVersion);
      if ($schema_found) {
        $needMysqlUpgrade=1 if ($v eq "8.0.0_GA");
        $needMysqlUpgrade=1 if ($v eq "8.5.0_BETA1");
      }
      last if ($v eq $targetVersion);
    }
  }

  main::setLocalConfig("ssl_allow_untrusted_certs", "true") if ($startMajor <= 7 && $targetMajor >= 8);
  # start ldap
  if (main::isInstalled ("zimbra-ldap")) {
    if($startMajor < 8) {
      my $rc=&upgradeLdap("8.0.0_BETA3");
      if ($rc) { return 1; }
    } elsif(($startMajor == 8 && $startMinor < 5)) {
      my $rc=&upgradeLdap("8.5.0_BETA1");
      if ($rc) { return 1; }
    } elsif (($startMajor == 8 && $startMinor <= 7)) {
      my $rc=&upgradeLdap("8.7.0_BETA2");
      if ($rc) { return 1; }
    }
    if ($startMajor == 8 && $startMinor == 0 && $startMicro < 3) {
      my $rc=&reloadLdap("8.0.3_GA");
      if ($rc) { return 1; }
    }
    if (startLdap()) {return 1;}
  }

  # Update our CA cert(s) for java/zmprov before we go further
  main::runAsZimbra("/opt/zimbra/bin/zmcertmgr createca");
  main::runAsZimbra("/opt/zimbra/bin/zmcertmgr deployca -localonly");

  if (main::isInstalled("zimbra-store")) {

    doMysqlUpgrade() if ($needMysqlUpgrade);

    doBackupRestoreVersionUpdate($startVersion);

    if ($curSchemaVersion < $hiVersion) {
      main::progress("Schema upgrade required from version $curSchemaVersion to $hiVersion.\n");
    }

    # the old slow painful way (ie lots of mysql invocations)
    while ($curSchemaVersion >= $lowVersion && $curSchemaVersion < $hiVersion) {
      if (runSchemaUpgrade ($curSchemaVersion)) { return 1; }
      $curSchemaVersion = Migrate::getSchemaVersion();
    }
     if ( $startMajor = 7 && $targetMajor >= 8) {
       # Bug #78297
       my $imap_cache_data_files = "/opt/zimbra/data/mailboxd/imap-*";
       system("/bin/rm -f ${imap_cache_data_files} 2> /dev/null");
     }
    stopSql();
  }

  my $found = 0;
  foreach my $v (@versionOrder) {
    if ($v eq $startVersion) {
      $found = 1;
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
  my $mysql_data_directory =
    main::getLocalConfig("mysql_data_directory") || "/opt/zimbra/db/data";
  my $zimbra_tmp_directory =
    main::getLocalConfig("zimbra_tmp_directory") || "/opt/zimbra/data/tmp";
  my $mysql_mycnf =
    main::getLocalConfig("mysql_mycnf") || "/opt/zimbra/conf/my.cnf";

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
    my $imap_cache_data_directory = "/opt/zimbra/data/mailboxd/imap";
    rmtree("${imap_cache_data_directory}")
      if ( -d "${imap_cache_data_directory}/");
    if ( -d "/opt/zimbra/zimlets-deployed/com_zimbra_smime/") {
      main::runAsZimbra("/opt/zimbra/bin/zmzimletctl -l undeploy com_zimbra_smime");
      system("rm -rf /opt/zimbra/mailboxd/webapps/service/zimlet/com_zimbra_smime")
        if (-d "/opt/zimbra/mailboxd/webapps/service/zimlet/com_zimbra_smime" );
    }
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

sub upgrade726GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 7.2.6_GA\n");
  return 0;
}

sub upgrade727GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 7.2.7_GA\n");
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

    qx(/opt/zimbra/common/bin/mysql -S '$mysql_socket' -u root --password='$mysql_root_password' -e "$sql");
    qx(/opt/zimbra/common/bin/mysql -S '$mysql_socket' -u root --password='$mysql_root_password' -e "DROP USER ''\@'localhost'; DROP USER ''\@'${host}'");
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
    if (-e "/opt/zimbra/jetty-6.1.22.z6/etc/jetty.keytab") {
      qx(mkdir -p /opt/zimbra/data/mailboxd/spnego);
      qx(cp -pf /opt/zimbra/jetty-6.1.22.z6/etc/jetty.keytab /opt/zimbra/data/mailboxd/spnego/jetty.keytab);
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
      main::runAsZimbra("sqlite3 $cbpdb < ${scriptDir}/migrate20130819-UpgradeQuotasTable.sql >/dev/null 2>&1");
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
    $main::config{RUNDKIM}="yes";
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
  if (main::isInstalled("zimbra-proxy")) {
    my $rpeioa=main::getLocalConfig("zimbra_reverseproxy_externalroute_include_original_authusername");
    if(lc($rpeioa) eq "true") {
      main::setLdapGlobalConfig("zimbraReverseProxyExternalRouteIncludeOriginalAuthusername","TRUE");
    }
  }
  main::deleteLocalConfig("zimbra_reverseproxy_externalroute_include_original_authusername");
  return 0;
}

sub upgrade806GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.0.6_GA\n");
  if (main::isZCA()) {
    main::progress("ZCA Install detected.  Removing VAMI Components...");
    my $rc = main::runAsRoot("${scriptDir}/migrate20131014-removezca.pl");
    main::progress(($rc == 0) ? "done.\n" : "failed. exiting.\n");
  }
  my @zimbraStatThreadNamePrefix=qx($su "$ZMPROV gacf zimbraStatThreadNamePrefix");
  if (! grep ( /qtp/, @zimbraStatThreadNamePrefix)) {
    main::runAsZimbra("$ZMPROV mcf +zimbraStatThreadNamePrefix qtp");
  }
  return 0;
}

sub upgrade807GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.0.7_GA\n");
  return 0;
}

sub upgrade808GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.0.8_GA\n");
  my $ldap_read_timeout=main::getLocalConfig("ldap_read_timeout");
  if ($ldap_read_timeout == 0) {
    main::deleteLocalConfig("ldap_read_timeout"); #85299
  }
  if (main::isInstalled("zimbra-ldap")) {
    my $ldap_common_writetimeout=main::getLocalConfig("ldap_common_writetimeout");
    if ($ldap_common_writetimeout == 0) {
      main::deleteLocalConfig("ldap_common_writetimeout"); #85299
    }
  }
  if (main::isInstalled("zimbra-mta")) {
    my @zimbraServiceInstalled=qx($su "$ZMPROV gs $hn zimbraServiceInstalled");
    my @zimbraServiceEnabled=qx($su "$ZMPROV gs $hn zimbraServiceEnabled");
    if (grep(/antivirus/, @zimbraServiceInstalled) || grep(/antispam/, @zimbraServiceInstalled) || grep(/archiving/, @zimbraServiceInstalled)) {
      main::setLdapServerConfig($hn, '+zimbraServiceInstalled', 'amavis');
    }
    if (grep(/antivirus/, @zimbraServiceEnabled) || grep(/antispam/, @zimbraServiceEnabled) || grep(/archiving/, @zimbraServiceEnabled)) {
      main::setLdapServerConfig($hn, '+zimbraServiceEnabled', 'amavis');
    }
  }
  return 0;
}

sub upgrade809GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.0.9_GA\n");
  return 0;
}

sub upgrade850BETA1 {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.5.0_BETA1\n");
  if (main::isInstalled("zimbra-store")) {
    my $mailboxd_java_options=main::getLocalConfigRaw("mailboxd_java_options");
    my $new_mailboxd_options="";
    if ($mailboxd_java_options =~ /-XX:\+PrintGCTimeStamps/) {
      foreach my $option (split(/\s+/, $mailboxd_java_options)) {
        $new_mailboxd_options.=" $option" if ($option !~ /^-XX:\+PrintGCTimeStamps/);
      }
      $new_mailboxd_options .= " -XX:+PrintGCDateStamps"
        unless ($mailboxd_java_options =~ /PrintGCDateStamps/);
      $new_mailboxd_options =~ s/^\s+//;
      main::setLocalConfig("mailboxd_java_options", $new_mailboxd_options)
        if ($new_mailboxd_options ne "");
    }
    if (main::isNetwork()) {
      my @zimbraReverseProxyUpstreamEwsServers=qx($su "$ZMPROV gacf zimbraReverseProxyUpstreamEwsServers");
      if (! grep(/$hn/, @zimbraReverseProxyUpstreamEwsServers)) {
        main::runAsZimbra("$ZMPROV mcf +zimbraReverseProxyUpstreamEwsServers $hn");
      }
    }
    main::setLdapServerConfig($hn, '+zimbraServiceEnabled', 'service');
    main::setLdapServerConfig($hn, '+zimbraServiceEnabled', 'zimbra');
    main::setLdapServerConfig($hn, '+zimbraServiceEnabled', 'zimbraAdmin');
    main::setLdapServerConfig($hn, '+zimbraServiceEnabled', 'zimlet');
    $main::config{SERVICEWEBAPP} = "yes";
    $main::config{UIWEBAPPS} = "yes";
    $main::installedWebapps{service} = "Enabled";
    $main::installedWebapps{zimlet} = "Enabled";
    $main::installedWebapps{zimbra} = "Enabled";
    $main::installedWebapps{zimbraAdmin} = "Enabled";
  }
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
      main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-innodb_data_file_path-fixup --section=mysqld --set --key=innodb_data_file_path --value=ibdata1:10M:autoextend ${antispam_mysql_mycnf}");
    }
    my $disclaimerEnabled = main::getLdapConfigValue("zimbraDomainMandatoryMailSignatureEnabled");
    if(lc($disclaimerEnabled) eq "true") {
      unlink("/opt/zimbra/data/altermime/global-default.txt");
      unlink("/opt/zimbra/data/altermime/global-default.html");
      my @domains = qx($su "$ZMPROV gad");
      foreach my $domain (@domains) {
        chomp $domain;
        main::runAsZimbra("/opt/zimbra/libexec/zmaltermimeconfig -e $domain");
      }
    }
    my $localxml = XMLin("/opt/zimbra/conf/localconfig.xml");

    my $lc_attr= $localxml->{key}->{amavis_max_servers}->{value};
    if (defined($lc_attr) && $lc_attr+0 != 0) {
      main::setLdapServerConfig($hn, 'zimbraAmavisMaxServers', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{clamav_max_threads}->{value};
    if (defined($lc_attr) && $lc_attr+0 != 0) {
      main::setLdapServerConfig($hn, 'zimbraClamAVMaxThreads', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{amavis_enable_dkim_verification}->{value};
    if (defined($lc_attr) && lc($lc_attr) eq "false") {
      main::setLdapServerConfig($hn, 'zimbraAmavisEnableDKIMVerification', "FALSE");
    }
    $lc_attr= $localxml->{key}->{amavis_originating_bypass_sa}->{value};
    if (defined($lc_attr) && lc($lc_attr) eq "true") {
      main::setLdapServerConfig($hn, 'zimbraAmavisOriginatingBypassSA', "TRUE");
    }
    $lc_attr= $localxml->{key}->{amavis_dspam_enabled}->{value};
    if (defined($lc_attr) && (lc($lc_attr) eq "yes" || lc($lc_attr) eq "true")) {
      main::setLdapServerConfig($hn, 'zimbraAmavisDSPAMEnabled', "TRUE");
    }
    $lc_attr= $localxml->{key}->{postfix_enable_smtpd_policyd}->{value};
    if (defined($lc_attr) && (lc($lc_attr) eq "yes" || lc($lc_attr) eq "true")) {
      main::setLdapServerConfig($hn, 'zimbraPostfixEnableSmtpdPolicyd', "TRUE");
    }
    $lc_attr= $localxml->{key}->{cbpolicyd_min_servers}->{value};
    if (defined($lc_attr) && $lc_attr != 4) {
      main::setLdapServerConfig($hn, 'zimbraCBPolicydMinServers', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{cbpolicyd_min_spare_servers}->{value};
    if (defined($lc_attr) && $lc_attr != 4) {
      main::setLdapServerConfig($hn, 'zimbraCBPolicydMinSpareServers', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{cbpolicyd_max_servers}->{value};
    if (defined($lc_attr) && $lc_attr != 25) {
      main::setLdapServerConfig($hn, 'zimbraCBPolicydMaxServers', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{cbpolicyd_max_spare_servers}->{value};
    if (defined($lc_attr) ne "" && $lc_attr != 12) {
      main::setLdapServerConfig($hn, 'zimbraCBPolicydMaxSpareServers', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{cbpolicyd_max_requests}->{value};
    if (defined($lc_attr) && $lc_attr != 1000) {
      main::setLdapServerConfig($hn, 'zimbraCBPolicydMaxRequests', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{cbpolicyd_timeout_idle}->{value};
    if (defined($lc_attr) && $lc_attr != 1020) {
      main::setLdapServerConfig($hn, 'zimbraCBPolicydTimeoutIdle', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{cbpolicyd_timeout_busy}->{value};
    if (defined($lc_attr) && $lc_attr != 120) {
      main::setLdapServerConfig($hn, 'zimbraCBPolicydTimeoutBusy', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{cbpolicyd_bypass_timeout}->{value};
    if (defined($lc_attr) && $lc_attr != 30) {
      main::setLdapServerConfig($hn, 'zimbraCBPolicydBypassTimeout', "TRUE");
    }
    $lc_attr= $localxml->{key}->{cbpolicyd_bypass_mode}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "tempfail" ) {
      main::setLdapServerConfig($hn, 'zimbraCBPolicydBypassMode', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{cbpolicyd_module_accesscontrol}->{value};
    if (defined($lc_attr) && (0+$lc_attr > 0  || lc($lc_attr) eq "true")) {
      main::setLdapServerConfig($hn, 'zimbraCBPolicydAccessControlEnabled', "TRUE");
    }
    $lc_attr= $localxml->{key}->{cbpolicyd_module_greylisting}->{value};
    if (defined($lc_attr) && (0+$lc_attr > 0  || lc($lc_attr) eq "true")) {
      main::setLdapServerConfig($hn, 'zimbraCBPolicydGreylistingEnabled', "TRUE");
    }
    $lc_attr= $localxml->{key}->{cbpolicyd_module_greylisting_training}->{value};
    if ($lc_attr ne "" && (0+$lc_attr > 0  || lc($lc_attr) eq "true")) {
      main::setLdapServerConfig($hn, 'zimbraCBPolicydGreylistingTrainingEnabled', "TRUE");
    }
    $lc_attr= $localxml->{key}->{cbpolicyd_module_greylisting_defer_msg}->{value};
    if (defined($lc_attr)) {
      main::setLdapServerConfig($hn, 'zimbraCBPolicydGreylistingDeferMsg', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{cbpolicyd_module_greylisting_blacklist_msg}->{value};
    if (defined($lc_attr)) {
      main::setLdapServerConfig($hn, 'zimbraCBPolicydGreylistingBlacklistMsg', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{cbpolicyd_module_checkhelo}->{value};
    if (defined($lc_attr) && (0+$lc_attr > 0 || lc($lc_attr) eq "yes" || lc($lc_attr) eq "true")) {
      main::setLdapServerConfig($hn, 'zimbraCBPolicydCheckHeloEnabled', "TRUE");
    }
    $lc_attr= $localxml->{key}->{cbpolicyd_module_checkspf}->{value};
    if (defined($lc_attr) && (0+$lc_attr > 0 || lc($lc_attr) eq "yes" || lc($lc_attr) eq "true")) {
      main::setLdapServerConfig($hn, 'zimbraCBPolicydCheckSPFEnabled', "TRUE");
    }
    $lc_attr= $localxml->{key}->{cbpolicyd_module_quotas}->{value};
    if (defined($lc_attr) && (0+$lc_attr == 0 || lc($lc_attr) eq "no" || lc($lc_attr) eq "false")) {
      main::setLdapServerConfig($hn, 'zimbraCBPolicydQuotasEnabled', "FALSE");
    }
    $lc_attr= $localxml->{key}->{cbpolicyd_module_amavis}->{value};
    if (defined($lc_attr) && (0+$lc_attr > 0 || lc($lc_attr) eq "yes" || lc($lc_attr) eq "true")) {
      main::setLdapServerConfig($hn, 'zimbraCBPolicydAmavisEnabled', "TRUE");
    }
    $lc_attr= $localxml->{key}->{cbpolicyd_module_accounting}->{value};
    if (defined($lc_attr) && (0+$lc_attr > 0 || lc($lc_attr) eq "yes" || lc($lc_attr) eq "true")) {
      main::setLdapServerConfig($hn, 'zimbraCBPolicydAccountingEnabled', "TRUE");
    }
    $lc_attr= $localxml->{key}->{postfix_always_add_missing_headers}->{value};
    if (defined($lc_attr) && lc($lc_attr) eq "no") {
      main::setLdapServerConfig($hn, 'zimbraMtaAlwaysAddMissingHeaders', "no");
    }
    $lc_attr= $localxml->{key}->{postfix_broken_sasl_auth_clients}->{value};
    if (defined($lc_attr) && lc($lc_attr) eq "no") {
      main::setLdapServerConfig($hn, 'zimbraMtaBrokenSaslAuthClients', "no");
    }
    $lc_attr= $localxml->{key}->{postfix_bounce_notice_recipient}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "postmaster") {
      main::setLdapServerConfig($hn, 'zimbraMtaBounceNoticeRecipient', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_bounce_queue_lifetime}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "5d") {
      main::setLdapServerConfig($hn, 'zimbraMtaBounceQueueLifetime', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_delay_warning_time}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "0h") {
      main::setLdapServerConfig($hn, 'zimbraMtaDelayWarningTime', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_header_checks}->{value};
    if (defined($lc_attr)) {
      if ($lc_attr =~ /\${zimbra_home}/) {
        $lc_attr =~ s/\${zimbra_home}/\/opt\/zimbra/;
      }
      $lc_attr =~ s/, /,/g;
      $lc_attr =~ s/\s+/ /g;
      foreach my $option (split(/,|\s/, $lc_attr)) {
        main::setLdapServerConfig($hn, '+zimbraMtaHeaderChecks', "$option");
      }
    }
    $lc_attr= $localxml->{key}->{postfix_in_flow_delay}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "1s") {
      main::setLdapServerConfig($hn, 'zimbraMtaInFlowDelay', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_import_environment}->{value};
    if (defined($lc_attr)) {
      $lc_attr =~ s/, /,/g;
      $lc_attr =~ s/\s+/ /g;
      foreach my $option (split(/,|\s/, $lc_attr)) {
        main::setLdapServerConfig($hn, '+zimbraMtaImportEnvironment', "$option");
      }
    }
    $lc_attr= $localxml->{key}->{postfix_lmtp_connection_cache_destinations}->{value};
    if (defined($lc_attr)) {
      $lc_attr =~ s/, /,/g;
      $lc_attr =~ s/\s+/ /g;
      foreach my $option (split(/,|\s/, $lc_attr)) {
        main::setLdapServerConfig($hn, '+zimbraMtaLmtpConnectionCacheDestinations', "$option");
      }
    }
    $lc_attr= $localxml->{key}->{postfix_lmtp_connection_cache_time_limit}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "4s") {
      main::setLdapServerConfig($hn, 'zimbraMtaLmtpConnectionCacheTimeLimit', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_lmtp_host_lookup}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "dns") {
      $lc_attr =~ s/, /,/g;
      $lc_attr =~ s/\s+/ /g;
      foreach my $option (split(/,|\s/, $lc_attr)) {
        main::setLdapServerConfig($hn, '+zimbraMtaLmtpHostLookup', "$option");
      }
    }
    $lc_attr= $localxml->{key}->{postfix_queue_directory}->{value};
    if (defined($lc_attr)) {
      if ($lc_attr =~ /\${zimbra_home}/) {
        $lc_attr =~ s/\${zimbra_home}/\/opt\/zimbra/;
      }
      main::setLdapServerConfig($hn, 'zimbraMtaQueueDirectory', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_maximal_backoff_time}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "4000s") {
      main::setLdapServerConfig($hn, 'zimbraMtaMaximalBackoffTime', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_minimal_backoff_time}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "300s") {
      main::setLdapServerConfig($hn, 'zimbraMtaMinimalBackoffTime', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_queue_run_delay}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "300s") {
      main::setLdapServerConfig($hn, 'zimbraMtaQueueRunDelay', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_milter_connect_timeout}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "30s") {
      main::setLdapServerConfig($hn, 'zimbraMtaMilterConnectTimeout', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_milter_content_timeout}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "300s") {
      main::setLdapServerConfig($hn, 'zimbraMtaMilterContentTimeout', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_milter_default_action}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "tempfail") {
      main::setLdapServerConfig($hn, 'zimbraMtaMilterDefaultAction', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_smtp_cname_overrides_servername}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "no") {
      main::setLdapServerConfig($hn, 'zimbraMtaSmtpCnameOverridesServername', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_smtp_helo_name}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne '$myhostname') {
      main::setLdapServerConfig($hn, 'zimbraMtaSmtpHeloName', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_smtp_sasl_auth_enable}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "no") {
      main::setLdapServerConfig($hn, 'zimbraMtaSmtpSaslAuthEnable', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_smtp_tls_security_level}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "may") {
      main::setLdapServerConfig($hn, 'zimbraMtaSmtpTlsSecurityLevel', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_smtp_sasl_mechanism_filter}->{value};
    if (defined($lc_attr)) {
      $lc_attr =~ s/, /,/g;
      $lc_attr =~ s/\s+/ /g;
      foreach my $option (split(/,|\s/, $lc_attr)) {
        main::setLdapServerConfig($hn, '+zimbraMtaSmtpSaslMechanismFilter', "$option");
      }
    }
    $lc_attr= $localxml->{key}->{postfix_smtp_sasl_password_maps}->{value};
    if (defined($lc_attr)) {
      $lc_attr =~ s/, /,/g;
      $lc_attr =~ s/\s+/ /g;
      main::setLdapServerConfig($hn, 'zimbraMtaSmtpSaslPasswordMaps', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_policy_time_limit}->{value};
    if (defined($lc_attr)) {
      main::setLdapServerConfig($hn, 'zimbraMtaPolicyTimeLimit', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_smtpd_banner}->{value};
    if (defined($lc_attr)) {
      main::setLdapServerConfig($hn, 'zimbraMtaSmtpdBanner', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_smtpd_proxy_timeout}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "100s") {
      main::setLdapServerConfig($hn, 'zimbraMtaSmtpdProxyTimeout', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_smtpd_reject_unlisted_recipient}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "no") {
      main::setLdapServerConfig($hn, 'zimbraMtaSmtpdRejectUnlistedRecipient', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_smtpd_reject_unlisted_sender}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "no") {
      main::setLdapServerConfig($hn, 'zimbraMtaSmtpdRejectUnlistedSender', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_smtpd_sasl_authenticated_header}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "no") {
      main::setLdapServerConfig($hn, 'zimbraMtaSmtpdSaslAuthenticatedHeader', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_smtpd_hard_error_limit}->{value};
    if (defined($lc_attr) && $lc_attr != 20) {
      main::setLdapServerConfig($hn, 'zimbraMtaSmtpdHardErrorLimit', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_smtpd_soft_error_limit}->{value};
    if (defined($lc_attr) && $lc_attr != 10) {
      main::setLdapServerConfig($hn, 'zimbraMtaSmtpdSoftErrorLimit', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_smtpd_error_sleep_time}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "1s") {
      main::setLdapServerConfig($hn, 'zimbraMtaSmtpdErrorSleepTime', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_smtpd_helo_required}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "yes") {
      main::setLdapServerConfig($hn, 'zimbraMtaSmtpdHeloRequired', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_smtpd_tls_loglevel}->{value};
    if (defined($lc_attr) && $lc_attr != 1) {
      main::setLdapServerConfig($hn, 'zimbraMtaSmtpdTlsLoglevel', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_virtual_alias_expansion_limit}->{value};
    if (defined($lc_attr) && $lc_attr != 10000) {
      main::setLdapServerConfig($hn, 'zimbraMtaVirtualAliasExpansionLimit', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_virtual_transport}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "error") {
      main::setLdapServerConfig($hn, 'zimbraMtaSmtpdVirtualTransport', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_notify_classes}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "resource,software") {
      $lc_attr =~ s/, /,/g;
      $lc_attr =~ s/\s+/ /g;
      foreach my $option (split(/,|\s/, $lc_attr)) {
        main::setLdapServerConfig($hn, '+zimbraMtaNotifyClasses', "$option");
      }
    }
    $lc_attr= $localxml->{key}->{postfix_propagate_unmatched_extensions}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "canonical") {
      $lc_attr =~ s/, /,/g;
      $lc_attr =~ s/\s+/ /g;
      foreach my $option (split(/,|\s/, $lc_attr)) {
        main::setLdapServerConfig($hn, '+zimbraMtaPropagateUnmatchedExtensions', "$option");
      }
    }
    $lc_attr= $localxml->{key}->{postfix_sender_canonical_maps}->{value};
    if (defined($lc_attr)) {
      if ($lc_attr =~ /\${zimbra_home}/) {
        $lc_attr =~ s/\${zimbra_home}/\/opt\/zimbra/g;
      }
      $lc_attr =~ s/, /,/g;
      $lc_attr =~ s/\s+/ /g;
      main::setLdapServerConfig($hn, 'zimbraMtaSenderCanonicalMaps', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_smtp_sasl_security_options}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "noplaintext,noanonymous") {
      $lc_attr =~ s/, /,/g;
      $lc_attr =~ s/\s+/ /g;
      foreach my $option (split(/,|\s/, $lc_attr)) {
        main::setLdapServerConfig($hn, '+zimbraMtaSmtpSaslSecurityOptions', "$option");
      }
    }
    $lc_attr= $localxml->{key}->{postfix_smtpd_sasl_security_options}->{value};
    if (defined($lc_attr) && lc($lc_attr) ne "noplaintext,noanonymous") {
      $lc_attr =~ s/, /,/g;
      $lc_attr =~ s/\s+/ /g;
      foreach my $option (split(/,|\s/, $lc_attr)) {
        main::setLdapServerConfig($hn, '+zimbraMtaSmtpdSaslSecurityOptions', "$option");
      }
    }
    $lc_attr= $localxml->{key}->{postfix_smtpd_sasl_tls_security_options}->{value};
    if (defined($lc_attr)) {
      $lc_attr =~ s/, /,/g;
      $lc_attr =~ s/\s+/ /g;
      foreach my $option (split(/,|\s/, $lc_attr)) {
        main::setLdapServerConfig($hn, '+zimbraMtaSmtpdSaslTlsSecurityOptions', "$option");
      }
    }
    $lc_attr= $localxml->{key}->{postfix_smtpd_client_restrictions}->{value};
    if (defined($lc_attr)) {
      main::setLdapServerConfig($hn, 'zimbraMtaSmtpdClientRestrictions', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_smtpd_data_restrictions}->{value};
    if (defined($lc_attr)) {
      main::setLdapServerConfig($hn, 'zimbraMtaSmtpdDataRestrictions', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_transport_maps}->{value};
    if (defined($lc_attr)) {
      if ($lc_attr =~ /\${zimbra_home}/) {
        $lc_attr =~ s/\${zimbra_home}/\/opt\/zimbra/g;
      }
      $lc_attr =~ s/, /,/g;
      $lc_attr =~ s/\s+/ /g;
      main::setLdapServerConfig($hn, 'zimbraMtaTransportMaps', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_virtual_alias_domains}->{value};
    if (defined($lc_attr)) {
      if ($lc_attr =~ /\${zimbra_home}/) {
        $lc_attr =~ s/\${zimbra_home}/\/opt\/zimbra/g;
      }
      $lc_attr =~ s/, /,/g;
      $lc_attr =~ s/\s+/ /g;
      main::setLdapServerConfig($hn, 'zimbraMtaVirtualAliasDomains', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_virtual_alias_maps}->{value};
    if (defined($lc_attr)) {
      if ($lc_attr =~ /\${zimbra_home}/) {
        $lc_attr =~ s/\${zimbra_home}/\/opt\/zimbra/g;
      }
      $lc_attr =~ s/, /,/g;
      $lc_attr =~ s/\s+/ /g;
      main::setLdapServerConfig($hn, 'zimbraMtaVirtualAliasMaps', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_virtual_mailbox_domains}->{value};
    if (defined($lc_attr)) {
      if ($lc_attr =~ /\${zimbra_home}/) {
        $lc_attr =~ s/\${zimbra_home}/\/opt\/zimbra/g;
      }
      $lc_attr =~ s/, /,/g;
      $lc_attr =~ s/\s+/ /g;
      main::setLdapServerConfig($hn, 'zimbraMtaVirtualMailboxDomains', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{postfix_virtual_mailbox_maps}->{value};
    if (defined($lc_attr)) {
      if ($lc_attr =~ /\${zimbra_home}/) {
        $lc_attr =~ s/\${zimbra_home}/\/opt\/zimbra/g;
      }
      $lc_attr =~ s/, /,/g;
      $lc_attr =~ s/\s+/ /g;
      main::setLdapServerConfig($hn, 'zimbraMtaVirtualMailboxMaps', "$lc_attr");
    }
    $lc_attr= $localxml->{key}->{sasl_smtpd_mech_list}->{value};
    if (defined($lc_attr)) {
      $lc_attr =~ s/, /,/g;
      $lc_attr =~ s/\s+/ /g;
      foreach my $option (split(/,|\s/, $lc_attr)) {
        main::setLdapServerConfig($hn, '+zimbraMtaSaslSmtpdMechList', "$option");
      }
    }
    $lc_attr= $localxml->{key}->{cbpolicyd_bind_port}->{value};
    if (defined($lc_attr) && $lc_attr != 10031) {
      main::setLdapServerConfig($hn, 'zimbraCBPolicydBindPort', "TRUE");
    }
    $lc_attr= $localxml->{key}->{cbpolicyd_log_level}->{value};
    if (defined($lc_attr) && $lc_attr != 3) {
      main::setLdapServerConfig($hn, 'zimbraCBPolicydLogLevel', "TRUE");
    }
  }
  main::deleteLocalConfig("amavis_max_servers");
  main::deleteLocalConfig("clamav_max_threads");
  main::deleteLocalConfig("amavis_enable_dkim_verification");
  main::deleteLocalConfig("amavis_originating_bypass_sa");
  main::deleteLocalConfig("amavis_dspam_enabled");
  main::deleteLocalConfig("postfix_enable_smtpd_policyd");
  main::deleteLocalConfig("cbpolicyd_min_servers");
  main::deleteLocalConfig("cbpolicyd_min_spare_servers");
  main::deleteLocalConfig("cbpolicyd_max_servers");
  main::deleteLocalConfig("cbpolicyd_max_spare_servers");
  main::deleteLocalConfig("cbpolicyd_max_requests");
  main::deleteLocalConfig("cbpolicyd_timeout_idle");
  main::deleteLocalConfig("cbpolicyd_timeout_busy");
  main::deleteLocalConfig("cbpolicyd_bypass_timeout");
  main::deleteLocalConfig("cbpolicyd_bypass_mode");
  main::deleteLocalConfig("cbpolicyd_module_accesscontrol");
  main::deleteLocalConfig("cbpolicyd_module_greylisting");
  main::deleteLocalConfig("cbpolicyd_module_greylisting_training");
  main::deleteLocalConfig("cbpolicyd_module_greylisting_defer_msg");
  main::deleteLocalConfig("cbpolicyd_module_greylisting_blacklist_msg");
  main::deleteLocalConfig("cbpolicyd_module_checkhelo");
  main::deleteLocalConfig("cbpolicyd_module_checkspf");
  main::deleteLocalConfig("cbpolicyd_module_quotas");
  main::deleteLocalConfig("cbpolicyd_module_amavis");
  main::deleteLocalConfig("cbpolicyd_module_accounting");
  main::deleteLocalConfig("postfix_alias_maps");
  main::deleteLocalConfig("postfix_always_add_missing_headers");
  main::deleteLocalConfig("postfix_broken_sasl_auth_clients");
  main::deleteLocalConfig("postfix_bounce_notice_recipient");
  main::deleteLocalConfig("postfix_bounce_queue_lifetime");
  main::deleteLocalConfig("postfix_command_directory");
  main::deleteLocalConfig("postfix_daemon_directory");
  main::deleteLocalConfig("postfix_delay_warning_time");
  main::deleteLocalConfig("postfix_header_checks");
  main::deleteLocalConfig("postfix_in_flow_delay");
  main::deleteLocalConfig("postfix_import_environment");
  main::deleteLocalConfig("postfix_lmtp_connection_cache_destinations");
  main::deleteLocalConfig("postfix_lmtp_connection_cache_time_limit");
  main::deleteLocalConfig("postfix_lmtp_host_lookup");
  main::deleteLocalConfig("postfix_mailq_path");
  main::deleteLocalConfig("postfix_manpage_directory");
  main::deleteLocalConfig("postfix_newaliases_path");
  main::deleteLocalConfig("postfix_queue_directory");
  main::deleteLocalConfig("postfix_sendmail_path");
  main::deleteLocalConfig("postfix_maximal_backoff_time");
  main::deleteLocalConfig("postfix_minimal_backoff_time");
  main::deleteLocalConfig("postfix_queue_run_delay");
  main::deleteLocalConfig("postfix_milter_connect_timeout");
  main::deleteLocalConfig("postfix_milter_command_timeout");
  main::deleteLocalConfig("postfix_milter_content_timeout");
  main::deleteLocalConfig("postfix_milter_default_action");
  main::deleteLocalConfig("postfix_smtp_cname_overrides_servername");
  main::deleteLocalConfig("postfix_smtp_helo_name");
  main::deleteLocalConfig("postfix_smtp_sasl_auth_enable");
  main::deleteLocalConfig("postfix_smtp_tls_security_level");
  main::deleteLocalConfig("postfix_smtp_sasl_mechanism_filter");
  main::deleteLocalConfig("postfix_smtp_sasl_password_maps");
  main::deleteLocalConfig("postfix_policy_time_limit");
  main::deleteLocalConfig("postfix_smtpd_banner");
  main::deleteLocalConfig("postfix_smtpd_proxy_timeout");
  main::deleteLocalConfig("postfix_smtpd_reject_unlisted_recipient");
  main::deleteLocalConfig("postfix_smtpd_reject_unlisted_sender");
  main::deleteLocalConfig("postfix_smtpd_sasl_authenticated_header");
  main::deleteLocalConfig("postfix_smtpd_hard_error_limit");
  main::deleteLocalConfig("postfix_smtpd_soft_error_limit");
  main::deleteLocalConfig("postfix_smtpd_error_sleep_time");
  main::deleteLocalConfig("postfix_smtpd_helo_required");
  main::deleteLocalConfig("postfix_smtpd_tls_loglevel");
  main::deleteLocalConfig("postfix_smtpd_tls_cert_file");
  main::deleteLocalConfig("postfix_smtpd_tls_key_file");
  main::deleteLocalConfig("postfix_virtual_alias_expansion_limit");
  main::deleteLocalConfig("postfix_virtual_transport");
  main::deleteLocalConfig("postfix_notify_classes");
  main::deleteLocalConfig("postfix_propagate_unmatched_extensions");
  main::deleteLocalConfig("postfix_sender_canonical_maps");
  main::deleteLocalConfig("postfix_smtp_sasl_security_options");
  main::deleteLocalConfig("postfix_smtpd_sasl_security_options");
  main::deleteLocalConfig("postfix_smtpd_sasl_tls_security_options");
  main::deleteLocalConfig("postfix_smtpd_client_restrictions");
  main::deleteLocalConfig("postfix_smtpd_data_restrictions");
  main::deleteLocalConfig("postfix_transport_maps");
  main::deleteLocalConfig("postfix_virtual_alias_domains");
  main::deleteLocalConfig("postfix_virtual_alias_maps");
  main::deleteLocalConfig("postfix_virtual_mailbox_domains");
  main::deleteLocalConfig("postfix_virtual_mailbox_maps");
  main::deleteLocalConfig("sasl_smtpd_mech_list");
  main::deleteLocalConfig("cbpolicyd_bind_port");
  main::deleteLocalConfig("cbpolicyd_log_level");
  return 0;
}

sub upgrade850BETA2 {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.5.0_BETA2\n");
  if (main::isInstalled("zimbra-ldap")) {
    if ($isLdapMaster) {
      main::setLdapGlobalConfig("zimbraVersionCheckURL","https://www.zimbra.com/aus/universal/update.php");
    }
  }
  if (main::isInstalled("zimbra-store")) {
    my $zimbra_log_directory = main::getLocalConfig("zimbra_log_directory");
    my $mysql_mycnf = main::getLocalConfig("mysql_mycnf");
    if ( -e ${mysql_mycnf} ) {
      main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-general_log_file-fixup --section=mysqld --set --key=general_log_file --value=${zimbra_log_directory}/mysql-mailboxd.log ${mysql_mycnf}");
    }
    my $mailboxd_java_options=main::getLocalConfigRaw("mailboxd_java_options");
    if ($mailboxd_java_options !~ /-Xloggc/) {
      $mailboxd_java_options .= " -Xloggc:/opt/zimbra/log/gc.log -XX:-UseGCLogFileRotation -XX:NumberOfGCLogFiles=20 -XX:GCLogFileSize=4096K";
      $mailboxd_java_options =~ s/^\s+//;
      main::setLocalConfig("mailboxd_java_options", $mailboxd_java_options);
    }
    if (main::isStoreWebNode()) {
      my @zimbraReverseProxyUpstreamLoginServers=qx($su "$ZMPROV gacf zimbraReverseProxyUpstreamLoginServers");
      if (! grep(/$hn/, @zimbraReverseProxyUpstreamLoginServers)) {
        main::runAsZimbra("$ZMPROV mcf +zimbraReverseProxyUpstreamLoginServers $hn");
      }
    }
  }
  if (main::isInstalled("zimbra-mta")) {
    my $antispam_mysql_mycnf = main::getLocalConfig("antispam_mysql_mycnf");
    my $zimbra_log_directory = main::getLocalConfig("zimbra_log_directory");
    if ( -e ${antispam_mysql_mycnf} ) {
      main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-antispam-general_log_file-fixup --section=mysqld --set --key=general_log_file --value=${zimbra_log_directory}/mysql-antispam.log ${antispam_mysql_mycnf}");
    }
    my @zimbraServiceInstalled=qx($su "$ZMPROV gs $hn zimbraServiceInstalled");
    my @zimbraServiceEnabled=qx($su "$ZMPROV gs $hn zimbraServiceEnabled");
    if (grep(/antivirus/, @zimbraServiceInstalled) || grep(/antispam/, @zimbraServiceInstalled) || grep(/archiving/, @zimbraServiceInstalled)) {
      main::setLdapServerConfig($hn, '+zimbraServiceInstalled', 'amavis');
    }
    if (grep(/antivirus/, @zimbraServiceEnabled) || grep(/antispam/, @zimbraServiceEnabled) || grep(/archiving/, @zimbraServiceEnabled)) {
      main::setLdapServerConfig($hn, '+zimbraServiceEnabled', 'amavis');
    }
    if (-f "/opt/zimbra/conf/sauser.cf") {
      qx(mv /opt/zimbra/conf/sauser.cf /opt/zimbra/data/spamassassin/localrules/sauser.cf);
    }
    if (-f "/opt/zimbra/conf/sa/sauser.cf") {
      qx(mv /opt/zimbra/conf/sa/sauser.cf /opt/zimbra/data/spamassassin/localrules/sauser.cf);
    }
  }
  return 0;
}

sub upgrade850BETA3 {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.5.0_BETA3\n");
  if (main::isInstalled("zimbra-ldap")) {
    if ($isLdapMaster) {
      runLdapAttributeUpgrade("85224");
      runLdapAttributeUpgrade("87674");
      runLdapAttributeUpgrade("88766");
      runLdapAttributeUpgrade("88098");
    }
  }
  if (main::isInstalled("zimbra-store")) {
    if (main::isStoreServiceNode()) {
      my @zimbraReverseProxyAvailableLookupTargets=qx($su "$ZMPROV gacf zimbraReverseProxyAvailableLookupTargets");
      if (! grep(/$hn/, @zimbraReverseProxyAvailableLookupTargets)) {
        main::runAsZimbra("$ZMPROV mcf +zimbraReverseProxyAvailableLookupTargets $hn");
      }
    }
  }
  if (main::isInstalled("zimbra-mta")) {
    my $antispam_mysql_mycnf = main::getLocalConfig("antispam_mysql_mycnf");
    if ( -e ${antispam_mysql_mycnf} ) {
      main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-long-query-time-fixup --section=mysqld --unset --key=long-query-time ${antispam_mysql_mycnf}");
      main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-long_query_time-fixup --section=mysqld --set --key=long_query_time --value=1 ${antispam_mysql_mycnf}");
      main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-log-queries-not-using-indexes-fixup --section=mysqld --unset --key=log-queries-not-using-indexes ${antispam_mysql_mycnf}");
      main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-log_queries_not_using_indexes-fixup --section=mysqld --set --key=log_queries_not_using_indexes ${antispam_mysql_mycnf}");
    }
  }
  return 0;
}

sub upgrade850GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.5.0_GA\n");

  if (main::isInstalled("zimbra-ldap")) {
      main::runAsZimbra("perl -I${scriptDir} ${scriptDir}/migrate20140728-AddSSHA512.pl");
      if ($isLdapMaster) {
        main::runAsZimbra("$ZMPROV mcf +zimbraSpamTrashAlias '/Deleted Messages'");
        main::runAsZimbra("$ZMPROV mcf +zimbraSpamTrashAlias '/Deleted Items'");
      }
  }
  return 0;
}

sub upgrade851GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.5.1_GA\n");
  if (main::isInstalled("zimbra-ldap")) {
    if ($isLdapMaster) {
      my $ldap_pass = qx($su "zmlocalconfig -s -m nokey ldap_root_password");
      chomp($ldap_pass);
      my $ldap;
      unless($ldap = Net::LDAP->new('ldapi://%2fopt%2fzimbra%2fdata%2fldap%2fstate%2frun%2fldapi/')) {
         main::progress("Unable to contact to ldapi: $!\n");
      } else {
        my $result = $ldap->bind("cn=config", password => $ldap_pass);
        $result = $ldap->search(
          base=> "cn=config,cn=zimbra",
          filter=>"(&(objectClass=*)(zimbraDomainMandatoryMailSignatureText=*))",
          scope => "base",
          attrs => ['zimbraDomainMandatoryMailSignatureText', 'zimbraDomainMandatoryMailSignatureHTML'],
        );
        my $totalcount=$result->count;
        if ($totalcount > 0) {
          my $entry=$result->entry($totalcount-1);
          my $text_disclaimer = $entry->get_value("zimbraDomainMandatoryMailSignatureText");
          my $html_disclaimer = $entry->get_value("zimbraDomainMandatoryMailSignatureHTML");
          $result = $ldap->search(
            base=> "",
            filter=>"(objectClass=zimbraDomain)",
            scope => "sub",
          );
          foreach $entry ($result->entries) {
            $result = $ldap->modify(
                $entry->dn,
                add =>{
                    zimbraAmavisDomainDisclaimerText=>$text_disclaimer,
                    zimbraAmavisDomainDisclaimerHTML=>$html_disclaimer,
                },
            );
          }
          $result = $ldap->modify(
            "cn=config,cn=zimbra",
            delete=>['zimbraDomainMandatoryMailSignatureText','zimbraDomainMandatoryMailSignatureHTML']
          );
        }
      }
    }
  }
  return 0;
}

sub upgrade860BETA1 {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.6.0_BETA1\n");
  my $ssl_default_digest = main::getLocalConfig("ssl_default_digest");
  if ($ssl_default_digest eq "sha1") {
      main::setLocalConfig("ssl_default_digest", "sha256");
  }
  if (main::isInstalled("zimbra-snmp")) {
    my $val = main::getLocalConfig("snmp_trap_host");
    if ($val =~ /\@/) {
      $val =~ s/.*\@//;
      main::setLocalConfig("snmp_trap_host", "$val");
    }
  }
  return 0;
}

sub upgrade860BETA2 {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.6.0_BETA2\n");
  if (main::isInstalled("zimbra-ldap")) {
      main::runAsZimbra("perl -I${scriptDir} ${scriptDir}/migrate20141022-AddTLSBits.pl");
  }
  if (main::isInstalled("zimbra-store")) {
      my @zimbraHttpContextPathBasedThreadPoolBalancingFilterRules=qx($su "$ZMPROV gacf zimbraHttpContextPathBasedThreadPoolBalancingFilterRules");
      foreach my $zimbraHttpContextPathBasedThreadPoolBalancingFilterRule (@zimbraHttpContextPathBasedThreadPoolBalancingFilterRules) {
        chomp($zimbraHttpContextPathBasedThreadPoolBalancingFilterRule);
        (my $filterKey, my $filterValue) = split(/:\s/,  $zimbraHttpContextPathBasedThreadPoolBalancingFilterRule);
        if ($filterValue eq "/service:min=10;max=80%") {
          main::runAsZimbra("$ZMPROV mcf -zimbraHttpContextPathBasedThreadPoolBalancingFilterRules '$filterValue'");
          main::runAsZimbra("$ZMPROV mcf +zimbraHttpContextPathBasedThreadPoolBalancingFilterRules '/service:max=80%'");
        }
        elsif ($filterValue eq "/zimbra:min=10;max=15%") {
          main::runAsZimbra("$ZMPROV mcf -zimbraHttpContextPathBasedThreadPoolBalancingFilterRules '$filterValue'");
          main::runAsZimbra("$ZMPROV mcf +zimbraHttpContextPathBasedThreadPoolBalancingFilterRules '/zimbra:max=15%'");
        }
        elsif ($filterValue eq "/zimbraAdmin:min=10;max=5%") {
          main::runAsZimbra("$ZMPROV mcf -zimbraHttpContextPathBasedThreadPoolBalancingFilterRules '$filterValue'");
          main::runAsZimbra("$ZMPROV mcf +zimbraHttpContextPathBasedThreadPoolBalancingFilterRules '/zimbraAdmin:max=5%'");
        }
      }
    }
  return 0;
}

sub upgrade860GA {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.6.0_GA\n");
  if(main::isInstalled("zimbra-ldap")) {
    if ($isLdapMaster) {
      my $mtasmtpdprotocols=main::getLdapConfigValue("zimbraMtaSmtpdTlsProtocols");
      if ($mtasmtpdprotocols eq "") {
        main::runAsZimbra("$ZMPROV mcf zimbraMtaSmtpdTlsProtocols '!SSLv2, !SSLv3'");
      }
    }
  }
  if ( -d "/opt/zimbra/zimlets-deployed/com_zimbra_linkedinimage/") {
    main::runAsZimbra("/opt/zimbra/bin/zmzimletctl -l undeploy com_zimbra_linkedinimage");
  }
  return 0;
}

sub upgrade870BETA1 {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.7.0_BETA1\n");
  if(main::isInstalled("zimbra-ldap")) {
    if ($isLdapMaster) {
      # Bug 99616 - Update olcSpSessionLog
      main::runAsZimbra("perl -I${scriptDir} ${scriptDir}/migrate20150930-AddSyncpovSessionlog.pl");

      # Bug 96921 - Update Jetty default SSL cipher excludes...
      my $sslexcludeciph=main::getLdapConfigValue("zimbraSSLExcludeCipherSuites") || "";
      my $cursslexcl=join(" ", sort split("\n", $sslexcludeciph));
      my $oldsslexcl=join(
        " ",
        sort qw(
          SSL_RSA_WITH_DES_CBC_SHA
          SSL_DHE_RSA_WITH_DES_CBC_SHA
          SSL_DHE_DSS_WITH_DES_CBC_SHA
          SSL_RSA_EXPORT_WITH_RC4_40_MD5
          SSL_RSA_EXPORT_WITH_DES40_CBC_SHA
          SSL_DHE_RSA_EXPORT_WITH_DES40_CBC_SHA
          SSL_DHE_DSS_EXPORT_WITH_DES40_CBC_SHA
        )
      );
      if ($cursslexcl eq $oldsslexcl) {
        main::runAsZimbra("$ZMPROV mcf zimbraSSLExcludeCipherSuites '.*_RC4_.*'");
      }

      # Bug 97332 - Some clients require SSLv2Hello support...
      my $sslprot=main::getLdapConfigValue("zimbraMailboxdSSLProtocols") || "";
      my $cursslprot=join(" ", sort split("\n", $sslprot));
      my $oldsslprot=join(" ", sort qw(TLSv1 TLSv1.1 TLSv1.2));
      if ($cursslprot eq $oldsslprot) {
        main::runAsZimbra("$ZMPROV mcf +zimbraMailboxdSSLProtocols SSLv2Hello");
      }
    }
  }
  if (main::isInstalled("zimbra-proxy")) {
    my $proxysslciphers=main::getLdapConfigValue("zimbraReverseProxySSLCiphers");
    if ($proxysslciphers eq "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:ECDHE-RSA-RC4-SHA:ECDHE-ECDSA-RC4-SHA:AES128:AES256:RC4-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!DES:!3DES:!MD5:!PSK") {
      main::runAsZimbra("$ZMPROV mcf zimbraReverseProxySSLCiphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128:AES256:HIGH:!aNULL:!eNULL:!EXPORT:!DES:!MD5:!PSK:!RC4'");
    }
  }
  if (main::isInstalled("zimbra-store")) {
    my $mailboxd_java_options=main::getLocalConfigRaw("mailboxd_java_options");
    my $new_mailboxd_options = $mailboxd_java_options;
    $new_mailboxd_options =~ s/-XX:(?:Max|)PermSize=\S*\s?//g;
    if ($new_mailboxd_options ne $mailboxd_java_options)
    {
      main::progress("Updating mailboxd_java_options to remove deprecated PermSize and MaxPermSize java options.\n");
      main::setLocalConfig("mailboxd_java_options", $new_mailboxd_options);
    }

    # Bug 80135 - Improved proxy timeout defaults...
    my $proxy_reconnect_timeout = main::getLdapServerValue("zimbraMailProxyReconnectTimeout");
    if ($proxy_reconnect_timeout eq "60")  {
      main::setLdapServerConfig($hn, 'zimbraMailProxyReconnectTimeout', '10');
    }
    # Bug 96857 -  MySQL meta files (pid file, socket, ..) should not be placed in db directory
    unlink("/opt/zimbra/db/mysql.pid") if (-e "/opt/zimbra/db/mysql.pid");
    unlink("/opt/zimbra/db/mysql.sock") if (-e "/opt/zimbra/db/mysql.sock");
  }
  my $localxml = XMLin("/opt/zimbra/conf/localconfig.xml");
  my $lc_attr= $localxml->{key}->{zimbra_class_database}->{value};
  if (defined($lc_attr) && $lc_attr eq "com.zimbra.cs.db.MySQL") {
    main::setLocalConfig("zimbra_class_database", "com.zimbra.cs.db.MariaDB");
  }

  $lc_attr= $localxml->{key}->{short_term_all_effective_rights_cache_expiration}->{value};
  if (defined($lc_attr) && $lc_attr+0 != 50000) {
    main::setLdapServerConfig($hn, 'zimbraShortTermAllEffectiveRightsCacheExpiration', "$lc_attr"."ms");
  }

  $lc_attr= $localxml->{key}->{short_term_all_effective_rights_cache_size}->{value};
  if (defined($lc_attr) && $lc_attr+0 != 128) {
    main::setLdapServerConfig($hn, 'zimbraShortTermAllEffectiveRightsCacheSize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{short_term_grantee_cache_expiration}->{value};
  if (defined($lc_attr) && $lc_attr+0 != 50000) {
    main::setLdapServerConfig($hn, 'zimbraShortTermGranteeCacheExpiration', "$lc_attr"."ms");
  }

  $lc_attr= $localxml->{key}->{short_term_grantee_cache_size}->{value};
  if (defined($lc_attr) && $lc_attr+0 != 128) {
    main::setLdapServerConfig($hn, 'zimbraShortTermGranteeCacheSize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_mailbox_throttle_reap_interval}->{value};
  if (defined($lc_attr) && $lc_attr+0 != 60000) {
    main::setLdapServerConfig($hn, 'zimbraMailboxThrottleReapInterval', "$lc_attr"."ms");
  }

  main::deleteLocalConfig("short_term_all_effective_rights_cache_expiration");
  main::deleteLocalConfig("short_term_all_effective_rights_cache_size");
  main::deleteLocalConfig("short_term_grantee_cache_expiration");
  main::deleteLocalConfig("short_term_grantee_cache_size");
  main::deleteLocalConfig("zimbra_mailbox_throttle_reap_interval");

  return 0;
}

sub upgrade870BETA2 {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 8.7.0_BETA2\n");
  if (main::isInstalled("zimbra-mta")) {
    my $antispam_mysql_mycnf = main::getLocalConfig("antispam_mysql_mycnf");
    if ( -e ${antispam_mysql_mycnf} ) {
      main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-mysql_basedir --section=mysqld --key=basedir --set --value='/opt/zimbra/common' ${antispam_mysql_mycnf}");
      main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-error-log --section=mysqld_safe --key=err-log --unset ${antispam_mysql_mycnf}");
      main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-error-log --section=mysqld_safe --key=log-error --set --value=/opt/zimbra/log/mysqld.log ${antispam_mysql_mycnf}");
    }
    main::setLdapServerConfig($hn, 'zimbraMtaCommandDirectory', "/opt/zimbra/common/sbin");
    main::setLdapServerConfig($hn, 'zimbraMtaDaemonDirectory', "/opt/zimbra/common/libexec");
    main::setLdapServerConfig($hn, 'zimbraMtaMailqPath', "/opt/zimbra/common/sbin/mailq");
    main::setLdapServerConfig($hn, 'zimbraMtaManpageDirectory', "/opt/zimbra/common/share/man");
    main::setLdapServerConfig($hn, 'zimbraMtaNewaliasesPath', "/opt/zimbra/common/sbin/newaliases");
    main::setLdapServerConfig($hn, 'zimbraMtaSendmailPath', "/opt/zimbra/common/sbin/sendmail");
    # Bug 98771 - Add support for DANE
    my $dns_setting = main::getLdapServerValue("zimbraMtaDnsLookupsEnabled");
    if (lc($dns_setting) eq "false")  {
      main::setLdapServerConfig($hn, 'zimbraMtaSmtpDnsSupportLevel', 'disabled');
    }
    # Bug 98072 - We must clear zimbraMtaSenderCanonicalMaps on upgrade
    main::setLdapServerConfig($hn, 'zimbraMtaSenderCanonicalMaps', "");
    main::setLdapGlobalConfig('zimbraMtaSenderCanonicalMaps',"");
    main::runAsZimbra("/opt/zimbra/bin/postconf -e sender_canonical_maps=''");
  }
  if (main::isFoss()) {
    main::setLdapServerConfig($hn, '-zimbraServiceEnabled', 'vmware-ha');
  }

  return 0;
}

sub upgrade900BETA1 {
  my ($startBuild, $targetVersion, $targetBuild) = (@_);
  main::progress("Updating from 9.0.0_BETA1\n");

  if (main::isInstalled("zimbra-ldap")) {
    if ($isLdapMaster) {
      my $ldap_pass = qx($su "zmlocalconfig -s -m nokey ldap_root_password");
      chomp($ldap_pass);
      my $ldap;
      unless($ldap = Net::LDAP->new('ldapi://%2fopt%2fzimbra%2fdata%2fldap%2fstate%2frun%2fldapi/')) {
         main::progress("Unable to contact to ldapi: $!\n");
      } else {
        my $result = $ldap->bind("cn=config", password => $ldap_pass);
        $result = $ldap->search(
          base=> "cn=appaccts,cn=zimbra",
          filter=>"(&(objectClass=zimbraAccount)(uid=zmbes-searcher))",
          scope => "base",
        );
        my $totalcount=$result->count;
        if ($totalcount > 0) {
          $result = $ldap->delete("uid=zmbes-searcher,cn=appaccts,cn=zimbra");
        }
      }
    }
  }

  if (main::isInstalled("zimbra-proxy")) {
    my $memcache_ttl=main::getLdapConfigValue("zimbraReverseProxyCacheEntryTTL");
    if ($memcache_ttl eq "1h") {
      main::runAsZimbra("$ZMPROV mcf zimbraReverseProxyCacheEntryTTL '1m'");
    }
  }

  my $localxml = XMLin("/opt/zimbra/conf/localconfig.xml");
  my $lc_attr= $localxml->{key}->{acl_cache_target_maxsize}->{value};
  if (defined($lc_attr) && $lc_attr != 1024) {
     main::setLdapServerConfig($hn, 'zimbraAdminAclCacheTargetMaxsize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{acl_cache_target_maxage}->{value};
  if (defined($lc_attr) && $lc_attr != 15) {
     main::setLdapServerConfig($hn, 'zimbraAdminAclCacheTargetMaxAge', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{acl_cache_credential_maxsize}->{value};
  if (defined($lc_attr) && $lc_attr != 512) {
     main::setLdapServerConfig($hn, 'zimbraAdminAclCacheCredentialMaxsize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{acl_cache_enabled}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraAdminAclCacheEnabled', "FALSE");
  }

  $lc_attr= $localxml->{key}->{antispam_enable_restarts}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraAntiSpamEnableRestarts', "TRUE");
  }

  $lc_attr= $localxml->{key}->{antispam_enable_rule_updates}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraAntiSpamEnableRuleUpdates', "TRUE");
  }

  $lc_attr= $localxml->{key}->{antispam_enable_rule_compilation}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraAntiSpamEnableRuleCompilation', "TRUE");
  }

  $lc_attr= $localxml->{key}->{calendar_cache_enabled}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraCalendarCacheEnabled', "FALSE");
  }

  $lc_attr= $localxml->{key}->{calendar_cache_lru_size}->{value};
  if (defined($lc_attr) && $lc_attr != 1000) {
     main::setLdapServerConfig($hn, 'zimbraCalendarCacheLRUSize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{calendar_cache_range_month_from}->{value};
  if (defined($lc_attr) && $lc_attr != 0) {
     main::setLdapServerConfig($hn, 'zimbraCalendarCacheRangeMonthFrom', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{calendar_cache_range_months}->{value};
  if (defined($lc_attr) && $lc_attr != 3) {
     main::setLdapServerConfig($hn, 'zimbraCalendarCacheRangeMonths', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{calendar_cache_max_stale_items}->{value};
  if (defined($lc_attr) && $lc_attr != 10) {
     main::setLdapServerConfig($hn, 'zimbraCalendarMaxStaleItems', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{calendar_exchange_form_auth_url}->{value};
  if (defined($lc_attr) && $lc_attr ne "/exchweb/bin/auth/owaauth.dll" ) {
     main::setLdapServerConfig($hn, 'zimbraCalendarExchangeFormAuthURL', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{calendar_item_get_max_retries}->{value};
  if (defined($lc_attr) && $lc_attr != 100) {
     main::setLdapServerConfig($hn, 'zimbraCalendarItemGetMaxRetries', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{calendar_ics_import_full_parse_max_size}->{value};
  if (defined($lc_attr) && $lc_attr != 131072) {
     main::setLdapServerConfig($hn, 'zimbraCalendarIcsImportFullParseMaxSize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{calendar_ics_export_buffer_size}->{value};
  if (defined($lc_attr) && $lc_attr != 131072) {
     main::setLdapServerConfig($hn, 'zimbraCalendarIcsExportBufferSize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{calendar_allow_invite_without_method}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraCalendarAllowInviteWithoutMethod', "TRUE");
  }

  $lc_attr= $localxml->{key}->{calendar_max_desc_in_metadata}->{value};
  if (defined($lc_attr) && $lc_attr != 4096) {
     main::setLdapServerConfig($hn, 'zimbraCalendarMaxDescInMetadata', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{calendar_freebusy_max_days}->{value};
  if (defined($lc_attr) && $lc_attr != 366) {
     main::setLdapServerConfig($hn, 'zimbraCalendarFreeBusyMaxDays', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{calendar_search_max_days}->{value};
  if (defined($lc_attr) && $lc_attr != 400) {
     main::setLdapServerConfig($hn, 'zimbraCalendarSearchMaxDays', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{imap_max_consecutive_error}->{value};
  if (defined($lc_attr) && $lc_attr != 5) {
     main::setLdapServerConfig($hn, 'zimbraImapMaxConsecutiveError', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{imap_inactive_session_cache_size}->{value};
  if (defined($lc_attr) && $lc_attr != 10000) {
     main::setLdapServerConfig($hn, 'zimbraImapInactiveSessionCacheSize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{imap_use_ehcache}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraImapUseEhcache', "FALSE");
  }

  $lc_attr= $localxml->{key}->{imap_write_timeout}->{value};
  if (defined($lc_attr) && $lc_attr != 60) {
     main::setLdapServerConfig($hn, 'zimbraImapWriteTimeout', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{imap_write_chunk_size}->{value};
  if (defined($lc_attr) && $lc_attr != 8192) {
     main::setLdapServerConfig($hn, 'zimbraImapWriteChunkSize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{imap_thread_keep_alive_time}->{value};
  if (defined($lc_attr) && $lc_attr != 60) {
     main::setLdapServerConfig($hn, 'zimbraImapThreadKeepAliveTime', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{imap_max_idle_time}->{value};
  if (defined($lc_attr) && $lc_attr != 60) {
     main::setLdapServerConfig($hn, 'zimbraImapMaxIdleTime', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{imap_authenticated_max_idle_time}->{value};
  if (defined($lc_attr) && $lc_attr != 1800) {
     main::setLdapServerConfig($hn, 'zimbraImapAuthenticatedMaxIdleTime', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{imap_throttle_ip_limit}->{value};
  if (defined($lc_attr) && $lc_attr != 5000) {
     main::setLdapServerConfig($hn, 'zimbraImapThrottleIpLimit', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{imap_throttle_acct_limit}->{value};
  if (defined($lc_attr) && $lc_attr != 5000) {
     main::setLdapServerConfig($hn, 'zimbraImapThrottleAcctLimit', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{imap_throttle_command_limit}->{value};
  if (defined($lc_attr) && $lc_attr != 25) {
     main::setLdapServerConfig($hn, 'zimbraImapThrottleCommandLimit', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{imap_throttle_fetch}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraImapThrottleFetch', "FALSE");
  }

  $lc_attr= $localxml->{key}->{data_source_imap_reuse_connections}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraImapReuseDataSourceConnections', "TRUE");
  }

  $lc_attr= $localxml->{key}->{autoprov_initial_sleep_ms}->{value};
  if (defined($lc_attr) && $lc_attr != 300000) {
     main::setLdapServerConfig($hn, 'zimbraAutoProvInitialSleep', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_admin_service_scheme}->{value};
  if (defined($lc_attr) && $lc_attr ne "https://") {
     main::setLdapServerConfig($hn, 'zimbraAdminServiceScheme', "http://");
  }

  $lc_attr= $localxml->{key}->{calendar_apple_ical_compatible_canceled_instances}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraCalendarAppleICalCompatibleCanceledInstances', "FALSE");
  }

  $lc_attr= $localxml->{key}->{zimbra_admin_waitset_default_request_timeout}->{value};
  if (defined($lc_attr) && $lc_attr != 3000) {
     main::setLdapServerConfig($hn, 'zimbraAdminWaitsetDefaultRequestTimeout', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_admin_waitset_max_request_timeout}->{value};
  if (defined($lc_attr) && $lc_attr != 3600) {
     main::setLdapServerConfig($hn, 'zimbraAdminWaitsetMaxRequestTimeout', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_admin_waitset_min_request_timeout}->{value};
  if (defined($lc_attr) && $lc_attr != 0) {
     main::setLdapServerConfig($hn, 'zimbraAdminWaitsetMinRequestTimeout', "$lc_attr");
  }

   $lc_attr= $localxml->{key}->{zimbra_mailbox_lock_max_waiting_threads}->{value};
  if (defined($lc_attr) && $lc_attr != 15) {
     main::setLdapServerConfig($hn, 'zimbraMailboxLockMaxWaitingThreads', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_mailbox_lock_readwrite}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraMailBoxLockReadWrite', "FALSE");
  }

  $lc_attr= $localxml->{key}->{zimbra_mailbox_lock_timeout}->{value};
  if (defined($lc_attr) && $lc_attr != 60) {
     main::setLdapServerConfig($hn, 'zimbraMailBoxLockTimeout', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_session_limit_admin}->{value};
  if (defined($lc_attr) && $lc_attr != 5) {
     main::setLdapServerConfig($hn, 'zimbraAdminSessionLimit', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_session_limit_imap}->{value};
  if (defined($lc_attr) && $lc_attr != 15) {
     main::setLdapServerConfig($hn, 'zimbraImapSessionLimit', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_session_limit_soap}->{value};
  if (defined($lc_attr) && $lc_attr != 5) {
     main::setLdapServerConfig($hn, 'zimbraSoapSessionLimit', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_session_limit_sync}->{value};
  if (defined($lc_attr) && $lc_attr != 5) {
     main::setLdapServerConfig($hn, 'zimbraSyncSessionLimit', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_session_max_pending_notifications}->{value};
  if (defined($lc_attr) && $lc_attr != 400) {
     main::setLdapServerConfig($hn, 'zimbraSessionMaxPendingNotifications', "$lc_attr");
  }

   $lc_attr= $localxml->{key}->{zimbra_session_timeout_soap}->{value};
  if (defined($lc_attr) && $lc_attr != 600) {
     main::setLdapServerConfig($hn, 'zimbraSoapSessionTimeout', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{calendar_resource_ldap_search_maxsize}->{value};
  if (defined($lc_attr) && $lc_attr != 1000) {
     main::setLdapServerConfig($hn, 'zimbraCalendarResourceLdapSearchMaxSize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{check_dl_membership_enabled}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraDesktopCalendarCheckDLMembership', "FALSE");
  }

  $lc_attr= $localxml->{key}->{ews_service_wsdl_location}->{value};
  if (defined($lc_attr) && $lc_attr ne "/opt/zimbra/lib/ext/zimbraews/") {
     main::setLdapServerConfig($hn, 'zimbraEwsWsdlLocation', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{ews_service_log_file}->{value};
  if (defined($lc_attr) && $lc_attr ne "/opt/zimbra/log/ews.log") {
     main::setLdapServerConfig($hn, 'zimbraEwsServiceLogFile', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{compute_aggregate_quota_threads}->{value};
  if (defined($lc_attr) && $lc_attr != 10) {
     main::setLdapServerConfig($hn, 'zimbraAdminComputeAggregateQuotaThreadPoolSize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{gal_group_cache_maxage}->{value};
  if (defined($lc_attr) && $lc_attr != 10080) {
     main::setLdapServerConfig($hn, 'zimbraGalGroupCacheMaxAge', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{gal_group_cache_maxsize_domains}->{value};
  if (defined($lc_attr) && $lc_attr != 10) {
     main::setLdapServerConfig($hn, 'zimbraGalGroupCacheMaxSizeDomains', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{gal_group_cache_maxsize_per_domain}->{value};
  if (defined($lc_attr) && $lc_attr != 0) {
     main::setLdapServerConfig($hn, 'zimbraGalGroupCacheMaxSizePerDomain', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{external_store_delete_max_ioexceptions}->{value};
  if (defined($lc_attr) && $lc_attr != 25) {
     main::setLdapServerConfig($hn, 'zimbraStoreExternalMaxIOExceptionsForDelete', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{external_store_local_cache_max_bytes}->{value};
  if (defined($lc_attr) && $lc_attr != 1073741824) {
     main::setLdapServerConfig($hn, 'zimbraStoreExternalLocalCacheMaxSize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{external_store_local_cache_max_files}->{value};
  if (defined($lc_attr) && $lc_attr != 10000) {
     main::setLdapServerConfig($hn, 'zimbraStoreExternalLocalCacheMaxFiles', "$lc_attr");
  }

   $lc_attr= $localxml->{key}->{external_store_local_cache_min_lifetime}->{value};
  if (defined($lc_attr) && $lc_attr != 60000) {
     main::setLdapServerConfig($hn, 'zimbraStoreExternalLocalCacheMinLifetime', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{javamail_imap_debug}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraImapEnableDebug', "TRUE");
  }

  $lc_attr= $localxml->{key}->{javamail_imap_enable_starttls}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraImapEnableStartTls', "FALSE");
  }

  $lc_attr= $localxml->{key}->{javamail_imap_timeout}->{value};
  if (defined($lc_attr) && $lc_attr != 60) {
     main::setLdapServerConfig($hn, 'zimbraImapTimeout', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{javamail_pop3_debug}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraPop3EnableDebug', "TRUE");
  }

  $lc_attr= $localxml->{key}->{javamail_pop3_enable_starttls}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraPop3EnableStartTls', "FALSE");
  }

  $lc_attr= $localxml->{key}->{javamail_pop3_timeout}->{value};
  if (defined($lc_attr) && $lc_attr != 60) {
     main::setLdapServerConfig($hn, 'zimbraPop3Timeout', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{javamail_smtp_debug}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraSmtpEnableDebug', "TRUE");
  }

  $lc_attr= $localxml->{key}->{javamail_smtp_enable_starttls}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraSmtpEnableStartTls', "FALSE");
  }

  $lc_attr= $localxml->{key}->{javamail_smtp_timeout}->{value};
  if (defined($lc_attr) && $lc_attr != 60) {
     main::setLdapServerConfig($hn, 'zimbraSmtpTimeout', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{javamail_zsmtp}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraSmtpUseZimbraClient', "FALSE");
  }

  $lc_attr= $localxml->{key}->{mime_encode_missing_blob}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraMimeEncodeMissingBlob', "FALSE");
  }

  $lc_attr= $localxml->{key}->{mime_exclude_empty_content}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraMimeExcludeEmptyContent', "FALSE");
  }

   $lc_attr= $localxml->{key}->{milter_max_idle_time}->{value};
  if (defined($lc_attr) && $lc_attr != 3630) {
     main::setLdapServerConfig($hn, 'zimbraMilterMaxIdleTIme',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{milter_thread_keep_alive_time}->{value};
  if (defined($lc_attr) && $lc_attr != 60) {
     main::setLdapServerConfig($hn, 'zimbraMilterThreadKeepAliveTime', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{milter_write_chunk_size}->{value};
  if (defined($lc_attr) && $lc_attr != 1024) {
     main::setLdapServerConfig($hn, 'zimbraMilterWriteChunkSize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{milter_write_timeout}->{value};
  if (defined($lc_attr) && $lc_attr != 10) {
     main::setLdapServerConfig($hn, 'zimbraMilterWriteTimeout', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_activesync_versions}->{value};
  if (defined($lc_attr) && $lc_attr ne "2.0,2.1,2.5,12.0,12.1") {
     main::setLdapServerConfig($hn, 'zimbraActiveSyncVersions', "$lc_attr");
  }

   $lc_attr= $localxml->{key}->{zimbra_activesync_contact_image_size}->{value};
  if (defined($lc_attr) && $lc_attr != 2097152) {
     main::setLdapServerConfig($hn, 'zimbraActiveSyncContactImageSize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_activesync_autodiscover_url}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "") {
     main::setLdapServerConfig($hn, 'zimbraActiveSyncAutoDiscoveryUrl', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_activesync_autodiscover_use_service_url}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraActiveSyncAutoDiscoverUseServiceUrl', "TRUE");
  }

  $lc_attr= $localxml->{key}->{zimbra_activesync_metadata_cache_expiration}->{value};
  if (defined($lc_attr) && $lc_attr != 3600) {
     main::setLdapServerConfig($hn, 'zimbraActiveSyncMetadataCacheExpiration', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_activesync_metadata_cache_max_size}->{value};
  if (defined($lc_attr) && $lc_attr != 5000) {
     main::setLdapServerConfig($hn, 'zimbraActiveSyncMetadataCacheMaxSize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_activesync_contact_image_size}->{value};
  if (defined($lc_attr) && $lc_attr != 2097152) {
     main::setLdapServerConfig($hn, 'zimbraActiveSyncContactImageSize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_activesync_heartbeat_interval_min}->{value};
  if (defined($lc_attr) && $lc_attr != 300) {
     main::setLdapServerConfig($hn, 'zimbraActiveSyncHeartbeatIntervalMin', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_activesync_heartbeat_interval_max}->{value};
  if (defined($lc_attr) && $lc_attr != 3540) {
     main::setLdapServerConfig($hn, 'zimbraActiveSyncHeartbeatIntervalMax',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_activesync_search_max_results}->{value};
  if (defined($lc_attr) && $lc_attr != 500) {
     main::setLdapServerConfig($hn, 'zimbraActiveSyncSearchMaxResults', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_activesync_general_cache_size}->{value};
  if (defined($lc_attr) && $lc_attr != 500) {
     main::setLdapServerConfig($hn, 'zimbraActiveSyncGeneralCacheSize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_activesync_parallel_sync_enabled}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraActiveSyncParallelSyncEnabled', "TRUE");
  }

  $lc_attr= $localxml->{key}->{zimbra_activesync_syncstate_item_cache_heap_size}->{value};
  if (defined($lc_attr) && $lc_attr ne "10M") {
     main::setLdapServerConfig($hn, 'zimbraActiveSyncSyncStateItemCacheHeapSize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_index_threads}->{value};
  if (defined($lc_attr) && $lc_attr != 10) {
     main::setLdapServerConfig($hn, 'zimbraIndexThreads',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_index_deferred_items_failure_delay}->{value};
  if (defined($lc_attr) && $lc_attr != 300) {
     main::setLdapServerConfig($hn, 'zimbraIndexDeferredItemsFailureDelay',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_index_lucene_io_impl}->{value};
  if (defined($lc_attr) && $lc_attr ne "nio") {
     main::setLdapServerConfig($hn, 'zimbraIndexLuceneIoImpl', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_index_lucene_merge_factor}->{value};
  if (defined($lc_attr) && $lc_attr != 10) {
     main::setLdapServerConfig($hn, 'zimbraIndexLuceneMergeFactor', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_index_manual_commit}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraIndexManualCommit', "FALSE");
  }

  $lc_attr= $localxml->{key}->{zimbra_index_max_transaction_bytes}->{value};
  if (defined($lc_attr) && $lc_attr != 5000000) {
     main::setLdapServerConfig($hn, 'zimbraIndexMaxTransactionBytes', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_index_max_transaction_items}->{value};
  if (defined($lc_attr) && $lc_attr != 100) {
     main::setLdapServerConfig($hn, 'zimbraIndexMaxTransactionItems',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_index_reader_cache_size}->{value};
  if (defined($lc_attr) && $lc_attr != 20) {
     main::setLdapServerConfig($hn, 'zimbraIndexReaderCacheSize',"$lc_attr");
  }

 $lc_attr= $localxml->{key}->{zimbra_index_reader_cache_ttl}->{value};
  if (defined($lc_attr) && $lc_attr != 300) {
     main::setLdapServerConfig($hn, 'zimbraIndexReaderCacheTtl', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_index_disable_perf_counters}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraIndexDisablePerfCounters', "TRUE");
  }

  $lc_attr= $localxml->{key}->{contact_ranking_enabled}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraContactRankingEnabled', "FALSE");
  }

  $lc_attr= $localxml->{key}->{conversation_ignore_maillist_prefix}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraConversationIgnoreMaillistPrefix',"FALSE");
  }

  $lc_attr= $localxml->{key}->{conversation_max_age_ms}->{value};
  if (defined($lc_attr) && $lc_attr != 2678400000) {
     main::setLdapServerConfig($hn, 'zimbraConversationMaxAge',"$lc_attr"."ms");
  }

  $lc_attr= $localxml->{key}->{empty_folder_batch_sleep_ms}->{value};
  if (defined($lc_attr) && $lc_attr != 1) {
     main::setLdapServerConfig($hn, 'zimbraMailboxDeleteFolderThreadSleep',"$lc_attr"."ms");
  }

 $lc_attr= $localxml->{key}->{filter_null_env_sender_for_dsn_redirect}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraFilterNullEnvelopeSenderForDSNRedirect', "FALSE");
  }

  $lc_attr= $localxml->{key}->{freebusy_disable_nodata_status}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraFreeBusyDisableNoDataStatus', "TRUE");
  }

  $lc_attr= $localxml->{key}->{jdbc_results_streaming_enabled}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraMysqlJdbcResultStreamingEnabled', "FALSE");
  }

  $lc_attr= $localxml->{key}->{krb5_debug_enabled}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraKerberosDebugEnabled',"TRUE");
  }

  $lc_attr= $localxml->{key}->{krb5_service_principal_from_interface_address}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraKerobosServicePrincipalFromInterfaceAddress',"TRUE");
  }

   $lc_attr= $localxml->{key}->{lmtp_throttle_ip_limit}->{value};
  if (defined($lc_attr) && $lc_attr != 0) {
     main::setLdapServerConfig($hn, 'zimbraLmtpThrottleIpLimit',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{max_image_size_to_resize}->{value};
  if (defined($lc_attr) && $lc_attr != 10485760) {
     main::setLdapServerConfig($hn, 'zimbraMimeMaxImageSizeToResize',"$lc_attr");
  }

 $lc_attr= $localxml->{key}->{nio_imap_enabled}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraImapNioEnabled', "FALSE");
  }

  $lc_attr= $localxml->{key}->{nio_max_write_queue_size}->{value};
  if (defined($lc_attr) && $lc_attr != 10000) {
     main::setLdapServerConfig($hn, 'zimbraNioMaxWriteQueueSize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{nio_pop3_enabled}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraPop3NioEnabled', "FALSE");
  }

  $lc_attr= $localxml->{key}->{notes_enabled}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraMailNotesEnabled',"TRUE");
  }

  $lc_attr= $localxml->{key}->{pop3_max_consecutive_error}->{value};
  if (defined($lc_attr) && $lc_attr != 5) {
     main::setLdapServerConfig($hn, 'zimbraPop3MaxConsecutiveError',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{pop3_max_idle_time}->{value};
  if (defined($lc_attr) && $lc_attr != 60) {
     main::setLdapServerConfig($hn, 'zimbraPop3MaxIdleTime', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{pop3_write_timeout}->{value};
  if (defined($lc_attr) && $lc_attr != 10) {
     main::setLdapServerConfig($hn, 'zimbraPop3WriteTimeout', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{pop3_thread_keep_alive_time}->{value};
  if (defined($lc_attr) && $lc_attr != 60) {
     main::setLdapServerConfig($hn, 'zimbraPop3ThreadKeepAliveTime', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{pop3_throttle_ip_limit}->{value};
  if (defined($lc_attr) && $lc_attr != 5000) {
     main::setLdapServerConfig($hn, 'zimbraPop3ThrottleIpLimit',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{pop3_throttle_acct_limit}->{value};
  if (defined($lc_attr) && $lc_attr != 5000) {
     main::setLdapServerConfig($hn, 'zimbraPop3ThrottleAcctLimit',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{purge_initial_sleep_ms}->{value};
  if (defined($lc_attr) && $lc_attr != 10) {
     main::setLdapServerConfig($hn, 'zimbraMailboxPurgeInitialSleep', "$lc_attr"."ms");
  }

  $lc_attr= $localxml->{key}->{rest_response_cache_control_value}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "no-store, no-cache") {
     main::setLdapServerConfig($hn, 'zimbraMailboxRestResponseCacheControl', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{search_dbfirst_term_percentage_cutoff}->{value};
  if (defined($lc_attr) && $lc_attr ne "") {
     main::setLdapServerConfig($hn, 'zimbraIndexDbFirstTermCutOffPercentage',"$lc_attr"*100);
  }

  $lc_attr= $localxml->{key}->{search_disable_database_hints}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraIndexDisableDatabaseHints',"TRUE");
  }

  $lc_attr= $localxml->{key}->{search_tagged_item_count_join_query_cutoff}->{value};
  if (defined($lc_attr) && $lc_attr != 1000) {
     main::setLdapServerConfig($hn, 'zimbraIndexTaggedItemCountJoinQueryCutoff', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{servlet_max_concurrent_http_requests_per_account}->{value};
  if (defined($lc_attr) && $lc_attr != 10) {
     main::setLdapServerConfig($hn, 'zimbraMailboxMaxConcurrentHttpRequestsPerAccount', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{servlet_max_concurrent_requests_per_session}->{value};
  if (defined($lc_attr) && $lc_attr != 0) {
     main::setLdapServerConfig($hn, 'zimbraMailboxMaxConcurrentRequestsPerSession', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{smtp_host_retry_millis}->{value};
  if (defined($lc_attr) && $lc_attr != 60000) {
     main::setLdapServerConfig($hn, 'zimbraMailboxSmtpHostRetryWait',"$lc_attr"."ms");
  }

  $lc_attr= $localxml->{key}->{smtp_to_lmtp_enabled}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraMailboxSmtpToLmtpEnabled',"TRUE");
  }

  $lc_attr= $localxml->{key}->{smtp_to_lmtp_port}->{value};
  if (defined($lc_attr) && $lc_attr != 7024) {
     main::setLdapServerConfig($hn, 'zimbraMailboxSmtpToLmtpPort', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{text_attachments_base64}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraMimeOverrideDefaultTransferEncodingToBase64', "FALSE");
  }

  $lc_attr= $localxml->{key}->{thread_pool_warn_percent}->{value};
  if (defined($lc_attr) && $lc_attr != 100) {
     main::setLdapServerConfig($hn, 'zimbraMailboxThreadPoolWarnPercent', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{tombstone_max_age_ms}->{value};
  if (defined($lc_attr) && $lc_attr != 8035200000) {
     main::setLdapServerConfig($hn, 'zimbraMailboxTombstoneMaxAge',"$lc_attr"."ms");
  }

  $lc_attr= $localxml->{key}->{uncompressed_cache_min_lifetime}->{value};
  if (defined($lc_attr) && $lc_attr != 60000) {
     main::setLdapServerConfig($hn, 'zimbraBlobStoreUncompressedCacheMinLifetime',"$lc_attr"."ms");
  }

  $lc_attr= $localxml->{key}->{zimbra_archive_formatter_disable_timeout}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraMailboxArchiveFormatterDisableTimeout',"FALSE");
  }

  $lc_attr= $localxml->{key}->{zimbra_csv_formatter_disable_timeout}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraMailboxCsvFormatterDisableTimeout', "FALSE");
  }

  $lc_attr= $localxml->{key}->{zimbra_archive_formatter_search_chunk_size}->{value};
  if (defined($lc_attr) && $lc_attr != 4096) {
     main::setLdapServerConfig($hn, 'zimbraMailboxArchiveFormatterSearchChunkSize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_auth_provider}->{value};
  if (defined($lc_attr)) {
     main::setLdapServerConfig($hn, 'zimbraAuthProvider',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_authtoken_cache_size}->{value};
  if (defined($lc_attr) && $lc_attr != 5000) {
     main::setLdapServerConfig($hn, 'zimbaAuthTokenCacheSize',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_blob_input_stream_buffer_size_kb}->{value};
  if (defined($lc_attr) && $lc_attr != 1) {
     main::setLdapServerConfig($hn, 'zimbraBlobStoreInputStreamBufferSize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_converter_depth_max}->{value};
  if (defined($lc_attr) && $lc_attr != 100) {
     main::setLdapServerConfig($hn, 'zimbraMimeConverterMaxMimepartDepth', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_converter_enabled_tnef}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraMimeConverterEnabledTnef',"FALSE");
  }

  $lc_attr= $localxml->{key}->{zimbra_converter_enabled_uuencode}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraMimeConverterEnableUuencode',"FALSE");
  }

  $lc_attr= $localxml->{key}->{zimbra_dav_max_idle_time_ms}->{value};
  if (defined($lc_attr) && $lc_attr != 0) {
     main::setLdapServerConfig($hn, 'zimbraMailboxDAVConnectionMaxIdleTime', "$lc_attr"."ms");
  }

  $lc_attr= $localxml->{key}->{zimbra_deregistered_authtoken_queue_size}->{value};
  if (defined($lc_attr) && $lc_attr != 5000) {
     main::setLdapServerConfig($hn, 'zimbraAuthDeregisteredAuthTokenQueueSize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_disk_cache_servlet_flush}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraMailboxDiskCacheFlush', "TRUE");
  }

  $lc_attr= $localxml->{key}->{zimbra_disk_cache_servlet_size}->{value};
  if (defined($lc_attr) && $lc_attr != 1000) {
     main::setLdapServerConfig($hn, 'zimbraMailboxDiskCacheSize',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_enable_text_extraction}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraMimeEnableTextExtraction',"FALSE");
  }

  $lc_attr= $localxml->{key}->{zimbra_ews_autodiscover_use_service_url}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraEwsAutoDiscoverUseServiceUrl', "TRUE");
  }

  $lc_attr= $localxml->{key}->{zimbra_gal_sync_disable_timeout}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraGalSyncConnectionDisableTimout', "FALSE");
  }

  $lc_attr= $localxml->{key}->{zimbra_galsync_index_reader_cache_size}->{value};
  if (defined($lc_attr) && $lc_attr != 5) {
     main::setLdapServerConfig($hn, 'zimbraIndexReaderGalSyncCacheSize',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_index_wildcard_max_terms_expanded}->{value};
  if (defined($lc_attr) && $lc_attr != 20000) {
     main::setLdapServerConfig($hn, 'zimbraIndexWildcardMaxTermsExpanded',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_lmtp_max_line_length}->{value};
  if (defined($lc_attr) && $lc_attr != 10240) {
     main::setLdapServerConfig($hn, 'zimbraLmtpMaxLineLength', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_lmtp_validate_messages}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "TRUE") {
     main::setLdapServerConfig($hn, 'zimbraLmtpValidateMessages', "FALSE");
  }

  $lc_attr= $localxml->{key}->{zimbra_mailbox_active_cache}->{value};
  if (defined($lc_attr) && $lc_attr != 500) {
     main::setLdapServerConfig($hn, 'zimbraMailboxMailItemActiveCache', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_mailbox_change_checkpoint_frequency}->{value};
  if (defined($lc_attr) && $lc_attr != 100) {
     main::setLdapServerConfig($hn, 'zimbraMailboxChangeCheckpointFrequency',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_mailbox_galsync_cache}->{value};
  if (defined($lc_attr) && $lc_attr != 10000) {
     main::setLdapServerConfig($hn, 'zimbraGalSyncMailboxMailItemCache',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_mailbox_inactive_cache}->{value};
  if (defined($lc_attr) && $lc_attr != 30) {
     main::setLdapServerConfig($hn, 'zimbraMailboxMailItemInactiveCache',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_mailbox_manager_hardref_cache}->{value};
  if (defined($lc_attr) && $lc_attr != 2500) {
     main::setLdapServerConfig($hn, 'zimbraMailboxManagerHardrefCache', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_minimize_resources}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraMailboxResourceBundleMinimizeResources', "TRUE");
  }

  $lc_attr= $localxml->{key}->{zimbra_noop_default_timeout}->{value};
  if (defined($lc_attr) && $lc_attr != 300) {
     main::setLdapServerConfig($hn, 'zimbraMailboxNoopDefaultTimeout',"$lc_attr"."s");
  }

  $lc_attr= $localxml->{key}->{zimbra_noop_max_timeout}->{value};
  if (defined($lc_attr) && $lc_attr != 1200) {
     main::setLdapServerConfig($hn, 'zimbraMailboxNoopMaxTimeout', "$lc_attr"."s");
  }

  $lc_attr= $localxml->{key}->{zimbra_noop_min_timeout}->{value};
  if (defined($lc_attr) && $lc_attr != 30) {
     main::setLdapServerConfig($hn, 'zimbraMailboxNoopMinTimeout', "$lc_attr"."s");
  }

  $lc_attr= $localxml->{key}->{zimbra_reindex_threads}->{value};
  if (defined($lc_attr) && $lc_attr != 10) {
     main::setLdapServerConfig($hn, 'zimbraIndexReIndexThreads', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_relative_volume_path}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraMailboxVolumeRelativePath',"TRUE");
  }

  $lc_attr= $localxml->{key}->{zimbra_rights_delegated_admin_supported}->{value};
  if (defined($lc_attr) && lc($lc_attr) ne "true") {
     main::setLdapServerConfig($hn, 'zimbraMailboxRightsDelegatedAdminSupported',"FALSE");
  }

  $lc_attr= $localxml->{key}->{zimbra_slow_logging_enabled}->{value};
  if (defined($lc_attr) && lc($lc_attr) eq "true") {
     main::setLdapServerConfig($hn, 'zimbraMailboxSoapApiSlowLoggingEnabled',"TRUE");
  }

  $lc_attr= $localxml->{key}->{zimbra_slow_logging_threshold}->{value};
  if (defined($lc_attr) && $lc_attr != 5000) {
     main::setLdapServerConfig($hn, 'zimbraMailboxSoapApiSlowLoggingThreshold',"$lc_attr"."ms");
  }

  $lc_attr= $localxml->{key}->{zimbra_spam_report_queue_size}->{value};
  if (defined($lc_attr) && $lc_attr != 100) {
     main::setLdapServerConfig($hn, 'zimbraMailboxSpamHandlerSpamReportQueueSize', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_store_sweeper_max_age}->{value};
  if (defined($lc_attr) && $lc_attr != 480) {
     main::setLdapServerConfig($hn, 'zimbraBlobStoreSweeperMaxAge',"$lc_attr"."m");
  }

  $lc_attr= $localxml->{key}->{zimbra_terms_cachesize}->{value};
  if (defined($lc_attr) && $lc_attr != 1024) {
     main::setLdapServerConfig($hn, 'zimbraIndexTermsCacheSize',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_waitset_default_request_timeout}->{value};
  if (defined($lc_attr) && $lc_attr != 300) {
     main::setLdapServerConfig($hn, 'zimbraMailboxWaitsetDefaultRequestTimeout', "$lc_attr"."s");
  }

  $lc_attr= $localxml->{key}->{zimbra_waitset_initial_sleep_time}->{value};
  if (defined($lc_attr) && $lc_attr != 1000) {
     main::setLdapServerConfig($hn, 'zimbraMailboxWaitsetInitialSleepTime', "$lc_attr"."ms");
  }

  $lc_attr= $localxml->{key}->{zimbra_waitset_max_per_account}->{value};
  if (defined($lc_attr) && $lc_attr != 5) {
     main::setLdapServerConfig($hn, 'zimbraMailboxWaitsetMaxPerAccount', "$lc_attr");
  }

  $lc_attr= $localxml->{key}->{zimbra_waitset_max_request_timeout}->{value};
  if (defined($lc_attr) && $lc_attr != 1200) {
     main::setLdapServerConfig($hn, 'zimbraMailboxWaitsetMaxRequestTimeout',"$lc_attr"."s");
  }

  $lc_attr= $localxml->{key}->{zimbra_waitset_min_request_timeout}->{value};
  if (defined($lc_attr) && $lc_attr != 30) {
     main::setLdapServerConfig($hn, 'zimbraMailboxWaitsetMinRequestTimeout',"$lc_attr"."s");
  }

  $lc_attr= $localxml->{key}->{zimbra_waitset_nodata_sleep_time}->{value};
  if (defined($lc_attr) && $lc_attr != 3000) {
     main::setLdapServerConfig($hn, 'zimbraMailboxWaitsetNoDataSleepTime',"$lc_attr"."ms");
  }

  $lc_attr= $localxml->{key}->{zimlet_deploy_timeout}->{value};
  if (defined($lc_attr) && $lc_attr != 10) {
     main::setLdapServerConfig($hn, 'zimbraZimletDeployTimeout',"$lc_attr"."s");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_account_maxsize}->{value};
  if (defined($lc_attr) && $lc_attr != 20000) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheAccountMaxSize',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_account_maxage}->{value};
  if (defined($lc_attr) && $lc_attr != 15) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheAccountMaxAge',"$lc_attr"."m");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_cos_maxsize}->{value};
  if (defined($lc_attr) && $lc_attr != 100) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheCosMaxSize',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_cos_maxage}->{value};
  if (defined($lc_attr) && $lc_attr != 15) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheCosMaxAge',"$lc_attr"."m");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_share_locator_maxsize}->{value};
  if (defined($lc_attr) && $lc_attr != 5000) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheShareLocatorMaxSize',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_share_locator_maxage}->{value};
  if (defined($lc_attr) && $lc_attr != 15) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheShareLocatorMaxAge',"$lc_attr"."m");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_domain_maxsize}->{value};
  if (defined($lc_attr) && $lc_attr != 500) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheDomainMaxSize',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_domain_maxage}->{value};
  if (defined($lc_attr) && $lc_attr != 15) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheDomainMaxAge',"$lc_attr"."m");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_mime_maxage}->{value};
  if (defined($lc_attr) && $lc_attr != 15) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheMimeTypeInfoMaxAge',"$lc_attr"."m");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_external_domain_maxsize}->{value};
  if (defined($lc_attr) && $lc_attr != 10000) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheExternalDomainMaxSize',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_external_domain_maxage}->{value};
  if (defined($lc_attr) && $lc_attr != 15) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheExternalDomainMaxAge',"$lc_attr"."m");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_group_maxsize}->{value};
  if (defined($lc_attr) && $lc_attr != 2000) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheGroupMaxSize',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_group_maxage}->{value};
  if (defined($lc_attr) && $lc_attr != 15) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheGroupMaxAge',"$lc_attr"."m");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_right_maxsize}->{value};
  if (defined($lc_attr) && $lc_attr != 100) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheRightMaxSize',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_right_maxage}->{value};
  if (defined($lc_attr) && $lc_attr != 15) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheRightMaxAge',"$lc_attr"."m");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_server_maxsize}->{value};
  if (defined($lc_attr) && $lc_attr != 100) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheServerMaxSize',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_server_maxage}->{value};
  if (defined($lc_attr) && $lc_attr != 15) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheServerMaxAge',"$lc_attr"."m");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_ucservice_maxsize}->{value};
  if (defined($lc_attr) && $lc_attr != 100) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheUCServiceMaxSize',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_ucservice_maxage}->{value};
  if (defined($lc_attr) && $lc_attr != 15) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheUCServiceMaxAge',"$lc_attr"."m");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_alwaysoncluster_maxsize}->{value};
  if (defined($lc_attr) && $lc_attr != 100) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheAlwaysOnClusterMaxSize',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_alwaysoncluster_maxage}->{value};
  if (defined($lc_attr) && $lc_attr != 15) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheAlwaysOnClusterMaxAge',"$lc_attr"."m");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_xmppcomponent_maxsize}->{value};
  if (defined($lc_attr) && $lc_attr != 100) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheXMPPComponentMaxSize',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_xmppcomponent_maxage}->{value};
  if (defined($lc_attr) && $lc_attr != 15) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheXMPPComponentMaxAge',"$lc_attr"."m");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_zimlet_maxsize}->{value};
  if (defined($lc_attr) && $lc_attr != 100) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheZimletMaxSize',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_zimlet_maxage}->{value};
  if (defined($lc_attr) && $lc_attr != 15) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheZimletMaxAge',"$lc_attr"."m");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_reverseproxylookup_domain_maxsize}->{value};
  if (defined($lc_attr) && $lc_attr != 100) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheReverseProxyLookupDomainMaxSize',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_reverseproxylookup_domain_maxage}->{value};
  if (defined($lc_attr) && $lc_attr != 15) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheReverseProxyLookupDomainMaxAge',"$lc_attr"."m");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_reverseproxylookup_server_maxsize}->{value};
  if (defined($lc_attr) && $lc_attr != 100) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheReverseProxyLookupServerMaxSize',"$lc_attr");
  }

  $lc_attr= $localxml->{key}->{ldap_cache_reverseproxylookup_server_maxage}->{value};
  if (defined($lc_attr) && $lc_attr != 15) {
     main::setLdapServerConfig($hn, 'zimbraLdapCacheReverseProxyLookupServerMaxAge',"$lc_attr"."m");
  }

  main::deleteLocalConfig("acl_cache_target_maxsize");
  main::deleteLocalConfig("acl_cache_target_maxage");
  main::deleteLocalConfig("acl_cache_credential_maxsize");
  main::deleteLocalConfig("acl_cache_enabled");
  main::deleteLocalConfig("antispam_enable_restarts");
  main::deleteLocalConfig("antispam_enable_rule_updates");
  main::deleteLocalConfig("antispam_enable_rule_compilation");
  main::deleteLocalConfig("antispam_backup_retention");
  main::deleteLocalConfig("calendar_cache_enabled");
  main::deleteLocalConfig("calendar_cache_lru_size");
  main::deleteLocalConfig("calendar_cache_range_month_from");
  main::deleteLocalConfig("calendar_cache_range_months");
  main::deleteLocalConfig("calendar_cache_max_stale_items");
  main::deleteLocalConfig("calendar_exchange_form_auth_url");
  main::deleteLocalConfig("calendar_item_get_max_retries");
  main::deleteLocalConfig("calendar_ics_import_full_parse_max_size");
  main::deleteLocalConfig("calendar_ics_export_buffer_size");
  main::deleteLocalConfig("calendar_allow_invite_without_method");
  main::deleteLocalConfig("calendar_max_desc_in_metadata");
  main::deleteLocalConfig("calendar_freebusy_max_days");
  main::deleteLocalConfig("calendar_search_max_days");
  main::deleteLocalConfig("imap_max_consecutive_error");
  main::deleteLocalConfig("imap_inactive_session_cache_size");
  main::deleteLocalConfig("imap_use_ehcache");
  main::deleteLocalConfig("imap_write_timeout");
  main::deleteLocalConfig("imap_write_chunk_size");
  main::deleteLocalConfig("imap_thread_keep_alive_time");
  main::deleteLocalConfig("imap_max_idle_time");
  main::deleteLocalConfig("imap_authenticated_max_idle_time");
  main::deleteLocalConfig("imap_throttle_ip_limit");
  main::deleteLocalConfig("imap_throttle_acct_limit");
  main::deleteLocalConfig("imap_throttle_command_limit");
  main::deleteLocalConfig("imap_throttle_fetch");
  main::deleteLocalConfig("data_source_imap_reuse_connections");
  main::deleteLocalConfig("autoprov_initial_sleep_ms");
  main::deleteLocalConfig("zimbra_admin_service_scheme");
  main::deleteLocalConfig("calendar_apple_ical_compatible_canceled_instances");
  main::deleteLocalConfig("zimbra_admin_waitset_default_request_timeout");
  main::deleteLocalConfig("zimbra_admin_waitset_max_request_timeout");
  main::deleteLocalConfig("zimbra_admin_waitset_min_request_timeout");
  main::deleteLocalConfig("zimbra_mailbox_lock_max_waiting_threads");
  main::deleteLocalConfig("zimbra_mailbox_lock_readwrite");
  main::deleteLocalConfig("zimbra_mailbox_lock_timeout");
  main::deleteLocalConfig("zimbra_session_limit_admin");
  main::deleteLocalConfig("zimbra_session_limit_imap");
  main::deleteLocalConfig("zimbra_session_limit_soap");
  main::deleteLocalConfig("zimbra_session_limit_sync");
  main::deleteLocalConfig("zimbra_session_max_pending_notifications");
  main::deleteLocalConfig("zimbra_session_timeout_soap");
  main::deleteLocalConfig("calendar_resource_ldap_search_maxsize");
  main::deleteLocalConfig("check_dl_membership_enabled");
  main::deleteLocalConfig("ews_service_wsdl_location");
  main::deleteLocalConfig("ews_service_log_file");
  main::deleteLocalConfig("compute_aggregate_quota_threads");
  main::deleteLocalConfig("gal_group_cache_maxage");
  main::deleteLocalConfig("gal_group_cache_maxsize_domains");
  main::deleteLocalConfig("gal_group_cache_maxsize_per_domain");
  main::deleteLocalConfig("external_store_delete_max_ioexceptions");
  main::deleteLocalConfig("external_store_local_cache_max_bytes");
  main::deleteLocalConfig("external_store_local_cache_max_files");
  main::deleteLocalConfig("external_store_local_cache_min_lifetime");
  main::deleteLocalConfig("javamail_imap_debug");
  main::deleteLocalConfig("javamail_imap_enable_starttls");
  main::deleteLocalConfig("javamail_imap_timeout");
  main::deleteLocalConfig("javamail_pop3_debug");
  main::deleteLocalConfig("javamail_pop3_enable_starttls");
  main::deleteLocalConfig("javamail_pop3_timeout");
  main::deleteLocalConfig("javamail_smtp_debug");
  main::deleteLocalConfig("javamail_smtp_enable_starttls");
  main::deleteLocalConfig("javamail_smtp_timeout");
  main::deleteLocalConfig("javamail_zsmtp");
  main::deleteLocalConfig("mime_encode_missing_blob");
  main::deleteLocalConfig("mime_exclude_empty_content");
  main::deleteLocalConfig("milter_max_idle_time");
  main::deleteLocalConfig("milter_thread_keep_alive_time");
  main::deleteLocalConfig("milter_write_chunk_size");
  main::deleteLocalConfig("milter_write_timeout");
  main::deleteLocalConfig("zimbra_activesync_versions");
  main::deleteLocalConfig("zimbra_activesync_contact_image_size");
  main::deleteLocalConfig("zimbra_activesync_autodiscover_url");
  main::deleteLocalConfig("zimbra_activesync_autodiscover_use_service_url");
  main::deleteLocalConfig("zimbra_activesync_metadata_cache_expiration");
  main::deleteLocalConfig("zimbra_activesync_metadata_cache_max_size");
  main::deleteLocalConfig("zimbra_activesync_heartbeat_interval_min");
  main::deleteLocalConfig("zimbra_activesync_heartbeat_interval_max");
  main::deleteLocalConfig("zimbra_activesync_search_max_results");
  main::deleteLocalConfig("zimbra_activesync_general_cache_size");
  main::deleteLocalConfig("zimbra_activesync_parallel_sync_enabled");
  main::deleteLocalConfig("zimbra_activesync_syncstate_item_cache_heap_size");
  main::deleteLocalConfig("zimbra_index_threads");
  main::deleteLocalConfig("zimbra_index_deferred_items_failure_delay");
  main::deleteLocalConfig("zimbra_index_lucene_io_impl");
  main::deleteLocalConfig("zimbra_index_lucene_merge_factor");
  main::deleteLocalConfig("zimbra_index_manual_commit");
  main::deleteLocalConfig("zimbra_index_max_transaction_bytes");
  main::deleteLocalConfig("zimbra_index_max_transaction_items");
  main::deleteLocalConfig("zimbra_index_reader_cache_size");
  main::deleteLocalConfig("zimbra_index_reader_cache_ttl");
  main::deleteLocalConfig("zimbra_index_disable_perf_counters");
  main::deleteLocalConfig("contact_ranking_enabled");
  main::deleteLocalConfig("conversation_ignore_maillist_prefix");
  main::deleteLocalConfig("conversation_max_age_ms");
  main::deleteLocalConfig("empty_folder_batch_sleep_ms");
  main::deleteLocalConfig("filter_null_env_sender_for_dsn_redirect");
  main::deleteLocalConfig("freebusy_disable_nodata_status");
  main::deleteLocalConfig("jdbc_results_streaming_enabled");
  main::deleteLocalConfig("krb5_debug_enabled");
  main::deleteLocalConfig("krb5_service_principal_from_interface_address");
  main::deleteLocalConfig("lmtp_throttle_ip_limit");
  main::deleteLocalConfig("max_image_size_to_resize");
  main::deleteLocalConfig("nio_imap_enabled");
  main::deleteLocalConfig("nio_max_write_queue_size");
  main::deleteLocalConfig("nio_pop3_enabled");
  main::deleteLocalConfig("notes_enabled");
  main::deleteLocalConfig("pop3_max_consecutive_error");
  main::deleteLocalConfig("pop3_max_idle_time");
  main::deleteLocalConfig("pop3_write_timeout");
  main::deleteLocalConfig("pop3_thread_keep_alive_time");
  main::deleteLocalConfig("pop3_throttle_ip_limit");
  main::deleteLocalConfig("pop3_throttle_acct_limit");
  main::deleteLocalConfig("ldap_bes_searcher_password");
  main::deleteLocalConfig("purge_initial_sleep_ms");
  main::deleteLocalConfig("rest_response_cache_control_value");
  main::deleteLocalConfig("search_dbfirst_term_percentage_cutoff");
  main::deleteLocalConfig("search_disable_database_hints");
  main::deleteLocalConfig("search_tagged_item_count_join_query_cutoff");
  main::deleteLocalConfig("servlet_max_concurrent_http_requests_per_account");
  main::deleteLocalConfig("servlet_max_concurrent_requests_per_session");
  main::deleteLocalConfig("smtp_host_retry_millis");
  main::deleteLocalConfig("smtp_to_lmtp_enabled");
  main::deleteLocalConfig("smtp_to_lmtp_port");
  main::deleteLocalConfig("text_attachments_base64");
  main::deleteLocalConfig("thread_pool_warn_percent");
  main::deleteLocalConfig("tombstone_max_age_ms");
  main::deleteLocalConfig("uncompressed_cache_min_lifetime");
  main::deleteLocalConfig("zimbra_archive_formatter_disable_timeout");
  main::deleteLocalConfig("zimbra_csv_formatter_disable_timeout");
  main::deleteLocalConfig("zimbra_archive_formatter_search_chunk_size");
  main::deleteLocalConfig("zimbra_auth_always_send_refer");
  main::deleteLocalConfig("zimbra_auth_provider");
  main::deleteLocalConfig("zimbra_authtoken_cache_size");
  main::deleteLocalConfig("zimbra_blob_input_stream_buffer_size_kb");
  main::deleteLocalConfig("zimbra_converter_depth_max");
  main::deleteLocalConfig("zimbra_converter_enabled_tnef");
  main::deleteLocalConfig("zimbra_converter_enabled_uuencode");
  main::deleteLocalConfig("zimbra_dav_max_idle_time_ms");
  main::deleteLocalConfig("zimbra_deregistered_authtoken_queue_size");
  main::deleteLocalConfig("zimbra_disk_cache_servlet_flush");
  main::deleteLocalConfig("zimbra_disk_cache_servlet_size");
  main::deleteLocalConfig("zimbra_enable_text_extraction");
  main::deleteLocalConfig("zimbra_ews_autodiscover_use_service_url");
  main::deleteLocalConfig("zimbra_gal_sync_disable_timeout");
  main::deleteLocalConfig("zimbra_galsync_index_reader_cache_size");
  main::deleteLocalConfig("zimbra_index_wildcard_max_terms_expanded");
  main::deleteLocalConfig("zimbra_lmtp_max_line_length");
  main::deleteLocalConfig("zimbra_lmtp_validate_messages");
  main::deleteLocalConfig("zimbra_mailbox_active_cache");
  main::deleteLocalConfig("zimbra_mailbox_change_checkpoint_frequency");
  main::deleteLocalConfig("zimbra_mailbox_galsync_cache");
  main::deleteLocalConfig("zimbra_mailbox_inactive_cache");
  main::deleteLocalConfig("zimbra_mailbox_manager_hardref_cache");
  main::deleteLocalConfig("zimbra_minimize_resources");
  main::deleteLocalConfig("zimbra_noop_default_timeout");
  main::deleteLocalConfig("zimbra_noop_max_timeout");
  main::deleteLocalConfig("zimbra_noop_min_timeout");
  main::deleteLocalConfig("zimbra_reindex_threads");
  main::deleteLocalConfig("zimbra_relative_volume_path");
  main::deleteLocalConfig("zimbra_rights_delegated_admin_supported");
  main::deleteLocalConfig("zimbra_slow_logging_enabled");
  main::deleteLocalConfig("zimbra_slow_logging_threshold");
  main::deleteLocalConfig("zimbra_spam_report_queue_size");
  main::deleteLocalConfig("zimbra_store_sweeper_max_age");
  main::deleteLocalConfig("zimbra_terms_cachesize");
  main::deleteLocalConfig("zimbra_waitset_default_request_timeout");
  main::deleteLocalConfig("zimbra_waitset_initial_sleep_time");
  main::deleteLocalConfig("zimbra_waitset_max_per_account");
  main::deleteLocalConfig("zimbra_waitset_max_request_timeout");
  main::deleteLocalConfig("zimbra_waitset_min_request_timeout");
  main::deleteLocalConfig("zimbra_waitset_nodata_sleep_time");
  main::deleteLocalConfig("zimlet_deploy_timeout");
  main::deleteLocalConfig("ldap_cache_account_maxsize");
  main::deleteLocalConfig("ldap_cache_account_maxage");
  main::deleteLocalConfig("ldap_cache_cos_maxsize");
  main::deleteLocalConfig("ldap_cache_cos_maxage");
  main::deleteLocalConfig("ldap_cache_share_locator_maxsize");
  main::deleteLocalConfig("ldap_cache_share_locator_maxage");
  main::deleteLocalConfig("ldap_cache_domain_maxsize");
  main::deleteLocalConfig("ldap_cache_domain_maxage");
  main::deleteLocalConfig("ldap_cache_mime_maxage");
  main::deleteLocalConfig("ldap_cache_external_domain_maxsize");
  main::deleteLocalConfig("ldap_cache_external_domain_maxage");
  main::deleteLocalConfig("ldap_cache_group_maxsize");
  main::deleteLocalConfig("ldap_cache_group_maxage");
  main::deleteLocalConfig("ldap_cache_right_maxsize");
  main::deleteLocalConfig("ldap_cache_right_maxage");
  main::deleteLocalConfig("ldap_cache_server_maxsize");
  main::deleteLocalConfig("ldap_cache_server_maxage");
  main::deleteLocalConfig("ldap_cache_ucservice_maxsize");
  main::deleteLocalConfig("ldap_cache_ucservice_maxage");
  main::deleteLocalConfig("ldap_cache_alwaysoncluster_maxsize");
  main::deleteLocalConfig("ldap_cache_alwaysoncluster_maxage");
  main::deleteLocalConfig("ldap_cache_xmppcomponent_maxsize");
  main::deleteLocalConfig("ldap_cache_xmppcomponent_maxage");
  main::deleteLocalConfig("ldap_cache_zimlet_maxsize");
  main::deleteLocalConfig("ldap_cache_zimlet_maxage");
  main::deleteLocalConfig("ldap_cache_reverseproxylookup_domain_maxsize");
  main::deleteLocalConfig("ldap_cache_reverseproxylookup_domain_maxage");
  main::deleteLocalConfig("ldap_cache_reverseproxylookup_server_maxsize");
  main::deleteLocalConfig("ldap_cache_reverseproxylookup_server_maxage");
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

sub doMysql55Upgrade {
    my $mysql_mycnf = main::getLocalConfig("mysql_mycnf");
    my $zimbra_log_directory = main::getLocalConfig("zimbra_log_directory") || "/opt/zimbra/log";
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion} --section=mysqld --unset --key=ignore-builtin-innodb ${mysql_mycnf}");
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion} --section=mysqld --unset --key=plugin-load ${mysql_mycnf}");
}

sub doAntiSpamMysql55Upgrade {
    my $antispam_mysql_mycnf = main::getLocalConfig("antispam_mysql_mycnf");
    my $zimbra_log_directory = main::getLocalConfig("zimbra_log_directory") || "/opt/zimbra/log";
    if ( -e ${antispam_mysql_mycnf} ) {
        main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion} --section=mysqld --unset --key=ignore-builtin-innodb ${antispam_mysql_mycnf}");
        main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion} --section=mysqld --unset --key=plugin-load ${antispam_mysql_mycnf}");
    }
}

sub doMysql56Upgrade {
    my $mysql_mycnf = main::getLocalConfig("mysql_mycnf");
    my $zimbra_log_directory = main::getLocalConfig("zimbra_log_directory") || "/opt/zimbra/log";
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-table_cache-fixup --section=mysqld --key=table_cache --unset ${mysql_mycnf}");
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-table_open_cache-fixup --section=mysqld --key=table_open_cache --setmin --value=1200 ${mysql_mycnf}");
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-innodb_data_file_path-fixup --section=mysqld --set --key=innodb_data_file_path --value=ibdata1:10M:autoextend ${mysql_mycnf}");
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-long-query-time-fixup --section=mysqld --unset --key=long-query-time ${mysql_mycnf}");
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-long_query_time-fixup --section=mysqld --set --key=long_query_time --value=1 ${mysql_mycnf}");
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-log-queries-not-using-indexes-fixup --section=mysqld --unset --key=log-queries-not-using-indexes ${mysql_mycnf}");
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-log_queries_not_using_indexes-fixup --section=mysqld --set --key=log_queries_not_using_indexes ${mysql_mycnf}");
}

sub doMariaDB101Upgrade {
    my $mysql_mycnf = main::getLocalConfig("mysql_mycnf");
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-mysql_socket --section=mysqld --key=socket --set --value='/opt/zimbra/data/tmp/mysql/mysql.sock' ${mysql_mycnf}");
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-mysql_pidfile --section=mysqld --key=pid-file --set --value='/opt/zimbra/log/mysql.pid' ${mysql_mycnf}");
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-mysql_pidfile --section=mysqld_safe --key=pid-file --set --value='/opt/zimbra/log/mysql.pid' ${mysql_mycnf}");
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-mysql_basedir --section=mysqld --key=basedir --set --value='/opt/zimbra/common' ${mysql_mycnf}");
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-error-log --section=mysqld_safe --key=err-log --unset ${mysql_mycnf}");
    main::runAsZimbra("/opt/zimbra/libexec/zminiutil --backup=.pre-${targetVersion}-error-log --section=mysqld_safe --key=log-error --set --value=/opt/zimbra/log/mysqld.log ${mysql_mycnf}");
}

sub doMysqlUpgrade {
    my $db_pass = main::getLocalConfig("mysql_root_password");
    my $zimbra_tmp = main::getLocalConfig("zimbra_tmp_directory") || "/tmp";
    my $mysql_socket = main::getLocalConfig("mysql_socket");
    my $mysql_mycnf = main::getLocalConfig("mysql_mycnf");
    my $mysqlUpgrade = "/opt/zimbra/common/bin/mysql_upgrade";
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
    if($upgradeVersion eq "8.7.0_BETA2") {
      if($main::migratedStatus{"LdapUpgraded$upgradeVersion"} ne "CONFIGURED") {
        if (-f '/opt/zimbra/data/ldap/config/cn=config/cn=module{0}.ldif') {
          my $infile="/opt/zimbra/data/ldap/config/cn\=config/cn\=module\{0\}.ldif";
          my $outfile="/tmp/mod0.ldif.$$";
          open(IN,"<$infile");
          open(OUT,">$outfile");
          while(<IN>) {
            if ($_ =~ /^olcModulePath: \/opt\/zimbra\/openldap\/sbin\/openldap/) {
              print OUT "olcModulePath: \/opt\/zimbra\/common\/libexec\/openldap\n";
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
    } elsif($upgradeVersion eq "8.5.0_BETA1") {
      if($main::migratedStatus{"LdapUpgraded$upgradeVersion"} ne "CONFIGURED") {
        unlink("/opt/zimbra/data/ldap/config/cn\=config/cn\=schema/cn\=\{7\}pgp-keyserver.ldif");
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
        if (-f '/opt/zimbra/data/ldap/config/cn=config/cn=module{0}.ldif') {
          my $infile="/opt/zimbra/data/ldap/config/cn\=config/cn\=module\{0\}.ldif";
          my $outfile="/tmp/mod0.ldif.$$";
          open(IN,"<$infile");
          open(OUT,">$outfile");
          while(<IN>) {
            if ($_ =~ /^olcModulePath: \/opt\/zimbra\/openldap\/sbin\/openldap/) {
              print OUT "olcModulePath: \/opt\/zimbra\/common\/libexec\/openldap\n";
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
        unlink("/opt/zimbra/data/ldap/config/cn\=config/cn\=schema/cn\=\{7\}pgp-keyserver.ldif");
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
              if ($_ =~ /^# CRC32/) {
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
              if ($_ =~ /^olcModulePath: \/opt\/zimbra\/openldap\/sbin\/openldap/) {
                print OUT "olcModulePath: \/opt\/zimbra\/common\/libexec\/openldap\n";
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
              if ($_ =~ /^# CRC32/) {
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
              if ($_ =~ /^# CRC32/) {
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

1;
