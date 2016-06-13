#!/bin/bash
# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2010, 2012, 2013, 2014, 2015, 2016 Synacor, Inc.
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
# 
ID=$(id -un)
if [ x"$ID" != "xroot" ]; then
  echo "$0 must be run as root."
  exit 1
fi

if [ $# -gt 1 ]
then
  echo "usage: $0 [--force]"
  exit 1
fi
if [ "x$1" != "x--force" -a "x$1" != "x" ]
then
  echo "usage: $0 [--force]"
  exit 1
fi

/usr/bin/perl bin/zmpatch.pl --config conf/zmpatch.xml --verbose $1
