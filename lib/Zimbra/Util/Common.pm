#!/usr/bin/perl
# 
# ***** BEGIN LICENSE BLOCK *****
# Version: MPL 1.1
# 
# The contents of this file are subject to the Mozilla Public License
# Version 1.1 ("License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://www.zimbra.com/license
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations
# under the License.
# 
# The Original Code is: Zimbra Collaboration Suite Server.
# 
# The Initial Developer of the Original Code is Zimbra, Inc.
# Portions created by Zimbra are Copyright (C) 2005, 2006 Zimbra, Inc.
# All Rights Reserved.
# 
# Contributor(s):
#
# 
# ***** END LICENSE BLOCK *****

package Zimbra::Util::Common; 
use strict;


# Zimbra Specfic library locations
use lib "/opt/zimbra/zimbramon/lib";
use lib "/opt/zimbra/zimbramon/lib/Zimbra/SOAP";
use lib "/opt/zimbra/zimbramon/lib/Zimbra/Mon";
use lib "/opt/zimbra/zimbramon/lib/Zimbra/DB";
foreach my $arch qw(i386 x86_64 i486 i586 i686 darwin) {
  foreach my $type qw(linux-thread-multi linux-gnu-thread-multi linux thread-multi thread-multi-2level) {
    my $dir = "/opt/zimbra/zimbramon/lib/${arch}-${type}";
    unshift(@INC, "$dir") 
      if (-d "$dir");
  }
}

1
