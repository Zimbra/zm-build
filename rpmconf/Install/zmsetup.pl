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

$|=1; # don't buffer stdout

our $platform = `/opt/zimbra/libexec/get_plat_tag.sh`;
chomp $platform;
our $addr_space = (($platform =~ m/\w+_(\d+)/) ? "$1" : "32");
my $logfile = "/tmp/zmsetup.log.$$";
open LOGFILE, ">$logfile" or die "Can't open $logfile: $!\n";

my $ol = select (LOGFILE);
select ($ol);
$| = 1;

print "Operations logged to $logfile\n";

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

if ($platform =~ /SuSE|openSUSE|SLES/) { `chmod 640 /etc/sudoers`;}

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

my $zimbraHome = "/opt/zimbra";

my %installStatus = ();
my %configStatus = ();

my $prevVersion = "";
our $curVersion = "";

our $newinstall = 1;

my $ldapConfigured = 0;
my $ldapRunning = 0;
my $sqlConfigured = 0;
my $sqlRunning = 0;
my $loggerSqlConfigured = 0;
my $loggerSqlRunning = 0;
my $installedServiceStr = "";
my $enabledServiceStr = "";

my $ldapPassChanged = 0;
my $ldapRepChanged = 0;
my $ldapPostChanged = 0;
my $ldapAmavisChanged = 0;

my @interfaces = ();

($>) and usage();

getopts("c:hd", \%options) or usage();

my $debug = $options{d};
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
  $msg =~ s/\n$//;
  $msg = "$sub:$line $msg" if $options{d};
  `echo "$msg" >> $logfile`;
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
    return 1;
  } else {
    return undef;
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
  if ($platform eq "DEBIAN3.1" || $platform eq "UBUNTU6" || $platform eq "DEBIAN4.0" ) {
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
  if (($platform eq "DEBIAN3.1" || $platform eq "UBUNTU6" || $platform eq "DEBIAN4.0") && $rc == 0 ) {
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

  my $sslport=getLdapServerValue("zimbraMailSSLPort");

  my $mailport=getLdapServerValue("zimbraMailPort");

  my $mailmode=getLdapServerValue("zimbraMailMode");

  $config{HTTPPORT} = $mailport;
  $config{HTTPSPORT} = $sslport;
  $config{MODE} = $mailmode;
  if ($config{HTTPPORT} eq 0) { $config{HTTPPORT} = 80; }
  if ($config{HTTPSPORT} eq 0) { $config{HTTPSPORT} = 443; }
  if ($config{MODE} eq "") { $config{MODE} = "mixed"; }

  # default domainname
  $config{zimbraDefaultDomainName} = getLdapConfigValue("zimbraDefaultDomainName");
  if ($config{zimbraDefaultDomainName} eq "") {
    $config{zimbraDefaultDomainName} = $config{CREATEDOMAIN};
  } else {
    $config{CREATEDOMAIN} = $config{zimbraDefaultDomainName};
    $config{CREATEADMIN} = "admin\@$config{CREATEDOMAIN}";
  }

  $config{IMAPPORT}       = getLdapServerValue("zimbraImapBindPort");
  $config{IMAPSSLPORT}     = getLdapServerValue("zimbraImapSSLBindPort");
  $config{POPPORT}       = getLdapServerValue("zimbraPop3BindPort");
  $config{POPSSLPORT}     = getLdapServerValue("zimbraPop3SSLBindPort");
  $config{HTTPPORT}       = getLdapServerValue("zimbraMailPort");
  $config{HTTPSPORT}       = getLdapServerValue("zimbraMailSSLPort");
  $config{IMAPPROXYPORT}     = getLdapServerValue("zimbraImapProxyBindPort");
  $config{IMAPSSLPROXYPORT}   = getLdapServerValue("zimbraImapSSLProxyBindPort");
  $config{POPPROXYPORT}     = getLdapServerValue("zimbraPop3ProxyBindPort");
  $config{POPSSLPROXYPORT}   = getLdapServerValue("zimbraPop3SSLProxyBindPort");

  $config{TRAINSASPAM} = getLdapConfigValue("zimbraSpamIsSpamAccount");
  $config{TRAINSAHAM} = getLdapConfigValue("zimbraSpamIsNotSpamAccount");
  $config{NOTEBOOKACCOUNT} = getLdapConfigValue("zimbraNotebookAccount");

  $config{SMTPSOURCE} = $config{CREATEADMIN};
  $config{SMTPDEST} = $config{CREATEADMIN};
  $config{AVUSER} = $config{CREATEADMIN};

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
  if (isInstalled("zimbra-proxy")) {
    if (isEnabled("zimbra-proxy")) {
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
    }
    my $query = "\(\|\(\|\(zimbraMailDeliveryAddress=\${USER}\@$config{zimbraDefaultDomainName}\)\(zimbraMailAlias=\${USER}\@$config{zimbraDefaultDomainName}\)\)\(\|\(zimbraMailDeliveryAddress=\${USER}\)\(zimbraMailAlias=\${USER}\)\)\)";

    $config{zimbraReverseProxyMailHostQuery} = getLdapConfigValue("zimbraReverseProxyMailHostQuery");
    $config{zimbraReverseProxyMailHostQuery} = $query
      if ($config{zimbraReverseProxyMailHostQuery} eq ""); 

    $config{zimbraReverseProxyMailHostAttribute} = getLdapConfigValue("zimbraReverseProxyMailHostAttribute");
    $config{zimbraReverseProxyMailHostAttribute} = "zimbraMailHost"
      if ($config{zimbraReverseProxyMailHostAttribute} eq "");

    $config{zimbraReverseProxyPortQuery} = getLdapConfigValue("zimbraReverseProxyPortQuery");
    $config{zimbraReverseProxyPortQuery} = '\(\&\(zimbraServiceHostname=\${MAILHOST}\)\(objectClass=zimbraServer\)\)'
      if ( $config{zimbraReverseProxyPortQuery} eq "");

    $config{zimbraReverseProxyPop3PortAttribute} = getLdapConfigValue("zimbraReverseProxyPop3PortAttribute");
    $config{zimbraReverseProxyPop3PortAttribute} = "zimbraPop3BindPort"
      if ( $config{zimbraReverseProxyPop3PortAttribute} eq "");

    $config{zimbraReverseProxyPop3SSLPortAttribute} = getLdapConfigValue("zimbraReverseProxyPop3SSLPortAttribute");
    $config{zimbraReverseProxyPop3SSLPortAttribute} = "zimbraPop3SSLBindPort"
      if ( $config{zimbraReverseProxyPop3SSLPortAttribute} eq "");

   $config{zimbraReverseProxyImapPortAttribute} = getLdapConfigValue("zimbraReverseProxyImapPortAttribute");
   $config{zimbraReverseProxyImapPortAttribute} = "zimbraImapBindPort"
      if ( $config{zimbraReverseProxyImapPortAttribute} eq "");

   $config{zimbraReverseProxyImapSSLPortAttribute} = getLdapConfigValue("zimbraReverseProxyImapSSLPortAttribute");
   $config{zimbraReverseProxyImapSSLPortAttribute} = "zimbraImapSSLBindPort"
      if ( $config{zimbraReverseProxyImapSSLPortAttribute} eq ""); 
  }
 
  # default values for upgrades 
 $config{NOTEBOOKACCOUNT} = "wiki".'@'.$config{CREATEDOMAIN}
  if ($config{NOTEBOOKACCOUNT} eq "");

  $config{USEKBSHORTCUTS} = getLdapCOSValue("default", "zimbraPrefUseKeyboardShortcuts");

  $config{zimbraPrefTimeZoneId}=getLdapCOSValue("default", "zimbraPrefTimeZoneId");

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
  $config{mailboxd_keystore_password} = genRandomPass();
  $config{mailboxd_truststore_password} = "changeit";
  print "DEBUG: \$config{mailboxd_directory}=$config{mailboxd_directory}\n" if $debug;

  $config{SMTPHOST} = "";
  $config{SNMPTRAPHOST} = $config{HOSTNAME};
  $config{DOCREATEDOMAIN} = "no";
  $config{CREATEDOMAIN} = $config{HOSTNAME};
  $config{DOCREATEADMIN} = "no";

  if (isEnabled("zimbra-cluster")) {
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

  }

  if (isEnabled("zimbra-ldap")) {
    progress "setting defaults for zimbra-ldap.\n" if $options{d};
    $config{DOCREATEDOMAIN} = "yes" if $newinstall;
    $config{LDAPPASS} = genRandomPass();
    $config{LDAPREPPASS} = genRandomPass();
    $config{LDAPPOSTPASS} = genRandomPass();
    $config{LDAPAMAVISPASS} = genRandomPass();
    $ldapRepChanged = 1;
    $ldapPostChanged = 1;
    $ldapAmavisChanged = 1;
  }

  $config{CREATEADMIN} = "admin\@$config{CREATEDOMAIN}";

  $config{zimbraPrefTimeZoneId} = '(GMT-08.00) Pacific Time (US & Canada)';

  $config{zimbra_ldap_userdn} = "uid=zimbra,cn=admins,cn=zimbra"
    if ($config{zimbra_ldap_userdn} eq "");

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
    my $tmpval = (`su - zimbra -c "postconf mynetworks"`);
    chomp($tmpval);
    $tmpval =~ s/mynetworks = //;
    if ($tmpval eq "") {
      $config{zimbraMtaMyNetworks} = "127.0.0.0/8 @interfaces";
    } else {
      $config{zimbraMtaMyNetworks} = "$tmpval";
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
    my $query = "\(\|\(\|\(zimbraMailDeliveryAddress=\${USER}\@$config{CREATEDOMAIN}\)\(zimbraMailAlias=\${USER}\@$config{CREATEDOMAIN}\)\)\(\|\(zimbraMailDeliveryAddress=\${USER}\)\(zimbraMailAlias=\${USER}\)\)\)";

    $config{zimbraReverseProxyMailHostQuery} = $query;
    $config{zimbraReverseProxyMailHostAttribute} = "zimbraMailHost";
    $config{zimbraReverseProxyPortQuery} = '\(\&\(zimbraServiceHostname=\${MAILHOST}\)\(objectClass=zimbraServer\)\)';
    $config{zimbraReverseProxyPop3PortAttribute} = "zimbraPop3BindPort";
    $config{zimbraReverseProxyPop3SSLPortAttribute} = "zimbraPop3SSLBindPort";
    $config{zimbraReverseProxyImapPortAttribute} = "zimbraImapBindPort";
    $config{zimbraReverseProxyImapSSLPortAttribute} = "zimbraImapSSLBindPort";
    $config{IMAPPROXYPORT} = 143;
    $config{IMAPSSLPROXYPORT} = 993;
    $config{POPPROXYPORT} = 110;
    $config{POPSSLPROXYPORT} = 995;
    $config{IMAPPORT} = 7143;
    $config{IMAPSSLPORT} = 7993;
    $config{POPPORT} = 7110;
    $config{POPSSLPORT} = 7995;
  } else {
    $config{IMAPPROXYPORT} = 7143;
    $config{IMAPSSLPROXYPORT} = 7993;
    $config{POPPROXYPORT} = 7110;
    $config{POPSSLPROXYPORT} = 7995;
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
  progress "done.\n" if $options{d};
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
  $config{LDAPPASS} = getLocalConfig ("ldap_root_password");
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

  if (isEnabled("zimbra-snmp")) {
    $config{SNMPNOTIFY} = getLocalConfig("snmp_notify");
    $config{SNMPNOTIFY} = "yes" if ($config{SNMPNOTIFY} eq "");

    $config{SMTPNOTIFY} = getLocalConfig("smtp_notify");
    $config{SMTPNOTIFY} = "yes" if ($config{SNMPNOTIFY} eq "");

    $config{SNMPTRAPHOST} = getLocalConfig("snmp_trap_host");
    $config{SNMPTRAPHOST} = $config{CREATEADMIN}
      if ($config{SNMPTRAPHOST} eq "");
  }

  if (isEnabled("zimbra-logger") || isEnabled("zimbra-snmp")) {
    $config{SMTPSOURCE} = getLocalConfig("smtp_source");
    $config{SMTPSOURCE} = $config{CREATEADMIN}
      if ($config{SMTPSOURCE} eq "");

    $config{SMTPDEST} = getLocalConfig("smtp_destination");
    $config{SMTPDEST} = $config{CREATEADMIN}
      if ($config{SMTPDEST} eq "");
  }
  if (isEnabled("zimbra-ldap")) {

    $config{LDAPREPPASS} = getLocalConfig ("ldap_replication_password");
    if ($config{LDAPREPPASS} eq "") {
      $config{LDAPREPPASS} = genRandomPass();
      $ldapRepChanged = 1;
    }

    $config{LDAPPOSTPASS} = getLocalConfig ("ldap_postfix_password");
    if ($config{LDAPPOSTPASS} eq "") {
      $config{LDAPPOSTPASS} = genRandomPass();
      $ldapPostChanged = 1;
    }

    $config{LDAPAMAVISPASS} = getLocalConfig ("ldap_amavis_password");
    if ($config{LDAPAMAVISPASS} eq "") {
      $config{LDAPAMAVISPASS} = genRandomPass();
      $ldapAmavisChanged = 1;
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

sub setLdapUserDN {
  while (1) {
    print "Warning: Do not change this from the default value unless\n";
    print "you are absolutely sure you know what you are doing!\n\n";
    my $new =
      askNonBlank("Ldap bind DN:",
        $config{zimbra_ldap_userdn});
    if ($config{zimbra_ldap_userdn} ne $new) {
      $config{zimbra_ldap_userdn} = $new;
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

sub setLdapPass {
  while (1) {
    my $new =
      askNonBlank("Password for ldap server (min 6 characters):",
        $config{LDAPPASS});
    if (length($new) >= 6) {
      if ($config{LDAPPASS} ne $new) {
        $config{LDAPPASS} = $new;
        $ldapPassChanged = 1;
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

sub setUseImapProxy {

  if (isEnabled("zimbra-proxy")) {
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

sub configurePackage {
  my $package = shift;
  if ($package eq "zimbra-logger") {
    configureLogger($package);
  } elsif ($package eq "zimbra-ldap") {
    configureLdap($package);
  } elsif ($package eq "zimbra-mta") {
    configureMta($package);
  } elsif ($package eq "zimbra-snmp") {
    configureSnmp($package);
  } elsif ($package eq "zimbra-spell") {
    configureSpell($package);
  } elsif ($package eq "zimbra-store") {
    configureStore($package);
  } elsif ($package eq "zimbra-cluster") {
    configureCluster($package);
  } elsif ($package eq "zimbra-proxy") {
    configureProxy($package);
  } elsif ($package eq "zimbra-archiving") {
    configureArchiving($package);
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
      $config{LDAPPASS} = "";
    }
  }

  if (isEnabled("zimbra-store")) {
    if (isEnabled("zimbra-mta")) {
      $config{SMTPHOST} = $config{HOSTNAME};
    }
  }
  if (isEnabled("zimbra-mta")) {
    $config{RUNAV} = "yes";
    $config{RUNSA} = "yes";
    $config{RUNARCHIVING} = "no";
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
  if ($package eq "zimbra-logger") {
    return createLoggerMenu($package);
  } elsif ($package eq "zimbra-ldap") {
    return createLdapMenu($package);
  } elsif ($package eq "zimbra-mta") {
    return createMtaMenu($package);
  } elsif ($package eq "zimbra-snmp") {
    return createSnmpMenu($package);
  } elsif ($package eq "zimbra-spell") {
    return createSpellMenu($package);
  } elsif ($package eq "zimbra-store") {
    return createStoreMenu($package);
  } elsif ($package eq "zimbra-cluster") {
    return createClusterMenu($package);
  } elsif ($package eq "zimbra-proxy") {
    return createProxyMenu($package)
  } elsif ($package eq "zimbra-archiving") {
    return createArchivingMenu($package)
  }
}
sub createLdapMenu {
  my $package = shift;
  my $lm = genPackageMenu($package);

  $$lm{title} = "Ldap configuration";

  $$lm{createsub} = \&createLdapMenu;
  $$lm{createarg} = $package;

  my $i = 2;
  if (isEnabled($package)) {
#    $$lm{menuitems}{$i} = { 
#      "prompt" => "Ldap host:", 
#      "var" => \$config{LDAPHOST}, 
#      "callback" => \&setLdapHost
#      };
#    $i++;
#    $$lm{menuitems}{$i} = { 
#      "prompt" => "Ldap port:", 
#      "var" => \$config{LDAPPORT}, 
#      "callback" => \&setLdapPort
#      };
#    $i++;
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
    $$lm{menuitems}{$i} = { 
      "prompt" => "Bind DN:", 
      "var" => \$config{zimbra_ldap_userdn}, 
      "callback" => \&setLdapUserDN,
      };
    $i++;

  }
  return $lm;
}

sub configureLdap {
  my $package = shift;

  my $lm = createLdapMenu($package);

  displayMenu($lm);
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

sub configureArchiving {
  my $package = shift;
  my $lm = createArchivingMenu($package);
  displayMenu($lm);
}

sub createSpellMenu {
  my $package = shift;
  my $lm = genPackageMenu($package);

  $$lm{title} = "Spell configuration";

  $$lm{createsub} = \&createSpellMenu;
  $$lm{createarg} = $package;

  my $i = 2;

  if (isEnabled($package)) {
#    $$lm{menuitems}{$i} = { 
#      "prompt" => "Enable SMTP notifications:", 
#      "var" => \$config{SMTPNOTIFY}, 
#      "callback" => \&toggleYN,
#      "arg" => "SMTPNOTIFY",
#      };
#    $i++;
  }
  return $lm;
}

sub configureSpell {
  my $package = shift;

  my $lm = createSpellMenu($package);

  displayMenu($lm);
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

sub configureCluster {
  my $package = shift;

  my $lm = createClusterMenu($package);

  displayMenu($lm);
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

sub configureSnmp {
  my $package = shift;

  my $lm = createSnmpMenu($package);

  displayMenu($lm);
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
  }
  return $lm;
}

sub configureMta {
  my $package = shift;

  my $lm = createMtaMenu($package);

  displayMenu($lm);
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

sub configureProxy {
  my $package = shift;

  my $lm = createProxyMenu($package);

  displayMenu($lm);
}

sub configureStore {
  my $package = shift;

  my $lm = createStoreMenu($package);

  displayMenu($lm);
}

sub createLoggerMenu {
  my $package = shift;
  my $lm = genPackageMenu($package);

  $$lm{title} = "Logger configuration";

  $$lm{createsub} = \&createLoggerMenu;
  $$lm{createarg} = $package;

  if (isEnabled($package)) {
  }
  return $lm;
}

sub configureLogger {
  my $package = shift;

  my $lm = createLoggerMenu($package);

  displayMenu($lm);
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
  $mm{menuitems}{1} = { 
    "prompt" => "Hostname:", 
    "var" => \$config{HOSTNAME}, 
    "callback" => \&setHostName
    };
  my $i = 2;
  $mm{menuitems}{$i} = { 
    "prompt" => "Ldap master host:", 
    "var" => \$config{LDAPHOST}, 
    "callback" => \&setLdapHost
    };
  $i++;
  $mm{menuitems}{$i} = { 
    "prompt" => "Ldap port:", 
    "var" => \$config{LDAPPORT}, 
    "callback" => \&setLdapPort
    };
  $i++;
  if ($config{LDAPPASS} ne "") {
    $config{LDAPPASSSET} = "set";
  } else {
    $config{LDAPPASSSET} = "UNSET";
  }
  $mm{menuitems}{$i} = { 
    "prompt" => "Ldap password:", 
    "var" => \$config{LDAPPASSSET}, 
    "callback" => \&setLdapPass
    };
  $i++;
  $mm{menuitems}{$i} = { 
    "prompt" => "TimeZone:", 
    "var" => \$config{zimbraPrefTimeZoneId},
    "callback" => \&setTimeZone
  };
  $i++;
  foreach (@packageList) {
    if ($_ eq "zimbra-core") {next;}
    if ($_ eq "zimbra-apache") {next;}
    if (defined($installedPackages{$_})) {
      if ($_ eq "zimbra-logger") {
        $mm{menuitems}{$i} = { 
          "prompt" => "$_:", 
          "var" => \$enabledPackages{$_},
          "callback" => \&toggleEnabled, 
          "arg" => $_
        };
        $i++;
        next;
      }
      my $submenu = createPackageMenu($_);
      $mm{menuitems}{$i} = { 
        "prompt" => "$_:", 
        "var" => \$enabledPackages{$_},
        "submenu" => $submenu,
      };
      $i++;
    } else {
      #push @mm, "$_ not installed";
    }
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
  # My laptop can't always find itself...
  my $H = $config{LDAPHOST};
  if (($config{LDAPHOST} eq $config{HOSTNAME}) && !$ldapConfigured) {
    return 0;
  }
  if ($config{LDAPPASS} eq "" || $config{LDAPPORT} eq "" || $config{LDAPHOST} eq "") {
    detail ( "ldap configuration not complete\n" );
    return 1;
  }
  detail( "Checking ldap on ${H}:$config{LDAPPORT}");
  my $ldap;
  my $ldap_secure = (($config{LDAPPORT} == "636") ? "s" : "");
  my $ldap_url = "ldap${ldap_secure}://$config{LDAPHOST}:$config{LDAPPORT}";
  unless($ldap = Net::LDAP->new($ldap_url)) {
    detail("failed: Unable to contact ldap at $ldap_url: $!");
    return 1;
  }

  my $result = $ldap->bind("$config{zimbra_ldap_userdn}", password => $config{LDAPPASS});
  if ($result->code()) {
    detail ("Unable to bind to $ldap_url with password $config{LDAPPASS}: $!");
    return 1;
  } else {
    $ldap->unbind;
    detail ("Verfied ldap running at $ldap_url\n");
    setLocalConfig ("ldap_url", $ldap_url);
    setLocalConfig ("zimbra_ldap_password", $config{LDAPPASS});
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
  my $key = shift;

  return $main::loaded{lc}{$key}
    if (exists $main::loaded{lc}{$key});

  detail ( "Getting local config $key" );
  my $val = `/opt/zimbra/bin/zmlocalconfig -x -s -m nokey ${key} 2> /dev/null`;
  chomp $val;
  detail ("DEBUG: $key=$val") if $debug;
  $main::loaded{lc}{$key} = $val;
  return $val;
}

sub deleteLocalConfig {
  my $key = shift;

  detail ( "Deleting local config $key" );
  my $rc = 0xffff & system("/opt/zimbra/bin/zmlocalconfig -u ${key} 2> /dev/null");
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
  $main::config{$key} = $val;
  $main::saved{lc}{$key} = $val;
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
  } else {
    setLocalConfig ("ldap_master_url", "ldap://$config{LDAPHOST}:$config{LDAPPORT}");
    if ($config{ldap_url} eq "") { 
      setLocalConfig ("ldap_url", "ldap://$config{LDAPHOST}:$config{LDAPPORT}");
    } else {
      setLocalConfig ("ldap_url", "$config{ldap_url}");
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
  setLocalConfig ("mailboxd_truststore_password", "$config{mailboxd_truststore_password}");
  setLocalConfig ("mailboxd_keystore_password", "$config{mailboxd_keystore_password}");
  setLocalConfig ("zimbra_ldap_userdn", "$config{zimbra_ldap_userdn}");

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
    progress("Updating ldap_root_password and zimbra_ldap_passwd...");
    setLocalConfig ("ldap_root_password", $config{LDAPPASS});
    setLocalConfig ("zimbra_ldap_password", $config{LDAPPASS});
    progress ( "done.\n" );
  }
  progress ( "Setting up CA..." );
  runAsRoot("/opt/zimbra/bin/zmcertmgr createca");
  progress ( "done.\n" );
  
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
    if (my $rc = runAsZimbraWithOutput("/opt/zimbra/libexec/zmldapinit $config{LDAPPASS}")) {
      progress ( "FAILED ($rc)\n" );
      failConfig();
    } else {
      progress ( "done.\n" );
    }
  } elsif (isEnabled("zimbra-ldap")) {
    # enable replica for both new and upgrade installs if we are adding ldap
    if ($config{LDAPHOST} ne $config{HOSTNAME} ||  -f "/opt/zimbra/.enable_replica") {
      progress("Updating ldap_root_password and zimbra_ldap_passwd...");
      setLocalConfig ("ldap_root_password", $config{LDAPPASS});
      setLocalConfig ("zimbra_ldap_password", $config{LDAPPASS});
      progress("done.\n");
      progress ( "Enabling ldap replication..." );
      my $rc = runAsZimbra ("/opt/zimbra/libexec/zmldapenablereplica");
      if ($rc == 0) {
        #unlink "/opt/zimbra/.enable_replica";
        $config{DOCREATEADMIN} = "no";
        $config{DOCREATEDOMAIN} = "no";
	runAsZimbra ("/opt/zimbra/bin/ldap stop");
        progress ( "done.\n" );
      } else {
        progress ("failed.\n");
        progress ("You will have to correct the problem and manually enable replication.\n");
        progress ("Disabling ldap on $config{HOSTNAME}...");
        runAsZimbra("$ZMPROV ms $config{HOSTNAME} -zimbraServiceEnabled ldap");
	runAsZimbra ("/opt/zimbra/bin/ldap stop");
        progress ("done.\n");
      }
    }

    # set default zmprov bahaviour
    if (isEnabled("zimbra-ldap")) {
      if (isEnabled("zimbra-store")) {
        setLocalConfig ("zimbra_zmprov_default_to_ldap", "FALSE");
      } else {
        setLocalConfig ("zimbra_zmprov_default_to_ldap", "TRUE");
      }
    }

    # zmldappasswd starts ldap and re-applies the ldif
    if ($ldapPassChanged) {
      progress ( "Setting ldap password..." );
      runAsZimbra ("/opt/zimbra/bin/zmldappasswd -r $config{LDAPPASS}");
      # No reason to run this twice, zmldappaswd will change it for admin
      # and root usr both when run with -r option
      #runAsZimbra ("/opt/zimbra/bin/zmldappasswd $config{LDAPPASS}");
      progress ( "done.\n" );
    } else {
      progress("Stopping ldap...");
      runAsZimbra ("/opt/zimbra/bin/ldap stop");
      progress("done.\n");
      startLdap();
    }
  } else {
    detail("Updating ldap_root_password and zimbra_ldap_passwd\n");
    setLocalConfig ("ldap_root_password", $config{LDAPPASS});
    setLocalConfig ("zimbra_ldap_password", $config{LDAPPASS});
  }
  if ($ldapRepChanged == 1) {
    setLocalConfig ("ldap_replication_password", "$config{LDAPREPPASS}");
    runAsZimbra ("/opt/zimbra/bin/zmldappasswd -l $config{LDAPREPPASS}");
  }
  if ($ldapPostChanged == 1) {
    setLocalConfig ("ldap_postfix_password", "$config{LDAPPOSTPASS}");
    runAsZimbra ("/opt/zimbra/bin/zmldappasswd -p $config{LDAPPOSTPASS}");
  }
  if ($ldapAmavisChanged == 1) {
    setLocalConfig ("ldap_amavis_password", "$config{LDAPAMAVISPASS}");
    runAsZimbra ("/opt/zimbra/bin/zmldappasswd -a $config{LDAPAMAVISPASS}");
  }

  configLog("configSetupLdap");
  return 0;

}

sub configSaveCA {

  if ($configStatus{configSaveCA} eq "CONFIGURED") {
    configLog("configSaveCA");
    return 0;
  }
  progress ( "Deploying CA to /opt/zimbra/conf/ca ..." );
  runAsRoot("/opt/zimbra/bin/zmcertmgr deployca");
  progress ( "done.\n" );
  configLog("configSaveCA");
}

sub configCreateCert {

  if ($configStatus{configCreateCert} eq "CONFIGURED") {
    configLog("configCreateCert");
    return 0;
  }

  progress ( "Creating SSL certificate..." );

  if (isEnabled("zimbra-store")) {
    if ( !-f "$config{mailboxd_keystore}" && !-f "/opt/zimbra/ssl/ssl/server/server.crt" ) {
      if (!-d "$config{mailboxd_directory}") {
        `mkdir -p $config{mailboxd_directory}/etc`;
        `chown -R zimbra:zimbra $config{mailboxd_directory}`;
        `chmod 744 $config{mailboxd_directory}/etc`;
      }
      runAsRoot("/opt/zimbra/bin/zmcertmgr install self");
    }
  }

  if (isEnabled("zimbra-ldap")) {
    if ( !-f "/opt/zimbra/conf/slapd.crt" && !-f "/opt/zimbra/ssl/ssl/server.crt") {
      runAsRoot("/opt/zimbra/bin/zmcertmgr install self");
    }
  }

  if (isEnabled("zimbra-mta")) {
    if ( !-f "/opt/zimbra/conf/smtpd.crt" && !-f "/opt/zimbra/ssl/ssl/server.crt") {
      runAsRoot("/opt/zimbra/bin/zmcertmgr install self");
    }
  }
  progress ( "done.\n" );

  configLog("configCreateCert");
}

sub configInstallCert {

  if ($configStatus{configInstallCert} eq "CONFIGURED") {
    configLog("configInstallCert");
    return 0;
  }

  if (isEnabled("zimbra-store") || isEnabled("zimbra-mta")) {
    progress ("Installing SSL certificate...");
    if (isEnabled("zimbra-store")) {
      if (!-f "$config{mailboxd_keystore}") {
        runAsRoot("/opt/zimbra/bin/zmcertmgr install self");
      }
    }
    if (isEnabled("zimbra-mta")) {
      if (! (-f "/opt/zimbra/conf/smtpd.key" || 
        -f "/opt/zimbra/conf/smtpd.crt")) {
        runAsRoot("/opt/zimbra/bin/zmcertmgr install self");
      }
    }
    progress ( "done.\n" );
  }
  if (isEnabled("zimbra-ldap")) {
    if (! (-f "/opt/zimbra/conf/slapd.key" || 
      -f "/opt/zimbra/conf/slapd.crt")) {
      progress ("Installing LDAP SSL certificate...");
      runAsRoot("/opt/zimbra/bin/zmcertmgr install self");
      progress ( "done.\n" );
    }
  }

  if (isEnabled("zimbra-proxy")) {
    if (! (-f "/opt/zimbra/conf/nginx.key" || 
      -f "/opt/zimbra/conf/nginx.crt")) {
      progress ("Installing Proxy SSL certificate...");
      runAsRoot("/opt/zimbra/bin/zmcertmgr install self");
      progress ( "done.\n" );
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

sub configInitBackupPrefs {
  if (isEnabled("zimbra-store") && isNetwork()) {
    runAsZimbra("$ZMPROV mcf zimbraBackupReportEmailRecipients $config{zimbraBackupReportEmailRecipients}");
    runAsZimbra("$ZMPROV mcf zimbraBackupReportEmailSender $config{zimbraBackupReportEmailSender}");
  }
}

sub configSetProxyPrefs {
  if (isInstalled("zimbra-proxy")) {
    # We have to use a pipe to write out the Query, otherwise ${USER} gets interpreted
    open(ZMPROV, "|su - zimbra -c 'zmprov -l'");
    print ZMPROV "mcf zimbraReverseProxyMailHostQuery $config{zimbraReverseProxyMailHostQuery}\n";
    print ZMPROV "mcf zimbraReverseProxyPortQuery $config{zimbraReverseProxyPortQuery}\n";
    close ZMPROV;
    runAsZimbra("$ZMPROV mcf zimbraReverseProxyMailHostAttribute $config{zimbraReverseProxyMailHostAttribute}");
    runAsZimbra("$ZMPROV mcf zimbraReverseProxyPop3PortAttribute $config{zimbraReverseProxyPop3PortAttribute}");
    runAsZimbra("$ZMPROV mcf zimbraReverseProxyPop3SSLPortAttribute $config{zimbraReverseProxyPop3SSLPortAttribute}");
    runAsZimbra("$ZMPROV mcf zimbraReverseProxyImapPortAttribute $config{zimbraReverseProxyImapPortAttribute}");
    runAsZimbra("$ZMPROV mcf zimbraReverseProxyImapSSLPortAttribute $config{zimbraReverseProxyImapSSLPortAttribute}");
  }
}

sub configSetCluster {
  runAsZimbra("$ZMPROV mcf zimbraClusterType $config{zimbraClusterType}"); 
}

sub zimletCleanup {
  my $ldap_pass = getLocalConfig("ldap_root_password");
  my $ldap_master_url = getLocalConfig("ldap_master_url");
  my $ldap;
  unless($ldap = Net::LDAP->new($ldap_master_url)) {
    detail("Unable to contact $ldap_master_url: $!");
    return 1;
  }
  my $ldap_dn = $config{zimbra_ldap_userdn};
  my $ldap_base = "cn=zimlets,cn=zimbra";
  my $result = $ldap->bind($ldap_dn, password => $ldap_pass);
  unless ($result->code()) {
    $result = $ldap->search(base => $ldap_base, scope => 'one', filter => "(|(cn=convertd)(cn=cluster)(cn=hsm)(cn=hotbackup))");
    return $result if ($result->code());
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
  zimletCleanup();

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

  configSetupLdap();

  configSaveCA();

  configInstallCert();

  configCreateServerEntry();

  if (isEnabled("zimbra-store")) {
    configSpellServer();

    configSetServicePorts();

    addServerToHostPool();

    configSetInstalledSkins();

    configSetKeyboardShortcutsPref() if (!$newinstall);

    configInitBackupPrefs();
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
  progress ( "Operations logged to $logfile\n" );
  progress ( "\n\n" );
  if (!defined ($options{c})) {
    ask("Configuration complete - press return to exit", "");
    print "\n\n";
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
    `crontab -u zimbra -l > /tmp/crontab.zimbra.orig`;
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
  my $percent = 30;
  $percent = int((2/$system_mem)*100)
    if ($system_mem > 2 && $addr_space eq "32");
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

  `$ZMPROV mc default $n >> $logfile 2>&1`;
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
  main::progress("Checking ldap status\n");
  my $rc = runAsZimbra("/opt/zimbra/bin/ldap status");
  if ($rc) { 
    main::progress("Starting ldap\n");
    runAsZimbra("/opt/zimbra/sleepycat/bin/db_recover -h /opt/zimbra/openldap-data");
    $rc = runAsZimbra ("/opt/zimbra/openldap/sbin/slapindex -b '' -q -f /opt/zimbra/conf/slapd.conf");
    $rc = runAsZimbra ("/opt/zimbra/libexec/zmldapapplyldif");
    $rc = runAsZimbra ("/opt/zimbra/bin/ldap status");
    if ($rc) {
      $rc = runAsZimbra("/opt/zimbra/bin/ldap start");
      if ($rc) { 
        main::progress("ldap startup failed with exit code $rc\n");
        system("su - zimbra -c \"/opt/zimbra/bin/ldap start 2>&1 | grep failed\"");
        return $rc;
      } 
    } 
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

getInstallStatus();

getInstalledPackages();

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

setDefaultsFromLocalConfig()
  if (! $newinstall);

# if we're an upgrade, run the upgrader...

if (! $newinstall && ($prevVersion ne $curVersion )) {
  progress ("Upgrading from $prevVersion to $curVersion\n");
  if (zmupgrade::upgrade($prevVersion, $curVersion)){
    progress ("UPGRADE FAILED - exiting\n");
    exit 1;
  } else {
    progress ("Upgrade complete\n");
  }
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

__END__
