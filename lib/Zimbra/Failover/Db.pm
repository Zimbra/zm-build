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
package Zimbra::Failover::Db;

use strict;
use DBI;
use Zimbra::Failover::Bootstrap;

my $ZIMBRA_HOME = $ENV{ZIMBRA_HOME} || $ENV{HOME} || '/opt/zimbra';

sub connect {
    my $class = shift;
    my $data_source = "dbi:mysql:database=zimbra;mysql_read_default_file=$ZIMBRA_HOME/conf/my.cnf";
    my $username = Zimbra::Failover::Bootstrap::getDbUsername();
    my $password = Zimbra::Failover::Bootstrap::getDbPassword();
    my $dbh = DBI->connect($data_source, $username, $password);
    if (!$dbh) {
        print STDERR "Unable to connect to DB $data_source: $DBI::errstr";
        return undef;
    }
    my $self = {CONN => $dbh};
    bless($self, $class);
    return $self;
}

sub disconnect($) {
    my $self = shift;
    if (defined($self->{CONN})) {
        $self->{CONN}->disconnect();
        $self->{CONN} = undef;
    }
}

sub setConfigKey($$$) {
    my ($self, $name, $value) = @_;
    my $stmt = "INSERT INTO config (name, value, modified) VALUES (?, ?, NOW()) ON DUPLICATE KEY UPDATE value = ?, modified = NOW()";
    my $sth = $self->{CONN}->prepare($stmt);
    $sth->bind_param(1, $name);
    $sth->bind_param(2, $value);
    $sth->bind_param(3, $value);
    my $rv = $sth->execute();
    if (!$rv) {
        print STDERR "Unable to update config key '$name' to '$value': $DBI::errstr\n";
        return 0;
    }
    return 1;
}

sub deleteConfigKey($$) {
    my ($self, $name) = @_;
    my $stmt = "DELETE FROM config WHERE name = ?";
    my $sth = $self->{CONN}->prepare($stmt);
    $sth->bind_param(1, $name);
    my $rv = $sth->execute();
    if (!$rv) {
        print STDERR "Unable to delete config key '$name': $DBI::errstr\n";
        return 0;
    }
    return 1;
}

sub getConfigKey($$) {
    my ($self, $name) = @_;
    my $stmt = "SELECT value FROM config WHERE name = ?";
    my $sth = $self->{CONN}->prepare($stmt);
    $sth->bind_param(1, $name);
    my $rv = $sth->execute();
    if (!$rv) {
        print STDERR "Unable to get config key '$name': $DBI::errstr\n";
        return 0;
    }
    my $value;
    my @data;
    if (@data = $sth->fetchrow_array()) {
        $value = $data[0];
    }
    $sth->finish();
    return $value;
}

1;
