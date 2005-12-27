package Zimbra::LicenseKey;

# id                      INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
# pubkey          TEXT NOT NULL,
# privkey         TEXT NOT NULL,
# gendate         DATETIME NOT NULL,
# expiredate      DATETIME NOT NULL,
# is_expired      BOOL NOT NULL DEFAULT 0

use strict;
use Time::Local;

sub new {
	my $class = shift;
	my $attrs = shift;
	my $self = {};
	bless $self, $class;
	$self->{is_expired} = 0;
	if (defined $attrs) {
		$self->{is_expired} = $$attrs{is_expired};
		$self->{gendate} = sqlTimeToTs($$attrs{gendate});
		$self->{expiredate} = sqlTimeToTs($$attrs{expiredate});
		@{$self->{pubkey}} = ();
		foreach (split /\n/, $$attrs{pubkey}) {
			push @{$self->{pubkey}}, $_."\n";
		}
		@{$self->{privkey}} = ();
		foreach (split /\n/, $$attrs{privkey}) {
			push @{$self->{privkey}}, $_."\n";
		}
		$self->{id} = $$attrs{id};
	}
	return $self;
}

sub toText {
	my $self = shift;
	my $verbose = shift;

	my $txt = "";
	if ($self->{is_expired}) {
		$txt .= "KEY EXPIRED\n\n";
	}
	$txt .= "ID: ";
	if (defined($self->{id})) {
		$txt .= $self->{id};
	} else {
		$txt .= "NULL";
	}
	$txt .= "\n";
	$txt .= "Created: ". tsToSqlTime($self->{gendate}). "\n";
	$txt .= "Expires: ". tsToSqlTime($self->{expiredate}). "\n";
	if ($verbose) {
		$txt .= "Private Key: \n";
		$txt .= "".Zimbra::LicenseKey::keyToString($self->{privkey});
		$txt .= "Public Key: \n";
		$txt .= "".Zimbra::LicenseKey::keyToString($self->{pubkey});
	}
	return $txt;
}

sub display {
	my $self = shift;
	my $verbose = shift;

	print $self->toText($verbose);
}

sub keyToString {
	my $key = shift;
	my $rv = "";
	foreach (@{$key}) {
		$rv .= $_;
	}
	return $rv;
}

sub generate {
	print "Generating key...";
	my $self = shift;
	my $ed = shift;
	my $gd = time();
	if ($ed eq "") {
		# default 365 days
		$ed = $gd + (60*60*24*365);
	} else {
	}

	$self->{'gendate'} = $gd;
	$self->{'expiredate'} = $ed;
	# id  set when we store it

	# Perl Openssl seems like too much trouble...

	my $privtmpfile = "/tmp/key.$$.pem";
	my $pubtmpfile = "/tmp/pubkey.$$.pem";
	my $rc = 0xffff & system ("openssl genrsa -out $privtmpfile 2048 2> /dev/null");
	$rc = $rc >> 8;
	if ($rc) {
		print "FAILED\n";
		return undef;
	}
	open KEY, "$privtmpfile" or return undef;
	@{$self->{'privkey'}} = <KEY>;
	close KEY;
	my $rc = 0xffff & system ("openssl rsa -in $privtmpfile -pubout -out $pubtmpfile 2> /dev/null");
	$rc = $rc >> 8;
	if ($rc) {
		print "FAILED\n";
		return undef;
	}
	open KEY, "$pubtmpfile" or return undef;
	@{$self->{'pubkey'}} = <KEY>;
	close KEY;

	unlink $privtmpfile;
	unlink $pubtmpfile;
	
	# pubkey, privkey
	print "Done\n";
	return 1;
}

sub verify {
	my $self = shift;
	my $signature = shift;
	my $plaintext = shift;

	#print "Verifying $signature\n";
	#print "Against $plaintext\n";
	my $tmppkfile = "/tmp/signkey.$$";
	open K, "> $tmppkfile" or return undef;
	foreach (@{$self->{privkey}}) {
		print K $_;
	}
	close K;

	my $tmpsnfile = "/tmp/sn.$$";
	open K, "> $tmpsnfile" or return undef;
	print K $signature;
	close K;

	my $tmp64file = "/tmp/64.$$";
	open K, "> $tmp64file" or return undef;
	print K $plaintext;
	close K;

	my $tmpsigfile = "/tmp/sig.$$";
	#print "openssl base64 -d -in $tmpsnfile -out $tmpsigfile > /dev/null 2>&1\n\n";
	my $rc = 0xffff & system 
		("openssl base64 -d -in $tmpsnfile -out $tmpsigfile > /dev/null 2>&1");

	#print "openssl dgst -prverify $tmppkfile -signature $tmpsigfile $tmp64file > /dev/null 2>&1\n\n";
	my $rc = 0xffff & system 
		("openssl dgst -prverify $tmppkfile -signature $tmpsigfile $tmp64file > /dev/null 2>&1");
	$rc = $rc >> 8;
	if ($rc) {
		return undef;
	}

	unlink $tmppkfile;
	unlink $tmpsnfile;
	unlink $tmp64file;
	unlink $tmpsigfile;

	return 1;
}

sub sign {
	my ($text) = (@_);
	my $key = getCurrentKey();
	if (!defined ($key)) {
		print STDERR "No key to sign with!\n\n";
		return undef;
	}

	my $tmppkfile = "/tmp/signkey.$$";
	my $tmpsnfile = "/tmp/clear.$$";
	my $tmp64file = "/tmp/64.$$";
	open K, "> $tmppkfile" or return undef;
	foreach (@{$key->{privkey}}) {
		print K $_;
	}
	close K;
	
	open K, "> $tmpsnfile" or return undef;
	print K $text;
	close K;

	#print "openssl dgst -sign $tmppkfile $tmpsnfile | openssl base64 -e -out $tmp64file\n";
	my $rc = 0xffff & system ("openssl dgst -sign $tmppkfile $tmpsnfile | openssl base64 -e -out $tmp64file");
	$rc = $rc >> 8;
	if ($rc) {
		print "FAILED\n";
		return undef;
	}

	my $signed = "";
	open K, "$tmp64file" or return undef;
	while (<K>) {
		$signed .= $_;
	}
	close K;

	unlink $tmppkfile;
	unlink $tmpsnfile;
	unlink $tmp64file;

	return $signed;

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

1;

