package Zimbra::LicensingDB;

use strict;
use DBI;
use Time::Local;

#my $data_source="dbi:mysql:database=license;mysql_read_default_file=/opt/zimbra/conf/my.logger.cnf;mysql_socket=/opt/zimbra/logger/db/mysql.sock";
my $data_source="dbi:mysql:database=license;mysql_read_default_file=/etc/my.cnf;mysql_socket=/var/lib/mysql/mysql.sock";

my $username="license";
my $password = "licensing";

my $dbh = DBI->connect($data_source, $username, $password, {PrintError=>0});

if (!$dbh) {
	print STDERR "DB: Can't connect to $data_source: $DBI::errstr\n";
	exit 1;
}

sub tsToSqlTime {
	my $ts = shift;
	my $dayTrunc = shift;
	# 2005-09-18 04:03:33
	my @tm = localtime($ts);

	# Truncate at hours.
	if (defined($dayTrunc)) {
		return sprintf ("%4d-%02d-%02d %02d:%02d:%02d",
		$tm[5]+1900,$tm[4]+1,$tm[3],0,0,0);
	} else {
		return sprintf ("%4d-%02d-%02d %02d:%02d:%02d",
		$tm[5]+1900,$tm[4]+1,$tm[3],$tm[2],0,0);
	}
}

sub sqlTimeToTs {
	my $sqlTime = shift;
	# 2005-09-18 04:03:33
	return timelocal(substr($sqlTime,17,2),substr($sqlTime,14,2),
		substr($sqlTime,11,2),substr($sqlTime,8,2),
		(substr($sqlTime,5,2)-1),substr($sqlTime,0,4));
}

sub getCustomer {
	my $id = shift;
	my $statement = "select id, name from customer where id=\"$id\"";
	my $customer = $dbh->selectrow_hashref($statement);
	if (defined($customer)) {
		return $customer;
	} else {
		return undef;
	}
}

sub putCustomer {
	my $customer = shift;
	my $statement = "insert into customer (name) values (?)";
	my $sth = sqlExec ($statement, $customer->{name});
	if (!$sth) {
		return undef;
	}
	my $h = $dbh->selectrow_hashref("select max(id) as id from customer");
	my $id = $h->{id};
	return $id;
}

sub getKeyIds {
	my $statement = "select id from sign_keys";
	my $ids = $dbh->selectall_arrayref($statement);
	return $ids;
}

sub getCustomerIds {
	my $statement = "select id from customer";
	my $ids = $dbh->selectall_arrayref($statement);
	return $ids;
}

sub getKey {
	my $id = shift;
	my $statement = "select id, pubkey, privkey, gendate, expiredate, is_expired ".
		"from sign_keys where id=\"$id\"";
	my $key = $dbh->selectrow_hashref($statement);
	if (defined($key)) {
		return $key;
	} else {
		return undef;
	}
}

sub putKey {
	my $key = shift;
	my $statement = "insert into sign_keys (pubkey, privkey, gendate, expiredate, is_expired) ".
		"values (?,?,?,?,?)";
	my $sth = sqlExec ($statement,
						Zimbra::LicenseKey::keyToString($key->{pubkey}),
						Zimbra::LicenseKey::keyToString($key->{privkey}),
						tsToSqlTime($key->{gendate}),
						tsToSqlTime($key->{expiredate}),
						$key->{is_expired});
	my $h = $dbh->selectrow_hashref("select max(id) as id from sign_keys");
	my $id = $h->{id};
	return $id;
}

sub getLicenseIds {
	my $statement = "select id from customer_license";
	my $ids = $dbh->selectall_arrayref($statement);
	return $ids;
}

sub getLicense {
	my $id = shift;
	my $statement = "select id, expiration, customer_id, license_text, license_version, is_deleted ".
		"from customer_license where id=\"$id\"";
	my $license = $dbh->selectrow_hashref($statement);
	if (!defined($license)) {
		return undef;
	}
	
	$statement = "select name, value from license_details where license_id=\"$id\"";
	my $ary = $dbh->selectall_arrayref($statement);
	foreach my $row (@$ary) {
		#print "$$row[0] == $$row[1]\n";
		$license->{options}{$$row[0]} = $$row[1];
	}
	return $license;
}

sub updateLicense {
	my $license = shift;
	my $statement = "update customer_license set customer_id=\"$license->{customer_id}\", ".
		"expiration=\"$license->{expiration}\", ".
		"license_text=\'$license->{license_text}\', ".
		"license_version=\"$license->{license_version}\", ".
		"is_deleted=\"$license->{is_deleted}\" ".
		"where id=\"$license->{id}\"";
	my $sth = sqlExec ($statement);
	if (!$sth) {
		return undef;
	}

	$statement = "delete from license_details where license_id=\"$license->{id}\"";
	my $sth = sqlExec ($statement);
	if (!$sth) {
		return undef;
	}

	$statement = "insert into license_details (license_id, name, value) values (?,?,?)";

	foreach (sort keys %{$license->{options}}) {
		$sth = sqlExec ($statement, $license->{id}, $_, $license->{options}{$_});
		if (!$sth) {
			return undef;
		}
	}
	return 1;
}

sub putLicense {
	my $license = shift;
	my $statement = "insert into customer_license (customer_id, expiration, license_text, license_version) ".
		"values (?,?,?,?)";
	my $sth = sqlExec ($statement, $license->{customer_id}, 
		$license->{expiration}, 
		$license->{license_text}, 
		$license->{license_version});
	if (!$sth) {
		return undef;
	}
	my $h = $dbh->selectrow_hashref("select max(id) as id from customer_license");

	my $id = $h->{id};
	return $id;

	$statement = "insert into license_details (license_id, name, value) values (?,?,?)";

	foreach (sort keys %{$license->{options}}) {
		$sth = sqlExec ($statement, $license->{id}, $_, $license->{options}{$_});
		if (!$sth) {
			return undef;
		}
	}
}

sub sqlExec {
	my $statement = shift;
	my @args = @_;

	my $sth = $dbh->prepare($statement);

	#print "Executing $statement with @args\n\n";

	eval {
		if (!$sth->execute(@args) ) {
			die $sth->errstr;
		}
	};
	if ($@) {
		print "Error executing $statement with @args\n";
		print $sth->errstr,"\n";
		print "$@\n";
		return undef;
	}

	return $sth;
}

1;
