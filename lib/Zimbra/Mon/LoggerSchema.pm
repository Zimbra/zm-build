# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2009, 2010, 2012 VMware, Inc.
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
package Zimbra::Mon::LoggerSchema;
use strict;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(@LOGGER_SCHEMA_UPGRADE);


our @LOGGER_SCHEMA_UPGRADE = (
    # version 0, schema version
    [ q{
    	CREATE TABLE config (
    	    version INTEGER NOT NULL UNIQUE
    	)
      },
      q{
        INSERT INTO config VALUES (0);
      }
    ],
    # version 1, column mapping
    [ q{
    	CREATE TABLE rrd_column_type (
    	    csv_file     varchar(255) not null,
    	    col_name     varchar(255) not null,
    	    -- G-AUGE, C-OUNTER, A-BSOLUTE or D-ERIVED
    	    col_type     char(1) not null,
    	    col_interval integer,
    	    CONSTRAINT unqcoltype UNIQUE (csv_file, col_name)
    	)
      },
      # sqlite's version of multiple insert
      #
      # by default, all columns will have an interval of 30s
      # and type of GAUGE (i.e. columns not in this table)
      q{
      	INSERT INTO rrd_column_type
      	          select 'mailboxd.csv', 'gc_minor_ms',    'C', 30
      	union all select 'mailboxd.csv', 'gc_minor_count', 'C', 30
      	union all select 'mailboxd.csv', 'gc_major_ms',    'C', 30
      	union all select 'mailboxd.csv', 'gc_major_count', 'C', 30
      	union all select 'mysql.csv',    'Slow_queries',   'C', 30
      	union all select 'mysql.csv',    'Opened_tables',  'C', 30
      	union all select 'df.csv',       'disk_pct_used',  'G', 600
      	union all select 'df.csv',       'disk_use',       'G', 600
      	union all select 'df.csv',       'disk_space',     'G', 600
      	union all select 'zmmtastats',   'clam_events',    'A', 300
      	union all select 'zmmtastats',   'sendmail_events','A', 300
      	union all select 'zmmtastats',   'filter_count',   'A', 300
      	union all select 'zmmtastats',   'filter_virus',   'A', 300
      	union all select 'zmmtastats',   'filter_spam',    'A', 300
      	union all select 'zmmtastats',   'filter_misc',    'A', 300
      	union all select 'zmmtastats',   'mta_count',      'A', 300
      	union all select 'zmmtastats',   'mta_volume',     'A', 300
      },
      q{
      	UPDATE config SET version = 1
      }
    ],
    # version 2, column globs
    [ q{
    	 UPDATE rrd_column_type SET col_interval = 60 WHERE csv_file = 'mailboxd.csv'
      },
      q{
      	INSERT INTO rrd_column_type
      	          select 'mailboxd.csv', '*',    'G', 60
      	union all select 'zmstatuslog',  '*',    'G', 120
      },
      q{
      	UPDATE config SET version = 2
      }
    ],
    # version 3, counter types
    [ q{
    	ALTER table rrd_column_type ADD COLUMN col_unit varchar(64)
      },
      q{
      	UPDATE rrd_column_type SET col_unit = '% time', col_interval = 60
      	 WHERE col_name IN ('gc_minor_ms', 'gc_major_ms')
      },
      q{
      	UPDATE rrd_column_type SET col_unit = 'times/second', col_interval = 60
      	 WHERE col_name IN ('gc_minor_count', 'gc_major_count')
      },
      q{
      	UPDATE rrd_column_type SET col_unit = 'queries/s'
      	 WHERE col_name = 'Slow_queries'
      },
      q{
      	UPDATE rrd_column_type SET col_unit = 'opens/s'
      	 WHERE col_name = 'Opened_tables'
      },
      q{
      	UPDATE rrd_column_type SET col_unit = 'bytes'
      	 WHERE col_name IN ('disk_use', 'disk_space')
      },
      q{
      	UPDATE rrd_column_type SET col_unit = 'events/s'
      	 WHERE col_name IN ('clam_events', 'sendmail_events')
      },
      q{
      	UPDATE rrd_column_type SET col_unit = 'filter/s'
      	 WHERE col_name IN ('filter_count', 'filter_misc', 'filter_virus', 'filter_spam')
      },
      q{
      	UPDATE rrd_column_type SET col_unit = 'msgs/s'
      	 WHERE col_name = 'mta_count'
      },
      q{
      	UPDATE rrd_column_type SET col_unit = 'bytes/s'
      	 WHERE col_name = 'mta_volume'
      },
      q{
      	INSERT INTO rrd_column_type select 'mysql.csv',  '*', 'G', 30, null
      },
      q{
      	INSERT INTO rrd_column_type
      	          select 'mtaqueue.csv', 'requests',          'G', 30, 'msgs'
      	union all select 'fd.csv',       'fd_count',          'G', 30, 'fd'
      	union all select 'cpu.csv',      '*',                 'G', 30, '% cpu'
      	union all select 'vmstat.csv',   'pageins',           'G', 30, 'KB/s'
      	union all select 'vmstat.csv',   'si',                'G', 30, 'KB/s'
      	union all select 'vmstat.csv',   'pageout',           'G', 30, 'KB/s'
      	union all select 'vmstat.csv',   'so',                'G', 30, 'KB/s'
      	union all select 'vmstat.csv',   'free',              'G', 30, 'KB'
      	union all select 'vmstat.csv',   'active',            'G', 30, 'KB'
      	union all select 'vmstat.csv',   'inac',              'G', 30, 'KB'
      	union all select 'vmstat.csv',   'Active',            'G', 30, 'KB'
      	union all select 'vmstat.csv',   'Inactive',          'G', 30, 'KB'
      	union all select 'vmstat.csv',   'cache',             'G', 30, 'KB'
      	union all select 'vmstat.csv',   'cs',                'G', 30, 'cs/s'
      	union all select 'vmstat.csv',   'r',                 'G', 30, 'run-q'
      	union all select 'vmstat.csv',   'b',                 'G', 30, 'io-q'
      	union all select 'vmstat.csv',   'loadavg',           'G', 30, null
      	union all select 'soap.csv',     'exec_count',        'A', 30, 'calls/s'
      	union all select 'soap.csv',     'exec_ms_avg',       'G', 30, null
      	union all select 'mailboxd.csv', 'mbox_add_msg_count','A', 30, 'add/s'
      	union all select 'mailboxd.csv', 'soap_count',        'A', 30, 'op/s'
      	union all select 'mailboxd.csv', 'imap_count',        'A', 30, 'op/s'
      	union all select 'mailboxd.csv', 'pop_count',         'A', 30, 'op/s'
      	union all select 'mailboxd.csv', 'mbox_msg_cache',    'G', 30, 'cache hit %'
      	union all select 'mailboxd.csv', 'mbox_item_cache',   'G', 30, 'cache hit %'
      	union all select 'convertd.csv', 'cputime',           'G', 30, 'seconds/100'
      	union all select 'convertd.csv', 'stime',             'G', 30, 'seconds/100'
      	union all select 'convertd.csv', 'utime',             'G', 30, 'seconds/100'
      	union all select 'convertd.csv', 'rss',               'G', 30, 'KB'
      	union all select 'allprocs.csv', 'cputime',           'G', 30, 'seconds'
      	union all select 'nginx.csv',    'cputime',           'G', 30, 'seconds/100'
      	union all select 'nginx.csv',    'stime',             'G', 30, 'seconds/100'
      	union all select 'nginx.csv',    'utime',             'G', 30, 'seconds/100'
      	union all select 'nginx.csv',    'rss',               'G', 30, 'KB'
      },
      q{
      	UPDATE config SET version = 3
      },
    ],
    [
      q{
      	DELETE FROM rrds WHERE csv_file = 'allprocs.csv';
      },
      q{
      	UPDATE config SET version = 4
      },
    ],
);

1;
