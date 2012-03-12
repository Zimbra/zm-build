#!/bin/bash
# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2010, 2011 VMware, Inc.
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

perl bin/zmpatch.pl --config conf/zmpatch.xml --verbose $1
