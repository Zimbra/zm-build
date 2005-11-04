#!/usr/bin/perl
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

use strict;

use lib "/opt/zimbra/libexec";

use postinstall;

use Getopt::Std;

my $newinstall = 0;

my %options = ();

my %config = ();

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
my %enabledPackages = ();

my $zimbraHome = "/opt/zimbra";

my $ldapConfigured = 0;
my $ldapRunning = 0;
my $sqlConfigured = 0;
my $sqlRunning = 0;
my $loggerSqlConfigured = 0;
my $loggerSqlRunning = 0;

my $ldapPassChanged = 0;

my $platform = `/opt/zimbra/bin/get_plat_tag.sh`;
chomp $platform;

my $logfile = "/tmp/zmsetup.log.$$";

open LOGFILE, ">$logfile" or die "Can't open $logfile: $!\n";

my $ol = select (LOGFILE);
$| = 1;
select ($ol);

print "Operations logged to $logfile\n";

($>) and usage();

getopts("c:h", \%options) or usage();

sub usage {
	($>) and print STDERR "Warning: $0 must be run as root!\n\n";
	print STDERR "Usage: $0 [-h] [-c <config file>]\n";
	print STDERR "\t-h: display this help message\n";
	print STDERR "\t-c: configure with values in <config file>\n\n";
	exit 1;
}

sub saveConfig {
	my $fname = "/opt/zimbra/config.$$";
	$fname = askNonBlank ("Save config in file:", $fname);

	if (open CONF, ">$fname") {
		print "Saving config in $fname...";
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
		print "Done\n";
	} else {
		print "Can't open $fname: $!\n";
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

sub getInstalledPackages {

	foreach my $p (@packageList) {
		if (isInstalled($p)) {
			$installedPackages{$p} = $p;
			$enabledPackages{$p} = "Enabled";
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
		$pkgQuery = "test -d /Library/Receipts/${pkg}*";
		$good = 0;
	} else {
		$pkgQuery = "rpm -q $pkg";
		$good = 0;
	}

	my $rc = 0xffff & system ("$pkgQuery > /dev/null 2>&1");
	$rc >>= 8;
	return ($rc == $good);

}

sub genRandomPass {
	open RP, "/opt/zimbra/bin/zmjava com.zimbra.cs.util.RandomPassword 8 10|" or
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
			$ldapRunning = ($ldapRunning)?0:1;
		} else {
			$config{DOCREATEDOMAIN} = "yes";
			$config{DOCREATEADMIN} = "yes";
		}
	}

	if (isEnabled("zimbra-store")) {
		if (-d "$zimbraHome/db/data") {
			$sqlConfigured = 1;
			$sqlRunning = 0xffff & system("/opt/zimbra/bin/mysqladmin status > /dev/null 2>&1");
			$sqlRunning = ($sqlRunning)?0:1;
		}
	}

	if (isEnabled("zimbra-logger")) {
		if (-d "$zimbraHome/logger/db/data") {
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

sub setDefaults {
	print "Setting defaults...";
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

	if ($platform eq "MACOSX") {
		setLocalConfig ("zimbra_java_home", "/usr");
		$config{HOSTNAME} = `hostname`;
	} else {
		$config{HOSTNAME} = `hostname --fqdn`;
	}
	chomp $config{HOSTNAME};

	$config{SMTPHOST} = "";
	$config{SNMPTRAPHOST} = $config{HOSTNAME};
	$config{DOCREATEDOMAIN} = "no";
	$config{CREATEDOMAIN} = $config{HOSTNAME};
	$config{DOCREATEADMIN} = "no";
	if (isEnabled("zimbra-ldap")) {
		$config{DOCREATEDOMAIN} = "yes";
		$config{DOCREATEADMIN} = "yes";
		$config{LDAPPASS} = genRandomPass();
	}
	$config{CREATEADMIN} = "admin\@$config{CREATEDOMAIN}";

	$config{SMTPSOURCE} = $config{CREATEADMIN};
	$config{SMTPDEST} = $config{CREATEADMIN};
	$config{AVUSER} = $config{CREATEADMIN};
	$config{SNMPNOTIFY} = "yes";
	$config{SMTPNOTIFY} = "yes";
	$config{STARTSERVERS} = "yes";

	$config{MODE} = "http";

	$config{CREATEADMINPASS} = "";

	if ( -f "/opt/zimbra/.newinstall") {
		$newinstall = 1;
		unlink "/opt/zimbra/.newinstall";
		my $t = time()+(60*60*24*60);
		my @d = localtime($t);
		$config{EXPIRY} = sprintf ("%04d%02d%02d",$d[5]+1900,$d[4]+1,$d[3]);
	} else {
		$config{DOCREATEDOMAIN} = "no";
		$config{DOCREATEADMIN} = "no";
		setDefaultsFromLocalConfig();
	}
	print "Done\n";
}


sub setDefaultsFromLocalConfig {
	$config{HOSTNAME} = getLocalConfig ("zimbra_server_hostname");
	$config{LDAPPORT} = getLocalConfig ("ldap_port");
	$config{LDAPHOST} = getLocalConfig ("ldap_host");
	$config{LDAPPASS} = getLocalConfig ("ldap_root_password");
	$config{SQLROOTPASS} = getLocalConfig ("mysql_root_password");
	$config{LOGSQLROOTPASS} = getLocalConfig ("mysql_logger_root_password");
	$config{ZIMBRASQLPASS} = getLocalConfig ("zimbra_mysql_password");
	$config{ZIMBRALOGSQLPASS} = getLocalConfig ("zimbra_logger_mysql_password");
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

sub setCreateDomain {
	$config{CREATEDOMAIN} =
		ask("Create Domain:",
			$config{CREATEDOMAIN});
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
}

sub setCreateAdmin {
	while (1) {
		my $new = 
			ask("Create admin user:",
				$config{CREATEADMIN});
		my ($u,$d) = split ('@', $new);
		if ($d ne $config{CREATEDOMAIN}) {
			print "You must create the admin user under the domain $config{CREATEDOMAIN}\n";
		} else {
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
	}

	setAdminPass();

}

sub initLdap {
	print "Warning - re-initializing the ldap database will delete\n";
	print "ALL USER ACCOUNTS, all server data, and all other system\n";
	print "configuration\n\n";

	if (askYN("Proceed with ldap initialization?","No") eq "no") { return (1); }

	if (isEnabled("zimbra-store") && $sqlConfigured) {
		print "Warning - the MySql database on this host is configured\n";
		print "This must be re-initialized PRIOR to ldap re-initialization\n";
		if (askYN("Delete MySql data now?","No") eq "no") { return (1); }
		if (deleteSql()) { 
			print "MySql removal failed!\n";
			ask("Press any key to continue", "");
			return (1); 
		}
	}
	print "Stopping ldap...\n";
	runAsZimbra ("/opt/zimbra/bin/ldap stop");
	print "Done\n";
	system ("/bin/rm -rf /opt/zimbra/openldap-data/*");
	print "Initializing ldap...\n";
	runAsZimbra ("/opt/zimbra/libexec/zmldapinit $config{LDAPPASS}");
	print "Done\n";
}

sub getVolumes {
	print "Getting volume list\n";
	if (open V, 
		"/opt/zimbra/bin/mysql -Bs zimbra -e 'select distinct(path) from volume' |") {
		my @volumes = <V>;
		close V;
		chomp @volumes;
		return \@volumes;
	}
	return undef;
}

sub deleteSql {

	print "Warning - MySql initialization on this host will delete\n";
	print "ALL MAIL ON THIS HOST.\n\n";
	if (askYN("Proceed with MySql initialization?","No") eq "no") { return (1); }

	if (!$sqlRunning) {
		print "Starting mysql...\n";
		runAsZimbra ("/opt/zimbra/bin/mysql.server start");
		print "Done\n";
	}
	my $v = getVolumes();
	if (!defined($v)) { print "Could not get volume list!\n"; return (1);}

	print "Stopping mysql...\n";
	runAsZimbra ("/opt/zimbra/bin/mysql.server stop");
	print "Done\n";

	foreach (@$v) {
		print "Deleting volume $_...";
		system ("/bin/rm -rf $_");
		print "Done\n";
	}

	$sqlConfigured = 0;
	return 0;

}

sub createSql {

	print "Initializing store sql database...\n";
	runAsZimbra ("/opt/zimbra/libexec/zmmyinit $config{SQLROOTPASS}");
	print "Done\n";
	$sqlConfigured = 1;
	return 0;
}

sub initSql {
	deleteSql();
	createSql();
}

sub initLoggerSql {
	print "Warning - Logger MySql initialization on this host will delete\n";
	print "all processed logs on this host.\n\n";
	if (askYN("Proceed with Logger MySql initialization?","No") eq "no") { return (1); }

	if ($loggerSqlRunning) {
		print "Stopping mysql...\n";
		runAsZimbra ("/opt/zimbra/bin/logmysql.server stop");
		print "Done\n";
	}

	print "Removing logger mysql database...\n";
	system ("/bin/rm -rf $zimbraHome/logger/db/data");
	print "Done\n";

	runAsZimbra ("/opt/zimbra/libexec/zmloggerinit");
	return 0;
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

sub setStoreMode {
	while (1) {
		my $m = 
			askNonBlank("Please enter the web server mode (http,https,mixed)",
				$config{MODE});
		if ($m eq "http" || $m eq "https" || $m eq "mixed") {
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

sub setHostName {
	my $old = $config{HOSTNAME};
	$config{HOSTNAME} = 
		askNonBlank("Please enter the logical hostname for this host",
			$config{HOSTNAME});
	if ($config{SMTPHOST} eq $old) {
		$config{SMTPHOST} = $config{HOSTNAME};
	}
	if ($config{SNMPTRAPHOST} eq $old) {
		$config{SNMPTRAPHOST} = $config{HOSTNAME};
	}
	if ($config{LDAPHOST} eq $old) {
		changeLdapHost($config{HOSTNAME});
	}
	if ($config{CREATEDOMAIN} eq $old) {
		$config{CREATEDOMAIN} = $config{HOSTNAME};
		my ($u,$d) = split ('@', $config{CREATEADMIN});
		$config{CREATEADMIN} = $u.'@'.$config{CREATEDOMAIN};
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

sub setLdapHost {
	changeLdapHost( askNonBlank("Please enter the ldap server hostname",
			$config{LDAPHOST}));
}

sub setLdapPort {
	changeLdapPort( askNum("Please enter the ldap server port",
			$config{LDAPPORT}));
}

sub setImapPort {
	askNum("Please enter the IMAP server port",
			$config{IMAPPORT});
}

sub setImapSSLPort {
	askNum("Please enter the IMAP SSL server port",
			$config{IMAPSSLPORT});
}

sub setPopPort {
	askNum("Please enter the POP server port",
			$config{POPPORT});
}

sub setPopSSLPort {
	askNum("Please enter the POP SSL server port",
			$config{POPSSLPORT});
}

sub setSpellUrl {
	$config{SPELLURL} = askNonBlank("Please enter the spell server URL", 
		$config{SPELLURL});
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
	}

	if (isEnabled("zimbra-spell")) {
		$config{USESPELL} = "yes";
		$config{SPELLURL} = "http://$config{HOSTNAME}:7780/aspell.php";
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

sub isEnabled {
	my $package = shift;
	return ($enabledPackages{$package} eq "Enabled");
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
#		$$lm{menuitems}{$i} = { 
#			"prompt" => "Ldap host:", 
#			"var" => \$config{LDAPHOST}, 
#			"callback" => \&setLdapHost
#			};
#		$i++;
#		$$lm{menuitems}{$i} = { 
#			"prompt" => "Ldap port:", 
#			"var" => \$config{LDAPPORT}, 
#			"callback" => \&setLdapPort
#			};
#		$i++;
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
	}
	return $lm;
}

sub configureLdap {
	my $package = shift;

	my $lm = createLdapMenu($package);

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
#		$$lm{menuitems}{$i} = { 
#			"prompt" => "Enable SMTP notifications:", 
#			"var" => \$config{SMTPNOTIFY}, 
#			"callback" => \&toggleYN,
#			"arg" => "SMTPNOTIFY",
#			};
#		$i++;
	}
	return $lm;
}

sub configureSpell {
	my $package = shift;

	my $lm = createSpellMenu($package);

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
	}
	return $lm;
}

sub configureMta {
	my $package = shift;

	my $lm = createMtaMenu($package);

	displayMenu($lm);
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
			"prompt" => "SMTP host:", 
			"var" => \$config{SMTPHOST}, 
			"callback" => \&setSmtpHost,
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
	}
	return $lm;
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
#	print "$indent$$items{title}\n";
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

sub createControlMenu {
	my %cm = ();
	$cm{createsub} = \&createControlMenu;
	$cm{title} = "Database Control menu";
	$cm{default} = "r";
	$cm{lastitem} = {
		"selector" => "r",
		"prompt" => "Return",
		"action" => "return",
		};

	my $i = 1;

	my $prompt;
	if (isEnabled("zimbra-ldap")) {
		if (!$ldapConfigured) {
			$prompt = "Ldap configured?";
			$config{LDAPRUNNING} = ($ldapConfigured)?"yes":"no";
		} else {
			$prompt = "Ldap Running?";
			$config{LDAPRUNNING} = ($ldapRunning)?"yes":"no";
		}
		$cm{menuitems}{$i} = { 
			"prompt" => $prompt,
			"var" => \$config{LDAPRUNNING}, 
			};
		$i++;
		$cm{menuitems}{$i} = { 
			"prompt" => "Re-initialize ldap...",
			"callback" => \&initLdap
			};
		$i++;
	}

	if (isEnabled("zimbra-store")) {
		if (!$sqlConfigured) {
			$prompt = "MySql configured?";
			$config{SQLRUNNING} = ($sqlConfigured)?"yes":"no";
		} else {
			$prompt = "MySql Running?";
			$config{SQLRUNNING} = ($sqlRunning)?"yes":"no";
		}
		$cm{menuitems}{$i} = { 
			"prompt" => $prompt,
			"var" => \$config{SQLRUNNING}, 
			};
		$i++;
		if ($ldapRunning) {
			$cm{menuitems}{$i} = { 
				"prompt" => "Re-initialize sql database...",
				"callback" => \&initSql
				};
			$i++;
		}
	}

	if (isEnabled("zimbra-logger")) {
		if (!$loggerSqlConfigured) {
			$prompt = "Logger MySql configured?";
			$config{LOGGERSQLRUNNING} = ($loggerSqlConfigured)?"yes":"no";
		} else {
			$prompt = "Logger MySql Running?";
			$config{LOGGERSQLRUNNING} = ($loggerSqlRunning)?"yes":"no";
		}
		$cm{menuitems}{$i} = { 
			"prompt" => $prompt,
			"var" => \$config{LOGGERSQLRUNNING}, 
			};
		$i++;
		if ($ldapRunning) {
			$cm{menuitems}{$i} = { 
				"prompt" => "Re-initialize logger sql database...",
				"callback" => \&initLoggerSql
				};
			$i++;
		}
	}

	return \%cm;
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
#	my %cm = ();
#	$cm{createsub} = \&createControlMenu;
#	$mm{menuitems}{d} = { 
#		"prompt" => "Database controls", 
#		"submenu" => \%cm,
#	};
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
			"prompt" => "***CONFIGURATION COMPLETE\nSelect from menu, or press 'a' to apply config", 
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
	if ($config{LDAPHOST} eq $config{HOSTNAME}) {
		$H = "localhost";
	}
	print "Checking ldap on ${H}:$config{LDAPPORT}...";

	my $ldapsearch = "$zimbraHome/bin/ldapsearch";
	my $args = "-x -h ${H} -p $config{LDAPPORT} ".
		"-D 'uid=zimbra,cn=admins,cn=zimbra' -w $config{LDAPPASS}";

	my $rc = 0xffff & system ("$ldapsearch $args > /tmp/zmsetup.ldap.out 2>&1");

	if ($rc) { print "FAILED\n"; } 
	else {print "Success\n";}
	return $rc;

}

sub runAsZimbra {
	my $cmd = shift;
	if ($cmd =~ /init/) {
		# Suppress passwords in log file
		my $c = (split ' ', $cmd)[0];
		print "*** Running as zimbra user: $c\n";
		print LOGFILE "*** Running as zimbra user: $c\n";
	} else {
		print "*** Running as zimbra user: $cmd\n";
		print LOGFILE "*** Running as zimbra user: $cmd\n";
	}
	my $rc;
	$rc = 0xffff & system("su - zimbra -c \"$cmd\" >> $logfile 2>&1");
	return $rc;
}

sub getLocalConfig {
	my $key = shift;
	print "Getting local config $key\n";
	print LOGFILE "Getting local config $key\n";
	my $val = `/opt/zimbra/bin/zmlocalconfig -s -m nokey ${key}`;
	chomp $val;
	return $val;
}

sub setLocalConfig {
	my $key = shift;
	my $val = shift;
	print "Setting local config $key to $val\n";
	print LOGFILE "Setting local config $key to $val\n";
	runAsZimbra("/opt/zimbra/bin/zmlocalconfig -f -e ${key}=${val}");
}

sub applyConfig {
	if (!defined ($options{c})) {
		if (askYN("Save configuration data to a file?", "Yes") eq "yes") {saveConfig();}
		if (askYN("The system will be modified - continue?", "No") eq "no") {return 1;}
	}
	print "Operations logged to $logfile\n";
	# This is the postinstall config
	my $installedServiceStr = "";
	my $enabledServiceStr = "";

	setLocalConfig ("zimbra_server_hostname", $config{HOSTNAME});

	setLocalConfig ("ldap_host", $config{LDAPHOST});
	setLocalConfig ("ldap_port", $config{LDAPPORT});
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

	if (!$ldapConfigured && isEnabled("zimbra-ldap")) {
		print "Initializing ldap...\n";
		print LOGFILE "Initializing ldap...\n";
		runAsZimbra ("/opt/zimbra/libexec/zmldapinit $config{LDAPPASS}");
		print "Done\n";
		print LOGFILE "Done\n";
	} elsif (isEnabled("zimbra-ldap")) {
		# zmldappasswd starts ldap and re-applies the ldif
		if ($ldapPassChanged) {
			print "Setting ldap password...\n";
			print LOGFILE "Setting ldap password...\n";
			runAsZimbra 
				("/opt/zimbra/openldap/sbin/slapindex -f /opt/zimbra/conf/slapd.conf");
			runAsZimbra ("/opt/zimbra/bin/zmldappasswd --root $config{LDAPPASS}");
			runAsZimbra ("/opt/zimbra/bin/zmldappasswd $config{LDAPPASS}");
			print "Done\n";
			print LOGFILE "Done\n";
		} else {
			print "Starting ldap...\n";
			print LOGFILE "Starting ldap...\n";
			runAsZimbra 
				("/opt/zimbra/openldap/sbin/slapindex -f /opt/zimbra/conf/slapd.conf");
			runAsZimbra ("ldap start");
			runAsZimbra ("zmldapapplyldif");
			print "Done\n";
			print LOGFILE "Done\n";
		}
	} else {
		setLocalConfig ("ldap_root_password", $config{LDAPPASS});
		setLocalConfig ("zimbra_ldap_password", $config{LDAPPASS});
	}

	print "Creating server entry for $config{HOSTNAME}...";
	print LOGFILE "Creating server entry for $config{HOSTNAME}...";
	runAsZimbra("/opt/zimbra/bin/zmprov cs $config{HOSTNAME}");
	print "Done\n";
	print LOGFILE "Done\n";

	if (isEnabled("zimbra-store")) {
		if ($config{USESPELL} eq "yes") {
			print "Setting spell check URL to $config{SPELLURL}...\n";
			print LOGFILE "Setting spell check URL to $config{SPELLURL}...\n";
			runAsZimbra("/opt/zimbra/bin/zmprov ms $config{HOSTNAME} ".
				"zimbraSpellCheckURL $config{SPELLURL}");
			print "Done\n";
			print LOGFILE "Done\n";
		}
		print "Setting service ports on $config{HOSTNAME}...\n";
		print LOGFILE "Setting service ports on $config{HOSTNAME}...\n";
		runAsZimbra("/opt/zimbra/bin/zmprov ms $config{HOSTNAME} ".
			"zimbraImapBindPort $config{IMAPPORT} zimbraImapSSLBindPort $config{IMAPSSLPORT} ".
			"zimbraPop3BindPort $config{POPPORT} zimbraPop3SSLBindPort $config{POPSSLPORT}");
		print "Done\n";
		print LOGFILE "Done\n";
		addServerToHostPool();
	}

	if (!$ldapConfigured && isEnabled("zimbra-ldap")) {
		if ($config{DOCREATEDOMAIN} eq "yes") {
			print "Creating domain $config{CREATEDOMAIN}...\n";
			print LOGFILE "Creating domain $config{CREATEDOMAIN}...\n";
			runAsZimbra("/opt/zimbra/bin/zmprov cd $config{CREATEDOMAIN}");
			runAsZimbra("/opt/zimbra/bin/zmprov mcf zimbraDefaultDomainName $config{CREATEDOMAIN}");
			print "Done\n";
			print LOGFILE "Done\n";
			if ($config{DOCREATEADMIN} eq "yes") {
				print "Creating user $config{CREATEADMIN}...\n";
				print LOGFILE "Creating user $config{CREATEADMIN}...\n";
				runAsZimbra("/opt/zimbra/bin/zmprov ca ".
					"$config{CREATEADMIN} \'$config{CREATEADMINPASS}\' ".
					"zimbraIsAdminAccount TRUE");
				print "Done\n";
				print LOGFILE "Done\n";
				print "Creating postmaster alias...\n";
				print LOGFILE "Creating postmaster alias...\n";
				runAsZimbra("/opt/zimbra/zmprov aaa $config{CREATEADMIN} root\@$config{CREATEDOMAIN}");
				runAsZimbra("/opt/zimbra/zmprov aaa $config{CREATEADMIN} postmaster\@$config{CREATEDOMAIN}");
				print "Done\n";
				print LOGFILE "Done\n";
			}
		}
	}

	if (!$sqlConfigured && isEnabled("zimbra-store")) {
		print "Initializing store sql database...\n";
		print LOGFILE "Initializing store sql database...\n";
		runAsZimbra ("/opt/zimbra/libexec/zmmyinit");
		print "Done\n";
		print LOGFILE "Done\n";
		print "Setting zimbraSmtpHostname for $config{HOSTNAME}\n";
		print LOGFILE "Setting zimbraSmtpHostname for $config{HOSTNAME}\n";
		runAsZimbra("/opt/zimbra/bin/zmprov ms $config{HOSTNAME} ".
			"zimbraSmtpHostname $config{SMTPHOST}");
		print "Done\n";
		print LOGFILE "Done\n";
	}

	if (!$loggerSqlConfigured && isEnabled("zimbra-logger")) {
		print "Initializing store sql database...\n";
		print LOGFILE "Initializing store sql database...\n";
		runAsZimbra ("/opt/zimbra/libexec/zmloggerinit");
		print "Done\n";
		print LOGFILE "Done\n";
	} 

	if (isEnabled("zimbra-logger")) {
		runAsZimbra ("/opt/zimbra/bin/zmprov mcf zimbraLogHostname $config{HOSTNAME}");
	}

	if (isEnabled("zimbra-mta")) {
		print "Initializing mta config...\n";
		print LOGFILE "Initializing mta config...\n";
		runAsZimbra ("/opt/zimbra/libexec/zmmtainit $config{LDAPHOST}");
		print "Done\n";
		print LOGFILE "Done\n";
		$installedServiceStr .= "zimbraServiceInstalled antivirus ";
		$installedServiceStr .= "zimbraServiceInstalled antispam ";
		if ($config{RUNAV} eq "yes") {
			$enabledServiceStr .= "zimbraServiceEnabled antivirus ";
		}
		if ($config{RUNSA} eq "yes") {
			$enabledServiceStr .= "zimbraServiceEnabled antispam ";
		}
	}

	if (isEnabled("zimbra-snmp")) {
		print "Configuring SNMP...\n";
		print LOGFILE "Configuring SNMP...\n";
		setLocalConfig ("snmp_notify", $config{SNMPNOTIFY});
		setLocalConfig ("smtp_notify", $config{SMTPNOTIFY});
		setLocalConfig ("snmp_trap_host", $config{SNMPTRAPHOST});
		setLocalConfig ("smtp_source", $config{SMTPSOURCE});
		setLocalConfig ("smtp_destination", $config{SMTPDEST});
		runAsZimbra ("/opt/zimbra/libexec/zmsnmpinit");
		print "Done\n";
		print LOGFILE "Done\n";
	}

	if (isEnabled("zimbra-spell")) {
		print "Configuring Spell server...\n";
		print LOGFILE "Configuring Spell server...\n";
		$enabledServiceStr .= "zimbraServiceEnabled spell ";
		print "Done\n";
		print LOGFILE "Done\n";
	}

	foreach my $p (keys %installedPackages) {
		if ($p eq "zimbra-core") {next;}
		if ($p eq "zimbra-apache") {next;}
		$p =~ s/zimbra-//;
		if ($p eq "store") {$p = "mailbox";}
		$installedServiceStr .= "zimbraServiceInstalled $p ";
	}

	foreach my $p (keys %enabledPackages) {
		if ($p eq "zimbra-core") {next;}
		if ($p eq "zimbra-apache") {next;}
		if ($enabledPackages{$p} eq "Enabled") {
			$p =~ s/zimbra-//;
			if ($p eq "store") {$p = "mailbox";}
			$enabledServiceStr .= "zimbraServiceEnabled $p ";
		}
	}

	print "Setting services on $config{HOSTNAME}\n";
	print LOGFILE "Setting services on $config{HOSTNAME}\n";
	runAsZimbra ("/opt/zimbra/bin/zmprov ms $config{HOSTNAME} $installedServiceStr");
	runAsZimbra ("/opt/zimbra/bin/zmprov ms $config{HOSTNAME} $enabledServiceStr");
	print "Done\n";
	print LOGFILE "Done\n";

	if (isEnabled("zimbra-store") || isEnabled("zimbra-mta")) {
		print "Setting up SSL...\n";
		print LOGFILE "Setting up SSL...\n";
		if (-f "/opt/zimbra/java/jre/lib/security/cacerts") {
			`chmod 777 /opt/zimbra/java/jre/lib/security/cacerts >> $logfile 2>&1`;
		}
		setLocalConfig ("ssl_allow_untrusted_certs", "TRUE");
		if (!-f "/opt/zimbra/tomcat/conf/keystore") {
			runAsZimbra("cd /opt/zimbra; zmcreatecert");
		}
		if (isEnabled("zimbra-store")) {
			if (!-f "/opt/zimbra/tomcat/conf/keystore") {
				runAsZimbra("cd /opt/zimbra; zmcertinstall mailbox");
			}
			runAsZimbra("cd /opt/zimbra; zmtlsctl $config{MODE}");
		}
		if (isEnabled("zimbra-mta")) {
			if (! (-f "/opt/zimbra/conf/smtpd.key" || 
				-f "/opt/zimbra/conf/smtpd.crt")) {
				runAsZimbra("cd /opt/zimbra; zmcertinstall mta ".
					"/opt/zimbra/ssl/ssl/server/smtpd.crt ".
					"/opt/zimbra/ssl/ssl/ca/ca.key");
			}
		}
		print "Done\n";
		print LOGFILE "Done\n";
	}

	setupCrontab();
	postinstall::configure();

	if ($config{STARTSERVERS} eq "yes") {
		runAsZimbra ("/opt/zimbra/bin/zmcontrol start");
		# runAsZimbra swallows the output, so call status this way
		`su - zimbra -c "/opt/zimbra/bin/zmcontrol status"`;
	}

	if ($newinstall) {
		runAsZimbra ("/opt/zimbra/bin/zmsshkeygen");
		runAsZimbra ("/opt/zimbra/bin/zmupdateauthkeys");
	}

	getSystemStatus();

	print "\n\n";
	print "Operations logged to $logfile\n";
	print "\n\n";
	if (!defined ($options{c})) {
		ask("Configuration complete - press return to exit", "");
		print "\n\n";
		exit 0;
	}
}

sub setupCrontab {

	`crontab -u zimbra -l > /tmp/crontab.zimbra.orig`;
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

	if (isEnabled("zimbra-store")) {
		`cat /opt/zimbra/zimbramon/crontabs/crontab.store >> /tmp/crontab.zimbra`;
	}

	if (isEnabled("zimbra-logger")) {
		`cat /opt/zimbra/zimbramon/crontabs/crontab.logger >> /tmp/crontab.zimbra`;
	}

	if (isEnabled("zimbra-mta")) {
		`cat /opt/zimbra/zimbramon/crontabs/crontab.mta >> /tmp/crontab.zimbra`;
	}

	`echo "# ZIMBRAEND -- DO NOT EDIT ANYTHING BETWEEN THIS LINE AND ZIMBRASTART" >> /tmp/crontab.zimbra`;
	`cat /tmp/crontab.zimbra.proc >> /tmp/crontab.zimbra`;

	`crontab -u zimbra /tmp/crontab.zimbra`;

}


sub addServerToHostPool {
	print "Adding $config{HOSTNAME} to zimbraMailHostPool in default COS\n";
	print LOGFILE "Adding $config{HOSTNAME} to zimbraMailHostPool in default COS\n";
	my $id = `/opt/zimbra/bin/zmprov gs $config{HOSTNAME} | grep zimbraId | sed -e 's/zimbraId: //'`;
	chomp $id;

	my $hp = `/opt/zimbra/bin/zmprov gc default | grep zimbraMailHostPool | sed 's/zimbraMailHostPool: //'`;
	chomp $hp;

	my @HP = split (' ', $hp);

	my $n = "";

	foreach (@HP) {
		chomp;
		$n .= "zimbraMailHostPool $_ ";
	}

	$n .= "zimbraMailHostPool $id";

	`/opt/zimbra/bin/zmprov mc default $n >> $logfile 2>&1`;
	print "Done\n";
	print LOGFILE "Done\n";
}

sub mainMenu {
	my %mm = ();
	$mm{createsub} = \&createMainMenu;

	displayMenu(\%mm);
}

sub startLdap {
	print "Starting ldap...\n";
	print LOGFILE "Starting ldap...\n";
	runAsZimbra 
		("/opt/zimbra/openldap/sbin/slapindex -f /opt/zimbra/conf/slapd.conf");
	runAsZimbra ("ldap start");
	runAsZimbra ("zmldapapplyldif");
	print "Done\n";
	print LOGFILE "Done\n";
}

getInstalledPackages();

setDefaults();

setEnabledDependencies();

getSystemStatus();

if (!$ldapRunning && $ldapConfigured) {
	startLdap();
}

if ($options{c}) {
	loadConfig ($options{c});
	applyConfig();
} else {
	mainMenu();
}

close LOGFILE;

__END__
