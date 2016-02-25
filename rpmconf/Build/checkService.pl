#!/usr/bin/perl
#
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2016 Zimbra, Inc.
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
use strict;
use lib qw(/opt/zimbra/common/lib/perl5 /opt/zimbra/zimbramon/lib);
use Getopt::Long;
use Net::LDAP;
use XML::Simple;

my %options;

GetOptions( \%options, "service=s", "help" ) or usage();

sub usage {
    print(
        "usage: checkService.pl -s SERVICE\n",
        "\t-s SERVICE: Example: -s proxy\n",
    );
    exit(0);
}

if ( $options{help} ) {
    usage();
}

unless ( $options{service} ) {
    die("ERROR: No service supplied.\n");
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
  or die "Error connecting to LDAP server: $ldap_master_url";
my $mesg;
if ( $ldap_master_url !~ /^ldaps/i ) {
    if ($ldap_starttls_supported) {
        $mesg = $ldap->start_tls(
            verify => 'none',
            capath => "/opt/zimbra/conf/ca",
        ) or die "start_tls: $@";
        $mesg->code && die "TLS: " . $mesg->error . "\n";
    }
}
$mesg = $ldap->bind( "$zimbra_admin_dn", password => "$zimbra_admin_password" );
$mesg->code && die "Bind: " . $mesg->error . "\n";
$mesg = $ldap->search(
    base   => "cn=servers,cn=zimbra",
    filter => "(zimbraServiceEnabled=$options{service})",
    attrs  => [
        'zimbraServiceEnabled', 'zimbraReverseProxyMailEnabled',
        'zimbraReverseProxyHttpEnabled'
    ],
);

my $size = $mesg->count;
if ( $size == 0 ) {
    $ldap->unbind();
    print STDERR "Error: $options{service} not enabled\n";
    exit 2;
}
else {
    if ( $options{service} eq "proxy" ) {
        foreach my $entry ( $mesg->entries ) {
            if (   $entry->get_value("zimbraReverseProxyMailEnabled") ne "TRUE"
                || $entry->get_value("zimbraReverseProxyHttpEnabled") ne
                "TRUE" ) {
                print STDERR
"Error: One or more proxies do not have zimbraReverseProxyMailEnabled and zimbraReverseProxyHttpEnabled set to TRUE. This is required for ZCS 8.7+\n";
                exit 3;
            }
        }
    }
}
