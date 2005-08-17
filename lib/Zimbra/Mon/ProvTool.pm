package Zimbra::Mon::ProvTool;

use strict;

use Zimbra::Mon::Logger;
use host;

my $provTool = "$::Basedir/../bin/zmprov";

our $AUTOLOAD;

sub new {
	my ( $class ) = @_;

	my $self = bless {}, $class;

	Zimbra::Mon::Logger::Log( "debug", "Created ProvTool" );

	return $self;
}

sub AUTOLOAD {
	my $self = shift;
	my $name = $AUTOLOAD;
	$name =~ s/.*:://;
	return $self->doProv($name, @_);
}

sub doProv {
	my $self = shift;
	my $cmd = shift;

	local $SIG{CHLD} = 'IGNORE';

	my $cmdline = "$provTool $cmd @_";
	if (!open(PT, "$cmdline |")) {
		Zimbra::Mon::Logger::Log( "crit", "Unable to invoke \"$cmdline\": $!" );
		return undef;
	}

	my @lines = <PT>;
	close PT;
	return \@lines;
}

1
