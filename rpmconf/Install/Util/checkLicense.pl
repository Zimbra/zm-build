#!/usr/bin/perl
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
