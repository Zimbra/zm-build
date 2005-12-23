package Zimbra::Customer;

use Zimbra::LicensingDB;

sub new {
	my $class = shift;
	my $attrs = shift;
	my $self = {};
	bless $self, $class;
	if (defined ($attrs)) {
		$self->{name} = $$attrs{name};
		$self->{id} = $$attrs{id};
	}
	return $self;
}

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
	my $self = shift;
	#print "Storing customer $self->{name} in database...";
	$self->{id} = Zimbra::LicensingDB::putCustomer($self);
	if (defined($self->{id})) {
	#print "Customer ID $self->{id}...Done\n";
	return 1;
	}
	#print "FAILED\n";
	return undef;
}

sub display {
	my $self = shift;
	print "ID: $self->{id}\n";
	print "Name: $self->{name}\n";
}

1;
