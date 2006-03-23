package Zimbra::License;

use strict;

sub new {
	my $class = shift;
	my $attrs = shift;
	my $self = {};
	bless $self, $class;
	if (defined ($attrs)) {
		$self->{id} = $$attrs{id};
		$self->{license_text} = $$attrs{license_text};
		$self->{license_version} = $$attrs{license_version};
		$self->{customer_id} = $$attrs{customer_id};
		$self->{expiration} = $$attrs{expiration};
		$self->{is_deleted} = $$attrs{is_deleted};
		foreach (keys %{$$attrs{options}}) {
			$self->{options}{$_} = $$attrs{options}{$_};
		}
	}
	return $self;
}

sub toText {
	my $self = shift;
	my $verbose = shift;
	return ($self->licenseToText($verbose));
}

sub licenseToText {
	my $self = shift;
	my $verbose = shift;

	my $txt = "";
	if ($self->{is_deleted}) {
		$txt .= "THIS LICENSE IS DELETED\n";
	}
	if ($verbose) {
		$txt .= $self->{license_text},"\n";
	} else {
		$txt .= sprintf ("License ID: %d\n", $self->{id});
		$txt .= sprintf ("License Version: %d\n", $self->{license_version});
		$txt .= sprintf ("Customer ID: %d\n", $self->{customer_id});
		$txt .= sprintf ("Expiration: %s\n", $self->{expiration});
		foreach (sort keys %{$self->{options}}) {
			$txt .= sprintf ("OPTION: %s %s\n", $_, $self->{options}{$_});
		}
	}
	return $txt;
}

sub generate {
	my $self = shift;
	print "Generating license...";

	$self->{license_version} = Zimbra::LicenseKey::getCurrentKeyId();

	$self->{license_text} = Zimbra::LicenseKey::sign($self->licenseToText())."\n".$self->licenseToText();

	print "Done\n";
	return 1;
}

sub display {
	my $self = shift;
	my $verbose = shift;
	print $self->toText($verbose);
}

sub licenseSignature {
	my $self = shift;
	my @sig = split ('\n',$self->{license_text});
	my $s = "";
	foreach (@sig) {
		if (/^$/) {last;}
		$s .= $_."\n";
	}
	return $s;
}

sub verify {
	my $self = shift;
	my $verbose = shift;

	my $key = Zimbra::LicenseKey::getKey($self->{license_version});

	return ($key->verify($self->licenseSignature(),$self->licenseToText()));

	return 0;
}

1;
