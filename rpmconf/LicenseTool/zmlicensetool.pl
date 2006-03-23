#!/usr/bin/perl

use strict;
use Zimbra::LicensingDB;
use Zimbra::License;
use Zimbra::LicenseKey;
use Zimbra::Customer;

use Getopt::Long;

my %options = ();
my %license_options = ();

my %actions = (
	'license_modify'	=> \&modifyLicense,
	'license_verify'	=> \&verifyLicense,
	'license_display'	=> \&displayLicense,
	'license_create'	=> \&createLicense,
	'license_list'		=> \&listLicenses,
	'key_delete'		=> \&deleteKey,
	'key_display'		=> \&displayKey,
	'key_create'		=> \&createKey,
	'key_list'			=> \&listKeys,
	'customer_modify'	=> \&modifyCustomer,
	'customer_display'	=> \&displayCustomer,
	'customer_create'	=> \&createCustomer,
	'customer_list'		=> \&listCustomers,
);

GetOptions (
	'help|h|?'		=> \$options{'help'},
	'verbose'		=> \$options{'verbose'},
	'id=s'			=> \$options{'id'},
	'display'		=> sub { $options{'opt'} = 'display' },
	'create'		=> sub { $options{'opt'} = 'create' },
	'list'			=> sub { $options{'opt'} = 'list' },
	'verify'		=> sub { $options{'opt'} = 'verify' },
	'modify'		=> sub { $options{'opt'} = 'modify' },
	'delete'		=> sub { $options{'opt'} = 'delete' },
	'key'			=> sub { $options{'action'} = 'key' },
	'license'		=> sub { $options{'action'} = 'license' },
	'customer'		=> sub { $options{'action'} = 'customer' },
	'expiration=s'  => \$options{'expiration'},
	'name=s'  		=> \$options{'name'},
	"opt=s"			=> \%license_options,
	);

setAction($options{'action'}, $options{'opt'});

if (defined ($options{'help'}) ) {
	usage();
}

if (!defined ($actions{$options{'action'}})) {
	usage("Unknown command $options{'action'}");
}

&{$actions{$options{'action'}}}();

sub setAction {
	my $act = shift;
	my $opt = shift;
	$options{'action'} = "${act}_${opt}";
	if (!defined ($actions{$options{'action'}})) {
		usage("Unknown command $act");
	}
}

sub displayCurrentKey {
	my $key = getCurrentKey();
	if (!defined($key)) {
		die "Can't get current key\n";
	}
	$key->display($options{'verbose'});
}

sub displayKey {

	if (!defined ($options{'id'}) ) {
		usage ("No key specified!");
	}
	if ($options{'id'} =~ /current/i) {return displayCurrentKey()};
	my $key = getKey($options{'id'});
	if (!defined($key)) {
		die "Can't get key $options{'id'}\n";
	}
	$key->display($options{'verbose'});
}

sub createKey {
	my %attrs = ();
	my $key = new Zimbra::LicenseKey;
	if (!$key->generate()) {
		exit 1;
	}
	if (!putKey($key)) {
		exit 1;
	}
	$key->display($options{'verbose'});
}

sub listKeys {
	my $ids = getKeyIds();

	foreach (@$ids) {
		my $key = getKey($$_[0]);
		if (!defined($key)) {
			warn "Can't get key $$_[0]\n";
		}
		$key->display($options{'verbose'});
	}

}

sub verifyLicense {
	if (!defined($options{'id'})) {
		usage ("Missing license id");
	}
	my $license = getLicense($options{'id'});
	if (!defined($license)) {
		usage ("Can't get license $options{'id'}\n");
	}

	if ($license->verify($options{'verbose'})) {
		print "License verified\n";
		exit 0;
	} else {
		print "Verification FAILED\n";
		exit 1;
	}
}

sub displayLicense {
	if (!defined($options{'id'})) {
		usage ("Missing license id");
	}

	my $license = getLicense($options{'id'});
	if (!defined($license)) {
		usage ("Can't get license $options{'id'}\n");
	}
	$license->display($options{'verbose'});
}

sub createLicense {
	if (!defined($options{'id'})) {
		usage ("Missing customer id");
	}
	if (!defined($options{'expiration'})) {
		usage ("Missing license expiration");
	}
	$options{'expiration'} = "$options{'expiration'} 00:00:00";

	my $customer = getCustomer($options{id});
	if (!defined ($customer)) {
		usage ("Customer $options{id} not found!");
	}

	my $license = new Zimbra::License();

	if (!defined ($license)) {
		usage();
	}
	$license->{'customer_id'} = $customer->{'id'};
	$license->{'expiration'} = $options{'expiration'};
	$license->{license_version} = getCurrentKeyId();

	foreach (sort keys %license_options) {
		$license->{options}{$_} = $license_options{$_};
	}

	my $id = putLicense($license);

	if (!$id) {
		usage ("License creation failed");
	}

	if (!$license->generate()) {
		usage ("License generation failed!");
	}

	if (!updateLicense($license)) {
		usage ("License generation failed!");
	}

	$license->display($options{'verbose'});

}

sub createCustomer {
	if (!defined($options{'name'})) {
		usage ("Missing customer name");
	}
	my $customer = new Zimbra::Customer();
	$customer->{name} = $options{'name'};
	if (defined($customer)) {
		my $id = putCustomer($customer);
		if ($id) {
			$customer->display($options{'verbose'});
		}
	}
}

sub displayCustomer {
	if (!defined ($options{'id'}) ) {
		usage ("No customer specified!");
	}
	my $customer = getCustomer($options{'id'});
	if (defined($customer)) {
		$customer->display($options{'verbose'});
	}
}

sub listCustomers {
	my $ids = getCustomerIds();

	foreach (@$ids) {
		my $customer = getCustomer($$_[0]);
		if (!defined($customer)) {
			warn "Can't get customer $$_[0]\n";
		}
		$customer->display($options{'verbose'});
	}
}

sub listLicenses {
	my $ids = getLicenseIds();

	foreach (@$ids) {
		my $license = getLicense($$_[0]);
		if (!defined($license)) {
			warn "Can't get license $$_[0]\n";
		}
		$license->display($options{'verbose'});
	}
}


sub modifyLicense {
	if (!defined($options{'id'})) {
		usage ("Missing license id");
	}

	my $customer;

	my $license = getLicense($options{'id'});
	if (!defined($license)) {
		usage ("Can't get license $options{'id'}\n");
	}

	if (defined ($options{'expiration'})) {
		$license->{'expiration'} = $options{'expiration'}." 00:00:00";
	}

	if (defined ($license_options{'customer'})) {
		$customer = getCustomer($license_options{'customer'});
		if (!defined($customer)) {
			usage ("Can't get customer $license_options{'customer'}\n");
		}
		$license->{'customer_id'} = $customer->{'id'};

		delete $license_options{'customer'};
	}

	if (defined ($license_options{'is_deleted'})) {
		$license->{'is_deleted'} = $license_options{'is_deleted'};

		delete $license_options{'is_deleted'};
	}

	foreach (keys %license_options) {
		$license->{options}{$_} = $license_options{$_};
	}

	if (!$license->generate()) {
		usage ("License generation failed!");
	}

	if (!updateLicense($license)) {
		usage ("License generation failed!");
	}

	$license->display($options{'verbose'});
}

sub usage {
	my $msg = shift;
	print STDERR $msg;
	print STDERR "\n";
	print STDERR<<EOF;
USAGE: $0 <command> <subcommand> <options> [--verbose]
Command is one of:
  --key          key operations
    key subcommands:
      --list     list keys
      --create   create key
      --delete   delete key
      --display --id <id> display key <id>

  --customer     customer operations
      --list     list customers
      --create   --name <customer name> create customer
      --display --id <id> display customer <id>

  --license      license operations
      --list     list licenses
      --display --id <id> display license <id>
      --verify  --id <id> verify license <id>
      --create   create license
        --create --id <customer_id> --expiration <YYYY-MM-DD> [--opt key=val]
      --modify 
        --modify --id <license_id> [--expiration <YYYY-MM-DD>] [--opt key=val]
EOF

	exit 1;
}

## Db Access commands

sub getCustomerIds {
	my $ids = Zimbra::LicensingDB::getCustomerIds();
	return $ids;
}

sub getCustomer {
	my $id = shift;
	#print "Fetching customer $id from database...";
	my $attrs = Zimbra::LicensingDB::getCustomer($id);
	if (defined ($attrs)) {
		my $customer = new Zimbra::Customer($attrs);
		#print "Done\n";
		return $customer;
	}
	#print "FAILED\n";
	return undef;
}

sub putCustomer {
	my $customer = shift;
	#print "Storing customer $self->{name} in database...";
	$customer->{id} = Zimbra::LicensingDB::putCustomer($customer);
	if (defined($customer->{id})) {
		#print "Customer ID $customer->{id}...Done\n";
		return 1;
	}
	#print "FAILED\n";
	return undef;
}

sub getCurrentKeyId {
	my $ids = getKeyIds();
	if ($#$ids < 0) {return undef;}
	my $curId = $$ids[$#$ids][0];
	return $curId;
}

sub getCurrentKey {
	my $id = getCurrentKeyId;
	if (!defined ($id)) {
		return undef;
	}
	return (getKey($id));
}

sub getKeyIds {
	my $ids = Zimbra::LicensingDB::getKeyIds();
	return $ids;
}

sub getKey {
	my $keyId = shift;
	#print "Fetching key $keyId from database...";
	my $attrs = Zimbra::LicensingDB::getKey($keyId);
	if (defined ($attrs)) {
		my $key = new Zimbra::LicenseKey($attrs);
		#print "Done\n";
		return $key;
	}
	#print "FAILED\n";
	return undef;
}

sub putKey {
	my $key = shift;

	#print "Storing key in database...";
	$key->{id} = Zimbra::LicensingDB::putKey($key);
	if (defined($key->{id})) {
		#print "Key ID $key->{id}...Done\n";
		return 1;
	}
	#print "FAILED\n";
	return undef;
}

sub getLicenseIds {
	my $ids = Zimbra::LicensingDB::getLicenseIds();
	return $ids;
}

sub getLicense {
	my $id = shift;
	my $attrs = Zimbra::LicensingDB::getLicense($id);
	if (defined($attrs)) {
		my $license = new Zimbra::License($attrs);
		return $license;
	}
	return undef;
}

sub putLicense {
	my $license = shift;
	#print "Storing license in database...";
	$license->{id} = Zimbra::LicensingDB::putLicense($license);
	if (defined($license->{id})) {
		#print "License ID $license->{id}...Done\n";
		return 1;
	}
	#print "FAILED\n";
	return undef;
}

sub updateLicense {
	my $license = shift;
	#print "Storing license in database...";
	if (Zimbra::LicensingDB::updateLicense($license)) {
		return 1;
	}
	#print "FAILED\n";
	return undef;
}   

