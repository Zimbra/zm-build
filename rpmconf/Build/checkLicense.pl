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
use Digest::MD5;

my %options;
my ( $licenseId, $fingerprint, @license, $blah, $host );

GetOptions( \%options, "version=s", "internal", "help" ) or usage();

sub usage {
    print(
        "usage: checkLicense.pl -v VERSION [-i]\n",
        "\t-v VERSION: Example: -v 8.7.0\n",
        "\t-i: Internal Zimbra usage\n"
    );
    exit(0);
}

if ( $options{help} ) {
    usage();
}

if ( $options{internal} ) {
    $host = 'zimbra-stage-license.eng.zimbra.com';
}
else {
    $host = 'license.zimbra.com';
}

unless ( $options{version} ) {
    myDie(3,"ERROR: No upgrade version supplied.\n");
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
    filter => "(zimbraNetworkLicense=*)",
    scope  => "base",
    attrs  => [ 'zimbraNetworkLicense', 'createTimestamp' ],
);

my $size = $mesg->count;
if ( $size == 0 ) {
    $ldap->unbind();
    myDie(2,"Error: License not found\n");
}

my $entry           = $mesg->entry(0);
my $license         = $entry->get_value("zimbraNetworkLicense");
my $createTimestamp = $entry->get_value("createTimestamp");
my $licensexml      = XMLin($license);
$licenseId = $licensexml->{item}->{LicenseId}->{value};
my $ctx = Digest::MD5->new;
$ctx->add($createTimestamp);
$fingerprint = $ctx->hexdigest;
$ldap->unbind();

my $caf = '/opt/zimbra/zimbramon/lib/Mozilla/CA/cacert.pem';
my @lwpargs = -f $caf ? ( ssl_opts => { SSL_ca_file => $caf, SSL_ca_path => undef } ) : ();
my $browser = LWP::UserAgent->new(@lwpargs);
$browser->env_proxy;

my $response = $browser->get(
"https://$host/zimbraLicensePortal/public/activation?action=getActivation&licenseId=$licenseId&version=$options{version}&fingerprint=$fingerprint"
);

if ( $response->is_success ) {
    myDie(0,"SUCCESS: ", $response->content, "\n");
}
else {
    myDie(1,"ERROR: ", $response->content, "\n");
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
