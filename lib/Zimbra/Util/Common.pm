#!/usr/bin/perl
# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2006, 2007, 2009, 2010, 2012, 2013, 2014, 2015, 2016 Synacor, Inc.
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software Foundation,
# version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with this program.
# If not, see <https://www.gnu.org/licenses/>.
# ***** END LICENSE BLOCK *****

package Zimbra::Util::Common; 
use strict;


# Zimbra Specfic library locations
use lib "/opt/zimbra/common/lib/perl5";
use lib "/opt/zimbra/common/lib/perl5/Zimbra/SOAP";
use lib "/opt/zimbra/common/lib/perl5/Zimbra/Mon";
use lib "/opt/zimbra/common/lib/perl5/Zimbra/DB";
foreach my $arch (qw(i386 x86_64 i486 i586 i686 darwin)) {
  foreach my $type (qw(linux-thread-multi linux-gnu-thread-multi linux thread-multi thread-multi-2level)) {
    my $dir = "/opt/zimbra/common/lib/perl5/${arch}-${type}";
    unshift(@INC, "$dir") 
      if (-d "$dir");
  }
}

1
