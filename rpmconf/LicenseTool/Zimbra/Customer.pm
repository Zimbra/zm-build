package Zimbra::Customer;

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

sub toText {
	my $self = shift;
	my $verbose = shift;
	my $txt = "ID: $self->{id}\n";
	$txt .= "Name: $self->{name}\n";
	return $txt;
}

sub display {
	my $self = shift;
	my $verbose = shift;
	print $self->toText($verbose);
}

1;
