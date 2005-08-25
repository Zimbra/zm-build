# 
# ***** BEGIN LICENSE BLOCK *****
# Version: ZPL 1.1
# 
# The contents of this file are subject to the Zimbra Public License
# Version 1.1 ("License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://www.zimbra.com/license
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations
# under the License.
# 
# The Original Code is: Zimbra Collaboration Suite.
# 
# The Initial Developer of the Original Code is Zimbra, Inc.
# Portions created by Zimbra are Copyright (C) 2005 Zimbra, Inc.
# All Rights Reserved.
# 
# Contributor(s):
# 
# ***** END LICENSE BLOCK *****
# 
#!/usr/bin/perl

package Zimbra::Mon::StatusMon;

use strict;

use Zimbra::Mon::Logger;
#use host;
use Zimbra::Mon::shortInfo;
use Zimbra::Mon::serviceInfo;
use Zimbra::Mon::Admin;

use DBI;

my $sleepInterval = 30;

my $statusDir = "$::Basedir/status";
my $serviceDir = "$::Basedir/service";
my $Signalled = 0;

require Exporter;

my @ISA = qw(Exporter);

sub new
{
	my ($class, $cluster) = @_;
	
	my $self = bless {},  $class;
	
	$self->{Cluster} = $cluster;

#	Zimbra::Mon::Logger::Log ("debug","Created StatusMon");

	return $self;
}

sub handle_usr2
{
#	Zimbra::Mon::Logger::Log ("debug","STATUS: USR2");
	$Signalled = 1;
	# We don't need to handle it, just enough to wake us from our sleep.
}

sub run
{
	my $self = shift;
	
	# setup before fork
	$self->setup();
	
	$self->{PID} = fork();
	
	if ($self->{PID}) {return};

	Zimbra::Mon::Logger::Log ("crit","Status monitor startup");

	$::PROGRAM_NAME = "Zimbra::Mon::StatusMon";
	
	$self->{ShortInfo} = new Zimbra::Mon::shortInfo(undef);
	$self->{ShortInfo}->clearStatusDir();
	$self->{ServiceInfo} = new Zimbra::Mon::serviceInfo($::Cluster->{LocalHost});

	sleep 10;

	local $SIG{CHLD} = 'IGNORE';

	$self->{sqlUser} = `zmlocalconfig zimbra_mysql_user`;
	chomp $self->{sqlUser};
	$self->{sqlUser} = (split(' ',$self->{sqlUser}))[2];
	$self->{sqlPass} = `zmlocalconfig -s zimbra_mysql_password`;
	chomp $self->{sqlPass};
	$self->{sqlPass} = (split(' ',$self->{sqlPass}))[2];

	while (1) {
		$SIG{USR2} = 'IGNORE';
		
		if (defined ($self->{Cluster}->{LocalHost}->isMonitor()) ) {
			$self->monitorPartner();
		}
		$self->getData();
		$SIG{USR2} = \&handle_usr2;
#		Zimbra::Mon::Logger::Log ("debug","Zimbra::Mon::StatusMon::run sleeping");
		if ($Signalled) {
			$Signalled = 0;
		} 

		sleep $sleepInterval;
#		Zimbra::Mon::Logger::Log ("debug","Zimbra::Mon::StatusMon::run waking up");
	}
}

sub getData
{
#	Zimbra::Mon::Logger::Log ("debug","Zimbra::Mon::StatusMon::getData");
	my $self = shift;
	
	$self->{ShortInfo}->getShortInfo();
	
	my $oldS = $self->{ServiceInfo};
	
	$self->{ServiceInfo} = new Zimbra::Mon::serviceInfo($::Cluster->{LocalHost});
	
	$self->{ServiceInfo}->getServiceInfo();
	
	# Compare the new and the old, and send events to the main process if anything's died.
	my $sname;
	
	foreach $sname (keys %{ $self->{ServiceInfo}{ServiceStatus} }) {
		if ($oldS->{ServiceStatus}{$sname}{status} ne "" &&
			$oldS->{ServiceStatus}{$sname}{status} ne $self->{ServiceInfo}{ServiceStatus}{$sname}{status} ) {
				my $prevStatus = $oldS->{ServiceStatus}{$sname}{status};
				my $curStatus = $self->{ServiceInfo}{ServiceStatus}{$sname}{status};
				my $cmd = $::syntaxes{zimbrasyntax}{statuschange};
				Zimbra::Mon::Logger::Log ("err", "Service status change: $sname $prevStatus $curStatus");
				$::Cluster->sendFifo("$cmd $sname $prevStatus $curStatus");
		}
	}

	my $data_source="dbi:mysql:database=zimbra;mysql_read_default_file=/opt/zimbra/conf/my.cnf;mysql_socket=/opt/zimbra/db/mysql.sock";
	my $username="zimbra";
	my $password = `zmlocalconfig -s zimbra_mysql_password`;
	chomp $password;
	$password = (split(' ',$password))[2];

	my $dbh;
	if (-f "/opt/zimbra/db/mysql.sock") {
		eval {
			$dbh = DBI->connect($data_source, $username, $password);
		};
	}

	foreach my $slice (@{$self->{ShortInfo}->{df}->{slices}}) {
		if ($slice->{cap} > $::DISK_CRIT_THRESHOLD) {
			Zimbra::Mon::Logger::Log ("crit",
			"Disk warning: $slice->{mt} ($slice->{dev}) at $slice->{cap} percent capacity");
		} elsif ($slice->{cap} > $::DISK_WARN_THRESHOLD) {
			Zimbra::Mon::Logger::Log ("err",
			"Disk warning: $slice->{mt} ($slice->{dev}) at $slice->{cap} percent capacity");
		}
		if (!$dbh) {
			Zimbra::Mon::Logger::Log ("debug", "No local db to store disk usage");
		} else {
			my $ts = ::timestamp_to_datetime($self->{ShortInfo}->{uts});
			my $name = "Slice:$slice->{mt}";
			my $val = "$slice->{cap}:$slice->{used}:$slice->{avail}:$slice->{dev}:$slice->{blk}";

			my $statement =
				"insert into server_stat(time, name, value) values (?,?,?)";
			my $sth = $dbh->prepare($statement);
			if (!$sth->execute($ts, $name, $val) ) {
				Zimbra::Mon::Logger::Log ("err", "DB: $statement - $DBI::errstr");
			}

		}

	}

}

sub setup
{
#	Zimbra::Mon::Logger::Log ("debug","Zimbra::Mon::StatusMon::setup");
	my $self = shift;
	
	if (!-d $statusDir)
	{
		mkdir ($statusDir);
		if (!-d $statusDir)
		{
			Zimbra::Mon::Logger::Log ("err", "Can't mkdir $statusDir: $!");
			# We can exit here, because zimbramon.pl hasn't forked yet.
			exit (1);
		}
	}
	if (!-d $serviceDir)
	{
		mkdir ($serviceDir);
		if (!-d $serviceDir)
		{
			Zimbra::Mon::Logger::Log ("err", "Can't mkdir $serviceDir: $!");
			# We can exit here, because zimbramon.pl hasn't forked yet.
			exit (1);
		}
	}
}

sub monitorPartner {
	my $self = shift;
	
	Zimbra::Mon::Logger::Log ("debug", "Monitoring cluster");
	
	# AppMon
	# PingMon NOT NEEDED
	
	
	if ($self->appMon()) {
	} else {
		Zimbra::Mon::Logger::Log ("debug", "Monitoring of cluster completed successfully");
	}
}

sub appMon {
	my $self = shift;
	
	Zimbra::Mon::Logger::Log ("debug", "Monitoring cluster APPLICATIONS");
	 
	# TODO monitor mail, calendar, AB.
	
	foreach my $host ($self->{Cluster}->getClusterHosts()) {
		$self->monitorOneHost($host);
	}
}

sub monitorOneHost {
	my $self = shift;
	my $host = shift;

	Zimbra::Mon::Logger::Log ("debug", "Monitoring host $host->{name}");

	my $oldS = $self->{RemoteInfo}{$host->{name}}{ServiceInfo};

	$self->{RemoteInfo}{$host->{name}}{ServiceInfo} = new Zimbra::Mon::serviceInfo($host);
	
	$self->{RemoteInfo}{$host->{name}}{ServiceInfo}->getServiceInfo();
	
	my $rsi = $self->{RemoteInfo}{$host->{name}}{ServiceInfo};
	# Compare the new and the old, and send events to the main process if anything's died.
	my $sname;
	
	# TODO get service list for each host.
	foreach $sname (keys %{ $rsi->{ServiceStatus} }) {
		if (defined $rsi->{ServiceStatus}{$sname}{status}) {
		Zimbra::Mon::Logger::Log ("info", 
			"Monitored $sname on $host->{name}: $rsi->{ServiceStatus}{$sname}{status}");
		}
		my $prevStatus = $oldS->{ServiceStatus}{$sname}{status};
		my $curStatus = $rsi->{ServiceStatus}{$sname}{status};
		if ( $prevStatus ne $curStatus ) {
			Zimbra::Mon::Logger::Log ("err", 
				"Remote Service status change: $host->{name} $sname $prevStatus $curStatus");
		}

		# update the db even if no change.

		my $username=$self->{sqlUser};
		my $password=$self->{sqlPass};

		my $statement;

		$statement = "delete from service_status where server = '".$host->{name}.
			"' and service = '".$sname."';";

		`/opt/zimbra/bin/mysql zimbra -e "$statement"`;

		my $status = 1;
		if ($curStatus == $::StatusStopped) {$status = 0;}
		my $t = `date "+%Y/%m/%d %H:%M:%S"`;
		chomp $t;
		#my $t = scalar(localtime());
		$statement = "insert into service_status (server,service,time,status) ".
			"values ('".$host->{name}."','".$sname."','".$t."',$status)";

		`/opt/zimbra/bin/mysql zimbra -e "$statement"`;

		next;

	}

}

1

