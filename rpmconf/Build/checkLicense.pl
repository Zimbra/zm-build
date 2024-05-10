#!/usr/bin/perl
#
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2014, 2015, 2016 Synacor, Inc.
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software Foundation,
# version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with this program.
# If not, see <https://www.gnu.org/licenses/>.
# ***** END LICENSE BLOCK *****
#
use strict;

use lib qw(/opt/zimbra/common/lib/perl5 /opt/zimbra/zimbramon/lib);
use LWP::UserAgent;
use Getopt::Long;
use Net::LDAP;
use XML::Simple;

sub valid_licensekey {
	my ($licensekey) = @_;
	return $licensekey =~ /^[A-Za-z0-9]{18,24}$/;
}

sub set_permissions {
	my ($file) = @_;
	system("chown zimbra:zimbra $file");
	system("chmod 644 $file");
}

sub compare_versions {
	my ($version1, $version2) = @_;
	my @v1 = split /\./, $version1;
	my @v2 = split /\./, $version2;
	for my $i (0 .. $#v1) {
		return -1 if !defined $v2[$i];
		return 1  if $v1[$i] > $v2[$i];
		return -1 if $v1[$i] < $v2[$i];
	}
	return 0 if @v1 == @v2;
	return 1 if @v1 > @v2;
	return -1;
}
my %options;
my ( $licensekey, $blah, $host );

GetOptions(
	\%options,
	"upgradeVersion|uv=s",
	"currentVersion|cv=s",
	"internal",
	"help"
) or usage();

sub usage {
    print(
        "usage: checkLicense.pl -uv UPGRADEVERSION -cv CURRENTVERSION [-i]\n",
        "\t-uv UPGRADEVERSION: Example: -uv 8.7.0\n",
        "\t-cv CURRENTVERSION: Example: -cv 8.6.0\n",
        "\t-i: Internal Zimbra usage\n",
        "\t-h: Display this help message\n"
    );
    exit(0);
}

if ( $options{help} ) {
    usage();
}

if ( $options{internal} ) {
    $host = 'http://zimbra-stage-license.eng.zimbra.com';
}
else {
    $host = 'https://license.zimbra.com';
}

unless ( $options{upgradeVersion} && $options{currentVersion} ) {
    myDie(3,"ERROR: Both upgrade version and current version must be supplied.\n");
}

my $localxml              = XMLin("/opt/zimbra/conf/localconfig.xml");
my $ldap_master_url       = $localxml->{key}->{ldap_master_url}->{value};
my $master_ref            = [ split( " ", $ldap_master_url ) ];
my $zimbra_admin_dn       = $localxml->{key}->{zimbra_ldap_userdn}->{value};
my $zimbra_admin_password = $localxml->{key}->{zimbra_ldap_password}->{value};
chomp($zimbra_admin_password);
my $ldap_starttls_supported =
  $localxml->{key}->{ldap_starttls_supported}->{value};
my $zimbra_require_interprocess_security =
  $localxml->{key}->{zimbra_require_interprocess_security}->{value};

my $ldap = Net::LDAP->new($master_ref)
  or myDie(4,"Error connecting to LDAP server: $ldap_master_url\n");
my $mesg;
if ( $ldap_master_url !~ /^ldaps/i ) {
    if ($ldap_starttls_supported) {
        $mesg = $ldap->start_tls(
            verify => 'none',
            capath => "/opt/zimbra/conf/ca",
        ) or myDie(5,"start_tls: $@\n");
        $mesg->code && myDie(5,"TLS: ", $mesg->error, "\n");
    }
}
$mesg = $ldap->bind( "$zimbra_admin_dn", password => "$zimbra_admin_password" );
$mesg->code && myDie(6,"Bind: ", $mesg->error, "\n");
$mesg = $ldap->search(
    base   => "cn=config,cn=zimbra",
    filter => "(zimbraNetworkRealtimeLicense=*)",
    scope  => "base",
    attrs  => [ 'zimbraNetworkRealtimeLicense'],
);

my $size = $mesg->count;
if (compare_versions($options{currentVersion}, '10.1.0') >= 0 && $size == 0) {
	$ldap->unbind();
	myDie(2,"Error: License key not detected\n");
}

my $entry           = $mesg->entry(0);
my $licensekey = "";
if ($entry) {
	$licensekey = $entry->get_value("zimbraNetworkRealtimeLicense");
}
if (!defined($licensekey) || $licensekey eq '') {
	my $license_file = "/opt/zimbra/conf/ZCSLicensekey";
	if (-e $license_file) {
		chomp($licensekey = qx(cat $license_file));
	} else {
		print "\n";
		print "Please enter the license key (an alphanumeric string of 18-24 characters without any special characters):";
		$licensekey = <STDIN>;
		chomp($licensekey);
		if (!valid_licensekey($licensekey)) {
			myDie(7,"Error: Invalid license key entered \n");
		}
		system("echo \"$licensekey\" > $license_file");
		set_permissions($license_file);
	}
}
my $caf = '/opt/zimbra/zimbramon/lib/Mozilla/CA/cacert.pem';
my @lwpargs = -f $caf ? ( ssl_opts => { SSL_ca_file => $caf, SSL_ca_path => undef } ) : ();
my $browser = LWP::UserAgent->new(@lwpargs);
$browser->env_proxy;
my $request = HTTP::Request->new(POST => "$host/rest/v1/public/license/$licensekey/validate?version=$options{upgradeVersion}");
$request->header('Content-Type' => 'application/json');
my $response = $browser->request($request);
if ( $response->is_success ) {
	my $json_content = $response->content;
	my ($status_code) = $json_content =~ /"status":\s*(\d+)/;
	if (defined $status_code && $status_code == 2000) {
		my ($status_message) = $json_content =~ /"statusMessage":\s*"([^"]*)"/;
		myDie(0, "SUCCESS: ", $status_message, "\n");
	} else {
		myDie(1, "ERROR: ", $response->content, "\n");

	}
} else {
	myDie(1, "ERROR: ", $response->content, "\n");
}

sub myDie() {
  my ($rc, @msg) = @_;
  if (@msg) {
    if ($rc != 0) {
      warn (@msg);
    } else {
      print STDOUT @msg;
    }
  }
  exit ($rc);
}
