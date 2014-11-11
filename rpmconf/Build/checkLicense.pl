#!/usr/bin/perl
#
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2008, 2009, 2010, 2011, 2012, 2013, 2014 Zimbra, Inc.
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
use lib qw(/opt/zimbra/zimbramon/lib);
use LWP::UserAgent;
use Getopt::Long;

my %options = ();
my ($licenseId, $fingerprint, @license, $blah, $host);

GetOptions ("version=s"    => \$options{v},
            "internal" => \$options{i},
           );

if ($options{i}) {
  $host='zimbra-stage-license.eng.zimbra.com';
} else {
  $host='license.zimbra.com';
}

if (!($options{v})) {
  print "ERROR: No upgrade version supplied.\n";
  exit 1;
}

if ( -x '/opt/zimbra/bin/zmlicense' ) {
  @license=qx(/opt/zimbra/bin/zmlicense -p);
  my $rc = $? >> 8;
  if ($rc) {
    print "ERROR: Unable to run zmlicense.\n";
    exit 2;
  }
  foreach (@license) {
    if ($_ =~ /^LicenseId=/) {
      ($blah, $licenseId) = split /=/;
      chomp($licenseId);
    }
  }
  $fingerprint=qx(/opt/zimbra/bin/zmlicense -f);
  chomp $fingerprint;
}

my $browser = LWP::UserAgent->new;

my $response = $browser->get("https://$host/zimbraLicensePortal/public/activation?action=getActivation&licenseId=$licenseId&version=$options{v}&fingerprint=$fingerprint");

if ($response->is_success) {
  print "SUCCESS: ".$response->content."\n";
  exit 0;
} else {
  print "ERROR: ".$response->content."\n";
  exit 1;
}
