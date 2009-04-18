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
    	)},
      q{
        INSERT INTO config VALUES (0);
      }
    ],
    # version 1, column mapping
    [
    ],
);

1;