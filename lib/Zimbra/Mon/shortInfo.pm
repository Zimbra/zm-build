#!/usr/bin/perl

package Zimbra::shortInfo;

use strict;

use Zimbra::Logger;
use Zimbra::diskUsage;
use FileHandle;

my $NUM_ITEMS = 30;

require Exporter;

my @ISA = qw(Exporter);

sub new {
	my ( $class, $host ) = @_;
	return $class if ref($class);

	my $self = bless {}, $class;

	$self->{host} = $host;

	$self->{uts} = 0;

	$self->{statusDir} = "$::Basedir/status";

	$self->{lastFileName} = "";

	$self->{load} = ();

	return $self;
}

sub readShortInfo {

	# readShortInfo reads info written by Zimbra::StatusMon
	my $self = shift;

	# Race condition fun - make sure the file we're reading doesn't get wiped.
	my $done = 0;
	while ( !$done ) {
		my $fn = $self->getLastFileName();

		my @lines;

		if ( rename $fn, "$fn.reading" ) {
			$done = 1;

			my $fh = new FileHandle;

			$fh->open("$fn.reading");

			@lines = <$fh>;

			$fh->close();

			rename "$fn.reading", $fn;
		}
		else {
			return;
		}

		$self->{load} = ();
		$self->{df}   = new Zimbra::diskUsage;

		foreach (@lines) {
			my ( $key, $val ) = split ':', $_, 2;
			if ( $key eq 'df' ) {
				my @fields = split ' ', $val;
				push( @{ $self->{df}->{slices} }, new Zimbra::diskSlice(@fields) );
			}
			elsif ( $key eq 'load' ) {
				push( @{ $self->{load} }, $val );
			}
			else {
				$self->{$key} = $val;
			}
		}
	}
}

sub getLastFileName {
	my $self = shift;

	my $fileName;

	opendir DIR, $self->{statusDir};

	my @fns = grep !/tmp/, sort map { "$self->{statusDir}/$_" } readdir DIR;

	closedir DIR;

	#	Zimbra::Logger::Log ("debug","getLastFileName ".$fns[$#fns]);

	return $fns[$#fns];
}

sub writeShortInfo {
	my $self = shift;

	my $t = time();

	my $statusFileName = $self->getStatusFilename($t) . "tmp";
	Zimbra::Logger::Log( "debug", "writeShortInfo " . $statusFileName );

	my $fh = new FileHandle;

	$fh->open(">$statusFileName");

	my $s = $self->prettyPrint();

	print $fh $s;

	$fh->close();

	rename( $statusFileName, $self->{statusFileName} );

	$self->cleanupStatusDir();
}

sub getStatusFilename {
	my $self = shift;
	my $t    = shift;
	my $fn   = $self->{statusDir};
	$fn .= "/status." . $t . "." . $$;

	#	Zimbra::Logger::Log ("debug","getStatusFilename ".$fn);

	$self->{statusFileName} = $fn;

	return $fn;
}

sub cleanupStatusDir {
	my $self = shift;

	#	Zimbra::Logger::Log ("debug","cleanupStatusDir ".$self->{lastFileName});

	if ( $self->{lastFileName} ne "" ) {
		unlink( $self->{lastFileName} );
	}
	$self->{lastFileName} = $self->{statusFileName};
}

sub clearStatusDir {
	my $self = shift;

	#	Zimbra::Logger::Log ("debug","cleanupStatusDir ".$self->{lastFileName});
	opendir DIR, $self->{statusDir};

	my @fns = grep !/tmp/, sort map { "$self->{statusDir}/$_" } readdir DIR;

	closedir DIR;

	#	Zimbra::Logger::Log ("debug","getLastFileName ".$fns[$#fns]);

	foreach (@fns) {
		unlink $_;
	}
}

sub prettyPrint {

	# getShortInfo gets info to be written by Zimbra::StatusMon
	my $self = shift;

	my $s;

	foreach ( keys %{$self} ) {
		if (   /^df$/
			|| /^status/
			|| /^lastFile/
			|| /^host$/
			|| /^load/ )
		{
			next;
		}
		$s .= $_ . ":" . $self->{$_} . "\n";
	}

	foreach ( @{ $self->{load} } ) {
		$s .= "load:" . $_ . "\n";
	}

	foreach ( @{ $self->{df}->{slices} } ) {
		$s .= "df:" . $_->prettyPrint() . "\n";
	}

	return $s;
}

sub getShortInfo {

	#	Zimbra::Logger::Log ("debug","getShortInfo");
	# getShortInfo gets info to be written by Zimbra::StatusMon
	my $self = shift;

	$self->{uts} = time();

	$self->{ts} = `date +%Y%m%d%H%M%S`;

	chomp $self->{ts};

	$self->{df} = new Zimbra::diskUsage;

	$self->{df}->get();

	$self->getLoad();

	$self->getVersion();

	$self->getMem();

	$self->writeShortInfo();

}

sub getLoad() {
	my $self = shift;

	open U, '/proc/loadavg' or return;

	my $l = <U>;
	close U;

	#load averages: 4.08 4.25 4.19

	# Get previous load

	my ( $a1, $a2, $a3 ) = ( $l =~ m/^([\d.]+)\s+([\d.]+)\s+([\d.]+).*/ );

	#	Zimbra::Logger::Log ("debug","LOAD $a1 $a2 $a3");
	push @{ $self->{load} }, "$self->{ts} $a1 $a2 $a3";

	while ( $#{ $self->{load} } >= $NUM_ITEMS ) {
		shift @{ $self->{load} };
	}
}

sub getVersion() {
	my $self = shift;
	$self->{version} = $::VERSION;
	open V, '/proc/version' or return;
	my $v = <V>;
	close V;

	$v =~ s/^Linux version (\S+) .*/\1/;
	$self->{osversion} = $v;
}

sub getMem() {
	my $self = shift;
	open M, '/proc/meminfo' or return;
	my @M = <M>;
	close M;
	
	foreach (@M) {
		if (/^MemTotal/) {
			$self->{memtotal} = (split)[1];
		} elsif (/^MemFree/) {
			$self->{memfree} = (split)[1];
		} elsif (/^SwapTotal/) {
			$self->{swaptotal} = (split)[1];
		} elsif (/^SwapFree/) {
			$self->{swapfree} = (split)[1];
		}
	}
}

1

