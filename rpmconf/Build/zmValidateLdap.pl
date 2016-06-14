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
# Must be run on a system where the ldap_url key is set to contain all of the
# replicas, as that is how the script determines what replicas exist.

use strict;
use lib qw(/opt/zimbra/common/lib/perl5/ /opt/zimbra/zimbramon/lib);
use Net::LDAP;
use Getopt::Long;

my ( %c, %loaded, %options );

$c{zmlocalconfig} = "/opt/zimbra/bin/zmlocalconfig";
my @verargs = qw (vmajor vminor vmicro umajor uminor umicro);

my $opts_good = GetOptions(
    "vmajor=i" => \$options{vmajor},
    "vminor=i" => \$options{vminor},
    "vmicro=i" => \$options{vmicro},
    "umajor=i" => \$options{umajor},
    "uminor=i" => \$options{uminor},
    "umicro=i" => \$options{umicro},
    "ldap"     => \$options{l},
);

if ( !$opts_good ) {
    print "Error: Invalid options.\n";
    exit 1;
}

my $ldap_is_master = getLocalConfig("ldap_is_master");
if ( lc($ldap_is_master) ne "true" ) {
    foreach my $arg (@verargs) {
        unless ( defined $options{$arg} ) {
            print
"Error: All of current major.minor.micro and upgrade major.minor.micro must be provided.\n";
            exit 1;
        }
    }
}

my $ldap_master             = getLocalConfig("ldap_master_url");
my $admin_user              = getLocalConfig("zimbra_ldap_userdn");
my $admin_password          = getLocalConfig("zimbra_ldap_password");
my $ldap_starttls_supported = getLocalConfig("ldap_starttls_supported");
my $upgradeOK               = 1;

my ( $mesgp, $entry );
my @masters = split / /, $ldap_master;
foreach my $master (@masters) {
    my $ldapp;
    chomp($master);
    if ( $master =~ /^ldaps:/ ) {
        $ldapp = Net::LDAP->new(
            $master,
            verify => 'require',
            capath => '/opt/zimbra/conf/ca'
        );
    }
    else {
        if ( $ldapp = Net::LDAP->new($master) ) {
            if ($ldap_starttls_supported) {
                $mesgp = $ldapp->start_tls(
                    verify => 'require',
                    capath => "/opt/zimbra/conf/ca",
                );
                if ( $mesgp->code ) {
                    print
"ERROR: Unable to connect via startTLS to master: $master\n";
                    exit 1;
                }
            }
        }
    }
    if ( !defined($ldapp) ) {
        print "ERROR: No LDAP connection.\n";
        exit 1;
    }
    if ( lc($ldap_is_master) ne "true" ) {
        $mesgp = $ldapp->bind( $admin_user, password => $admin_password );
        if ( $mesgp->code ) {
            print "ERROR: Unable to bind as the Zimbra Admin LDAP user.\n";
            $ldapp->unbind();
            exit 3;
        }
        my $ldap_master_host = $ldapp->host();
        $mesgp = $ldapp->search(
            base   => "cn=servers,cn=zimbra",
            filter => "cn=$ldap_master_host",
            attrs  => [
                'zimbraServerVersionMajor', 'zimbraServerVersionMinor',
                'zimbraServerVersionMicro', 'zimbraServerVersionType',
                'zimbraServerVersionBuild',
            ]
        );
        if ( $mesgp->code ) {
            print "Search error: Unable to search master.\n";
            exit 4;
        }
        my $size = $mesgp->count;
        if ( $size != 1 ) {
            print
"Size error: Invalid response from ldap master. Please verify cn=$ldap_master_host,cn=servers,cn=zimbra exists in ldap and is a master ldap server.\n";
            exit 4;
        }
        my ( $lmMajor, $lmMinor, $lmMicro, $lmType );
        my $entry = $mesgp->entry(0);
        chomp( $lmMajor = $entry->get_value('zimbraServerVersionMajor') );
        chomp( $lmMinor = $entry->get_value('zimbraServerVersionMinor') );
        chomp( $lmMicro = $entry->get_value('zimbraServerVersionMicro') );
        if ( $lmMajor eq "" ) {
            $upgradeOK = 0;
            $ldapp->unbind;
        }
        if (   ( $lmMajor != $options{umajor} )
            || ( $lmMinor != $options{uminor} )
            || ( $lmMicro != $options{umicro} ) )
        {
            $upgradeOK = 0;
            $ldapp->unbind;
        }
    }
}

if ( !$upgradeOK ) {
    print "ERROR: One or more masters have not yet been upgraded.  Aborting.\n";
    exit 5;
}

if ( $options{l} ) {
    if (   -f '/opt/zimbra/data/ldap/mdb/db/data.mdb'
        || -f '/opt/zimbra/data/ldap/hdb/db/id2entry.bdb' )
    {
        my $ldap_root_password = getLocalConfig("ldap_root_password");
        my $ldap;
        if ( $options{vmajor} < 8
            || ( $options{vmajor} == 8 && $options{vminor} == 0 ) )
        {
            $ldap = Net::LDAP->new(
                'ldapi://%2fopt%2fzimbra%2fopenldap%2fvar%2frun%2fldapi/')
              or die "$@";
        }
        else {
            $ldap = Net::LDAP->new(
                'ldapi://%2fopt%2fzimbra%2fdata%2fldap%2fstate%2frun%2fldapi/')
              or die "$@";
        }
        my $mesg = $ldap->bind( "cn=config", password => $ldap_root_password );
        if ( $mesg->code ) {
            print "ERROR: Unable to bind as root LDAP user.\n";
            $ldap->unbind();
            exit 2;
        }
        my $admin_user     = getLocalConfig("zimbra_ldap_userdn");
        my $admin_password = getLocalConfig("zimbra_ldap_password");
        $mesg = $ldap->bind( $admin_user, password => $admin_password );
        if ( $mesg->code ) {
            print "ERROR: Unable to bind as Zimbra Admin LDAP user.\n";
            $ldap->unbind();
            exit 3;
        }
        $ldap->unbind();
    }
}

sub getLocalConfig {
    my ( $key, $force ) = @_;

    return $loaded{lc}{$key}
      if ( exists $loaded{lc}{$key} && !$force );
    my $val = qx($c{zmlocalconfig} -x -s -m nokey ${key} 2> /dev/null);
    chomp($val);
    $loaded{lc}{$key} = $val;
    return $val;
}
