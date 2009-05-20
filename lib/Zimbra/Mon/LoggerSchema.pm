# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2009 Zimbra, Inc.
# 
# The contents of this file are subject to the Yahoo! Public License
# Version 1.0 ("License"); you may not use this file except in
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
);

1;