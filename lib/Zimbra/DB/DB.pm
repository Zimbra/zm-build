# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2005, 2007, 2009, 2010, 2011 Zimbra Software, LLC.
# 
# The contents of this file are subject to the Zimbra Public License
# Version 1.3 ("License"); you may not use this file except in
# compliance with the License.  You may obtain a copy of the License at
# http://www.zimbra.com/license.
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied.
# ***** END LICENSE BLOCK *****
# 
package Zimbra::DB::DB;

use strict;

#############

my $MYSQL = "mysql";
my $DB_USER = "zimbra";
my $DB_PASSWORD = "zimbra";
my $database = "zimbra";
my $ZIMBRA_HOME = $ENV{ZIMBRA_HOME} || '/opt/zimbra';
my $ZMLOCALCONFIG = "$ZIMBRA_HOME/bin/zmlocalconfig";

if ($^O !~ /MSWin/i) {
    $DB_PASSWORD = `$ZMLOCALCONFIG -s -m nokey zimbra_mysql_password`;
    chomp $DB_PASSWORD;
    $DB_USER = `$ZMLOCALCONFIG -m nokey zimbra_mysql_user`;
    chomp $DB_USER;
    $MYSQL = "/opt/zimbra/bin/mysql";
}

sub getDatabase() {
    return $database;
}

sub setDatabase($) {
    $database = shift();
}

sub getMailboxIds() {
    return runSql("SELECT id FROM mailbox ORDER BY id");
}

sub runSql(@) {
    my ($script, $logSql) = @_;

    if (! defined($logSql)) {
	$logSql = 1;
    }

    # Write the last script to a text file for debugging
    # open(LASTSCRIPT, ">lastScript.sql") || die "Could not open lastScript.sql";
    # print(LASTSCRIPT $script);
    # close(LASTSCRIPT);

    if ($logSql) {
	Zimbra::DB::DB::log($script);
    }

    # Run the mysql command and redirect output to a temp file
    my $tempFile = "/tmp/mysql.out.$$";
    my $command = "$MYSQL --user=$DB_USER --password=$DB_PASSWORD " .
        "--database=$database --batch --skip-column-names";
    open(MYSQL, "| $command > $tempFile") || die "Unable to run $command";
    print(MYSQL $script);
    close(MYSQL);

    if ($? != 0) {
        die "Error while running '$command'.";
    }

    # Process output
    open(OUTPUT, $tempFile) || die "Could not open $tempFile";
    my @output;
    while (<OUTPUT>) {
        s/\s+$//;
        push(@output, $_);
    }

    unlink($tempFile);
    return @output;
}

sub log
{
    print scalar(localtime()), ": ", @_, "\n";
}

1;
