#!/usr/bin/perl
# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2005, 2006, 2007 Zimbra, Inc.
# 
# The contents of this file are subject to the Yahoo! Public License
# Version 1.0 ("License"); you may not use this file except in
# compliance with the License.  You may obtain a copy of the License at
# http://www.zimbra.com/license.
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied.
# ***** END LICENSE BLOCK *****
# 

use strict;

use lib "/opt/zimbra/libexec";
use lib "/opt/zimbra/zimbramon/lib";
use Zimbra::Util::Common;
use Net::LDAP;
use Cwd;
use Time::localtime;

$|=1; # don't buffer stdout

our $platform = `/opt/zimbra/libexec/get_plat_tag.sh`;
chomp $platform;
our $addr_space = (($platform =~ m/\w+_(\d+)/) ? "$1" : "32");
$addr_space = 32 unless ($addr_space =~ m/32|64/);
my $logfile = "/tmp/zmsetup.".getDateStamp().".log";
open LOGFILE, ">$logfile" or die "Can't open $logfile: $!\n";
unlink("/tmp/zmsetup.log") if (-e "/tmp/zmsetup.log");
symlink($logfile, "/tmp/zmsetup.log");

my $ol = select (LOGFILE);
select ($ol);
$| = 1;

progress("Operations logged to $logfile\n");

our $ZMPROV = "/opt/zimbra/bin/zmprov -l";

if ($platform =~ /MACOSX/) {
  progress ("Checking java version...");
  my $rc = 0xffff & system("su - zimbra -c \"java -version 2>&1 | grep 'java version' | grep -q 1.5\"");
  if ($rc) {
    progress ("\n\nERROR\n\n");
    progress ("Java version 1.5 required - please update your java version\n");
    progress ("and set the default version to be 1.5 before proceeding\n\n");
    ask ("Press any key to exit","");
    exit (1);
  } else {
    progress ("1.5 found\n");
  }
}

use preinstall;
use postinstall;
use zmupgrade;
use Getopt::Std;
use Net::DNS::Resolver;

our %options = ();
our %config = ();
our %loaded = ();
our %saved = ();

my @packageList = (
  "zimbra-core",
  "zimbra-ldap",
  "zimbra-store",
  "zimbra-mta",
  "zimbra-snmp",
  "zimbra-logger",
  "zimbra-apache",
  "zimbra-spell",
  "zimbra-cluster",
  "zimbra-proxy",
  "zimbra-archiving",
);

my %packageServiceMap = (
  antivirus => "zimbra-mta",
  antispam  => "zimbra-mta",
  mta       => "zimbra-mta",
  logger    => "zimbra-logger",
  mailbox   => "zimbra-store",
  snmp      => "zimbra-snmp",
  ldap      => "zimbra-ldap",
  spell     => "zimbra-spell",
  stats     => "zimbra-core",
  imapproxy => "zimbra-proxy",
  archiving => "zimbra-archiving",
);

my %installedPackages = ();
my %prevInstalledPackages = ();
my %enabledPackages = ();
my %enabledServices = ();

my $zimbraHome = "/opt/zimbra";

my %installStatus = ();
my %configStatus = ();

my $prevVersion = "";
our $curVersion = "";
my ($prevVersionMinor,$prevVersionMajor,$prevVersionMicro,$prevVersionBuild);
my ($curVersionMinor,$curVersionMajor,$curVersionMicro,$curVersionBuild);
our $newinstall = 1;

my $ldapConfigured = 0;
my $ldapRunning = 0;
my $sqlConfigured = 0;
my $sqlRunning = 0;
my $loggerSqlConfigured = 0;
my $loggerSqlRunning = 0;
my $installedServiceStr = "";
my $enabledServiceStr = "";

my $ldapRootPassChanged = 0;
my $ldapAdminPassChanged = 0;
my $ldapRepChanged = 0;
my $ldapPostChanged = 0;
my $ldapAmavisChanged = 0;
my $ldapReplica = 0;
my $starttls = 0;
my $needNewCert = "";
my $ssl_cert_type = "self";

my @interfaces = ();

($>) and usage();

getopts("c:hd", \%options) or usage();

my $debug = $options{d};


getInstallStatus();

getInstalledPackages();

if ($0 =~ /testMenu/) {
  #delete $installedPackages{"zimbra-ldap"}; 
  #delete $installedPackages{"zimbra-mta"}; 
  setDefaults();
  mainMenu();
  exit;
}


unless (isEnabled("zimbra-core")) {
  progress("zimbra-core must be enabled.");
  exit 1;
}

if ($options{d}) {
  foreach my $pkg (keys %installedPackages) {
    detail("Package $pkg is installed");
  }
  foreach my $pkg (keys %enabledPackages) {
    detail("Package $pkg is $enabledPackages{$pkg}");
  }     
} 

setDefaults();

if (! $newinstall ) {

  # if we're an upgrade, run the upgrader...
  if (($prevVersion ne $curVersion )) {
    progress ("Upgrading from $prevVersion to $curVersion\n");
    if (zmupgrade::upgrade($prevVersion, $curVersion)){
      progress ("UPGRADE FAILED - exiting\n");
      exit 1;
    } else {
      progress ("Upgrade complete\n");
    }
  }

  setDefaultsFromLocalConfig();
}

setEnabledDependencies();

checkPortConflicts();

getSystemStatus();

if ($ldapConfigured) {
  startLdap();
}

if ($ldapConfigured || 
  (($config{LDAPHOST} ne $config{HOSTNAME}) && !verifyLdap())) {
  setLdapDefaults();
  getAvailableComponents();
}

if ($options{c}) {
  loadConfig ($options{c});
  applyConfig();
} else {
  if ($configStatus{BEGIN} eq "CONFIGURED" &&
    $configStatus{END}  ne "CONFIGURED") {
    resumeConfiguration();
  }
  if (!$newinstall) {
    my $m = createMainMenu();
    if (checkMenuConfig($m)) {
      applyConfig();
    }
  } 
  mainMenu();
}

close LOGFILE;
chmod 0600, $logfile;
if (-d "/opt/zimbra/log") {
  main::progress("Moving $logfile to /opt/zimbra/log\n");
  system("cp -f $logfile /opt/zimbra/log");
}

################################################################
# End Main
################################################################

################################################################
# Subroutines
################################################################

sub usage {
  ($>) and print STDERR "Warning: $0 must be run as root!\n\n";
  print STDERR "Usage: $0 [-h] [-c <config file>]\n";
  print STDERR "\t-h: display this help message\n";
  print STDERR "\t-c: configure with values in <config file>\n\n";
  #print STDERR "\t-l: install license in <license file>\n\n";
  exit 1;
}

sub progress {
  my $msg = shift;
  print $msg;
  my ($sub,$line) = (caller(1))[3,2];
  $msg = "$sub:$line $msg" if $options{d};
  detail ($msg);
}

sub status {
}

sub detail {
  my $msg = shift;
  my ($sub,$line) = (caller(1))[3,2];
  my $date = ctime();
  $msg =~ s/\n$//;
  $msg = "$sub:$line $msg" if $options{d};
  `echo "$date $msg" >> $logfile`;
}

sub saveConfig {
  my $fname = "/opt/zimbra/config.$$";
  if (!(defined ($options{c})) && $newinstall ) {
    $fname = askNonBlank ("Save config in file:", $fname);
  }

  if (open CONF, ">$fname") {
    progress ("Saving config in $fname...");
    foreach (sort keys %config) {
      # Don't write passwords
      if (/PASS/) {next;} 
      print CONF "$_=$config{$_}\n";
    }
    print CONF "INSTALL_PACKAGES=\"";
    foreach (sort keys %installedPackages) {
      print CONF "$_ ";
    }
    print CONF "\"\n";
    close CONF;
    chmod 0600, $fname;
    progress ("done.\n");
  } else {
    progress( "Can't open $fname: $!\n");
  }
}

sub loadConfig {
  my $filename = shift;
  open (CONF, $filename) or die "Can't open $filename: $!";
  my @lines = <CONF>;
  close CONF;
  foreach (@lines) {
    chomp;
    my ($k, $v) = split ('=', $_, 2);
    $config{$k} = $v;
  }

  $config{ALLOWSELFSIGNED} = "true";
}

sub checkPortConflicts {

  if ($platform =~ /MACOSX/) {
    # Shutdown postfix in launchd
    if (-f "/System/Library/LaunchDaemons/org.postfix.master.plist") {
      progress ( "Disabling postfix in launchd\n");
      system ("/bin/launchctl unload -w /System/Library/LaunchDaemons/org.postfix.master.plist");
    }
  }
  progress ( "Checking for port conflicts\n" );
  my %needed = (
    25 => 'zimbra-mta',
    80 => 'zimbra-store',
    110 => 'zimbra-store',
    143 => 'zimbra-store',
    389 => 'zimbra-ldap',
    443 => 'zimbra-store',
    636 => 'zimbra-ldap',
    993 => 'zimbra-store',
    995 => 'zimbra-store',
    7025 => 'zimbra-store',
    7306 => 'zimbra-store',
    7307 => 'zimbra-store',
    7780 => 'zimbra-spell',
    10024 => 'zimbra-mta',
    10025 => 'zimbra-mta',
  );

  open PORTS, "netstat -an | egrep '^tcp' | grep LISTEN | awk '{print \$4}' | sed -e 's/.*://' |";
  my @ports = <PORTS>;
  close PORTS;
  chomp @ports;

  my $any = 0;
  foreach (@ports) {
    if (defined ($needed{$_}) && isEnabled($needed{$_})) {
      # don't report ldap conflicts on upgrade # 14438
      unless ($needed{$_} eq "zimbra-ldap" && $newinstall == 0) {
        $any = 1;
        progress ( "Port conflict detected: $_ ($needed{$_})\n" );
      }
    }
  }

  if (!$options{c}) {
    if ($any) { ask("Port conflicts detected! - Any key to continue", ""); }
  }

}

sub isComponentAvailable {
  my $component = shift;
  detail("checking isComponentAvailable $component");
  # if its already defined return;
  if (exists $main::loaded{components}{$component}) {
    return 1;
  }
  if ($ldapConfigured || 
    (($config{LDAPHOST} ne $config{HOSTNAME}) && !verifyLdap())) {
    getAvailableComponents();
  }
  if (exists $main::loaded{components}{$component}) {
    detail("Component $component is available.");
    return 1;
  } else {
    detail("Component $component is not available.");
    return 0;
  }
  
}

sub getAvailableComponents {
  detail("Getting available components");
  open(ZM, "$ZMPROV gcf zimbraComponentAvailable 2> /dev/null|") or 
    return undef;
  while (<ZM>) {
    chomp;
    if (/^zimbraComponentAvailable: (\S+)/) {
      $main::loaded{components}{$1} = "zimbraComponentAvailable";
    }
  }
  close(ZM) or return undef;
}

sub getDateStamp() {
  my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time());
  $year = 1900+$year;
  $sec = sprintf("%02d", $sec);
  $min = sprintf("%02d", $min);
  $hour = sprintf("%02d", $hour);
  $mday = sprintf("%02d", $mday);
  $mon = sprintf("%02d", $mon+1);
  my $stamp = "$mon$mday$year-$hour$min$sec";
  return $stamp;
}

sub getInstalledPackages {
  detail("Getting installed packages");
  foreach my $p (@packageList) {
    if (isInstalled($p)) {
      $installedPackages{$p} = $p;
    }
  }

  # get list of previously installed packages on upgrade  
  if ($newinstall == 0) {
    $config{zimbra_server_hostname} = getLocalConfig ("zimbra_server_hostname")
      if ($config{zimbra_server_hostname} eq "");
    detail ("DEBUG: zimbra_server_hostname=$config{zimbra_server_hostname}") 
      if $options{d};

    $config{ldap_url} = getLocalConfig ("ldap_url")
      if ($config{ldap_url} eq "");
    detail ("DEBUG: ldap_url=$config{ldap_url}") 
      if $options{d};

    if (index($config{ldap_url}, $config{zimbra_server_hostname}) != -1) {
      detail ("zimbra_server_hostname contained in ldap_url checking ldap status");
      if (startLdap()) {return 1;}
    } else {
      detail ("zimbra_server_hostname not in ldap_url not starting slapd");
    }
    detail("Getting installed services from ldap");
    open(ZMPROV, "$ZMPROV gs $config{zimbra_server_hostname}|");
    while (<ZMPROV>) {
      chomp;
      if (/zimbraServiceInstalled:\s(.*)/) {
        my $service = $1;
        if (exists $packageServiceMap{$service}) {
          detail ("Marking $service as previously installed.")
            if ($debug);
          $prevInstalledPackages{$packageServiceMap{$service}} = "Installed";
        } else {
          progress("WARNING: Unknown package installed for $service.\n");
        }
      } else {
        detail ("DEBUG: skipping not zimbraServiceInstalled =>  $_") if $debug;
      }
    } 
  }
  
}

sub isServiceEnabled {
  my $service = shift;

  if (defined ($enabledServices{$service})) {
    if ($enabledServices{$service} eq "Enabled") {
      detail ("$service is enabled");
      return 1;
    } else {
      detail("$service is not enabled");
      return undef;
    }
  } else {
    detail("$service not in enabled cache");
  }

  return undef;
}

sub isEnabled {
  my $package = shift;
  detail("checking isEnabled $package");
  # if its already defined return;
  if (defined $enabledPackages{$package}) {
    if ($enabledPackages{$package} eq "Enabled") {
      detail("$package is enabled");
      return 1;
    } else {
      detail("$package is not enabled");
      return undef;
    }
  } else {
    detail("$package not in enabled cache");
    my $packages = join(" ", keys %enabledPackages);
    detail("enabled packages $packages");
  }
  

  # lookup service in ldap
  if ($newinstall == 0) {
    $config{zimbra_server_hostname} = getLocalConfig ("zimbra_server_hostname")
      if ($config{zimbra_server_hostname} eq "");
    detail ("DEBUG: zimbra_server_hostname=$config{zimbra_server_hostname}") 
      if $options{d};

    $config{ldap_url} = getLocalConfig ("ldap_url")
      if ($config{ldap_url} eq "");
    detail ("DEBUG: ldap_url=$config{ldap_url}") 
      if $options{d};

    if (index($config{ldap_url}, $config{zimbra_server_hostname}) != -1) {
      detail ("zimbra_server_hostname contained in ldap_url checking ldap status");
      if (startLdap()) {return 1;}
    } else {
      detail ("zimbra_server_hostname not in ldap_url not starting slapd");
    }
    detail("Getting enabled services from ldap");
    $enabledPackages{"zimbra-core"} = "Enabled"
      if (isInstalled("zimbra-core"));

    open(ZMPROV, "$ZMPROV gs $config{zimbra_server_hostname}|");
    while (<ZMPROV>) {
      chomp;
      if (/zimbraServiceEnabled:\s(.*)/) {
        my $service = $1;
        if (exists $packageServiceMap{$service}) {
          detail ("Marking $service as an enabled service.")
            if ($debug);
          $enabledPackages{$packageServiceMap{$service}} = "Enabled";
          $enabledServices{$service} = "Enabled";
        } else {
          progress("WARNING: Unknown package installed for $service.\n");
        }
      } else {
        detail ("DEBUG: skipping not zimbraServiceEnabled => $_") if $debug;
      }
    } 
    foreach my $p (@packageList) {
      if (isInstalled($p) and not defined $prevInstalledPackages{$p}) {
        detail("Marking $p as installed. Services for $p will be enabled.");
        $enabledPackages{$p} = "Enabled";
      } elsif (isInstalled($p) and not defined $enabledPackages{$p}) {
        detail("Marking $p as disabled.");
        $enabledPackages{$p} = "Disabled";
      }
    }
    close(ZMPROV);
  } else {
    detail("Newinstall enabling all installed packages");
    foreach my $p (@packageList) {
      if (isInstalled($p)) {
        unless ($enabledPackages{$p} eq "Disabled") {
          detail("Enabling $p");
          $enabledPackages{$p} = "Enabled" 
        }
      }
    }
  }
  
  $enabledPackages{$package} = "Disabled" 
    if ($enabledPackages{$package} ne "Enabled");

  return ($enabledPackages{$package} eq "Enabled" ? 1 : 0);
}

sub isInstalled {
  my $pkg = shift;

  my $pkgQuery;

  my $good = 0;
  if ($platform eq "DEBIAN3.1" || $platform eq "UBUNTU6" || $platform eq "UBUNTU7" || $platform eq "UBUNTUUNKNOWN" || $platform eq "DEBIAN4.0" || $platform eq "UBUNTU6_64" ) {
    $pkgQuery = "dpkg -s $pkg";
  } elsif ($platform =~ /MACOSX/) {
    my @l = sort glob ("/Library/Receipts/${pkg}*");
    if ( $#l < 0 ) { return 0; }
    $pkgQuery = "test -d $l[$#l]";
  } elsif ($platform =~ /RPL/) {
    $pkgQuery = "conary q $pkg";
  } else {
    $pkgQuery = "rpm -q $pkg";
  }

  my $rc = 0xffff & system ("$pkgQuery > /dev/null 2>&1");
  $rc >>= 8;
  if (($platform eq "DEBIAN3.1" || $platform eq "UBUNTU6" || $platform eq "UBUNTU7" || $platform eq "UBUNTUUNKNOWN" || $platform eq "DEBIAN4.0" || $platform eq "UBUNTU6_64" ) && $rc == 0 ) {
    $good = 1;
    $pkgQuery = "dpkg -s $pkg | egrep '^Status: ' | grep 'not-installed'";
    $rc = 0xffff & system ("$pkgQuery > /dev/null 2>&1");
    $rc >>= 8;
    return ($rc == $good);
  } else {
    return ($rc == $good);
  }
}

sub genRandomPass {
  open RP, "/opt/zimbra/bin/zmjava com.zimbra.common.util.RandomPassword -l 8 10|" or
    die "Can't generate random password: $!\n";
  my $rp = <RP>;
  close RP;
  chomp $rp;
  return $rp;
}

sub getSystemStatus {

  if (isEnabled("zimbra-ldap")) {
    if (-f "$zimbraHome/openldap-data/mail.bdb") {
      $ldapConfigured = 1;
      $ldapRunning = 0xffff & system("/opt/zimbra/bin/ldap status > /dev/null 2>&1");
      if ($ldapRunning) {
        $ldapRunning = 0;
      } else {
        $ldapRunning = 1;
      }
      # Mac on x86 choked on this line?
      #$ldapRunning = ($ldapRunning)?0:1;
    } else {
      $config{DOCREATEDOMAIN} = "yes";
    }
  }

  if (isEnabled("zimbra-store")) {
    if (-d "$zimbraHome/db/data/zimbra") {
      $sqlConfigured = 1;
      $sqlRunning = 0xffff & system("/opt/zimbra/bin/mysqladmin status > /dev/null 2>&1");
      $sqlRunning = ($sqlRunning)?0:1;
    }
    if ($newinstall) {
      $config{DOCREATEADMIN} = "yes";
      $config{DOTRAINSA} = "yes";
    }
  }

  if (isEnabled("zimbra-logger")) {
    if (-d "$zimbraHome/logger/db/data/zimbra_logger") {
      $loggerSqlConfigured = 1;
      $loggerSqlRunning = 0xffff & 
        system("/opt/zimbra/bin/logmysqladmin status > /dev/null 2>&1");
      $loggerSqlRunning = ($loggerSqlRunning)?0:1;
    }
  }

  if (isEnabled("zimbra-mta")) {
    if ($config{SMTPHOST} eq "") {
      $config{SMTPHOST} = $config{HOSTNAME};
    }
  }
}
sub getLdapCOSValue {
  my ($cos,$attrib) = @_;

  return $main::loaded{gc}{$cos}{$attrib} 
    if (exists $main::loaded{gc}{$cos}{$attrib});
  # Gotta love the triple escape: \\\  
  my $rc = 0xffff & system("su - zimbra -c \"$ZMPROV gc $cos | grep $attrib | sed -e \\\"s/${attrib}: //\\\" > /tmp/ld.out\"");
  my $val=`cat /tmp/ld.out`;
  unlink "/tmp/ld.out";
  chomp $val;
  detail ( "COS attribute retrieved for COS $cos: $attrib=$val");

  $main::loaded{gc}{$cos}{$attrib} = $val;

  return $val;
}

sub getLdapConfigValue {
  my $attrib = shift;
  
  return $main::loaded{gcf}{$attrib}
    if (exists $main::loaded{gcf}{$attrib});

  #detail ( "Getting global config attribute $attrib from ldap.\n" );
  # Gotta love the triple escape: \\\  
  my $rc = 0xffff & system("su - zimbra -c \"$ZMPROV gcf $attrib 2> /tmp/ld.err 2> /tmp/ld.err | sed -e \\\"s/${attrib}: //\\\" > /tmp/ld.out\"");
  my $val=`cat /tmp/ld.out`;
  chomp($val);
  detail ("Global config attribute retrieved from ldap: $attrib=$val");
  $main::loaded{gcf}{$attrib} = $val;

  if (!-z "/tmp/ld.err") {
    my $err=`cat /tmp/ld.err`;
    chomp($err);
    #my $level = $val ? "WARNING" : "ERROR";
    #detail ("$level: $ZMPROV gcf $attrib: $err");
  }
  unlink "/tmp/ld.out";
  unlink "/tmp/ld.err";
  return $val;
}

sub getLdapServerValue {
  my $attrib = shift;
  my $hn = shift;
  if ($hn eq "") {
    $hn = $config{HOSTNAME};
  }

  return $main::loaded{gs}{$hn}{$attrib}
    if (exists $main::loaded{gs}{$hn}{$attrib});

  #detail ( "Getting server config attribute $attrib for $hn from ldap." );
  # Gotta love the triple escape: \\\  
  my $rc = 0xffff & system("su - zimbra -c \"$ZMPROV gs $hn | grep $attrib | sed -e \\\"s/${attrib}: //\\\" > /tmp/ld.out\"");
  my $val=`cat /tmp/ld.out`;
  unlink "/tmp/ld.out";
  chomp $val;
  detail("Server config attribute retrieved for $hn: $attrib=$val");
  $main::loaded{gs}{$hn}{$attrib} = $val;

  return $val;
}

sub setLdapDefaults {
  progress ( "Setting defaults from ldap..." );

  # default domainname
  $config{zimbraDefaultDomainName} = getLdapConfigValue("zimbraDefaultDomainName");
  if ($config{zimbraDefaultDomainName} eq "") {
    $config{zimbraDefaultDomainName} = $config{CREATEDOMAIN};
  } else {
    $config{CREATEDOMAIN} = $config{zimbraDefaultDomainName};
    $config{CREATEADMIN} = "admin\@$config{CREATEDOMAIN}";
  }

  $config{IMAPPORT}         = getLdapServerValue("zimbraImapBindPort");
  $config{IMAPSSLPORT}      = getLdapServerValue("zimbraImapSSLBindPort");
  $config{POPPORT}          = getLdapServerValue("zimbraPop3BindPort");
  $config{POPSSLPORT}       = getLdapServerValue("zimbraPop3SSLBindPort");

  $config{IMAPPROXYPORT}    = getLdapServerValue("zimbraImapProxyBindPort");
  $config{IMAPSSLPROXYPORT} = getLdapServerValue("zimbraImapSSLProxyBindPort");
  $config{POPPROXYPORT}     = getLdapServerValue("zimbraPop3ProxyBindPort");
  $config{POPSSLPROXYPORT}  = getLdapServerValue("zimbraPop3SSLProxyBindPort");
  $config{MAILPROXY}        = getLdapServerValue("zimbraReverseProxyMailEnabled");

  $config{MODE}             = getLdapServerValue("zimbraMailMode");
  $config{HTTPPORT}         = getLdapServerValue("zimbraMailPort");
  $config{HTTPSPORT}        = getLdapServerValue("zimbraMailSSLPort");

  $config{HTTPPROXYPORT}    = getLdapServerValue("zimbraMailProxyPort");
  $config{HTTPSPROXYPORT}   = getLdapServerValue("zimbraMailSSLProxyPort");
  $config{HTTPPROXY}        = getLdapServerValue("zimbraReverseProxyHttpEnabled");

  $config{TRAINSASPAM}      = getLdapConfigValue("zimbraSpamIsSpamAccount");
  $config{TRAINSAHAM}       = getLdapConfigValue("zimbraSpamIsNotSpamAccount");
  $config{NOTEBOOKACCOUNT}  = getLdapConfigValue("zimbraNotebookAccount");

  if ($config{HTTPPORT} eq 0) { $config{HTTPPORT} = 80; }
  if ($config{HTTPSPORT} eq 0) { $config{HTTPSPORT} = 443; }
  if ($config{MODE} eq "") { $config{MODE} = "mixed"; }

  if (isEnabled("zimbra-mta")) {
    my $tmpval = getLdapServerValue("zimbraMtaMyNetworks");
    $config{zimbraMtaMyNetworks} = $tmpval
      unless ($tmpval eq "");
  }

  if (isNetwork() && isEnabled("zimbra-store")) {
    $config{zimbraBackupReportEmailRecipients} = getLdapConfigValue("zimbraBackupReportEmailRecipients");
    $config{zimbraBackupReportEmailRecipients} = $config{CREATEADMIN}
      if ($config{zimbraBackupReportEmailRecipients} eq "");

    $config{zimbraBackupReportEmailSender} = getLdapConfigValue("zimbraBackupReportEmailSender");
    $config{zimbraBackupReportEmailSender} = $config{CREATEADMIN}
      if ($config{zimbraBackupReportEmailSender} eq "");
  }
  if (isInstalled("zimbra-proxy") && isEnabled("zimbra-proxy")) {
     if ($config{MAILPROXY} eq "TRUE") {
        if ($config{IMAPPORT} == $config{IMAPPROXYPORT} && $config{IMAPPORT} == 143) {
            $config{IMAPPORT} = 7143;
        }
        if ($config{IMAPSSLPORT} == $config{IMAPSSLPROXYPORT} && $config{IMAPSSLPORT} == 993) {
            $config{IMAPSSLPORT} = 7993;
        }
        if ($config{POPPORT} == $config{POPPROXYPORT} && $config{POPPORT} == 110) {
            $config{POPPORT} = 7110;
        }
        if ($config{POPSSLPORT} == $config{POPSSLPROXYPORT} && $config{POPSSLPORT} == 995) {
            $config{POPSSLPORT} = 7995;
        }
        if ($config{IMAPPORT} == $config{IMAPPROXYPORT} && $config{IMAPPORT} == 7143) {
            $config{IMAPPROXYPORT} = 143;
        }
        if ($config{IMAPSSLPORT} == $config{IMAPSSLPROXYPORT} && $config{IMAPSSLPORT} == 7993) {
            $config{IMAPSSLPROXYPORT} = 993;
        }
        if ($config{POPPORT} == $config{POPPROXYPORT} && $config{POPPORT} == 7110) {
            $config{POPPROXYPORT} = 110;
        }
        if ($config{POPSSLPORT} == $config{POPSSLPROXYPORT} && $config{POPSSLPORT} == 7995) {
            $config{POPSSLPROXYPORT} = 995;
        }
     }
     if ($config{HTTPPROXY} eq "TRUE") {
        if ($config{HTTPPORT} == $config{HTTPPROXYPORT} && $config{HTTPPORT} == 80) {
            $config{HTTPPORT} = 8080;
        }
        if ($config{HTTPSPORT} == $config{HTTPSPROXYPORT} && $config{HTTPSPORT} == 443) {
            $config{HTTPSPORT} = 8443;
        }
        if ($config{HTTPPORT} == $config{HTTPPROXYPORT} && $config{HTTPPORT} == 8080) {
            $config{HTTPPROXYPORT} = 80;
        }
        if ($config{HTTPSPORT} == $config{HTTPSPROXYPORT} && $config{HTTPSPORT} == 8443) {
            $config{HTTPSPROXYPORT} = 443;
        }
     }
  } else {
        if ($config{IMAPPORT} == $config{IMAPPROXYPORT} && $config{IMAPPORT} == 143) {
            $config{IMAPPROXYPORT} = 7143;
        }
        if ($config{IMAPSSLPORT} == $config{IMAPSSLPROXYPORT} && $config{IMAPSSLPORT} == 993) {
            $config{IMAPSSLPROXYPORT} = 7993;
        }
        if ($config{POPPORT} == $config{POPPROXYPORT} && $config{POPPORT} == 110) {
            $config{POPPROXYPORT} = 7110;
        }
        if ($config{POPSSLPORT} == $config{POPSSLPROXYPORT} && $config{POPSSLPORT} == 995) {
            $config{POPSSLPROXYPORT} = 7995;
        }
        if ($config{IMAPPORT} == $config{IMAPPROXYPORT} && $config{IMAPPORT} == 7143) {
            $config{IMAPPORT} = 143;
        }
        if ($config{IMAPSSLPORT} == $config{IMAPSSLPROXYPORT} && $config{IMAPSSLPORT} == 7993) {
            $config{IMAPSSLPORT} = 993;
        }
        if ($config{POPPORT} == $config{POPPROXYPORT} && $config{POPPORT} == 7110) {
            $config{POPPORT} = 110;
        }
        if ($config{POPSSLPORT} == $config{POPSSLPROXYPORT} && $config{POPSSLPORT} == 7995) {
            $config{POPSSLPORT} = 995;
        }
        if ($config{HTTPPORT} == $config{HTTPPROXYPORT} && $config{HTTPPORT} == 80) {
            $config{HTTPPROXYPORT} = 8080;
        }
        if ($config{HTTPSPORT} == $config{HTTPSPROXYPORT} && $config{HTTPSPORT} == 443) {
            $config{HTTPSPROXYPORT} = 8443;
        }
        if ($config{HTTPPORT} == $config{HTTPPROXYPORT} && $config{HTTPPORT} == 8080) {
            $config{HTTPPORT} = 80;
        }
        if ($config{HTTPSPORT} == $config{HTTPSPROXYPORT} && $config{HTTPSPORT} == 8443) {
            $config{HTTPSPORT} = 443;
        }
        $config{MAILPROXY} = "FALSE";
        $config{HTTPPROXY} = "FALSE";
  }
 
  # default values for upgrades 
  $config{NOTEBOOKACCOUNT} = "wiki".'@'.$config{CREATEDOMAIN}
    if ($config{NOTEBOOKACCOUNT} eq "");

  $config{USEKBSHORTCUTS} = getLdapCOSValue("default", "zimbraPrefUseKeyboardShortcuts");

  $config{zimbraPrefTimeZoneId}=getLdapCOSValue("default", "zimbraPrefTimeZoneId");

  if ($prevVersionMajor < 5) {
    $config{zimbraFeatureIMEnabled} = "Disabled";
    $config{zimbraFeatureBriefcasesEnabled} = "Disabled";
    $config{zimbraFeatureTasksEnabled} = "Disabled";
    $config{zimbraFeatureNotebookEnabled} = "Enabled";
  } else {
    $config{zimbraFeatureIMEnabled}=getLdapCOSValue("default", "zimbraFeatureIMEnabled");
    $config{zimbraFeatureIMEnabled}="Enabled"
      if (lc($config{zimbraFeatureIMEnabled}) eq "true");
    $config{zimbraFeatureIMEnabled}="Disabled"
      if (lc($config{zimbraFeatureIMEnabled}) eq "false");
    
    $config{zimbraFeatureTasksEnabled}=getLdapCOSValue("default", "zimbraFeatureTasksEnabled");
    $config{zimbraFeatureTasksEnabled}="Enabled"
      if (lc($config{zimbraFeatureTasksEnabled}) eq "true");
    $config{zimbraFeatureTasksEnabled}="Disabled"
      if (lc($config{zimbraFeatureTasksEnabled}) eq "false");
  
    $config{zimbraFeatureBriefcasesEnabled}=getLdapCOSValue("default", "zimbraFeatureBriefcasesEnabled");
    $config{zimbraFeatureBriefcasesEnabled}="Enabled"
      if (lc($config{zimbraFeatureBriefcasesEnabled}) eq "true");
    $config{zimbraFeatureBriefcasesEnabled}="Disabled"
      if (lc($config{zimbraFeatureBriefcasesEnabled}) eq "false");
  
    $config{zimbraFeatureNotebookEnabled}=getLdapCOSValue("default", "zimbraFeatureNotebookEnabled");
    $config{zimbraFeatureNotebookEnabled}="Enabled"
      if (lc($config{zimbraFeatureNotebookEnabled}) eq "true");
    $config{zimbraFeatureNotebookEnabled}="Disabled"
      if (lc($config{zimbraFeatureNotebookEnabled}) eq "false");
  }
  
  my $smtphost=getLdapServerValue("zimbraSmtpHostname");
  if ( $smtphost ne "") {
    $config{SMTPHOST} = $smtphost;
  }

  my $mtaauthhost=getLdapServerValue("zimbraMtaAuthHost");
  if ( $mtaauthhost ne "") {
    $config{MTAAUTHHOST} = $mtaauthhost;
  }

  if ($options{d}) {
    foreach my $key (sort keys %config) {
      print "\tDEBUG: $key=$config{$key}\n";
    }
  }

  progress ( "done.\n" );
}

sub setDefaults {
  progress ( "Setting defaults..." ) unless $options{d};

  # Get the interfaces.
  # Do this in perl, since it's the same on all platforms.
  open INTS, "/sbin/ifconfig | grep 'inet ' |";
  foreach (<INTS>) {
    chomp;
    s/.*inet //;
    s/\s.*//;
    s/[a-zA-Z:]//g;
    push @interfaces, $_;
  }
  close INTS;
  if (-x "/sbin/ip") {
    open INTS, "/sbin/ip addr| grep 'inet ' |";
    foreach (<INTS>) {
      chomp;
      s/.*inet //;
      s/\s.*//;
      s/\/\d+$//;
      s/[a-zA-Z:]//g;
      push @interfaces, $_;
    }
  close INTS;
  }
  my %seen=();
  @interfaces = grep {!$seen{$_}++} @interfaces;

  $config{EXPANDMENU} = "no";
  $config{REMOVE} = "no";
  $config{UPGRADE} = "yes";
  $config{LDAPPORT} = 389;
  $config{USESPELL} = "no";
  $config{SPELLURL} = "";

  $config{IMAPPORT} = 143;
  $config{IMAPSSLPORT} = 993;
  $config{POPPORT} = 110;
  $config{POPSSLPORT} = 995;
  $config{HTTPPORT} = 80;
  $config{HTTPSPORT} = 443;

  if ($platform =~ /MACOSX/) {
    $config{JAVAHOME} = "/System/Library/Frameworks/JavaVM.framework/Versions/1.5/Home";
    setLocalConfig ("zimbra_java_home", "$config{JAVAHOME}");
    $config{HOSTNAME} = `hostname`;
  } else {
    $config{JAVAHOME} = "/opt/zimbra/java";
    setLocalConfig ("zimbra_java_home", "$config{JAVAHOME}");
    $config{HOSTNAME} = `hostname --fqdn`;
  }
  chomp $config{HOSTNAME};

  $config{ldap_dit_base_dn_config} = "cn=zimbra" 
    if ($config{ldap_dit_base_dn_config} eq "");
  $config{mailboxd_directory} = "/opt/zimbra/mailboxd";
  if ( -f "/opt/zimbra/jetty/start.jar" ) {
    $config{mailboxd_keystore} = "$config{mailboxd_directory}/etc/keystore";
    $config{mailboxd_server} = "jetty";
  } elsif ( -f "/opt/zimbra/tomcat/bin/startup.sh" ) {
    $config{mailboxd_keystore} = "$config{mailboxd_directory}/conf/keystore";
    $config{mailboxd_server} = "tomcat";
  } else {
    $config{mailboxd_keystore} = "/opt/zimbra/conf/keystore";
  }
  if ($platform =~ /MACOSX/) {
      $config{mailboxd_truststore} = "/System/Library/Frameworks/JavaVM.framework/Versions/1.5/Home/lib/security/cacerts";
  } else {
    if ( -f "/opt/zimbra/java/lib/security/cacerts") {
      $config{mailboxd_truststore} = "/opt/zimbra/java/lib/security/cacerts";
    } else {
      $config{mailboxd_truststore} = "/opt/zimbra/java/jre/lib/security/cacerts";
    }
  }
  $config{mailboxd_keystore_password} = genRandomPass();
  $config{mailboxd_truststore_password} = "changeit";
  print "DEBUG: \$config{mailboxd_directory}=$config{mailboxd_directory}\n" if $debug;

  $config{SMTPHOST} = "";
  $config{SNMPTRAPHOST} = $config{HOSTNAME};
  $config{DOCREATEDOMAIN} = "no";
  $config{CREATEDOMAIN} = $config{HOSTNAME};
  $config{DOCREATEADMIN} = "no";

  if (isEnabled("zimbra-cluster")) {
    progress  "setting defaults for zimbra-cluster.\n" if $options{d};
    $config{zimbraClusterType} = "RedHat"; 
  } else {
    $config{zimbraClusterType} = "none";
  }

  if (isEnabled("zimbra-store")) {
    progress  "setting defaults for zimbra-store.\n" if $options{d};
    $config{MTAAUTHHOST} = $config{HOSTNAME};
    $config{DOCREATEADMIN} = "yes" if $newinstall;
    $config{DOTRAINSA} = "yes";

    # default values for upgrades 
    $config{NOTEBOOKACCOUNT} = "wiki".'@'.$config{CREATEDOMAIN}
      if ($config{NOTEBOOKACCOUNT} eq "");

    if ($config{TRAINSASPAM} eq "") {
      $config{TRAINSASPAM} = "spam.".lc(genRandomPass());
      $config{TRAINSASPAM} .= '@'.$config{CREATEDOMAIN};
    }
    if ($config{TRAINSAHAM} eq "") {
      $config{TRAINSAHAM} = "ham.".lc(genRandomPass());
      $config{TRAINSAHAM} .= '@'.$config{CREATEDOMAIN};
    }

    # bug. we shouldn't update this on upgrade.
    $config{NOTEBOOKPASS} = genRandomPass();

    # license files locations this is associated with the store
    # for now as there is a dependancy on the store jar file. 
    $config{DEFAULTLICENSEFILE} = "/opt/zimbra/conf/ZCSLicense.xml" 
      if isNetwork();

    $config{LICENSEFILE} = $config{DEFAULTLICENSEFILE}
      if (-f "$config{DEFAULTLICENSEFILE}" && isNetwork());

    if (!$newinstall) {
      $config{zimbraFeatureIMEnabled} = "Disabled"
        if ($config{zimbraFeatureIMEnabled} eq "");
      $config{zimbraFeatureBriefcasesEnabled} = "Disabled"
        if ($config{zimbraFeatureBriefcasesEnabled} eq "");
      $config{zimbraFeatureTasksEnabled} = "Disabled"
        if ($config{zimbraFeatureTasksEnabled} eq "");
      $config{zimbraFeatureNotebookEnabled} = "Enabled"
        if ($config{zimbraFeatureNotebookEnabled} eq "");
    } else {
      $config{zimbraFeatureIMEnabled} = "Disabled"
        if ($config{zimbraFeatureIMEnabled} eq "");
      $config{zimbraFeatureNotebookEnabled} = "Enabled"
        if ($config{zimbraFeatureNotebookEnabled} eq "");
      $config{zimbraFeatureBriefcasesEnabled} = "Enabled"
        if ($config{zimbraFeatureBriefcasesEnabled} eq "");
      $config{zimbraFeatureTasksEnabled} = "Enabled"
        if ($config{zimbraFeatureTasksEnabled} eq "");
    }

  }

  if (isEnabled("zimbra-ldap")) {
    progress "setting defaults for zimbra-ldap.\n" if $options{d};
    $config{DOCREATEDOMAIN} = "yes" if $newinstall;
    $config{LDAPROOTPASS} = genRandomPass();
    $config{LDAPADMINPASS} = $config{LDAPROOTPASS};
    $config{LDAPREPPASS} =  $config{LDAPADMINPASS};
    $config{LDAPPOSTPASS} = $config{LDAPADMINPASS};
    $config{LDAPAMAVISPASS} =  $config{LDAPADMINPASS};
    $ldapRepChanged = 1;
    $ldapPostChanged = 1;
    $ldapAmavisChanged = 1;
  }

  $config{CREATEADMIN} = "admin\@$config{CREATEDOMAIN}";

  $config{zimbraPrefTimeZoneId} = '(GMT-08.00) Pacific Time (US & Canada)';

  $config{zimbra_ldap_userdn} = "uid=zimbra,cn=admins,$config{ldap_dit_base_dn_config}";

  $config{SMTPSOURCE} = $config{CREATEADMIN};
  $config{SMTPDEST} = $config{CREATEADMIN};
  $config{AVUSER} = $config{CREATEADMIN};
  $config{SNMPNOTIFY} = "yes";
  $config{SMTPNOTIFY} = "yes";
  $config{STARTSERVERS} = "yes";

  if (isEnabled("zimbra-store") && isNetwork()) {
    $config{zimbraBackupReportEmailRecipients} = $config{CREATEADMIN};
    $config{zimbraBackupReportEmailSender} = $config{CREATEADMIN};
  }

  if (isEnabled("zimbra-mta")) {
    progress  "setting defaults for zimbra-mta.\n" if $options{d};
    my $tmpval = (`su - zimbra -c "/opt/zimbra/postfix/sbin/postconf mynetworks"`);
    chomp($tmpval);
    $tmpval =~ s/mynetworks = //;
    if ($tmpval eq "") {
      $config{zimbraMtaMyNetworks} = "127.0.0.0/8 @interfaces";
    } else {
      $config{zimbraMtaMyNetworks} = "$tmpval";
    }

    if ($platform eq "MACOSXx86_10.5") {
      $config{postfix_mail_owner} = "_postfix";
      $config{postfix_setgid_group} = "_postdrop";
    } else {
      $config{postfix_mail_owner} = "postfix";
      $config{postfix_setgid_group} = "postdrop";
    }
  }

  $config{MODE} = "http";

  $config{SYSTEMMEMORY} = getSystemMemory();
  $config{MYSQLMEMORYPERCENT} = mysqlMemoryPercent($config{SYSTEMMEMORY});
  $config{MAILBOXDMEMORYPERCENT} = mailboxdMemoryPercent($config{SYSTEMMEMORY});

  $config{CREATEADMINPASS} = "" unless ($config{CREATEADMINPASS});

  if (!$options{c} && $newinstall) {
    progress "no config file and newinstall checking dns resolution\n" if $options{d};

    if (lookupHostName ($config{HOSTNAME}, 'A')) {
      progress("\n\nDNS ERROR resolving $config{HOSTNAME}\n");
      progress("It is suggested that the hostname be resolveable via DNS\n");
      if (askYN("Change hostname","Yes") eq "yes") {
        setHostName();
      }
    }

    my $good = 0;

    if ($config{DOCREATEDOMAIN} = "yes") {
      my $ans = getDnsRecords($config{CREATEDOMAIN}, 'MX');
      if (!defined($ans)) {
        progress("\n\nDNS ERROR resolving MX for $config{CREATEDOMAIN}\n");
        progress("It is suggested that the domain name have an MX record configured in DNS\n");
        if (askYN("Change domain name?","Yes") eq "yes") {
          setCreateDomain();
        }
      } elsif (isEnabled("zimbra-mta")) {

        my @answer = $ans->answer;
        foreach my $a (@answer) {
          if ($a->type eq "MX") {
            my $h = getDnsRecords ($a->exchange,'A');
            if (defined $h) {
              my @ha = $h->answer;
              foreach $h (@ha) {
                if ($h->type eq 'A') {
                  progress "\tMX: ".$a->exchange." (".$h->address.")\n";
                }
              }
            } else {
              progress "\n\nDNS ERROR - No A record for $config{CREATEDOMAIN}.\n";
            }
          }
        }
        progress "\n";
        foreach my $i (@interfaces) {
          progress "\tInterface: $i\n";
        }
        foreach my $a (@answer) {
          foreach my $i (@interfaces) {
            if ($a->type eq "MX") {
              my $h = getDnsRecords ($a->exchange,'A');
              if (defined $h) {
                my @ha = $h->answer;
                foreach $h (@ha) {
                  if ($h->type eq 'A') {
                    print "\t\t".$h->address."\n";
                    if ($h->address eq $i) {
                      $good = 1;
                      last;
                    }
                  }
                }
                if ($good) { last; }
              }
            }
          }
          if ($good) {last;}
        }
        if (!$good) { 
          progress ("\n\nDNS ERROR - none of the MX records for $config{CREATEDOMAIN}\n");
          progress ("resolve to this host\n");
          if (askYN("Change domain name?","Yes") eq "yes") {
            setCreateDomain();
          }
        }

      }
    }

  }
  if (isInstalled("zimbra-proxy")) {
    progress  "setting defaults for zimbra-proxy.\n" if $options{d};
    $config{IMAPPROXYPORT} = 143;
    $config{IMAPSSLPROXYPORT} = 993;
    $config{POPPROXYPORT} = 110;
    $config{POPSSLPROXYPORT} = 995;
    $config{IMAPPORT} = 7143;
    $config{IMAPSSLPORT} = 7993;
    $config{POPPORT} = 7110;
    $config{POPSSLPORT} = 7995;
    $config{MAILPROXY} = "TRUE";
    $config{HTTPPROXY} = "FALSE";
    $config{HTTPPROXYPORT} = 8080;
    $config{HTTPSPROXYPORT} = 8443;
    $config{HTTPPORT} = 80;
    $config{HTTPSPORT} = 443;
  } else {
    $config{IMAPPROXYPORT} = 7143;
    $config{IMAPSSLPROXYPORT} = 7993;
    $config{POPPROXYPORT} = 7110;
    $config{POPSSLPROXYPORT} = 7995;
    $config{MAILPROXY} = "FALSE";
    $config{HTTPPROXY} = "FALSE";
    $config{HTTPPROXYPORT} = 8080;
    $config{HTTPSPROXYPORT} = 8443;
  }
 
  if ($options{d}) {
    foreach my $key (sort keys %config) {
      print "\tDEBUG: $key=$config{$key}\n";
    }
  }

  progress ( "done.\n" );
}

sub getInstallStatus {
  progress "getting install status..." if $options{d};

  if (open H, "/opt/zimbra/.install_history") {

    my @history = <H>;
    close H;
    foreach my $h (@history) {
      if ($h =~ /CONFIG SESSION COMPLETE/) {
        next;
      }
      if ($h =~ /CONFIG SESSION START/) {
        %configStatus = ();
        next;
      }
      if ($h =~ /INSTALL SESSION COMPLETE/) {
        next;
      }
      if ($h =~ /INSTALL SESSION START/) {
        %installStatus = ();
        %configStatus = ();
        next;
      }
      my ($d, $op, $stage) = split ' ', $h;
      if ($op eq "INSTALLED" || $op eq "UPGRADED") {
        my $v = $stage;
        $stage =~ s/[-_]\d.*//;
        $installStatus{$stage}{op} = $op;
        $installStatus{$stage}{date} = $d;
        if ($stage eq "zimbra-core") {
          #$prevVersion = $curVersion;
          $v =~ s/_HEAD.*//;
          $v =~ s/^zimbra-core[-_]//;
          $v =~ s/^(\d+\.\d+\.[^_]*_[^_]+_[^.]+).*/\1/;
          $curVersion = $v;
        }
      } elsif ($op eq "CONFIGURED") {
        $configStatus{$stage} = $op;
        if ($stage eq "END") {
          $prevVersion = $curVersion;
        }
      }
    }

    if ( ($installStatus{"zimbra-core"}{op} eq "INSTALLED") &&
      ($configStatus{"END"} ne "CONFIGURED") ){
      $newinstall = 1;
    } else {
      $newinstall = 0;
      #$config{DOCREATEDOMAIN} = "no";
      #$config{DOCREATEADMIN} = "no";
      #setDefaultsFromLocalConfig();
    }
  } else {
    $newinstall = 1;
  }

  ($prevVersionMajor,$prevVersionMinor,$prevVersionMicro,$prevVersionBuild) = 
    $prevVersion =~ /(\d+)\.(\d+)\.(\d+_[^_]*)_(\d+)/;
  ($curVersionMajor,$curVersionMinor,$curVersionMicro,$curVersionBuild) = 
    $curVersion =~ /(\d+)\.(\d+)\.(\d+_[^_]*)_(\d+)/;

  if ($options{d}) {
    progress "done.\n";
    progress "Previous version  maj:$prevVersionMajor minor:$prevVersionMinor micro:$prevVersionMicro build:$prevVersionBuild\n";
    progress "Current version  maj:$curVersionMajor minor:$curVersionMinor micro:$curVersionMicro build:$curVersionBuild\n";
  }
}

sub setDefaultsFromLocalConfig {
  progress ("Setting defaults from existing config...");
  $config{HOSTNAME} = getLocalConfig ("zimbra_server_hostname");
  $config{HOSTNAME} = lc ($config{HOSTNAME});
  my $ldapUrl = getLocalConfig ("ldap_master_url");
  my $ld = (split ' ', $ldapUrl)[0];
  my $p = $ld;
  $p =~ s/ldaps?:\/\///;
  $p =~ s/.*:?//;
  if ($p ne "") {
    $config{LDAPPORT} = $p;
  } else {
    $p = getLocalConfig ("ldap_port");
    if ($p ne "") {
      $config{LDAPPORT} = $p;
    }
  }
  my $h = $ld;
  $h =~ s/ldaps?:\/\///;
  $h =~ s/:\d*$//;
  if ($h ne "") {
    $config{LDAPHOST} = $h;
  } else {
    $h = getLocalConfig ("ldap_host");
    if ($h ne "") {
      $config{LDAPHOST} = $h;
    }
  }
  $config{LDAPROOTPASS} = getLocalConfig ("ldap_root_password");
  $config{LDAPADMINPASS} = getLocalConfig ("zimbra_ldap_password");
  $config{SQLROOTPASS} = getLocalConfig ("mysql_root_password");
  $config{LOGSQLROOTPASS} = getLocalConfig ("mysql_logger_root_password");
  $config{ZIMBRASQLPASS} = getLocalConfig ("zimbra_mysql_password");
  $config{ZIMBRALOGSQLPASS} = getLocalConfig ("zimbra_logger_mysql_password");
  $config{MAILBOXDMEMORYPERCENT} = getLocalConfig ("mailboxd_java_heap_memory_percent");
  $config{MYSQLMEMORYPERCENT} = getLocalConfig ("mysql_memory_percent");
  $config{mailboxd_directory} = getLocalConfig("mailboxd_directory");
  $config{mailboxd_keystore} = getLocalConfig("mailboxd_keystore");
  $config{mailboxd_keystore_password} = getLocalConfig ("mailboxd_keystore_password")
    if (getLocalConfig("mailboxd_keystore_password") ne "");
  $config{mailboxd_truststore_password} = getLocalConfig ("mailboxd_truststore_password") 
    if (getLocalConfig("mailboxd_truststore_password") ne "");
  $config{zimbra_ldap_userdn} = getLocalConfig("zimbra_ldap_userdn")
    if (getLocalConfig("zimbra_ldap_userdn") ne "");

  $config{ldap_dit_base_dn_config} = getLocalConfig("ldap_dit_base_dn_config");
  $config{ldap_dit_base_dn_config} = "cn=zimbra" 
    if ($config{ldap_dit_base_dn_config} eq "");

  if (isEnabled("zimbra-snmp")) {
    $config{SNMPNOTIFY} = getLocalConfig("snmp_notify");
    $config{SNMPNOTIFY} = "yes" if ($config{SNMPNOTIFY} eq "");

    $config{SMTPNOTIFY} = getLocalConfig("smtp_notify");
    $config{SMTPNOTIFY} = "yes" if ($config{SNMPNOTIFY} eq "");

    $config{SNMPTRAPHOST} = getLocalConfig("snmp_trap_host");
    $config{SNMPTRAPHOST} = $config{CREATEADMIN}
      if ($config{SNMPTRAPHOST} eq "");
  }

  $config{SMTPSOURCE} = getLocalConfig("smtp_source");
  $config{SMTPSOURCE} = $config{CREATEADMIN}
    if ($config{SMTPSOURCE} eq "");

  $config{SMTPDEST} = getLocalConfig("smtp_destination");
  $config{SMTPDEST} = $config{CREATEADMIN}
    if ($config{SMTPDEST} eq "");

  $config{AVUSER} = getLocalConfig("av_notify_user");
  $config{AVUSER} = $config{CREATEADMIN}
    if ($config{AVUSER} eq "");

  if (isEnabled("zimbra-mta")) {
    $config{postfix_mail_owner} = getLocalConfig ("postfix_mail_owner");
    if ($config{postfix_mail_owner} eq "") {
      if ($platform eq "MACOSXx86_10.5") {
        $config{postfix_mail_owner} = "_postfix";
      } else {
        $config{postfix_mail_owner} = "postfix";
      }
    }
    $config{postfix_setgid_group} = getLocalConfig ("postfix_setgid_group");
    if ($config{postfix_setgid_group} eq "") {
      if ($platform eq "MACOSXx86_10.5") {
        $config{postfix_setgid_group} = "_postdrop";
      } else {
        $config{postfix_setgid_group} = "postdrop";
      }
    }

  }

  if (isEnabled("zimbra-ldap")) {
    $config{LDAPREPPASS} = getLocalConfig ("ldap_replication_password");
    if ($config{LDAPREPPASS} eq "") {
      $config{LDAPREPPASS} = $config{LDAPADMINPASS};
      $ldapRepChanged = 1;
    }
  } 
  if (isEnabled("zimbra-ldap") || isEnabled("zimbra-mta")) {
    $config{LDAPPOSTPASS} = getLocalConfig ("ldap_postfix_password");
    if ($config{LDAPPOSTPASS} eq "") {
      $config{LDAPPOSTPASS} = $config{LDAPADMINPASS};
      $ldapPostChanged = 1;
    }
    $config{LDAPAMAVISPASS} = getLocalConfig ("ldap_amavis_password");
    if ($config{LDAPAMAVISPASS} eq "") {
      $config{LDAPAMAVISPASS} = $config{LDAPADMINPASS};
      $ldapAmavisChanged = 1;
    }
  }

  if ($options{d}) {
    foreach my $key (sort keys %config) {
      print "\tlc DEBUG: $key=$config{$key}\n";
    }
  }
  progress("done.\n");
}

sub ask {
  my $prompt = shift;
  my $default = shift;
  if ($default eq "") {
    print "$prompt ";
  } else {
    print "$prompt [$default] ";
  }
  my $rc = <>;
  chomp $rc;
  if ($rc eq "") {return $default;}
  return $rc;
}

sub askYN {
  my $prompt = shift;
  my $default = shift;
  while (1) {
    my $v = ask($prompt, $default);
    $v = lc($v);
    $v = substr ($v,0,1);
    if ($v eq "y") {return "yes";}
    if ($v eq "n") {return "no";}
    print "A Yes/No answer is required\n";
  }
}

sub askTF {
  my $prompt = shift;
  my $default = shift;
  while (1) {
    my $v = ask($prompt, $default);
    $v = lc($v);
    $v = substr ($v,0,1);
    if ($v eq "t") {return "TRUE";}
    if ($v eq "f") {return "FALSE";}
    print "A True/False answer is required\n";
  }
}

sub askNum {
  my $prompt = shift;
  my $default = shift;
  while (1) {
    my $v = ask($prompt, $default);
    my $i = int($v);
    if ($v eq $i) { return $v; }
    print "A numeric response is required!\n";
  }
}

sub askNonBlank {
  my $prompt = shift;
  my $default = shift;
  while (1) {
    my $v = ask($prompt, $default);
    if ($v ne "") {return $v;}
    print "A non-blank answer is required\n";
  }
}

sub askFileName {
  my $prompt = shift;
  my $default = shift;
  while (1) {
    my $v = ask($prompt, $default);
    if ($v ne "" && -f $v) {return $v;}
    print "A non-blank answer is required\n" if ($v eq "");;
    print "$v must exist and be readable\n" if (!-f $v && $v ne "");
  }
}

sub setClusterType {
  while (1) {
    my $m = askNonBlank("Cluster Type:", $config{zimbraClusterType});
    if ($m eq "RedHat" || $m eq "Veritas" || $m eq "none" ) {
      $config{zimbraClusterType} = $m;
      return;
    }
    print "Supported cluster types are RedHat, Veritas or none\n";
  }
}

sub setCreateDomain {
  my $oldDomain = $config{CREATEDOMAIN};
  my $good = 0;
  while (1) {
    $config{CREATEDOMAIN} =
      ask("Create Domain:",
        $config{CREATEDOMAIN});
    my $ans = getDnsRecords($config{CREATEDOMAIN}, 'MX');
    if (!defined ($ans)) {
      progress("\n\nDNS ERROR resolving MX for $config{CREATEDOMAIN}\n");
      progress("It is suggested that the domain name have an MX record configured in DNS\n");
      if (askYN("Re-Enter domain name?","Yes") eq "no") {
        last;
      }
      $config{CREATEDOMAIN} = $oldDomain;
      next;
    } elsif (isEnabled("zimbra-mta")) {

      my @answer = $ans->answer;
      foreach my $a (@answer) {
        if ($a->type eq "MX") {
          my $h = getDnsRecords ($a->exchange,'A');
          if (!defined ($h)) {
            progress "\tWarning: no 'A' record found for ".$a->exchange."\n";
            next;
          }
          my @ha = $h->answer;
          foreach $h (@ha) {
            if ($h->type eq 'A') {
              progress "\tMX: ".$a->exchange." (".$h->address.")\n";
            }
          }
        }
      }
      progress "\n";
      foreach my $i (@interfaces) {
        progress "\tInterface: $i\n";
      }
      foreach my $a (@answer) {
        foreach my $i (@interfaces) {
          if ($a->type eq "MX") {
            my $h = getDnsRecords ($a->exchange,'A');
            if (!defined ($h)) {
              progress "\tWarning: no 'A' record found for ".$a->exchange."\n";
              next;
            }
            my @ha = $h->answer;
            foreach $h (@ha) {
              if ($h->type eq 'A') {
                if ($h->address eq $i) {
                  $good = 1;
                  last;
                }
              }
            }
            if ($good) { last; }
          }
        }
        if ($good) { last; }
      }
      if ($good) { last; }
      else {
        progress ("\n\nDNS ERROR - none of the MX records for $config{CREATEDOMAIN}\n");
        progress ("resolve to this host\n");
        progress ("It is suggested that the MX record resolve to this host\n");
        if (askYN("Re-Enter domain name?","Yes") eq "no") {
          last;
        }
        $config{CREATEDOMAIN} = $oldDomain;
        next;
      }

    }
    last;
  }
  my ($u,$d) = split ('@', $config{CREATEADMIN});
  my $old = $config{CREATEADMIN};
  $config{CREATEADMIN} = $u.'@'.$config{CREATEDOMAIN};

  if ($old eq $config{AVUSER}) {
    $config{AVUSER} = $config{CREATEADMIN};
  }
  if ($old eq $config{SMTPDEST}) {
    $config{SMTPDEST} = $config{CREATEADMIN};
  }
  if ($old eq $config{SMTPSOURCE}) {
    $config{SMTPSOURCE} = $config{CREATEADMIN};
  }
  my ($spamUser, $spamDomain) = split ('@', $config{TRAINSASPAM});
  my ($hamUser, $hamDomain) = split ('@', $config{TRAINSAHAM});
  my ($notebookUser, $notebookDomain) = split ('@', $config{NOTEBOOKACCOUNT});

  $config{NOTEBOOKACCOUNT} = $notebookUser.'@'.$config{CREATEDOMAIN}
    if ($notebookDomain eq $oldDomain);

  $config{TRAINSASPAM} = $spamUser.'@'.$config{CREATEDOMAIN}
    if ($spamDomain eq $oldDomain);

  $config{TRAINSAHAM} = $hamUser.'@'.$config{CREATEDOMAIN}
    if ($hamDomain eq $oldDomain);

}

sub setLdapBaseDN {
  while (1) {
    print "Warning: Do not change this from the default value unless\n";
    print "you are absolutely sure you know what you are doing!\n\n";
    my $new =
      askNonBlank("Ldap base DN:",
        $config{ldap_dit_base_dn_config});
    if ($config{ldap_dit_base_dn_config} ne $new) {
      $config{ldap_dit_base_dn_config} = $new;
    }
    return;
  }
}

sub setNotebookAccount {
  while (1) {
    my $new = 
      ask("Global Documents account:",
        $config{NOTEBOOKACCOUNT});
    my ($u,$d) = split ('@', $new);
    my ($adminUser,$adminDomain) = split('@', $config{CREATEADMIN});
    if ($d ne $config{CREATEDOMAIN} && $d ne $adminDomain) {
      if ($config{CREATEDOMAIN} eq $adminDomain) {
        progress ( "You must create the user under the domain $config{CREATEDOMAIN}\n" );
      } else {
        progress ( "You must create the user under the domain $config{CREATEDOMAIN} or $adminDomain\n" );
      }
    } else {
      $config{NOTEBOOKACCOUNT} = $new;
      last;
    }
  }
}

sub setTrainSASpam {
  while (1) {

    my $new = ask("Spam training user:", $config{TRAINSASPAM});
      
    my ($u,$d) = split ('@', $new);
    my ($adminUser,$adminDomain) = split('@', $config{CREATEADMIN});
    if ($d ne $config{CREATEDOMAIN} && $d ne $adminDomain) {
      if ($config{CREATEDOMAIN} eq $adminDomain) {
        progress ( "You must create the user under the domain $config{CREATEDOMAIN}\n" );
      } else {
        progress ( "You must create the user under the domain $config{CREATEDOMAIN} or $adminDomain\n" );
      }
    } else {
      $config{TRAINSASPAM} = $new;
      last;
    }
  }
}

sub setTrainSAHam {
  while (1) {
    my $new = 
      ask("Ham training user:",
        $config{TRAINSAHAM});
    my ($u,$d) = split ('@', $new);
    my ($adminUser,$adminDomain) = split('@', $config{CREATEADMIN});
    if ($d ne $config{CREATEDOMAIN} && $d ne $adminDomain) {
      if ($config{CREATEDOMAIN} eq $adminDomain) {
        progress ( "You must create the user under the domain $config{CREATEDOMAIN}\n" );
      } else {
        progress ( "You must create the user under the domain $config{CREATEDOMAIN} or $adminDomain\n" );
      }
    } else {
      $config{TRAINSAHAM} = $new;
      last;
    }
  }
}

sub setCreateAdmin {

  while (1) {
    my $new = 
      ask("Create admin user:", $config{CREATEADMIN});
    my ($u,$d) = split ('@', $new);

    unless(validEmailAddress($new)) {
      progress ( "Admin user must a valid email account [$u\@$config{CREATEDOMAIN}]\n");
      next;
    }

    # spam/ham/notebook accounts follow admin domain if ldap isn't install
    # this prevents us from trying to provision in a non-existent domain
    if (!isEnabled("zimbra-ldap")) {
      my ($spamUser, $spamDomain) = split ('@', $config{TRAINSASPAM});
      my ($hamUser, $hamDomain) = split ('@', $config{TRAINSAHAM});
      my ($notebookUser, $notebookDomain) = split ('@', $config{NOTEBOOKACCOUNT});
      $config{CREATEDOMAIN} = $d
        if ($config{CREATEDOMAIN} ne $d);

      $config{NOTEBOOKACCOUNT} = $notebookUser.'@'.$d
        if ($notebookDomain ne $d);

      $config{TRAINSASPAM} = $spamUser.'@'.$d
        if ($spamDomain ne $d);
  
      $config{TRAINSAHAM} = $hamUser.'@'.$d
        if ($hamDomain ne $d);
    }

    if ($config{CREATEADMIN} eq $config{AVUSER}) {
      $config{AVUSER} = $new;
    }
    if ($config{CREATEADMIN} eq $config{SMTPDEST}) {
      $config{SMTPDEST} = $new;
    }
    if ($config{CREATEADMIN} eq $config{SMTPSOURCE}) {
      $config{SMTPSOURCE} = $new;
    }
    $config{CREATEADMIN} = $new;
    last;
  }
  
  setAdminPass();

}

sub validEmailAddress {
   return($_[0] =~ m/^[^@]+@([-\w]+\.)+[A-Za-z]{2,4}/ ? 1 : 0);
}

sub setLdapRootPass {
  while (1) {
    my $new =
      askNonBlank("Password for ldap root user (min 6 characters):",
        $config{LDAPROOTPASS});
    if (length($new) >= 6) {
      if ($config{LDAPROOTPASS} ne $new) {
        $config{LDAPROOTPASS} = $new;
        $ldapRootPassChanged = 1;
      }
      return;
    } else {
      print "Minimum length of 6 characters!\n";
    }
  }
}

sub setLdapAdminPass {
  while (1) {
    my $new =
      askNonBlank("Password for ldap admin user (min 6 characters):",
        $config{LDAPADMINPASS});
    if (length($new) >= 6) {
      if ($config{LDAPADMINPASS} ne $new) {
        $config{LDAPADMINPASS} = $new;
        $ldapAdminPassChanged = 1;
      }
      return;
    } else {
      print "Minimum length of 6 characters!\n";
    }
  }
}

sub setLdapRepPass {
  while (1) {
    my $new =
      askNonBlank("Password for ldap replication user (min 6 characters):",
        $config{LDAPREPPASS});
    if (length($new) >= 6) {
      if ($config{LDAPREPPASS} ne $new) {
        $config{LDAPREPPASS} = $new;
        $ldapRepChanged = 1;
      }
      return;
    } else {
      print "Minimum length of 6 characters!\n";
    }
  } 
}

sub setLdapPostPass {
  while (1) {
    my $new =
      askNonBlank("Password for ldap Postfix user (min 6 characters):",
        $config{LDAPPOSTPASS});
    if (length($new) >= 6) {
      if ($config{LDAPPOSTPASS} ne $new) {
        $config{LDAPPOSTPASS} = $new;
        $ldapPostChanged = 1;
      }
      return;
    } else {
      print "Minimum length of 6 characters!\n";
    }
  }
}

sub setLdapAmavisPass {
  while (1) {
    my $new =
      askNonBlank("Password for ldap Amavis user (min 6 characters):",
        $config{LDAPAMAVISPASS});
    if (length($new) >= 6) {
      if ($config{LDAPAMAVISPASS} ne $new) {
        $config{LDAPAMAVISPASS} = $new;
        $ldapAmavisChanged = 1;
      }
      return;
    } else {
      print "Minimum length of 6 characters!\n";
    }
  }
}

sub setAdminPass {
  if ($config{CREATEADMIN} ne "") {
    while (1) {
      if ($config{CREATEADMINPASS} eq "") { $config{CREATEADMINPASS} = genRandomPass(); }
      my $new =
        askNonBlank("Password for $config{CREATEADMIN} (min 6 characters):",
          $config{CREATEADMINPASS});
      if (length($new) >= 6) {
        $config{CREATEADMINPASS} = $new;
        return;
      } else {
        print "Minimum length of 6 characters!\n";
      }
    }
  }
}

sub setSmtpSource {
  $config{SMTPSOURCE} =
    askNonBlank("SMTP Source address:",
      $config{SMTPSOURCE});
}

sub setSmtpDest {
  $config{SMTPDEST} =
    askNonBlank("SMTP Destination address:",
      $config{SMTPDEST});
}

sub setSnmpTrapHost {
  $config{SNMPTRAPHOST} = 
    askNonBlank("SNMP Trap host:",
      $config{SNMPTRAPHOST});
}

sub setAvUser {
  $config{AVUSER} = 
    askNonBlank("Notification address for AV alerts:",
      $config{AVUSER});
  (undef, $config{AVDOMAIN}) = (split ('@',$config{AVUSER}))[1];
}

sub toggleYN {
  my $key = shift;
  $config{$key} = ($config{$key} eq "yes")?"no":"yes";
}
sub toggleTF {
  my $key = shift;
  $config{$key} = ($config{$key} eq "TRUE")?"FALSE":"TRUE";
}
sub toggleConfigEnabled {
  my $key = shift;
  $config{$key} = ($config{$key} eq "Enabled")?"Disabled":"Enabled";
}

sub setUseImapProxy {

   if (isEnabled("zimbra-proxy")) {
      if ($config{MAILPROXY} eq "TRUE") {
         if ($config{IMAPPROXYPORT} == $config{IMAPPORT}) {
             $config{IMAPPORT} = 7000+$config{IMAPPROXYPORT};
         }
         if ($config{IMAPPORT}+7000 == $config{IMAPPROXYPORT}) {
             $config{IMAPPORT} = $config{IMAPPROXYPORT};
             $config{IMAPPROXYPORT} = $config{IMAPPROXYPORT}-7000;
         }
         if ($config{IMAPSSLPROXYPORT} == $config{IMAPSSLPORT}) {
             $config{IMAPSSLPORT} = 7000+$config{IMAPSSLPROXYPORT};
         }
         if ($config{IMAPSSLPORT}+7000 == $config{IMAPSSLPROXYPORT}) {
             $config{IMAPSSLPORT} = $config{IMAPSSLPROXYPORT};
             $config{IMAPSSLPROXYPORT} = $config{IMAPSSLPROXYPORT}-7000;  
         }
         if ($config{POPPROXYPORT} == $config{POPPORT}) {
             $config{POPPORT} = 7000+$config{POPPROXYPORT};
         }
         if ($config{POPPORT}+7000 == $config{POPPROXYPORT}) {
             $config{POPPORT} = $config{POPPROXYPORT};
             $config{POPPROXYPORT} = $config{POPPROXYPORT}-7000;
         }
         if ($config{POPSSLPROXYPORT} == $config{POPSSLPORT}) {
             $config{POPSSLPORT} = 7000+$config{POPSSLPROXYPORT};
         }
         if ($config{POPSSLPORT}+7000 == $config{POPSSLPROXYPORT}) {
             $config{POPSSLPORT} = $config{POPSSLPROXYPORT};
             $config{POPSSLPROXYPORT} = $config{POPSSLPROXYPORT}-7000;
         }
      } else {
         if ($config{IMAPPROXYPORT}+7000 == $config{IMAPPORT}) {
             $config{IMAPPORT} = $config{IMAPPROXYPORT};
             $config{IMAPPROXYPORT} = $config{IMAPPROXYPORT}+7000;
         }
         if ($config{IMAPSSLPROXYPORT}+7000 == $config{IMAPSSLPORT}) {
             $config{IMAPSSLPORT} = $config{IMAPSSLPROXYPORT};
             $config{IMAPSSLPROXYPORT} = $config{IMAPSSLPROXYPORT} + 7000;
         }
         if ($config{POPPROXYPORT}+7000 == $config{POPPORT}) {
             $config{POPPORT} = $config{POPPROXYPORT};
             $config{POPPROXYPORT} = $config{POPPROXYPORT} + 7000;
         }
         if ($config{POPSSLPROXYPORT}+7000 == $config{POPSSLPORT}) {
             $config{POPSSLPORT} = $config{POPSSLPROXYPORT};
             $config{POPSSLPROXYPORT} = $config{POPSSLPROXYPORT}+7000;
         }
      }
      if ($config{HTTPPROXY} eq "TRUE") {
         if ($config{HTTPROXYPPORT} == $config{HTTPPORT}) {
             $config{HTTPPORT} = 8000+$config{HTTPPROXYPORT};
         }
         if ($config{HTTPPORT}+8000 == $config{HTTPPROXYPORT}) {
             $config{HTTPPORT} = $config{HTTPPROXYPORT};
             $config{HTTPPROXYPORT} = $config{HTTPPORT} - 8000;
         }
         if ($config{HTTPSPROXYPORT} == $config{HTTPSPORT}) {
             $config{HTTPSPORT} = 8000+$config{HTTPSPROXYPORT};
         }
         if ($config{HTTPSPORT}+8000 == $config{HTTPSPROXYPORT}) {
             $config{HTTPSPORT} = $config{HTTPSPROXYPORT};
             $config{HTTPSPROXYPORT} = $config{HTTPSPORT} - 8000;
         }
      } else {
         if ($config{HTTPPROXYPORT}+8000 == $config{HTTPPORT}) {
             $config{HTTPPORT} = $config{HTTPPROXYPORT};
             $config{HTTPPROXYPORT} = $config{HTTPPORT}-8000;
         }
         if ($config{HTTPSPROXYPORT}+8000 == $config{HTTPSPORT}) {
             $config{HTTPSPORT} = $config{HTTPSPROXYPORT};
             $config{HTTPSPROXYPORT} = $config{HTTPSPORT}-8000;
         }
      }
   } else {
      if ($config{IMAPPROXYPORT}+7000 == $config{IMAPPORT}) {
          $config{IMAPPORT} = $config{IMAPPROXYPORT};
          $config{IMAPPROXYPORT} = $config{IMAPPROXYPORT}+7000;
      }
      if ($config{IMAPSSLPROXYPORT}+7000 == $config{IMAPSSLPORT}) {
          $config{IMAPSSLPORT} = $config{IMAPSSLPROXYPORT};
          $config{IMAPSSLPROXYPORT} = $config{IMAPSSLPROXYPORT} + 7000;
      }
      if ($config{POPPROXYPORT}+7000 == $config{POPPORT}) {
          $config{POPPORT} = $config{POPPROXYPORT};
           $config{POPPROXYPORT} = $config{POPPROXYPORT} + 7000;
      }
      if ($config{POPSSLPROXYPORT}+7000 == $config{POPSSLPORT}) {
          $config{POPSSLPORT} = $config{POPSSLPROXYPORT};
          $config{POPSSLPROXYPORT} = $config{POPSSLPROXYPORT}+7000;
      }
      if ($config{HTTPPROXYPORT}+8000 == $config{HTTPPORT}) {
          $config{HTTPPORT} = $config{HTTPPROXYPORT};
          $config{HTTPPROXYPORT} = $config{HTTPPORT}-8000;
      }
      if ($config{HTTPSPROXYPORT}+8000 == $config{HTTPSPORT}) {
          $config{HTTPSPORT} = $config{HTTPSPROXYPORT};
          $config{HTTPSPROXYPORT} = $config{HTTPSPORT}-8000;
      }
   }
}

sub setStoreMode {
  while (1) {
    my $m = 
      askNonBlank("Please enter the web server mode (http,https,both,mixed,redirect)",
        $config{MODE});
    if ($m eq "http" || $m eq "https" || $m eq "mixed" || $m eq "both" || $m eq "redirect" ) {
      $config{MODE} = $m;
      return;
    }
    print "Please enter a valid mode!\n";
  }
}

sub changeLdapHost {
  $config{LDAPHOST} = shift;
  $config{LDAPHOST} = lc($config{LDAPHOST});
  if (isInstalled("zimbra-ldap") && $config{LDAPHOST} != $config{HOSTNAME}) {
      $ldapReplica=1;
  }
}

sub changeLdapPort {
  $config{LDAPPORT} = shift;
}

sub getDnsRecords {
  my $name = shift;
  my $qtype = shift;

  my $res = Net::DNS::Resolver->new;
  my @servers = $res->nameservers();
  my $ans = $res->search ($name, $qtype);

  return $ans;
}

sub lookupHostName { 
  my $name = shift;
  my $qtype = shift;

  my $res = Net::DNS::Resolver->new;
  my @servers = $res->nameservers();
  my $ans = $res->search ($name, $qtype);
  if (!defined ($ans)) {
    progress ("No results returned for $qtype lookup of $name\n");
    progress ("Checked nameservers:\n");
    foreach (@servers) {
      progress ("\t$_\n");
    }
    return 1;
  } else {
    #progress ("Received answer:\n");
    #progress ($ans->string()."\n");
    return 0;
  }
}

sub setHostName {
  my $old = $config{HOSTNAME};
  while (1) {
    $config{HOSTNAME} = 
      askNonBlank("Please enter the logical hostname for this host",
        $config{HOSTNAME});
    if (lookupHostName ($config{HOSTNAME}, 'A')) {
      progress("\n\nDNS ERROR resolving $config{HOSTNAME}\n");
      progress("It is suggested that the hostname be resolveable via DNS\n");
      if (askYN("Re-Enter hostname","Yes") eq "no") {
        last;
      }
      $config{HOSTNAME} = $old;
    } else {last;}
  }
  $config{HOSTNAME} = lc($config{HOSTNAME});
  if ($config{SMTPHOST} eq $old) {
    $config{SMTPHOST} = $config{HOSTNAME};
  }
  if ($config{SNMPTRAPHOST} eq $old) {
    $config{SNMPTRAPHOST} = $config{HOSTNAME};
  }
  if ($config{LDAPHOST} eq $old) {
    changeLdapHost($config{HOSTNAME});
  }
  if ($config{MTAAUTHHOST} eq $old) {
    $config{MTAAUTHHOST} = $config{HOSTNAME};
  }
  if ($config{CREATEDOMAIN} eq $old) {
    $config{CREATEDOMAIN} = $config{HOSTNAME};

    my ($u,$d) = split ('@', $config{CREATEADMIN});
    $config{CREATEADMIN} = $u.'@'.$config{CREATEDOMAIN};

    my ($u,$d) = split ('@', $config{NOTEBOOKACCOUNT});
    $config{NOTEBOOKACCOUNT} = $u.'@'.$config{CREATEDOMAIN};

    my ($u,$d) = split ('@', $config{TRAINSASPAM});
    $config{TRAINSASPAM} = $u.'@'.$config{CREATEDOMAIN};

    my ($u,$d) = split ('@', $config{TRAINSAHAM});
    $config{TRAINSAHAM} = $u.'@'.$config{CREATEDOMAIN};
  }
  my ($suser,$sdomain) = split ('@', $config{SMTPSOURCE}, 2);
  if ($sdomain eq $old) {
    $config{SMTPSOURCE} = $suser.'@'.$config{CREATEDOMAIN};
  }
  ($suser,$sdomain) = split ('@', $config{SMTPDEST}, 2);
  if ($sdomain eq $old) {
    $config{SMTPDEST} = $suser.'@'.$config{CREATEDOMAIN};
  }
  if ($config{SPELLURL} eq "http://${old}:7780/aspell.php") {
    $config{SPELLURL} = "http://$config{HOSTNAME}:7780/aspell.php";
  }
}

sub setSmtpHost {
  $config{SMTPHOST} = 
    askNonBlank("Please enter the SMTP server hostname",
      $config{SMTPHOST});
}

sub setMtaAuthHost {
  $config{MTAAUTHHOST} = askNonBlank("Please enter the mta authentication server hostname",
      $config{MTAAUTHHOST});
}

sub setLdapHost {
  changeLdapHost( askNonBlank("Please enter the ldap server hostname",
      $config{LDAPHOST}));
}

sub setLdapPort {
  changeLdapPort( askNum("Please enter the ldap server port",
      $config{LDAPPORT}));
}

sub setHttpPort {
  $config{HTTPPORT} = askNum("Please enter the HTTP server port",
      $config{HTTPPORT});
}

sub setHttpsPort {
  $config{HTTPSPORT} = askNum("Please enter the HTTPS server port",
      $config{HTTPSPORT});
}

sub setImapPort {
  $config{IMAPPORT} = askNum("Please enter the IMAP server port",
      $config{IMAPPORT});
}

sub setImapSSLPort {
  $config{IMAPSSLPORT} = askNum("Please enter the IMAP SSL server port",
      $config{IMAPSSLPORT});
}

sub setPopPort {
  $config{POPPORT} = askNum("Please enter the POP server port",
      $config{POPPORT});
}

sub setPopSSLPort {
  $config{POPSSLPORT} = askNum("Please enter the POP SSL server port",
      $config{POPSSLPORT});
}

sub setImapProxyPort {
  $config{IMAPPROXYPORT} = askNum("Please enter the IMAP Proxy server port",
      $config{IMAPPROXYPORT});
}
sub setImapSSLProxyPort {
  $config{IMAPSSLPROXYPORT} = askNum("Please enter the IMAP SSL Proxy server port",
      $config{IMAPSSLPROXYPORT});
}
sub setPopProxyPort {
  $config{POPPROXYPORT} = askNum("Please enter the POP Proxy server port",
      $config{POPPROXYPORT});
}
sub setPopSSLProxyPort {
  $config{POPSSLPROXYPORT} = askNum("Please enter the POP SSL Proxyserver port",
      $config{POPSSLPROXYPORT});
}

sub setHttpProxyPort {
  $config{HTTPPROXYPORT} = askNum("Please enter the HTTP Proxyserver port",
      $config{HTTPPROXYPORT});
}

sub setHttpsProxyPort {
  $config{HTTPSPROXYPORT} = askNum("Please enter the HTTPS Proxyserver port",
      $config{HTTPSPROXYPORT});
}

sub setSpellUrl {
  $config{SPELLURL} = askNonBlank("Please enter the spell server URL", 
    $config{SPELLURL});
}

sub setLicenseFile {
  $config{LICENSEFILE} = askFileName("Enter the name of the file that contains the license:", 
    $config{LICENSEFILE});
  system("cp $config{LICENSEFILE} /opt/zimbra/conf/ZCSLicense.xml")
    if ($config{LICENSEFILE} ne "/opt/zimbra/conf/ZCSLicense.xml");
  if ( -f "/opt/zimbra/conf/ZCSLicense.xml") {
    `chown zimbra:zimbra /opt/zimbra/conf/ZCSLicense.xml`;
    `chmod 444 /opt/zimbra/conf/ZCSLicense.xml`;
  }
}

sub setTimeZone {
  my $timezones="/opt/zimbra/conf/timezones.ics";
  if (-f $timezones) {
    detail ("DEBUG: Checking for timezones in $timezones\n");
    open (ICS, "$timezones");
    my %TZID;
    my $i=0;
    foreach my $tz (grep(/^TZID/, <ICS>)) {
      chomp $tz;
      $tz =~ s/^TZID://;
      $i++;
      $TZID{$tz} = $i;
    }
    my %RTZID = reverse %TZID;
    close(ICS);
    my $new;
    my $default = $TZID{$config{zimbraPrefTimeZoneId}} || "5";
    while ($new eq "") {
      foreach (sort {$TZID{$a} <=> $TZID{$b}} keys %TZID) {
        print "$TZID{$_} $_\n";
      }
      my $ans=askNum("Enter the number for the local timezone:", $default);
      $new = $RTZID{$ans};
    }
    $config{zimbraPrefTimeZoneId} = $new;
    
  }
}

sub setEnabledDependencies {
  if (isEnabled("zimbra-ldap")) {
    if ($config{LDAPHOST} eq "") {
      changeLdapHost($config{HOSTNAME});
    }
  } else {
    if ($config{LDAPHOST} eq $config{HOSTNAME}) {
      changeLdapHost("");
      $config{LDAPADMINPASS} = "";
      $config{LDAPROOTPASS} = "";
    }
  }

  if (isEnabled("zimbra-store")) {
    if (isEnabled("zimbra-mta")) {
      $config{SMTPHOST} = $config{HOSTNAME};
    }
  }

  if (isEnabled("zimbra-mta")) {
    if ($newinstall) {
      $config{RUNAV} = "yes";
      $config{RUNSA} = "yes";
      $config{RUNARCHIVING} = "no";
    } else {
      $config{RUNAV} = (isServiceEnabled("antispam") ? "yes" : "no");
      $config{RUNSA} = (isServiceEnabled("antivirus") ? "yes" : "no");
      $config{RUNARCHIVING} = (isServiceEnabled("archiving") ? "yes" : "no");
    }
  }

  if (isEnabled("zimbra-spell")) {
    $config{USESPELL} = "yes";
    $config{SPELLURL} = "http://$config{HOSTNAME}:7780/aspell.php";
  }
  if (isInstalled("zimbra-proxy")) {
     setUseImapProxy();
  }
}

sub toggleEnabled {
  my $p = shift;
  $enabledPackages{$p} = (isEnabled($p))?"Disabled":"Enabled";
  setEnabledDependencies();
}

sub verifyQuit {
  if (askYN("Quit without applying changes?", "No") eq "yes") {return 1;}
  return 0;
}

sub genPackageMenu {
  my $package = shift;
  my %lm = ();
  $lm{menuitems}{1} = { 
    "prompt" => "Status:", 
    "var" => \$enabledPackages{$package},
    "callback" => \&toggleEnabled,
    "arg" => $package};
  $lm{promptitem} = { 
    "selector" => "r", 
    "prompt" => "Select, or 'r' for previous menu ", 
    "action" => "return"};
  $lm{default} = "r";
  return \%lm;
}

sub genSubMenu {
  my %lm = ();
  $lm{promptitem} = { 
    "selector" => "r", 
    "prompt" => "Select, or 'r' for previous menu ", 
    "action" => "return"};
  $lm{default} = "r";
  return \%lm;
}

sub isNetwork {
  return((-f "/opt/zimbra/lib/ext/zimbra-license/zimbra-license.jar") ? 1 : 0);
}

sub isFoss {
  return((-f "/opt/zimbra/lib/ext/zimbra-license/zimbra-license.jar") ? 0 : 1);
}

sub isLicenseInstalled {
 return(runAsZimbra("zmlicense -c") ? 0 : 1); 
}

sub createPackageMenu {
  my $package = shift;
  if ($package eq "zimbra-ldap") {
    return createLdapMenu($package);
  } elsif ($package eq "zimbra-mta") {
    return createMtaMenu($package);
  } elsif ($package eq "zimbra-snmp") {
    return createSnmpMenu($package);
  } elsif ($package eq "zimbra-store") {
    return createStoreMenu($package);
  } elsif ($package eq "zimbra-cluster") {
    return createClusterMenu($package);
  } elsif ($package eq "zimbra-proxy") {
    return createProxyMenu($package)
  }
}

sub createCommonMenu {
  my $package = shift;
  my $lm = genSubMenu();

  $$lm{title} = "Common configuration";

  $$lm{createsub} = \&createCommonMenu;
  $$lm{createarg} = $package;

  my $i = 1;
  $$lm{menuitems}{$i} = { 
    "prompt" => "Hostname:", 
    "var" => \$config{HOSTNAME}, 
    "callback" => \&setHostName
    };
  $i++;
  $$lm{menuitems}{$i} = { 
    "prompt" => "Ldap master host:", 
    "var" => \$config{LDAPHOST}, 
    "callback" => \&setLdapHost
    };
  $i++;
  $$lm{menuitems}{$i} = { 
    "prompt" => "Ldap port:", 
    "var" => \$config{LDAPPORT}, 
    "callback" => \&setLdapPort
    };
  $i++;
  if ($config{LDAPADMINPASS} ne "") {
    $config{LDAPADMINPASSSET} = "set";
  } else {
    $config{LDAPADMINPASSSET} = "UNSET";
  }
  $$lm{menuitems}{$i} = { 
    "prompt" => "Ldap Admin password:", 
    "var" => \$config{LDAPADMINPASSSET}, 
    "callback" => \&setLdapAdminPass
    };
  $i++;
  # ldap users
  if (!defined($installedPackages{"zimbra-ldap"})) {
    $$lm{menuitems}{$i} = { 
      "prompt" => "LDAP Base DN:", 
      "var" => \$config{ldap_dit_base_dn_config}, 
      "callback" => \&setLdapBaseDN,
      };
    $i++;
  }
  $$lm{menuitems}{$i} = { 
    "prompt" => "TimeZone:", 
    "var" => \$config{zimbraPrefTimeZoneId},
    "callback" => \&setTimeZone
  };
  $i++;
  return $lm;
}

sub createLdapMenu {
  my $package = shift;
  my $lm = genPackageMenu($package);

  $$lm{title} = "Ldap configuration";

  $$lm{createsub} = \&createLdapMenu;
  $$lm{createarg} = $package;

  my $i = 2;
  if (isEnabled($package)) {
    $$lm{menuitems}{$i} = { 
      "prompt" => "Create Domain:", 
      "var" => \$config{DOCREATEDOMAIN}, 
      "callback" => \&toggleYN,
      "arg" => "DOCREATEDOMAIN",
      };
    $i++;
    if ($config{DOCREATEDOMAIN} eq "yes") {
      $$lm{menuitems}{$i} = { 
        "prompt" => "Domain to create:", 
        "var" => \$config{CREATEDOMAIN}, 
        "callback" => \&setCreateDomain,
        };
      $i++;
    }
    if ($config{LDAPROOTPASS} ne "") {
      $config{LDAPROOTPASSSET} = "set";
    } else {
      $config{LDAPROOTPASSSET} = "UNSET";
    }
    $$lm{menuitems}{$i} = {
      "prompt" => "Ldap Root password:",
      "var" => \$config{LDAPROOTPASSSET},
      "callback" => \&setLdapRootPass
      };
    $i++;
    if ($config{LDAPREPPASS} ne "") {
      $config{LDAPREPPASSSET} = "set";
    } else {
      $config{LDAPREPPASSSET} = "UNSET";
    }
    $$lm{menuitems}{$i} = {
      "prompt" => "Ldap Replication password:",
      "var" => \$config{LDAPREPPASSSET},
      "callback" => \&setLdapRepPass
      };
    $i++;
    if ($config{LDAPPOSTPASS} ne "") {
      $config{LDAPPOSTPASSSET} = "set";
    } else {
      $config{LDAPPOSTPASSSET} = "UNSET";
    }
    $$lm{menuitems}{$i} = {
      "prompt" => "Ldap Postfix password:",
      "var" => \$config{LDAPPOSTPASSSET},
      "callback" => \&setLdapPostPass
      };
    $i++;
    if ($config{LDAPAMAVISPASS} ne "") {
      $config{LDAPAMAVISPASSSET} = "set";
    } else {
      $config{LDAPAMAVISPASSSET} = "UNSET";
    }
    $$lm{menuitems}{$i} = {
      "prompt" => "Ldap Amavis password:",
      "var" => \$config{LDAPAMAVISPASSSET},
      "callback" => \&setLdapAmavisPass
      };
    $i++;
  }
  return $lm;
}
sub createCOSMenu {
  my $package = shift;
  my $lm = genSubMenu();

  $$lm{title} = "Default Class of Service configuration";

  $$lm{createsub} = \&createCOSMenu;
  $$lm{createarg} = $package;

  my $i = 1;
  $$lm{menuitems}{$i} = { 
    "prompt" => "Enable Instant Messaging Feature:", 
    "var" => \$config{zimbraFeatureIMEnabled}, 
    "callback" => \&toggleConfigEnabled,
    "arg" => "zimbraFeatureIMEnabled",
    };
  $i++;
  $$lm{menuitems}{$i} = { 
    "prompt" => "Enable Briefcases Feature:", 
    "var" => \$config{zimbraFeatureBriefcasesEnabled}, 
    "callback" => \&toggleConfigEnabled,
    "arg" => "zimbraFeatureBriefcasesEnabled",
    };
  $i++;
  $$lm{menuitems}{$i} = { 
    "prompt" => "Enable Tasks Feature:", 
    "var" => \$config{zimbraFeatureTasksEnabled}, 
    "callback" => \&toggleConfigEnabled,
    "arg" => "zimbraFeatureTasksEnabled",
    };
  $i++;
  $$lm{menuitems}{$i} = { 
    "prompt" => "Enable Notebook Feature:", 
    "var" => \$config{zimbraFeatureNotebookEnabled}, 
    "callback" => \&toggleConfigEnabled,
    "arg" => "zimbraFeatureNotebookEnabled",
    };
  $i++;
  return $lm;
}

sub createLdapUsersMenu {
  my $package = shift;
  my $lm = genSubMenu();

  $$lm{title} = "Ldap Users configuration";

  $$lm{createsub} = \&createLdapUsersMenu;
  $$lm{createarg} = $package;

  my $i = 1;
  return $lm;
}

sub createArchivingMenu {
  my $package = shift;
  my $lm = genPackageMenu($package);
  $$lm{title} = "Archiving configuration";
  $$lm{createsub} = \&createArchivingMenu;
  $$lm{createarg} = $package;
  my $i = 2;
  return $lm;
}


sub createClusterMenu {
  my $package = shift;
  my $lm = genPackageMenu($package);

  $$lm{title} = "Cluster configuration";

  $$lm{createsub} = \&createClusterMenu;
  $$lm{createarg} = $package;

  my $i = 2;
  if (isEnabled($package)) {
    $$lm{menuitems}{$i} = { 
      "prompt" => "Cluster type:", 
      "var" => \$config{zimbraClusterType}, 
      "callback" => \&setClusterType,
      };
    $i++;
  }
  return $lm;
}

sub createSnmpMenu {
  my $package = shift;
  my $lm = genPackageMenu($package);

  $$lm{title} = "Snmp configuration";

  $$lm{createsub} = \&createSnmpMenu;
  $$lm{createarg} = $package;

  my $i = 2;
  if (isEnabled($package)) {
    $$lm{menuitems}{$i} = { 
      "prompt" => "Enable SNMP notifications:", 
      "var" => \$config{SNMPNOTIFY}, 
      "callback" => \&toggleYN,
      "arg" => "SNMPNOTIFY",
      };
    $i++;
    if ($config{SNMPNOTIFY} eq "yes") {
      $$lm{menuitems}{$i} = { 
        "prompt" => "SNMP Trap hostname:", 
        "var" => \$config{SNMPTRAPHOST}, 
        "callback" => \&setSnmpTrapHost,
        };
      $i++;
    }
    $$lm{menuitems}{$i} = { 
      "prompt" => "Enable SMTP notifications:", 
      "var" => \$config{SMTPNOTIFY}, 
      "callback" => \&toggleYN,
      "arg" => "SMTPNOTIFY",
      };
    $i++;
    if ($config{SMTPNOTIFY} eq "yes") {
      $$lm{menuitems}{$i} = { 
        "prompt" => "SMTP Source email address:", 
        "var" => \$config{SMTPSOURCE}, 
        "callback" => \&setSmtpSource,
        };
      $i++;
      $$lm{menuitems}{$i} = { 
        "prompt" => "SMTP Destination email address:", 
        "var" => \$config{SMTPDEST}, 
        "callback" => \&setSmtpDest,
        };
      $i++;
    }
  }
  return $lm;
}

sub createMtaMenu {
  my $package = shift;
  my $lm = genPackageMenu($package);

  $$lm{title} = "Mta configuration";

  $$lm{createsub} = \&createMtaMenu;
  $$lm{createarg} = $package;

  my $i = 2;
  if (isEnabled($package)) {
    $$lm{menuitems}{$i} = { 
      "prompt" => "MTA Auth host:", 
      "var" => \$config{MTAAUTHHOST}, 
      "callback" => \&setMtaAuthHost,
      "arg" => "MTAAUTHHOST",
      };
    $i++;
    $$lm{menuitems}{$i} = { 
      "prompt" => "Enable Spamassassin:", 
      "var" => \$config{RUNSA}, 
      "callback" => \&toggleYN,
      "arg" => "RUNSA",
      };
    $i++;
    $$lm{menuitems}{$i} = { 
      "prompt" => "Enable Clam AV:", 
      "var" => \$config{RUNAV}, 
      "callback" => \&toggleYN,
      "arg" => "RUNAV",
      };
    $i++;
    if ($config{RUNAV} eq "yes") {
      $$lm{menuitems}{$i} = { 
        "prompt" => "Notification address for AV alerts:", 
        "var" => \$config{AVUSER}, 
        "callback" => \&setAvUser,
        };
      $i++;
    }
    if (isEnabled("zimbra-archiving") || isComponentAvailable("archiving")) {
      $$lm{menuitems}{$i} = { 
        "prompt" => "Enable Archiving and Discovery:",
        "var" => \$config{RUNARCHIVING}, 
        "callback" => \&toggleYN,
        "arg" => "RUNARCHIVING",
        };
      $i++;
    }
    if ($config{LDAPPOSTPASS} ne "") {
      $config{LDAPPOSTPASSSET} = "set";
    } else {
      $config{LDAPPOSTPASSSET} = "UNSET";
    }
    $$lm{menuitems}{$i} = {
      "prompt" => "Bind password for postfix ldap user:",
      "var" => \$config{LDAPPOSTPASSSET},
      "callback" => \&setLdapPostPass
      };
    $i++;
    if ($config{LDAPAMAVISPASS} ne "") {
      $config{LDAPAMAVISPASSSET} = "set";
    } else {
      $config{LDAPAMAVISPASSSET} = "UNSET";
    }
    $$lm{menuitems}{$i} = {
      "prompt" => "Bind password for amavis ldap user:",
      "var" => \$config{LDAPAMAVISPASSSET},
      "callback" => \&setLdapAmavisPass
      };
    $i++;
  }
  return $lm;
}

sub createProxyMenu {
  my $package = shift;
  my $lm = genPackageMenu($package);

  $$lm{title} = "Proxy configuration";

  $$lm{createsub} = \&createProxyMenu;
  $$lm{createarg} = $package;

  my $i = 2;
  if (isInstalled($package)) {
    $$lm{menuitems}{$i} = {
      "prompt" => "Enable POP/IMAP Proxy:",
      "var" => \$config{MAILPROXY},
      "callback" => \&toggleTF,
      "arg" => "MAILPROXY",
    };
    $i++;
    if($config{MAILPROXY} eq "TRUE") {
       $$lm{menuitems}{$i} = { 
         "prompt" => "IMAP proxy port:", 
         "var" => \$config{IMAPPROXYPORT}, 
         "callback" => \&setImapProxyPort,
       };
       $i++;
       $$lm{menuitems}{$i} = { 
         "prompt" => "IMAP SSL proxy port:", 
         "var" => \$config{IMAPSSLPROXYPORT}, 
         "callback" => \&setImapSSLProxyPort,
       };
       $i++;
       $$lm{menuitems}{$i} = { 
         "prompt" => "POP proxy port:", 
         "var" => \$config{POPPROXYPORT}, 
         "callback" => \&setPopProxyPort,
       };
       $i++;
       $$lm{menuitems}{$i} = { 
         "prompt" => "POP SSL proxy port:", 
         "var" => \$config{POPSSLPROXYPORT}, 
         "callback" => \&setPopSSLProxyPort,
       };
       $i++;
    }
    $$lm{menuitems}{$i} = {
      "prompt" => "Enable HTTP[S] Proxy:",
      "var" => \$config{HTTPPROXY},
      "callback" => \&toggleTF,
      "arg" => "HTTPPROXY",
    };
    $i++;
    if ($config{HTTPPROXY} eq "TRUE") {
       $$lm{menuitems}{$i} = {
         "prompt" => "HTTP proxy port:", 
         "var" => \$config{HTTPPROXYPORT}, 
         "callback" => \&setHttpProxyPort,
       };
       $i++;
       $$lm{menuitems}{$i} = {
         "prompt" => "HTTPS proxy port:", 
         "var" => \$config{HTTPSPROXYPORT}, 
         "callback" => \&setHttpsProxyPort,
       };
       $i++;
    }
  }
  return $lm;
}

sub createStoreMenu {
  my $package = shift;
  my $lm = genPackageMenu($package);

  $$lm{title} = "Store configuration";

  $$lm{createsub} = \&createStoreMenu;
  $$lm{createarg} = $package;

  my $i = 2;
  if (isEnabled($package)) {
    $$lm{menuitems}{$i} = { 
      "prompt" => "Create Admin User:", 
      "var" => \$config{DOCREATEADMIN}, 
      "callback" => \&toggleYN,
      "arg" => "DOCREATEADMIN",
      };
    $i++;
    if ($config{DOCREATEADMIN} eq "yes") {
      $$lm{menuitems}{$i} = { 
        "prompt" => "Admin user to create:", 
        "var" => \$config{CREATEADMIN}, 
        "callback" => \&setCreateAdmin
        };
      $i++;
      if ($config{CREATEADMINPASS} ne "") {
        $config{ADMINPASSSET} = "set";
      } else {
        $config{ADMINPASSSET} = "UNSET";
      }
      $$lm{menuitems}{$i} = { 
        "prompt" => "Admin Password", 
        "var" => \$config{ADMINPASSSET},
        "callback" => \&setAdminPass
        };
      $i++;
    }
    $$lm{menuitems}{$i} = { 
      "prompt" => "Enable automated spam training:", 
      "var" => \$config{DOTRAINSA}, 
      "callback" => \&toggleYN,
      "arg" => "DOTRAINSA",
      };
    $i++;
    if ($config{DOTRAINSA} eq "yes") {

      my $ldap_trainsaspam = getLdapConfigValue("zimbraSpamIsSpamAccount")
        if (!verifyLdap());

      if ($ldap_trainsaspam eq "") {
        $$lm{menuitems}{$i} = { 
          "prompt" => "Spam training user:", 
          "var" => \$config{TRAINSASPAM}, 
          "callback" => \&setTrainSASpam
          };
        $i++;
      } else {
        $config{TRAINSASPAM} = $ldap_trainsaspam;
      }


      my $ldap_trainsaham = getLdapConfigValue("zimbraSpamIsNotSpamAccount")
        if (!verifyLdap());

      if ($ldap_trainsaham eq "") {
        $$lm{menuitems}{$i} = { 
          "prompt" => "Non-spam(Ham) training user:", 
          "var" => \$config{TRAINSAHAM}, 
          "callback" => \&setTrainSAHam
          };
        $i++;
      } else {
        $config{TRAINSAHAM} = $ldap_trainsaham;
      }
    }

    my $ldap_wikiAccount = getLdapConfigValue("zimbraNotebookAccount")
      if (!verifyLdap());

    if ($ldap_wikiAccount eq "") {
      $$lm{menuitems}{$i} = { 
        "prompt" => "Global Documents Account:", 
        "var" => \$config{NOTEBOOKACCOUNT}, 
        "callback" => \&setNotebookAccount
      };
      $i++;
    } else {
      $config{NOTEBOOKACCOUNT} = $ldap_wikiAccount;
    }

    $$lm{menuitems}{$i} = { 
      "prompt" => "SMTP host:", 
      "var" => \$config{SMTPHOST}, 
      "callback" => \&setSmtpHost,
      };
    $i++;
    $$lm{menuitems}{$i} = { 
      "prompt" => "Web server HTTP port:", 
      "var" => \$config{HTTPPORT}, 
      "callback" => \&setHttpPort,
      };
    $i++;
    $$lm{menuitems}{$i} = { 
      "prompt" => "Web server HTTPS port:", 
      "var" => \$config{HTTPSPORT}, 
      "callback" => \&setHttpsPort,
      };
    $i++;
    $$lm{menuitems}{$i} = { 
      "prompt" => "Web server mode:", 
      "var" => \$config{MODE}, 
      "callback" => \&setStoreMode,
      };
    $i++;

    $$lm{menuitems}{$i} = { 
      "prompt" => "IMAP server port:", 
      "var" => \$config{IMAPPORT}, 
      "callback" => \&setImapPort,
      };
    $i++;
    $$lm{menuitems}{$i} = { 
      "prompt" => "IMAP server SSL port:", 
      "var" => \$config{IMAPSSLPORT}, 
      "callback" => \&setImapSSLPort,
      };
    $i++;
    $$lm{menuitems}{$i} = { 
      "prompt" => "POP server port:", 
      "var" => \$config{POPPORT}, 
      "callback" => \&setPopPort,
      };
    $i++;
    $$lm{menuitems}{$i} = { 
      "prompt" => "POP server SSL port:", 
      "var" => \$config{POPSSLPORT}, 
      "callback" => \&setPopSSLPort,
      };
    $i++;

    $$lm{menuitems}{$i} = { 
      "prompt" => "Use spell check server:", 
      "var" => \$config{USESPELL}, 
      "callback" => \&toggleYN,
      "arg" => "USESPELL",
      };
    $i++;
    if ($config{USESPELL} eq "yes") {
      $$lm{menuitems}{$i} = { 
        "prompt" => "Spell server URL:", 
        "var" => \$config{SPELLURL}, 
        "callback" => \&setSpellUrl,
        };
      $i++;
    }
    # only prompt for license if we are network install and
    # a license doesn't exist in /opt/zimbra/conf or ldap.
    if (isNetwork() && !-f $config{DEFAULTLICENSEFILE} && !isLicenseInstalled() ) {
      $$lm{menuitems}{$i} = { 
        "prompt" => "License filename:", 
        "var" => \$config{LICENSEFILE}, 
        "callback" => \&setLicenseFile,
        };
      $i++;
    }
  }
  return $lm;
}

sub displaySubMenuItems {
  my $items = shift;
  my $parentmenuvar = shift;
  my $indent = shift;

  if (defined($$items{createsub})) {
    $items = &{$$items{createsub}}($$items{createarg});
  }
#  print "$indent$$items{title}\n";
  foreach my $i (sort menuSort keys %{$$items{menuitems}}) {
    if (defined($$items{menuitems}{$i}{var}) &&
      $$items{menuitems}{$i}{var} == $parentmenuvar) {next;}
    my $len = 44-(length($indent));
    my $v;
    my $ind = $indent;
    if (defined $$items{menuitems}{$i}{var}) {
      $v = ${$$items{menuitems}{$i}{var}};
      if ($v eq "" || $v eq "none" || $v eq "UNSET") { $v = "UNSET"; $ind=~s/ /*/g; }
    }
    printf ("%s +%-${len}s %-30s\n", $ind,
      $$items{menuitems}{$i}{prompt}, $v);
    if (defined ($$items{menuitems}{$i}{submenu}) ) {
      displaySubMenuItems($$items{menuitems}{$i}{submenu},"$indent  ");
    }
  }
}

sub menuSort {
  if ( ($a eq int($a)) && ($b eq int($b)) ) {
    return $a <=> $b;
  }
  return $a cmp $b;
}

sub displayMenu {
  my $items = shift;
  while (1) {
    if (defined($$items{createsub})) {
      $items = &{$$items{createsub}}($$items{createarg});
    }

    print "\n$$items{title}\n\n";
    foreach my $i (sort menuSort keys %{$$items{menuitems}}) {
      my $v;
      my $ind = "  ";
      if (defined $$items{menuitems}{$i}{var}) {
        $v = ${$$items{menuitems}{$i}{var}};
        if ($v eq "" || $v eq "none" || $v eq "UNSET") { $v = "UNSET"; $ind="**"; }
      }
      my $subMenuCheck = 1;
      if (defined ($$items{menuitems}{$i}{submenu}) || 
        defined ($$items{menuitems}{$i}{callback}) ) {
        if (defined ($$items{menuitems}{$i}{submenu})) {
          $subMenuCheck = checkMenuConfig($$items{menuitems}{$i}{submenu});
        }
        printf ("${ind}%2s) %-40s %-30s\n", $i, 
          $$items{menuitems}{$i}{prompt}, $v);
      } else {
        # Disabled items
        printf ("${ind}    %-40s %-30s\n", 
          $$items{menuitems}{$i}{prompt}, $v);
      }
      if ($config{EXPANDMENU} eq "yes" || !$subMenuCheck) {
        if (defined ($$items{menuitems}{$i}{submenu}) ) {
          displaySubMenuItems($$items{menuitems}{$i}{submenu},
            $$items{menuitems}{$i}{var},"       ");
          print "\n";
        }
      }
    }
    if (defined($$items{lastitem})) {
      printf ("  %2s) %-40s\n", $$items{lastitem}{selector}, 
        $$items{lastitem}{prompt});
    }
    my $menuprompt = "\n";
    if (defined($$items{promptitem})) {
      $menuprompt .= $$items{promptitem}{prompt};
    } else {
      $menuprompt .= "Select ";
    }
    if (defined($$items{help})) {
      $menuprompt .= " (? - help) ";
    }
    print "$menuprompt";
    if (defined $$items{default}) {
      print "[$$items{default}] ";
    }
    my $r = <>;
    chomp $r;
    if ($r eq "") { $r = $$items{default}; }
    if ($r eq "") { next; }
    if ($r eq $$items{lastitem}{selector}) {
      if ($$items{lastitem}{action} eq "quit") {
        if (verifyQuit()) {
          exit 0;
        }
      } elsif ($$items{lastitem}{action} eq "return") {
        return;
      }
    } elsif (defined $$items{help} && $r eq "?") {
      print "\n\n";
      print $$items{help}{helptext};
      print "\n";
      ask("Press any key to continue", "");
      print "\n\n";
    } elsif (defined $$items{promptitem} && $r eq $$items{promptitem}{selector}) {
      if (defined $$items{promptitem}{callback}) {
        &{$$items{promptitem}{callback}}($$items{promptitem}{arg});
      } elsif (defined $$items{promptitem}{action}) {
        if ($$items{promptitem}{action} eq "quit") {
          if (verifyQuit()) {
            exit 0;
          }
        } elsif ($$items{promptitem}{action} eq "return") {
          return;
        }
      }
    } elsif (defined $$items{menuitems}{$r}) {
      print "\n";
      if (defined $$items{menuitems}{$r}{callback}) {
        &{$$items{menuitems}{$r}{callback}}($$items{menuitems}{$r}{arg});
      } elsif (defined ($$items{menuitems}{$r}{submenu})) {
        displayMenu($$items{menuitems}{$r}{submenu});
      }
    } else {
      ask("Invalid selection! - press any key to continue", "");
      print "\n\n";
    }
  }
}

sub createMainMenu {
  my %mm = ();
  $mm{createsub} = \&createMainMenu;
  $mm{title} = "Main menu";
  $mm{help} = {
    "selector" => "?",
    "prompt" => "Help",
    "action" => "help",
    "helptext" => 
      "Main Menu help\n\n".
      "Items marked with ** MUST BE CONFIGURED prior to applying configuration\n\n".
      "",
    };
  $mm{lastitem} = {
    "selector" => "q",
    "prompt" => "Quit",
    "action" => "quit",
    };
  my $i = 1;
  my $submenu = createCommonMenu("zimbra-core");
  $mm{menuitems}{$i} = {
    "prompt" => "Common Configuration:",
    "submenu" => $submenu,
  };
  $i++;
  foreach my $package (@packageList) {
    if ($package eq "zimbra-core") {next;}
    if ($package eq "zimbra-apache") {next;}
    if ($package eq "zimbra-archiving") {next;}
    if (defined($installedPackages{$package})) {
      if ($package =~ /logger|spell/) {
        $mm{menuitems}{$i} = { 
          "prompt" => "$package:", 
          "var" => \$enabledPackages{$package},
          "callback" => \&toggleEnabled, 
          "arg" => $package
        };
        $i++;
        next;
      }
      my $submenu = createPackageMenu($package);
      $mm{menuitems}{$i} = { 
        "prompt" => "$package:", 
        "var" => \$enabledPackages{$package},
        "submenu" => $submenu,
      };
      $i++;
    } else {
      #push @mm, "$package not installed";
    }
  }
  
  if (defined($installedPackages{"zimbra-store"})) {
    my $submenu = createCOSMenu("cos");
    $mm{menuitems}{$i} = {
      "prompt" => "Default Class of Service Configuration:",
      "submenu" => $submenu,
    };
    $i++;
  }
  $i = &preinstall::mainMenuExtensions(\%mm, $i);
  $mm{menuitems}{r} = { 
    "prompt" => "Start servers after configuration", 
    "callback" => \&toggleYN,
    "var" => \$config{STARTSERVERS},
    "arg" => "STARTSERVERS"
    };
  if ($config{EXPANDMENU} eq "yes") {
    $mm{menuitems}{c} = { 
      "prompt" => "Collapse menu", 
      "callback" => \&toggleYN,
      "arg" => "EXPANDMENU"
      };
  } else {
    $mm{menuitems}{x} = { 
      "prompt" => "Expand menu", 
      "callback" => \&toggleYN,
      "arg" => "EXPANDMENU"
      };
  }
  # Allow save of even incomplete config
  $mm{menuitems}{s} = { 
    "prompt" => "Save config to file", 
    "callback" => \&saveConfig,
    };
  if (checkMenuConfig(\%mm)) {
    $mm{promptitem} = { 
      "selector" => "a",
      "prompt" => "*** CONFIGURATION COMPLETE - press 'a' to apply\nSelect from menu, or press 'a' to apply config", 
      "callback" => \&applyConfig,
      };
  } else {
    $mm{promptitem} = { 
      "selector" => "qqazyre",
      "prompt" => "Address unconfigured (**) items ", 
      "callback" => \&applyConfig,
      };
    if (verifyLdap()) {
      $mm{promptitem}{prompt} .= "or correct ldap configuration ";
    }
  }
  return \%mm;
}

sub checkMenuConfig {
  my $items = shift;

  my $needldapverified = 0;

  foreach my $i (sort menuSort keys %{$$items{menuitems}}) {
    my $v;
    my $ind = "  ";
    if (defined $$items{menuitems}{$i}{var}) {
      $v = ${$$items{menuitems}{$i}{var}};
      if ($v eq "" || $v eq "none" || $v eq "UNSET") { return 0; }
      if ($$items{menuitems}{$i}{var} == \$config{LDAPHOST}) {
        $needldapverified = 1;
      }
      if ($$items{menuitems}{$i}{var} == \$config{LDAPPORT}) {
        $needldapverified = 1;
      }
    }
    if (defined ($$items{menuitems}{$i}{submenu}) ) {
      if (!checkMenuConfig($$items{menuitems}{$i}{submenu})) {
        return 0;
      }
    }
  }
  if ($needldapverified) {
    if (verifyLdap()) {
      return 0;
    }
  }
  return 1;
}

sub verifyLdap {
  if (($config{LDAPHOST} eq $config{HOSTNAME}) && !$ldapConfigured) {
    return 0;
  }

  # check zimbra ldap admin user binding to the master
  if ($config{LDAPADMINPASS} eq "" || $config{LDAPPORT} eq "" || $config{LDAPHOST} eq "") {
    detail ( "ldap configuration not complete\n" );
    return 1;
  }
  if (checkLdapBind($config{zimbra_ldap_userdn},$config{LDAPADMINPASS})) {
    detail ("Couldn't bind to $config{LDAPHOST} as $config{zimbra_ldap_userdn}\n");
    return 1 
  } else {
    detail ("Verified $config{zimbra_ldap_userdn} on $config{LDAPHOST}.\n");
    setLocalConfig ("zimbra_ldap_password", $config{LDAPADMINPASS});
  }

  # check postfix and amavis user binding to the master
  if (isInstalled("zimbra-mta")) {
    if ($config{LDAPPOSTPASS} eq "" || $config{LDAPAMAVISPASS} eq "") {
      detail ("mta configuration not complete\n");
      return 1;
    }
    my $binduser = "uid=zmpostfix,cn=appaccts,$config{ldap_dit_base_dn_config}";
    if (checkLdapBind($binduser,$config{LDAPPOSTPASS})) {
      detail ("Couldn't bind to $config{LDAPHOST} as $binduser\n");
      #return 1 
    }
    my $binduser = "uid=zmamavis,cn=appaccts,$config{ldap_dit_base_dn_config}";
    if (checkLdapBind($binduser,$config{LDAPAMAVISPASS})) {
      detail ("Couldn't bind to $config{LDAPHOST} as $binduser\n");
      #return 1 
    } else {
      detail ("Verified $binduser on $config{LDAPHOST}.\n");
    }
  }

  # check replication user binding to master
  if (isInstalled("zimbra-ldap") && $config{LDAPHOST} ne $config{HOSTNAME}) {
    if ($config{LDAPREPPASS} eq "") {
      detail ("ldap configuration not complete\n");
      return 1;
    }
    my $binduser = "uid=zmreplica,cn=admins,$config{ldap_dit_base_dn_config}";
    if (checkLdapBind($binduser,$config{LDAPREPPASS})) {
      detail ("Couldn't bind to $config{LDAPHOST} as $binduser\n");
      #return 1 
    } else {
      detail ("Verified $binduser on $config{LDAPHOST}.\n");
    }
  }
  return 0;
}

sub checkLdapBind() {
  my ($binduser,$bindpass) = @_;

  detail( "Checking ldap on $config{LDAPHOST}:$config{LDAPPORT}");
  my $ldap;
  my $ldap_secure = (($config{LDAPPORT} == "636") ? "s" : "");
  my $ldap_url = "ldap${ldap_secure}://$config{LDAPHOST}:$config{LDAPPORT}";
  unless($ldap = Net::LDAP->new($ldap_url)) {
    detail("failed: Unable to contact ldap at $ldap_url: $!");
    return 1;
  }

  if ($ldap_secure ne "s") {
    $starttls = 1;
    my $result = $ldap->start_tls(verify=>'none');
    if ($result->code()) {
      detail("Unable to startTLS: $!\n");
      return 1;
    }
  } else {
    $starttls = 0;
  }
  my $result = $ldap->bind($binduser, password => $bindpass);
  if ($result->code()) {
    detail ("Unable to bind to $ldap_url with user $binduser and password $bindpass: $!");
    return 1;
  } else {
    $ldap->unbind;
    detail ("Verfied ldap running at $ldap_url\n");
    setLocalConfig ("ldap_url", $ldap_url);
    setLocalConfig ("ldap_starttls_supported", $starttls);
    return 0;
  }

}

sub runAsRoot {
  my $cmd = shift;
  if ($cmd =~ /init/ || $cmd =~ /zmprov -l ca/) {
    # Suppress passwords in log file
    my $c = (split ' ', $cmd)[0];
    detail ( "*** Running as root user: $c\n" );
  } else {
    detail ( "*** Running as root user: $cmd\n" );
  }
  my $rc;
  $rc = 0xffff & system("$cmd >> $logfile 2>&1");
  return $rc;
}

sub runAsZimbra {
  my $cmd = shift;
  if ($cmd =~ /init/ || $cmd =~ /zmprov -l ca/) {
    # Suppress passwords in log file
    my $c = (split ' ', $cmd)[0];
    detail ( "*** Running as zimbra user: $c\n" );
  } else {
    detail ( "*** Running as zimbra user: $cmd\n" );
  }
  my $rc;
  $rc = 0xffff & system("su - zimbra -c \"$cmd\" >> $logfile 2>&1");
  return $rc;
}

sub runAsZimbraWithOutput {
  my $cmd = shift;
  if ($cmd =~ /init/ || $cmd =~ /zmprov -l ca/) {
    # Suppress passwords in log file
    my $c = (split ' ', $cmd)[0];
    detail ( "*** Running as zimbra user: $c\n" );
  } else {
    detail ( "*** Running as zimbra user: $cmd\n" );
  }
  system("su - zimbra -c \"$cmd\"");
  my $exit_value = $? >> 8;
  my $signal_num = $? & 127;
  my $dumped_core = $? & 128;
  detail ("DEBUG: exit status from cmd was $exit_value") if $debug;
  return $exit_value;
}

sub getLocalConfig {
  my ($key,$force) = @_;

  return $main::loaded{lc}{$key}
    if (exists $main::loaded{lc}{$key} && !$force);

  detail ( "Getting local config $key" );
  my $val = `/opt/zimbra/bin/zmlocalconfig -x -s -m nokey ${key} 2> /dev/null`;
  chomp $val;
  detail ("DEBUG: LC Loaded $key=$val") if $debug;
  $main::loaded{lc}{$key} = $val;
  return $val;
}

sub deleteLocalConfig {
  my $key = shift;

  detail ( "Deleting local config $key" );
  my $rc = runAsZimbra("/opt/zimbra/bin/zmlocalconfig -u ${key} 2> /dev/null");
  if ($rc == 0) {
    detail ("DEBUG: deleted localconfig key $key") if $debug;
    delete($main::loaded{lc}{$key}) if (exists $main::loaded{lc}{$key});
    return 1;
  } else {
    detail ("DEBUG: failed to deleted localconfig key $key") if $debug;
    return undef
  }
}

sub setLocalConfig {
  my $key = shift;
  my $val = shift;

  if (exists $main::saved{lc}{$key} && $main::saved{lc}{$key} eq $val) {
    detail ( "Skipping $key=$val. Already written.");
    return;
  }
  detail ( "Setting local config $key to $val" );
  #$main::config{$key} = $val;
  $main::saved{lc}{$key} = $val;
  $main::loaded{lc}{$key} = $val;
  runAsZimbra("/opt/zimbra/bin/zmlocalconfig -f -e ${key}=\'${val}\' 2> /dev/null");
}

sub configLCValues {

  if ($configStatus{configLCValues} eq "CONFIGURED") {
    configLog("configLCValues");
    return 0;
  }

  progress ("Setting local config values...");
  setLocalConfig ("zimbra_server_hostname", lc($config{HOSTNAME}));

  if ($config{LDAPPORT} == 636) {
    setLocalConfig ("ldap_master_url", "ldaps://$config{LDAPHOST}:$config{LDAPPORT}");
    setLocalConfig ("ldap_url", "ldaps://$config{LDAPHOST}:$config{LDAPPORT}");
    setLocalConfig ("ldap_starttls_supported", 0);
  } else {
    setLocalConfig ("ldap_master_url", "ldap://$config{LDAPHOST}:$config{LDAPPORT}");
    if ($config{ldap_url} eq "") { 
      setLocalConfig ("ldap_url", "ldap://$config{LDAPHOST}:$config{LDAPPORT}");
      setLocalConfig ("ldap_starttls_supported", 1);
    } else {
      setLocalConfig ("ldap_url", "$config{ldap_url}");
      if ($config{ldap_url} !~ /^ldaps/i) {
        setLocalConfig ("ldap_starttls_supported", 1);
      } else {
        setLocalConfig ("ldap_starttls_supported", 0);
      }
    }
  }

  setLocalConfig ("ldap_port", "$config{LDAPPORT}");
  setLocalConfig ("ldap_host", "$config{LDAPHOST}");

  my $uid = `id -u zimbra`;
  chomp $uid;
  my $gid = `id -g zimbra`;
  chomp $gid;
  setLocalConfig ("zimbra_uid", $uid);
  setLocalConfig ("zimbra_gid", $gid);
  setLocalConfig ("zimbra_user", "zimbra");

  if (defined $config{AVUSER}) {
    setLocalConfig ("av_notify_user", $config{AVUSER})
  }
  if (defined $config{AVDOMAIN}) {
    setLocalConfig ("av_notify_domain", $config{AVDOMAIN})
  }

  setLocalConfig ("ssl_allow_untrusted_certs", "TRUE");
  setLocalConfig ("mysql_memory_percent", $config{MYSQLMEMORYPERCENT});
  setLocalConfig ("mailboxd_java_heap_memory_percent", $config{MAILBOXDMEMORYPERCENT});
  setLocalConfig ("mailboxd_directory", $config{mailboxd_directory});
  setLocalConfig ("mailboxd_keystore", $config{mailboxd_keystore});
  setLocalConfig ("mailboxd_server", $config{mailboxd_server});
  setLocalConfig ("mailboxd_truststore", "$config{mailboxd_truststore}");
  setLocalConfig ("mailboxd_truststore_password", "$config{mailboxd_truststore_password}");
  setLocalConfig ("mailboxd_keystore_password", "$config{mailboxd_keystore_password}");
  setLocalConfig ("zimbra_ldap_userdn", "$config{zimbra_ldap_userdn}");
  setLocalConfig ("ldap_dit_base_dn_config", "$config{ldap_dit_base_dn_config}")
    if ($config{ldap_dit_base_dn_config} ne "cn=zimbra");

  configLog ("configLCValues");

  progress ("done.\n");

}

sub configCASetup {

  if ($configStatus{configCASetup} eq "CONFIGURED") {
    configLog("configCASetup");
    return 0;
  }

  if ($config{LDAPHOST} ne $config{HOSTNAME}) {
    # fetch it from ldap if ldap has been configed
    progress("Updating ldap_root_password and zimbra_ldap_password...");
    setLocalConfig ("ldap_root_password", $config{LDAPROOTPASS});
    setLocalConfig ("zimbra_ldap_password", $config{LDAPADMINPASS});
    progress ( "done.\n" );
  }
  progress ( "Setting up CA..." );
  if (! $newinstall) {
    if (-f "/opt/zimbra/conf/ca/ca.pem") {
      my $rc = runAsRoot("openssl verify -purpose sslserver -CAfile /opt/zimbra/conf/ca/ca.pem /opt/zimbra/conf/ca/ca.pem | egrep \"^error 10\"");
      $needNewCert = "-new" if ($rc == 0);
    }
  } 
  my $rc = runAsRoot("/opt/zimbra/bin/zmcertmgr createca $needNewCert");
  if ($rc != 0) {
    progress ( "failed.\n" );
    exit 1;
  } else {
    progress ( "done.\n" );
  }

  progress ( "Deploying CA to /opt/zimbra/conf/ca ..." );
  my $rc = runAsRoot("/opt/zimbra/bin/zmcertmgr deployca -localonly");
  if ($rc != 0) {
    progress ( "failed.\n" );
    exit 1;
  } else {
    progress ( "done.\n" );
  }

    
  configLog("configCASetup");
}

sub configSetupLdap {

  if ($configStatus{configSetupLdap} eq "CONFIGURED") {
    detail("ldap already configured bypassing configuration\n");
    configLog("configSetupLdap");
    return 0;
  }

  if (!$ldapConfigured && isEnabled("zimbra-ldap") && ! -f "/opt/zimbra/.enable_replica" && $newinstall && ($config{LDAPHOST} eq $config{HOSTNAME})) {
    progress ( "Initializing ldap..." ) ;
    if (my $rc = runAsZimbra("/opt/zimbra/libexec/zmldapinit $config{LDAPROOTPASS} $config{LDAPADMINPASS}")) {
      progress ( "failed. ($rc)\n" );
      failConfig();
    } else {
      progress ( "done.\n" );
      if ($ldapRepChanged == 1) {
         progress ( "Setting replication password..." );
         runAsZimbra ("/opt/zimbra/bin/zmldappasswd -l $config{LDAPREPPASS}");
         progress ( "done.\n" );
      }
      if ($ldapPostChanged == 1) {
         progress ( "Setting Postfix password..." );
         runAsZimbra ("/opt/zimbra/bin/zmldappasswd -p $config{LDAPPOSTPASS}");
         progress ( "done.\n" );
      }
      if ($ldapAmavisChanged == 1) {
         progress ( "Setting amavis password..." );
         runAsZimbra ("/opt/zimbra/bin/zmldappasswd -a $config{LDAPAMAVISPASS}");
         progress ( "done.\n" );
      }
    }
  } elsif (isEnabled("zimbra-ldap")) {
    # enable replica for both new and upgrade installs if we are adding ldap
    if ($config{LDAPHOST} ne $config{HOSTNAME} ||  -f "/opt/zimbra/.enable_replica") {
      progress("Updating ldap_root_password and zimbra_ldap_password...");
      setLocalConfig ("ldap_root_password", $config{LDAPROOTPASS});
      setLocalConfig ("zimbra_ldap_password", $config{LDAPADMINPASS});
      setLocalConfig ("ldap_replication_password", "$config{LDAPREPPASS}");
      progress("done.\n");
      progress ( "Enabling ldap replication..." );
      my $rc = runAsZimbra ("/opt/zimbra/libexec/zmldapenablereplica");
      if ( ! -f "/opt/zimbra/.enable_replica" ) {
         my $file="/opt/zimbra/.enable_replica";
         open(ER,">>$file");
         close ER;
      }
      if ($rc == 0) {
        #unlink "/opt/zimbra/.enable_replica";
        $config{DOCREATEADMIN} = "no";
        $config{DOCREATEDOMAIN} = "no";
        progress ( "done.\n" );
        progress("Stopping ldap...");
        runAsZimbra ("/opt/zimbra/bin/ldap stop");
        progress("done.\n");
        startLdap();
      } else {
        progress ("failed.\n");
        progress ("You will have to correct the problem and manually enable replication.\n");
        progress ("Disabling ldap on $config{HOSTNAME}...");
        runAsZimbra("$ZMPROV ms $config{HOSTNAME} -zimbraServiceEnabled ldap");
        progress ("done.\n");
        progress("Stopping ldap...");
        runAsZimbra ("/opt/zimbra/bin/ldap stop");
        progress("done.\n");
      }
    }


    # zmldappasswd starts ldap and re-applies the ldif
    if ($ldapRootPassChanged || $ldapAdminPassChanged || $ldapRepChanged || $ldapPostChanged || $ldapAmavisChanged) {
      if ($ldapRootPassChanged) {
         progress ( "Setting ldap root password..." );
         runAsZimbra ("/opt/zimbra/bin/zmldappasswd -r $config{LDAPROOTPASS}");
         progress ( "done.\n" );
      }
      if ($ldapAdminPassChanged) {
         progress ( "Setting ldap admin password..." );
         if ($config{LDAPHOST} eq $config{HOSTNAME} ) {
           runAsZimbra ("/opt/zimbra/bin/zmldappasswd $config{LDAPADMINPASS}");
         } else {
           setLocalConfig ("zimbra_ldap_password", "$config{LDAPADMINPASS}");
         }
         progress ( "done.\n" );
      }
      if ($ldapRepChanged == 1) {
         progress ( "Setting replication password..." );
         if ($config{LDAPHOST} eq $config{HOSTNAME} ) {
           runAsZimbra ("/opt/zimbra/bin/zmldappasswd -l $config{LDAPREPPASS}");
         } else {
           setLocalConfig ("ldap_replication_password", "$config{LDAPREPPASS}");
         }
         progress ( "done.\n" );
      }
      if ($ldapPostChanged == 1) {
         progress ( "Setting Postfix password..." );
         if ($config{LDAPHOST} eq $config{HOSTNAME} ) {
           runAsZimbra ("/opt/zimbra/bin/zmldappasswd -p $config{LDAPPOSTPASS}");
         } else {
           setLocalConfig ("ldap_postfix_password", "$config{LDAPPOSTPASS}");
         }
         progress ( "done.\n" );
      }
      if ($ldapAmavisChanged == 1) {
         progress ( "Setting amavis password..." );
         if ($config{LDAPHOST} eq $config{HOSTNAME} ) {
           runAsZimbra ("/opt/zimbra/bin/zmldappasswd -a $config{LDAPAMAVISPASS}");
         } else {
           setLocalConfig ("ldap_amavis_password", "$config{LDAPAMAVISPASS}");
        }
         progress ( "done.\n" );
      }
    } else {
      progress("Stopping ldap...");
      runAsZimbra ("/opt/zimbra/bin/ldap stop");
      progress("done.\n");
      startLdap();
    }
  } else {
    detail("Updating ldap user passwords\n");
    setLocalConfig ("ldap_root_password", $config{LDAPROOTPASS});
    setLocalConfig ("zimbra_ldap_password", $config{LDAPADMINPASS});
    setLocalConfig ("ldap_replication_password", "$config{LDAPREPPASS}");
    setLocalConfig ("ldap_postfix_password", "$config{LDAPPOSTPASS}");
    setLocalConfig ("ldap_amavis_password", "$config{LDAPAMAVISPASS}");
  }
  # set default zmprov bahaviour
  if (isEnabled("zimbra-ldap")) {
    if (isEnabled("zimbra-store")) {
      setLocalConfig ("zimbra_zmprov_default_to_ldap", "FALSE");
    } else {
      setLocalConfig ("zimbra_zmprov_default_to_ldap", "TRUE");
    }
  }

  configLog("configSetupLdap");
  return 0;

}

sub configSaveCA {

  if ($configStatus{configSaveCA} eq "CONFIGURED") {
    configLog("configSaveCA");
    return 0;
  }
  progress ( "Saving CA in ldap ..." );
  my $rc = runAsRoot("/opt/zimbra/bin/zmcertmgr deployca");
  if ($rc != 0) {
    progress ( "failed.\n" );
    exit 1;
  } else {
    progress ( "done.\n" );
  }
  configLog("configSaveCA");
}

sub configCreateCert {

  if ($configStatus{configCreateCert} eq "CONFIGURED") {
    configLog("configCreateCert");
    return 0;
  }

  if (!$newinstall) {
    my $rc = runAsRoot("/opt/zimbra/bin/zmcertmgr verifycrt comm > /dev/null 2>&1");
    if ($rc != 0) {
      $rc = runAsRoot("/opt/zimbra/bin/zmcertmgr verifycrt self > /dev/null 2>&1");
      if ($rc != 0) {
        progress("Warning: No valid SSL certificates were found.\n");
        progress("New self-signed certificates will be generated and installed.\n");
        $needNewCert = "-new" if ($rc != 0);
        $ssl_cert_type="self";
      }
    } else {
      $ssl_cert_type="comm";
    }
  }

  my $rc;
  if (isInstalled("zimbra-store")) {
    if ( !-f "$config{mailboxd_keystore}" && !-f "/opt/zimbra/ssl/zimbra/server/server.crt" ) {
      if (!-d "$config{mailboxd_directory}") {
        `mkdir -p $config{mailboxd_directory}/etc`;
        `chown -R zimbra:zimbra $config{mailboxd_directory}`;
        `chmod 744 $config{mailboxd_directory}/etc`;
      }
      progress ( "Creating SSL certificate..." );
      $rc = runAsRoot("/opt/zimbra/bin/zmcertmgr createcrt self $needNewCert");
      if ($rc != 0) {
        progress ( "failed.\n" );
        exit 1;
      } else {
        progress ( "done.\n" );
      }
    } elsif ( $needNewCert ne "" && $ssl_cert_type eq "self") {
      progress ( "Creating SSL certificate..." );
      $rc = runAsRoot("/opt/zimbra/bin/zmcertmgr createcrt self $needNewCert");
      if ($rc != 0) {
        progress ( "failed.\n" );
        exit 1;
      } else {
        progress ( "done.\n" );
      }
    }
  }

  if (isInstalled("zimbra-ldap")) {
    if ( !-f "/opt/zimbra/conf/slapd.crt" && !-f "/opt/zimbra/ssl/zimbra/server/server.crt") {
      progress ( "Creating SSL certificate..." );
      $rc = runAsRoot("/opt/zimbra/bin/zmcertmgr createcrt self $needNewCert");
      if ($rc != 0) {
        progress ( "failed.\n" );
        exit 1;
      } else {
        progress ( "done.\n" );
      }
    } elsif ( $needNewCert ne "" && $ssl_cert_type eq "self") {
      progress ( "Creating SSL certificate..." );
      $rc = runAsRoot("/opt/zimbra/bin/zmcertmgr createcrt self $needNewCert");
      if ($rc != 0) {
        progress ( "failed.\n" );
        exit 1;
      } else {
        progress ( "done.\n" );
      }
    }
  }

  if (isInstalled("zimbra-mta")) {
    if ( !-f "/opt/zimbra/conf/smtpd.crt" && !-f "/opt/zimbra/ssl/zimbra/server/server.crt") {
      progress ( "Creating SSL certificate..." );
      $rc = runAsRoot("/opt/zimbra/bin/zmcertmgr createcrt self $needNewCert");
      if ($rc != 0) {
        progress ( "failed.\n" );
        exit 1;
      } else {
        progress ( "done.\n" );
      }
    } elsif ( $needNewCert ne "" && $ssl_cert_type eq "self") {
      progress ( "Creating SSL certificate..." );
      $rc = runAsRoot("/opt/zimbra/bin/zmcertmgr createcrt self $needNewCert");
      if ($rc != 0) {
        progress ( "failed.\n" );
        exit 1;
      } else {
        progress ( "done.\n" );
      }
    }
  }

  if (isInstalled("zimbra-proxy")) {
    if ( !-f "/opt/zimbra/conf/nginx.crt" && !-f "/opt/zimbra/ssl/zimbra/server/server.crt") {
      progress ( "Creating SSL certificate..." );
      $rc = runAsRoot("/opt/zimbra/bin/zmcertmgr createcrt self $needNewCert");
      if ($rc != 0) {
        progress ( "failed.\n" );
        exit 1;
      } else {
        progress ( "done.\n" );
      }
    } elsif ( $needNewCert ne "" && $ssl_cert_type eq "self") {
      progress ( "Creating SSL certificate..." );
      $rc = runAsRoot("/opt/zimbra/bin/zmcertmgr createcrt self $needNewCert");
      if ($rc != 0) {
        progress ( "failed.\n" );
        exit 1;
      } else {
        progress ( "done.\n" );
      }
    }
  }

  configLog("configCreateCert");
}

sub configInstallCert {

  if ($configStatus{configInstallCert} eq "CONFIGURED") {
    configLog("configInstallCert");
    return 0;
  }
  my $rc;
  if (isEnabled("zimbra-store")) {
    if (!-f "$config{mailboxd_keystore}") {
      progress ("Installing SSL certificates...");
      $rc = runAsRoot("/opt/zimbra/bin/zmcertmgr deploycrt self $needNewCert");
      if ($rc != 0) {
        progress ( "failed.\n" );
        exit 1;
      } else {
        progress ( "done.\n" );
      }
    }
  }

  if (isEnabled("zimbra-mta")) {
    if (! (-f "/opt/zimbra/conf/smtpd.key" || 
      -f "/opt/zimbra/conf/smtpd.crt")) {
      progress ("Installing SSL certificates...");
      $rc = runAsRoot("/opt/zimbra/bin/zmcertmgr deploycrt self $needNewCert");
      if ($rc != 0) {
        progress ( "failed.\n" );
        exit 1;
      } else {
        progress ( "done.\n" );
      }
    }
  }

  if (isEnabled("zimbra-ldap")) {
    if (! (-f "/opt/zimbra/conf/slapd.key" || 
      -f "/opt/zimbra/conf/slapd.crt")) {
      progress ("Installing LDAP SSL certificate...");
      $rc = runAsRoot("/opt/zimbra/bin/zmcertmgr deploycrt self $needNewCert");
      if ($rc != 0) {
        progress ( "failed.\n" );
        exit 1;
      } else {
        progress ( "done.\n" );
      }
    }
  }

  if (isEnabled("zimbra-proxy")) {
    if (! (-f "/opt/zimbra/conf/nginx.key" || 
      -f "/opt/zimbra/conf/nginx.crt")) {
      progress ("Installing Proxy SSL certificate...");
      $rc = runAsRoot("/opt/zimbra/bin/zmcertmgr deploycrt self $needNewCert");
      if ($rc != 0) {
        progress ( "failed.\n" );
        exit 1;
      } else {
        progress ( "done.\n" );
      }
    }
  }

  configLog("configInstallCert");
}

sub configCreateServerEntry {

  if ($configStatus{configCreateServerEntry} eq "CONFIGURED") {
    configLog("configCreateServerEntry");
    return 0;
  }

  progress ( "Creating server entry for $config{HOSTNAME}..." );
  runAsZimbra("$ZMPROV cs $config{HOSTNAME}");
  progress ( "done.\n" );
  configLog("configCreateServerEntry");
}

sub configSpellServer {
  if ($configStatus{configSpellServer} eq "CONFIGURED") {
    configLog("configSpellServer");
    return 0;
  }

  if ($config{USESPELL} eq "yes") {
    progress ( "Setting spell check URL..." );
    runAsZimbra("$ZMPROV ms $config{HOSTNAME} ".
      "zimbraSpellCheckURL $config{SPELLURL}");
    progress ( "done.\n" );
  }

  configLog("configSpellServer");
}

sub configSetMtaAuthHost {

  if ($configStatus{configSetMtaAuthHost} eq "CONFIGURED") {
    configLog("configSetMtaAuthHost");
    return 0;
  }

  if (isEnabled ("zimbra-ldap") && ! isEnabled ("zimbra-store")) {
    progress ( "WARNING\n\nYou are configuring this host as an MTA server, but there are no\n");
    progress ( "currently configured mailstore servers.  This will cause smtp authentication\n");
    progress ( "to fail.\n");
    progress ( "To correct this - after installing a mailstore server, reset the zimbraMtaAuthHost\n");
    progress ( "attribute for this server:\n");
    progress ( "$ZMPROV ms $config{HOSTNAME} zimbraMtaAuthHost $config{MTAAUTHHOST}\n\n");
    progress ( "\nOnce done, start the MTA:\n");
    progress ( "zmmtactl start\n\n");
    if (!$options{c}) {
      ask ("Press return to continue\n","");
    }
  }
  if ($config{MTAAUTHHOST} ne "") {
    progress ( "Setting MTA auth host..." );
    runAsZimbra("$ZMPROV ms $config{HOSTNAME} ".
      "zimbraMtaAuthHost $config{MTAAUTHHOST}");
    progress ( "done.\n" );
  }

  configLog("configSetMtaAuthHost");
}

sub configSetStoreDefaults {
  runAsZimbra("$ZMPROV ms $config{HOSTNAME} zimbraReverseProxyLookupTarget TRUE");
}

sub configSetServicePorts {

  if ($configStatus{configSetServicePorts} eq "CONFIGURED") {
    configLog("configSetServicePorts");
    return 0;
  }

  progress ( "Setting service ports on $config{HOSTNAME}..." );
  runAsZimbra("$ZMPROV ms $config{HOSTNAME} ".
    "zimbraImapBindPort $config{IMAPPORT} zimbraImapSSLBindPort $config{IMAPSSLPORT} ".
    "zimbraImapProxyBindPort $config{IMAPPROXYPORT} zimbraImapSSLProxyBindPort $config{IMAPSSLPROXYPORT} ");
  runAsZimbra("$ZMPROV ms $config{HOSTNAME} ".
    "zimbraPop3BindPort $config{POPPORT} zimbraPop3SSLBindPort $config{POPSSLPORT} ".
    "zimbraPop3ProxyBindPort $config{POPPROXYPORT} zimbraPop3SSLProxyBindPort $config{POPSSLPROXYPORT} ");
  runAsZimbra("$ZMPROV ms $config{HOSTNAME} ".
    "zimbraMailPort $config{HTTPPORT} zimbraMailSSLPort $config{HTTPSPORT} ".
    "zimbraMailProxyPort $config{HTTPPROXYPORT} zimbraMailSSLProxyPort $config{HTTPSPROXYPORT} ".
    "zimbraMailMode $config{MODE}");

  progress ( "done.\n" );
  configLog("configSetServicePorts");
}

sub configSetInstalledSkins {
  if ($configStatus{configSetInstalledSkins} eq "CONFIGURED") {
    configLog("configSetInstalledSkins");
    return 0;
  }

  if (opendir DIR, "$config{mailboxd_directory}/webapps/zimbra/skins") {
    progress ( "Installing skins... " );
    runAsZimbra("$ZMPROV mcf zimbraInstalledSkin ''");
    my @skins = grep { !/^[\._]/ } readdir(DIR);
    foreach my $skindir (@skins) {
      if (-d "$config{mailboxd_directory}/webapps/zimbra/skins/$skindir") {
        my $skin = $skindir;
        runAsZimbra("$ZMPROV mcf +zimbraInstalledSkin $skin");
        print  ("\n\t$skin");
      }
    }
    progress ( "\ndone.\n" );
  }

  configLog("configSetInstalledSkins");
}

sub configSetKeyboardShortcutsPref {
  if ($configStatus{zimbraPrefUseKeyboardShortcuts} eq "CONFIGURED") {
    configLog("zimbraPrefUseKeyboardShortcuts");
    return 0;
  }
  progress ( "Setting Keyboard Shortcut Preferences...");
  runAsZimbra("$ZMPROV mc default zimbraPrefUseKeyboardShortcuts $config{USEKBSHORTCUTS}");
  progress ( "done.\n" );
  configLog("zimbraPrefUseKeyboardShortcuts");
}

sub configSetTimeZonePref {
  if ($configStatus{zimbraPrefTimeZoneId} eq "CONFIGURED") {
    configLog("zimbraPrefTimeZoneId");
    return 0;
  }
  progress ( "Setting TimeZone Preference...");
  runAsZimbra("$ZMPROV mc default zimbraPrefTimeZoneId \'$config{zimbraPrefTimeZoneId}\'");
  progress ( "done.\n" );
  configLog("zimbraPrefTimeZoneId");
}

sub configSetCEFeatures {
  foreach my $feature qw(IM Tasks Briefcases Notebook) {
    my $key = "zimbraFeature${feature}Enabled";
    my $val = ($config{$key} eq "Enabled" ? "TRUE" : "FALSE");; 
    if ($configStatus{$key} eq "CONFIGURED") {
      configLog($key);
      next;
    }
    progress ( "Setting $key=$val...");
    runAsZimbra("$ZMPROV mc default $key \'$val\'");
    progress ( "done.\n" );
    configLog($key);
  }
}

sub configSetNEFeatures {
  return unless isNetwork();
}

sub configInitBackupPrefs {
  if (isEnabled("zimbra-store") && isNetwork()) {
    runAsZimbra("$ZMPROV mcf zimbraBackupReportEmailRecipients $config{zimbraBackupReportEmailRecipients}");
    runAsZimbra("$ZMPROV mcf zimbraBackupReportEmailSender $config{zimbraBackupReportEmailSender}");
  }
}

sub setProxyBits {
  detail("Setting Proxy pieces\n");
  my $zimbraReverseProxyMailHostQuery =
        "\(\|\(zimbraMailDeliveryAddress=\${USER}\)\(zimbraMailAlias=\${USER}\)\)";
  my $zimbraReverseProxyDomainNameQuery =
        '\(\&\(zimbraVirtualIPAddress=\${IPADDR}\)\(objectClass=zimbraDomain\)\)';
  my $zimbraReverseProxyPortQuery =
        '\(\&\(zimbraServiceHostname=\${MAILHOST}\)\(objectClass=zimbraServer\)\)';
  open(ZMPROV, "|su - zimbra -c 'zmprov -l'");

  print ZMPROV "mcf zimbraReverseProxyMailHostQuery $zimbraReverseProxyMailHostQuery\n"
    if(getLdapConfigValue("zimbraReverseProxyMailHostQuery") eq "");

  print ZMPROV "mcf zimbraReverseProxyPortQuery $zimbraReverseProxyPortQuery\n"
    if(getLdapConfigValue("zimbraReverseProxyPortQuery") eq "");

  print ZMPROV "mcf zimbraReverseProxyDomainNameQuery $zimbraReverseProxyDomainNameQuery\n"
    if(getLdapConfigValue("zimbraReverseProxyDomainNameQuery") eq "");

  print ZMPROV "mcf zimbraMemcachedBindPort 11211\n"
    if(getLdapConfigValue("zimbraMemcachedBindPort") eq "");

  print ZMPROV "mcf zimbraReverseProxyMailHostAttribute zimbraMailHost\n"
    if(getLdapConfigValue("zimbraReverseProxyMailHostAttribute") eq "");

  print ZMPROV "mcf zimbraReverseProxyPop3PortAttribute zimbraPop3BindPort\n"
    if(getLdapConfigValue("zimbraReverseProxyPop3PortAttribute") eq "");

  print ZMPROV "mcf zimbraReverseProxyPop3SSLPortAttribute zimbraPop3SSLBindPort\n"
    if(getLdapConfigValue("zimbraReverseProxyPop3SSLPortAttribute") eq "");

  print ZMPROV "mcf zimbraReverseProxyImapPortAttribute zimbraImapBindPort\n"
    if(getLdapConfigValue("zimbraReverseProxyImapPortAttribute") eq "");

  print ZMPROV "mcf zimbraReverseProxyImapSSLPortAttribute zimbraImapSSLBindPort\n"
    if(getLdapConfigValue("zimbraReverseProxyImapSSLPortAttribute") eq "");

  print ZMPROV "mcf zimbraReverseProxyDomainNameAttribute zimbraDomainName\n"
    if(getLdapConfigValue("zimbraReverseProxyDomainNameAttribute") eq "");

  print ZMPROV "mcf zimbraImapCleartextLoginEnabled FALSE\n"
    if(getLdapConfigValue("zimbraImapCleartextLoginEnabled") eq "");

  print ZMPROV "mcf zimbraPop3CleartextLoginEnabled FALSE\n"
    if(getLdapConfigValue("zimbraPop3CleartextLoginEnabled") eq "");
 
  print ZMPROV "mcf zimbraReverseProxyAuthWaitInterval 10s\n"
    if(getLdapConfigValue("zimbraReverseProxyAuthWaitInterval") eq "");

  print ZMPROV "mcf zimbraReverseProxyIPLoginLimit 0\n"
    if(getLdapConfigValue("zimbraReverseProxyIPLoginLimit") eq "");

  print ZMPROV "mcf zimbraReverseProxyIPLoginLimitTime 3600\n"
    if(getLdapConfigValue("zimbraReverseProxyIPLoginLimitTime") eq "");

  print ZMPROV "mcf zimbraReverseProxyUserLoginLimit 0\n"
    if(getLdapConfigValue("zimbraReverseProxyUserLoginLimit") eq "");

  print ZMPROV "mcf zimbraReverseProxyUserLoginLimitTime 3600\n"
    if(getLdapConfigValue("zimbraReverseProxyUserLoginLimitTime") eq "");

  print ZMPROV "mcf zimbraMailProxyPort 0\n"
    if(getLdapConfigValue("zimbraMailProxyPort") eq "");

  print ZMPROV "mcf zimbraMailSSLProxyPort 0\n"
    if(getLdapConfigValue("zimbraMailSSLProxyPort") eq "");

  print ZMPROV "mcf zimbraReverseProxyHttpEnabled FALSE\n"
    if(getLdapConfigValue("zimbraReverseProxyHttpEnabled") eq "");

  print ZMPROV "mcf zimbraReverseProxyMailEnabled TRUE\n"
    if(getLdapConfigValue("zimbraReverseProxyMailEnabled") eq "");

  close ZMPROV;
}

sub configSetProxyPrefs {
   if (isEnabled("zimbra-proxy")) {
     if ($config{MAILPROXY} eq "FALSE" && $config{HTTPPROXY} eq "FALSE") {
        $enabledPackages{"zimbra-proxy"} = "Disabled";
     } else {
        if($config{MAILPROXY} eq "TRUE") {
           if ((($config{IMAPPORT} == 143 || $config{IMAPPORT} == 7143) &&
                ($config{IMAPPROXYPORT} == 143 || $config{IMAPPROXYPORT} == 7143)) &&
               (($config{IMAPSSLPORT} == 993 || $config{IMAPSSLPORT} == 7993) &&
                ($config{IMAPSSLPROXYPORT} == 993 || $config{IMAPSSLPROXYPORT} == 7993)) &&
               (($config{POPPORT} == 110 || $config{POPPORT} == 7110) &&
                ($config{POPPROXYPORT} == 110 || $config{POPPROXYPORT} == 7110)) &&
               (($config{POPSSLPORT} == 995 || $config{POPSSLPORT} == 7995) &&
                ($config{POPSSLPROXYPORT} == 995 || $config{POPSSLPROXYPORT} == 7995)))
           {
             runAsRoot("/opt/zimbra/libexec/zmproxyinit -m -e $config{HOSTNAME}");
           }
           runAsZimbra("$ZMPROV ms $config{HOSTNAME} zimbraImapCleartextLoginEnabled TRUE");
           runAsZimbra("$ZMPROV ms $config{HOSTNAME} zimbraPop3CleartextLoginEnabled TRUE");
        } else {
            if ((($config{IMAPPORT} == 143 || $config{IMAPPORT} == 7143) &&
             ($config{IMAPPROXYPORT} == 143 || $config{IMAPPROXYPORT} == 7143)) &&
            (($config{IMAPSSLPORT} == 993 || $config{IMAPSSLPORT} == 7993) &&
             ($config{IMAPSSLPROXYPORT} == 993 || $config{IMAPSSLPROXYPORT} == 7993)) &&
            (($config{POPPORT} == 110 || $config{POPPORT} == 7110) &&
             ($config{POPPROXYPORT} == 110 || $config{POPPROXYPORT} == 7110)) &&
            (($config{POPSSLPORT} == 995 || $config{POPSSLPORT} == 7995) &&
             ($config{POPSSLPROXYPORT} == 995 || $config{POPSSLPROXYPORT} == 7995)))
            {
               runAsRoot("/opt/zimbra/libexec/zmproxyinit -m -d $config{HOSTNAME}");
            }
        }
        if ($config{HTTPPROXY} eq "TRUE" ) {
           if ((($config{HTTPPORT} == 80 || $config{HTTPPORT} == 8080) &&
                ($config{HTTPPROXYPORT} == 80 || $config{HTTPPROXYPORT} == 8080)) &&
               (($config{HTTPSPORT} == 443 || $config{HTTPSPORT} == 8443) &&
                ($config{HTTPSPROXYPORT} == 8443 || $config{HTTPSPROXYPORT} == 8443)))
           {
             runAsRoot("/opt/zimbra/libexec/zmproxyinit -w -e $config{HOSTNAME}");
           }
        } else {
           if ((($config{HTTPPORT} == 80 || $config{HTTPPORT} == 8080) &&
                ($config{HTTPPROXYPORT} == 80 || $config{HTTPPROXYPORT} == 8080)) &&
               (($config{HTTPSPORT} == 443 || $config{HTTPSPORT} == 8443) &&
                ($config{HTTPSPROXYPORT} == 8443 || $config{HTTPSPROXYPORT} == 8443)))
           {
             runAsRoot("/opt/zimbra/libexec/zmproxyinit -w -d $config{HOSTNAME}");
           }
        }
     }
   } else {
     if ((($config{IMAPPORT} == 143 || $config{IMAPPORT} == 7143) &&
          ($config{IMAPPROXYPORT} == 143 || $config{IMAPPROXYPORT} == 7143)) &&
         (($config{IMAPSSLPORT} == 993 || $config{IMAPSSLPORT} == 7993) &&
          ($config{IMAPSSLPROXYPORT} == 993 || $config{IMAPSSLPROXYPORT} == 7993)) &&
         (($config{POPPORT} == 110 || $config{POPPORT} == 7110) &&
          ($config{POPPROXYPORT} == 110 || $config{POPPROXYPORT} == 7110)) &&
         (($config{POPSSLPORT} == 995 || $config{POPSSLPORT} == 7995) &&
          ($config{POPSSLPROXYPORT} == 995 || $config{POPSSLPROXYPORT} == 7995)))
      {
        runAsRoot("/opt/zimbra/libexec/zmproxyinit -m -d $config{HOSTNAME}");
      }
      if ((($config{HTTPPORT} == 80 || $config{HTTPPORT} == 8080) &&
           ($config{HTTPPROXYPORT} == 80 || $config{HTTPPROXYPORT} == 8080)) &&
          (($config{HTTPSPORT} == 443 || $config{HTTPSPORT} == 8443) &&
           ($config{HTTPSPROXYPORT} == 8443 || $config{HTTPSPROXYPORT} == 8443)))
      {
        runAsRoot("/opt/zimbra/libexec/zmproxyinit -w -d $config{HOSTNAME}");
      }
   }
}

sub configSetCluster {
  runAsZimbra("$ZMPROV mcf zimbraClusterType $config{zimbraClusterType}"); 
}

sub zimletCleanup {
  my $ldap_pass = getLocalConfig("zimbra_ldap_password");
  my $ldap_master_url = getLocalConfig("ldap_master_url");
  my $ldap;
  unless($ldap = Net::LDAP->new($ldap_master_url)) {
    detail("Unable to contact $ldap_master_url: $!");
    return 1;
  }
  my $ldap_dn = $config{zimbra_ldap_userdn};
  my $ldap_base = "cn=zimlets,$config{ldap_dit_base_dn_config}";

  my $result = $ldap->bind($ldap_dn, password => $ldap_pass);
  if ($result->code()) {
    detail("ldap bind failed for $ldap_dn");
    return 1;
  } else {
    detail("ldap bind done for $ldap_dn");
    $result = $ldap->search(base => $ldap_base, scope => 'one', filter => "(|(cn=convertd)(cn=cluster)(cn=hsm)(cn=hotbackup)(cn=zimbra_cert_manager)(cn=com_zimbra_search))", attrs => ['zimbraZimletKeyword']);
    return $result if ($result->code());
    detail("processing ldap search results");
    foreach my $entry ($result->all_entries) {
      my $zimlet = $entry->get_value('zimbraZimletKeyword');
      detail("Removing $zimlet");
      runAsZimbra("/opt/zimbra/bin/zmzimletctl undeploy $zimlet")
    }
  }
  $result = $ldap->unbind;
  return 0;
}

sub configInstallZimlets {

  if ($configStatus{configInstallZimlets} eq "CONFIGURED") {
    configLog("configInstallZimlets");
    return 0;
  }

  # cleanup renamed zimlets, this is really an upgrade task but
  # mailboxd needs to be be running here.
  progress("Checking for deprecated zimlets...");
  if (zimletCleanup()) {
    progress("failed.\n");
  } else {
    progress("done.\n");
  }

  # Install zimlets
  if (opendir DIR, "/opt/zimbra/zimlets") {
    progress ( "Installing zimlets... " );
    my @zimlets = grep { !/^\./ } readdir(DIR);
    foreach my $zimletfile (@zimlets) {
      my $zimlet = $zimletfile;
      $zimlet =~ s/\.zip$//;
      progress  ("\n\t$zimlet");
      runAsZimbra ("/opt/zimbra/bin/zmzimletctl -l deploy zimlets/$zimletfile");
    }
    progress ( "\ndone.\n" );
  }

  # Install zimlets
  if (opendir DIR, "/opt/zimbra/zimlets-network") {
    progress ( "Installing network zimlets... " );
    my @zimlets = grep { !/^\./ } readdir(DIR);
    foreach my $zimletfile (@zimlets) {
      my $zimlet = $zimletfile;
      $zimlet =~ s/\.zip$//;
      progress  ("\n\t$zimlet");
      runAsZimbra ("/opt/zimbra/bin/zmzimletctl -l deploy zimlets-network/$zimletfile");
    }
    progress ( "\ndone.\n" );
  }

  configLog("configInstallZimlets");
}

sub configCreateDomain {

  if ($configStatus{configCreateDomain} eq "CONFIGURED") {
    configLog("configCreateDomain");
    return 0;
  }

  if (!$ldapConfigured && isEnabled("zimbra-ldap")) {
    if ($config{DOCREATEDOMAIN} eq "yes") {
      progress ( "Creating domain $config{CREATEDOMAIN}..." );
      runAsZimbra("$ZMPROV cd $config{CREATEDOMAIN}");
      runAsZimbra("$ZMPROV mcf zimbraDefaultDomainName $config{CREATEDOMAIN}");
      progress ( "done.\n" );

    }
  }
  if (isEnabled("zimbra-store")) {
    if ($config{DOCREATEADMIN} eq "yes") {
      $config{CREATEADMIN} = lc($config{CREATEADMIN});
      progress ( "Creating user $config{CREATEADMIN}..." );
      my ($u,$d) = split ('@', $config{CREATEADMIN});
      runAsZimbra("$ZMPROV cd $d");
      runAsZimbra("$ZMPROV ca ".
        "$config{CREATEADMIN} \'$config{CREATEADMINPASS}\' ".
        "zimbraIsAdminAccount TRUE");
      progress ( "done.\n" );

      progress ( "Creating postmaster alias..." );
      runAsZimbra("$ZMPROV aaa ".
        "$config{CREATEADMIN} root\@$config{CREATEDOMAIN}");
      runAsZimbra("$ZMPROV aaa ".
        "$config{CREATEADMIN} postmaster\@$config{CREATEDOMAIN}");
      progress ( "done.\n" );

      $config{NOTEBOOKACCOUNT} = lc($config{NOTEBOOKACCOUNT});
      progress ( "Creating user $config{NOTEBOOKACCOUNT}..." );
      runAsZimbra("$ZMPROV ca ".
        "$config{NOTEBOOKACCOUNT} \'$config{NOTEBOOKPASS}\' ".
        "amavisBypassSpamChecks TRUE ".
        "zimbraAttachmentsIndexingEnabled FALSE ".
        "zimbraIsSystemResource TRUE ".
        "zimbraHideInGal TRUE ".
        "zimbraMailQuota 0 ".
        "description \'Global Documents account\'");
      progress ( "done.\n" );
    }
    if ($config{DOTRAINSA} eq "yes") {
      $config{TRAINSASPAM} = lc($config{TRAINSASPAM});
      progress ( "Creating user $config{TRAINSASPAM}..." );
      my $pass = genRandomPass();
      runAsZimbra("$ZMPROV ca ".
        "$config{TRAINSASPAM} \'$pass\' ".
        "amavisBypassSpamChecks TRUE ".
        "zimbraAttachmentsIndexingEnabled FALSE ".
        "zimbraIsSystemResource TRUE ".
        "zimbraHideInGal TRUE ".
        "zimbraMailQuota 0 ".
        "description \'Spam training account\'");
      progress ( "done.\n" );

      $config{TRAINSAHAM} = lc($config{TRAINSAHAM});
      progress ( "Creating user $config{TRAINSAHAM}..." );
        runAsZimbra("$ZMPROV ca ".
        "$config{TRAINSAHAM} \'$pass\' ".
        "amavisBypassSpamChecks TRUE ".
        "zimbraAttachmentsIndexingEnabled FALSE ".
        "zimbraIsSystemResource TRUE ".
        "zimbraHideInGal TRUE ".
        "zimbraMailQuota 0 ".
        "description \'Spam training account\'");
      progress ( "done.\n" );

      progress ( "Setting spam training accounts..." );
      runAsZimbra("$ZMPROV mcf ".
        "zimbraSpamIsSpamAccount $config{TRAINSASPAM} ".
        "zimbraSpamIsNotSpamAccount $config{TRAINSAHAM}");
      progress ( "done.\n" );
    }
  }
  configLog("configCreateDomain");
}

sub configInitSql {

  if ($configStatus{configInitSql} eq "CONFIGURED") {
    configLog("configInitSql");
    return 0;
  }

  if (!$sqlConfigured && isEnabled("zimbra-store")) {
    progress ( "Initializing store sql database..." );
    runAsZimbra ("/opt/zimbra/libexec/zmmyinit");
    progress ( "done.\n" );
    progress ( "Setting zimbraSmtpHostname for $config{HOSTNAME}..." );
    runAsZimbra("$ZMPROV ms $config{HOSTNAME} ".
      "zimbraSmtpHostname $config{SMTPHOST}");
    progress ( "done.\n" );
  }
  configLog("configInitSql");
}

sub configInitLogger {

  if ($configStatus{configInitLogger} eq "CONFIGURED") {
    configLog("configInitLogger");
    return 0;
  }

  if (!$loggerSqlConfigured && isEnabled("zimbra-logger")) {
    progress ( "Initializing logger sql database..." );
    runAsZimbra ("/opt/zimbra/libexec/zmloggerinit");
    progress ( "done.\n" );
  } 

  if (isEnabled("zimbra-logger")) {
    runAsZimbra ("$ZMPROV mcf zimbraLogHostname $config{HOSTNAME}");
    setLocalConfig ("smtp_source", $config{SMTPSOURCE});
    setLocalConfig ("smtp_destination", $config{SMTPDEST});
  }
  configLog("configInitLogger");
}

sub configInitMta {

  if ($configStatus{configInitMta} eq "CONFIGURED") {
    configLog("configInitMta");
    return 0;
  }

  if (isEnabled("zimbra-mta")) {
    progress ( "Initializing mta config..." );

    setLocalConfig("postfix_mail_owner", $config{postfix_mail_owner});
    setLocalConfig("postfix_setgid_group", $config{postfix_setgid_group});

    runAsZimbra ("/opt/zimbra/libexec/zmmtainit $config{LDAPHOST} $config{LDAPPORT}");
    progress ( "done.\n" );
    $installedServiceStr .= "zimbraServiceInstalled antivirus ";
    $installedServiceStr .= "zimbraServiceInstalled antispam ";
    if ($config{RUNAV} eq "yes") {
      $enabledServiceStr .= "zimbraServiceEnabled antivirus ";
    }
    if ($config{RUNARCHIVING} eq "yes") {
      $installedServiceStr .= "zimbraServiceInstalled archiving ";
      $enabledServiceStr .= "zimbraServiceEnabled archiving ";
    }
    if ($config{RUNSA} eq "yes") {
      $enabledServiceStr .= "zimbraServiceEnabled antispam ";
    }

    runAsZimbra ("$ZMPROV ms $config{HOSTNAME} zimbraMtaMyNetworks \'$config{zimbraMtaMyNetworks}\'")
      if ($config{zimbraMtaMyNetworks} ne "");

      
  }
  configLog("configInitMta");
}

sub configInitSnmp {

  if ($configStatus{configInitSnmp} eq "CONFIGURED") {
    configLog("configInitSnmp");
    return 0;
  }

  if (isEnabled("zimbra-snmp")) {
    progress ( "Configuring SNMP..." );
    setLocalConfig ("snmp_notify", $config{SNMPNOTIFY});
    setLocalConfig ("smtp_notify", $config{SMTPNOTIFY});
    setLocalConfig ("snmp_trap_host", $config{SNMPTRAPHOST});
    setLocalConfig ("smtp_source", $config{SMTPSOURCE});
    setLocalConfig ("smtp_destination", $config{SMTPDEST});
    runAsZimbra ("/opt/zimbra/libexec/zmsnmpinit");
    progress ( "done.\n" );
  }
  configLog("configInitSnmp");
}

sub configInitNotebooks {

  if (isEnabled("zimbra-store")) {
    progress ( "Initializing Documents..." );
    my ($notebookUser, $notebookDomain, $globalWikiAcct);
    my $rc = 0;

    # get the default state
    my $zimbraFeatureNotebookEnabled = getLdapCOSValue("default", "zimbraFeatureNotebookEnabled");
    $zimbraFeatureNotebookEnabled = "FALSE" unless $zimbraFeatureNotebookEnabled;

    $globalWikiAcct = getLdapConfigValue("zimbraNotebookAccount");

    if ($globalWikiAcct eq "") {
      if ($config{NOTEBOOKACCOUNT} eq "") {
        open DOMAINS, "$ZMPROV gad|" or die "Can't get domain list!";
        my $domain = <DOMAINS>;
        close DOMAINS;
        chomp $domain;
        $config{NOTEBOOKACCOUNT} = "wiki.".lc(genRandomPass())."\@$domain";
        $config{NOTEBOOKPASS} = lc(genRandomPass());
      }
    }

    # enable wiki before we do anything else.
    runAsZimbra("/opt/zimbra/bin/zmprov mc default zimbraFeatureNotebookEnabled TRUE");

    # global Documents
    runAsZimbra("/opt/zimbra/bin/zmprov mcf zimbraNotebookAccount $config{NOTEBOOKACCOUNT}");
    $rc = runAsZimbra("/opt/zimbra/bin/zmprov in $config{NOTEBOOKACCOUNT}");
    if ($rc != 0) {
      runAsZimbra("/opt/zimbra/bin/zmprov mc default zimbraFeatureNotebookEnabled FALSE");
      progress ("failed to initialize documents...see logfile for details.\n");

    } else {
      $rc = runAsZimbra("/opt/zimbra/bin/zmprov impn $config{NOTEBOOKACCOUNT} /opt/zimbra/wiki/Template Template");

      if ($rc != 0) {
        runAsZimbra("/opt/zimbra/bin/zmprov mc default zimbraFeatureNotebookEnabled FALSE");
        progress ("failed to initialize documents...see logfile for details.\n");
      } else {
        runAsZimbra("/opt/zimbra/bin/zmprov ma $config{NOTEBOOKACCOUNT} zimbraFeatureNotebookEnabled TRUE");
        progress ( "done.\n" );
      }
    }

    # domain Documents only if the domain is local and wiki account
    # was previously setup.
    open(ZM, "$ZMPROV gad|") or warn "Can't get domain list!";
    my @domains = <ZM>;
    close(ZM);
    foreach my $domain (@domains) {
      chomp($domain);
      my $domainType = (split(/\s+/, `su - zimbra -c "$ZMPROV gd $domain | grep zimbraDomainType"`))[-1];
      next unless $domainType eq "local";
    
      my $domainWikiAcct = (split(/\s+/, `su - zimbra -c "$ZMPROV gd $domain | grep zimbraNotebookAccount"`))[-1];
      next if ($domainWikiAcct eq "");
    
      # global and domain accounts cannot be the same
      next if ($domainWikiAcct eq $config{NOTEBOOKACCOUNT});
      progress("Updating document templates for $domainWikiAcct...");
      $rc = runAsZimbra("/opt/zimbra/bin/zmprov impn $domainWikiAcct /opt/zimbra/wiki/Template Template");
      if ($rc != 0) {
        progress ("failed...see logfile for details.\n");
      } else {
        progress ("done.\n");
      }
    }

    runAsZimbra("/opt/zimbra/bin/zmprov mc default zimbraFeatureNotebookEnabled $zimbraFeatureNotebookEnabled");
  }
    
  configLog("configInitNotebooks");
}

sub configSetEnabledServices {

  if ($configStatus{configSetEnabledServices} eq "CONFIGURED") {
    configLog("configSetEnabledServices");
    return 0;
  }

  foreach my $p (keys %installedPackages) {
    if ($p eq "zimbra-core") {
      $installedServiceStr .= "zimbraServiceInstalled stats ";
      next;
    }
    if ($p eq "zimbra-apache") {next;}
    if ($p eq "zimbra-cluster") {next;}
    $p =~ s/zimbra-//;
    if ($p eq "store") {$p = "mailbox";}
    if ($p eq "proxy") { $p = "imapproxy";}
    $installedServiceStr .= "zimbraServiceInstalled $p ";
  }

  foreach my $p (keys %enabledPackages) {
    if ($p eq "zimbra-core") {
      $enabledServiceStr .= "zimbraServiceEnabled stats ";
      next;
    }
    if ($p eq "zimbra-apache") {next;}
    if ($p eq "zimbra-cluster") {next;}
    if ($p eq "zimbra-archiving") {next;}
    if ($enabledPackages{$p} eq "Enabled") {
      $p =~ s/zimbra-//;
      if ($p eq "store") {$p = "mailbox";}
      if ($p eq "proxy") { $p = "imapproxy";}
      $enabledServiceStr .= "zimbraServiceEnabled $p ";
    }
  }

  progress ( "Setting services on $config{HOSTNAME}..." );
  runAsZimbra ("$ZMPROV ms $config{HOSTNAME} $installedServiceStr");
  runAsZimbra ("$ZMPROV ms $config{HOSTNAME} $enabledServiceStr");
  progress ( "done.\n" );

  configLog("configSetEnabledServices");
}

sub failConfig {
  progress ("\n\nERROR\n\n");
  progress ("\n\nConfiguration failed\n\n");
  progress ("Please address the error and re-run /opt/zimbra/libexec/zmsetup.pl to\n");
  progress ("complete the configuration.\n");
  progress ("\nErrors have been logged to $logfile\n\n");
  exit 1;
}

sub applyConfig {
  if (!(defined ($options{c})) && $newinstall ) {
    if (askYN("Save configuration data to a file?", "Yes") eq "yes") {
      saveConfig();
    }
    if (askYN("The system will be modified - continue?", "No") eq "no") {
      return 1;
    }
  } else {
    saveConfig();
  }
  progress ( "Operations logged to $logfile\n" );

  open (H, ">>/opt/zimbra/.install_history");

  print H time(),": CONFIG SESSION START\n";
  # This is the postinstall config

  configLog ("BEGIN");

  configLCValues();

  # About SSL
  # 
  # On the master ldap server, create a ca and a cert
  # On store and MTA servers, just create a cert.
  #
  # Non-ldap masters use the master CA, which they get from ldap
  # but ldap won't start without a cert.
  #
  # so - ldap - create CA, create cert, init ldap, store CA in ldap
  #
  # non-ldap - fetch CA, create cert

  configCASetup();

  configCreateCert();

  configInstallCert();

  configSetupLdap();

  configSaveCA();

  configCreateServerEntry();

  if (isEnabled("zimbra-store")) {
    configSpellServer();

    configSetServicePorts();

    addServerToHostPool();

    configSetInstalledSkins();

    configSetKeyboardShortcutsPref() if (!$newinstall);

    configInitBackupPrefs();

    configSetCEFeatures();

    configSetNEFeatures() if isNetwork();

    configSetStoreDefaults();
  }

  if (isEnabled("zimbra-mta")) {
    configSetMtaAuthHost();
  }

  if (isEnabled("zimbra-ldap")) {
    configSetTimeZonePref();
  }

  if (isInstalled("zimbra-proxy")) {
    configSetProxyPrefs();
  }

  if( (!$newinstall) && isInstalled("zimbra-ldap") ){
    setProxyBits();
  }
  if (isInstalled("zimbra-cluster")) {
    configSetCluster();
  }

  configCreateDomain();

  configInitSql();

  configInitLogger();

  configInitMta();

  configInitSnmp();

  configSetEnabledServices();

  setupCrontab();

  setupSyslog();

  postinstall::configure();

  `touch /opt/zimbra/.bash_history`;
  `chown zimbra:zimbra /opt/zimbra/.bash_history`;

  if ($config{STARTSERVERS} eq "yes") {

    # bug 6270 
    if (($platform =~ m/DEBIAN/ || $platform =~ m/UBUNTU/) && ! $newinstall) {
      `chown zimbra:zimbra /opt/zimbra/redolog/redo.log`;
    }

    progress ( "Starting servers..." );
    #runAsZimbra ("$ZMPROV ms $config{HOSTNAME} zimbraUserServicesEnabled FALSE");
    runAsZimbra ("/opt/zimbra/bin/zmcontrol start");
    # runAsZimbra swallows the output, so call status this way
    `su - zimbra -c "/opt/zimbra/bin/zmcontrol status"`;
    progress ( "done.\n" );

    # Initialize application server specific items
    # only after the application server is running.
    if (isEnabled("zimbra-store")) {
      configInstallZimlets();
      configInitNotebooks();

      progress ( "Restarting mailboxd...");
      runAsZimbra("/opt/zimbra/bin/zmmailboxdctl restart");
      progress ( "done.\n" );
    }
    #runAsZimbra ("$ZMPROV ms $config{HOSTNAME} zimbraUserServicesEnabled TRUE");
  } else {
    progress ( "WARNING: Document and Zimlet initialization skipped because Application Server was not configured to start.\n")
      if (isEnabled("zimbra-store"));
  }

  if ($newinstall) {
    runAsZimbra ("/opt/zimbra/bin/zmsshkeygen");
    runAsZimbra ("/opt/zimbra/bin/zmupdateauthkeys");
  } else {
    runAsZimbra ("/opt/zimbra/bin/zmupdateauthkeys");
  }

  configLog ("END");

  print H time(),": CONFIG SESSION COMPLETE\n";

  close H;

  getSystemStatus();

  progress ( "\n\n" );
  chmod 0600, $logfile;
  if (-d "/opt/zimbra/log") {
    main::progress("Moving $logfile to /opt/zimbra/log\n");
    system("cp -f $logfile /opt/zimbra/log");
  } else {
    progress ( "Operations logged to $logfile\n" );
  }
  progress ( "\n\n" );
  if (!defined ($options{c})) {
    ask("Configuration complete - press return to exit", "");
    print "\n\n";
    close LOGFILE;
    exit 0;
  }
}

sub configLog {
  my $stage = shift;
  my $msg = time().": CONFIGURED $stage\n";
  print H $msg;
  #progress ($msg);
}

sub setupSyslog {
  progress ("Setting up syslog.conf...");
  if ( -f "/opt/zimbra/bin/zmsyslogsetup") {
    my $rc = 0xffff & system("/opt/zimbra/bin/zmsyslogsetup local");
    if ($rc) {
      progress ("Failed\n");
      } else {
      progress ("done.\n");
    }
  } else {
    progress ("Failed\n");
  }
  configLog("setupSyslog");
}

sub setupCrontab {
  my @backupSchedule=();
  progress ("Setting up zimbra crontab...");
  if ( -x "/opt/zimbra/bin/zmschedulebackup") {
    detail("Getting current backup schedule in restorable format.");
    @backupSchedule = (`su - zimbra -c "zmschedulebackup -s" 2> /dev/null`);
    for (my $i=0;$i<=$#backupSchedule;$i++) {
      $backupSchedule[$i] =~ s/"/\\"/g;
    }
    if (scalar @backupSchedule == 0) {
      detail("Backup schedule was not previously defined");
    } else {
      detail("Retrieved backup schedule:\n @backupSchedule");
    }
  }
  if ($platform =~ /SUSE/i) {
    `cp -f /var/spool/cron/tabs/zimbra /tmp/crontab.zimbra.orig`;
  } else {
    `crontab -u zimbra -l > /tmp/crontab.zimbra.orig 2> /dev/null`;
  }
  my $rc = 0xffff & system("grep ZIMBRASTART /tmp/crontab.zimbra.orig > /dev/null 2>&1");
  if ($rc) {
    `cat /dev/null > /tmp/crontab.zimbra.orig`;
  }
  $rc = 0xffff & system("grep ZIMBRAEND /tmp/crontab.zimbra.orig > /dev/null 2>&1");
  if ($rc) {
    `cat /dev/null > /tmp/crontab.zimbra.orig`;
  }
  `cat /tmp/crontab.zimbra.orig | sed -e '/# ZIMBRASTART/,/# ZIMBRAEND/d' > /tmp/crontab.zimbra.proc`;
  `cp -f /opt/zimbra/zimbramon/crontabs/crontab /tmp/crontab.zimbra`;

  if (isEnabled("zimbra-ldap")) {
    detail("Crontab: Adding zimbra-ldap specific crontab entries");
    `cat /opt/zimbra/zimbramon/crontabs/crontab.ldap >> /tmp/crontab.zimbra`;
  }

  if (isEnabled("zimbra-store")) {
    detail("Crontab: Adding zimbra-store specific crontab entries");
    `cat /opt/zimbra/zimbramon/crontabs/crontab.store >> /tmp/crontab.zimbra`;
  }

  if (isEnabled("zimbra-logger")) {
    detail("Crontab: Adding zimbra-logger specific crontab entries");
    `cat /opt/zimbra/zimbramon/crontabs/crontab.logger >> /tmp/crontab.zimbra`;
  }

  if (isEnabled("zimbra-mta")) {
    detail("Crontab: Adding zimbra-mta specific crontab entries");
    `cat /opt/zimbra/zimbramon/crontabs/crontab.mta >> /tmp/crontab.zimbra`;
  }

  `echo "# ZIMBRAEND -- DO NOT EDIT ANYTHING BETWEEN THIS LINE AND ZIMBRASTART" >> /tmp/crontab.zimbra`;
  `cat /tmp/crontab.zimbra.proc >> /tmp/crontab.zimbra`;
  detail("crontab: installing new crontab");
  `crontab -u zimbra /tmp/crontab.zimbra 2> /dev/null`;
  if ( -x "/opt/zimbra/bin/zmschedulebackup" && scalar @backupSchedule > 0) {
    detail("Restoring previous backup schedule.");
    for (my $i=0;$i<=$#backupSchedule;$i++) {
      chomp($backupSchedule[$i]);
      if ($i == 0) {
        `su - zimbra -c "/opt/zimbra/bin/zmschedulebackup -R $backupSchedule[$i]"`;
      } else {
        `su - zimbra -c "/opt/zimbra/bin/zmschedulebackup -A $backupSchedule[$i]"`;
      }
    }
  } elsif ( -f "/opt/zimbra/bin/zmschedulebackup" && scalar @backupSchedule == 0 && !$newinstall) {
    detail("No backup schedule found: installing default schedule.");
    `su - zimbra -c "/opt/zimbra/bin/zmschedulebackup -D" > /dev/null 2>&1`;
  }

  if (isEnabled("zimbra-cluster")) {
    mkdir("/opt/zimbra/conf/cron");
    runAsZimbra("mkdir -p /opt/zimbra/conf/cron");
    runAsZimbra("crontab -l > /opt/zimbra/conf/cron/crontab");
  }
  progress ("done.\n");
  configLog("setupCrontab");
}

sub getSystemMemory {
  my $os = lc `uname -s`;
  chomp($os);
  return "unknown" unless $os;
  my $mem;
  if ($os eq "linux") {
    $mem = `cat /proc/meminfo | grep ^MemTotal: | awk '{print \$2}'`;
    chomp($mem);
    $mem = sprintf "%0.1f", $mem/(1024*1024);
  } elsif ($os eq "darwin") {
    $mem = `sysctl hw.memsize | awk '{print \$NF}'`;
    chomp($mem);
    $mem = sprintf "%0.1f", $mem/(1024*1024*1024);
  }
  return $mem;
}

sub mysqlMemoryPercent {
  my $system_mem = shift;
  my $os = lc `uname -s`;
  chomp($os);
  my $percent = 30;
  if ($system_mem > 2 && $addr_space eq "32") {
    $percent = int((1.55/$system_mem)*100);
    return 10 if ($os eq "darwin");
  }
  return $percent;
}

sub mailboxdMemoryPercent {
  my $system_mem = shift;
  my $percent = 40;
  # can only allocate about 1.6GB on a 32 bit system
  $percent = int((1.5/$system_mem)*100)
    if ($system_mem > 2 && $addr_space eq "32");
  return $percent;
}

sub addServerToHostPool {
  progress ( "Adding $config{HOSTNAME} to zimbraMailHostPool in default COS..." );
  my $id = `$ZMPROV gs $config{HOSTNAME} | grep zimbraId | sed -e 's/zimbraId: //'`;
  chomp $id;

  my $hp = `$ZMPROV gc default | grep zimbraMailHostPool | sed 's/zimbraMailHostPool: //'`;
  chomp $hp;

  my @HP = split (' ', $hp);

  my $n = "";

  foreach (@HP) {
    chomp;
    $n .= "zimbraMailHostPool $_ ";
  }

  $n .= "zimbraMailHostPool $id";

  runAsZimbra("$ZMPROV mc default $n");
  progress ( "done.\n" );
}

sub mainMenu {
  my %mm = ();
  $mm{createsub} = \&createMainMenu;

  displayMenu(\%mm);
}

sub stopLdap {
  main::progress("Stopping ldap\n");
  my $rc = 0xffff & system("su - zimbra -c \"/opt/zimbra/bin/ldap stop > /dev/null 2>&1\"");
  $rc = $rc >> 8;
  if ($rc) {
    main::progress("LDAP stop failed with exit code $rc\n");
    return $rc;
  }
  sleep 5; # give it a chance to shutdown.
  return 0;
}

sub startLdap {
  main::detail("Checking ldap status.");
  my $rc = runAsZimbra("/opt/zimbra/bin/ldap status");
  if ($rc) { 
    main::progress("Starting ldap...");
    runAsZimbra("/opt/zimbra/sleepycat/bin/db_recover -h /opt/zimbra/openldap-data");
    $rc = runAsZimbra ("/opt/zimbra/libexec/zmldapapplyldif");
    $rc = runAsZimbra ("/opt/zimbra/bin/ldap status");
    if ($rc) {
      $rc = runAsZimbra("/opt/zimbra/bin/ldap start");
      if ($rc) { 
        main::progress("failed with exit code $rc.\n");
        system("su - zimbra -c \"/opt/zimbra/bin/ldap start 2>&1 | grep failed\"");
        return $rc;
      } 
    }  else {
      main::progress("done.\n");
    }
  } else {
    main::detail("slapd already running.\n");
  }
  return 0;
}

sub resumeConfiguration {
  progress ( "\n\nNote\n\n" );
  progress ( "The previous configuration appears to have failed to complete\n\n");
  if (askYN ("Attempt to complete configuration now?", "yes") eq "yes") {
    applyConfig();
  } else {
    %configStatus = ();
  }
}

### end subs


__END__
