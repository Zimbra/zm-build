#!/bin/bash
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
# Portions created by Zimbra are Copyright (C) 2005 Zimbra, Inc.
# All Rights Reserved.
# 
# Contributor(s):
# 
# ***** END LICENSE BLOCK *****
# 


if [ -f /etc/redhat-release ]; then
	grep "Red Hat Enterprise Linux" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "RHEL4"
		exit 0
	fi

	grep "Fedora Core release 4" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "FC4"
		exit 0
	fi

	grep "Fedora Core release 3" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "FC3"
		exit 0
	fi

	grep "CentOS release 4" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "CentOS4"
		exit 0
	fi
fi

if [ -f /etc/SuSE-release ]; then
	grep "SUSE LINUX Enterprise Server 9" /etc/SuSE-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "SuSEES9"
		exit 0
	fi
	grep "SUSE LINUX 10.0" /etc/SuSE-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "SuSE10"
		exit 0
	fi
fi

if [ -f /etc/debian_version ]; then
	grep "3.1" /etc/debian_version > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "DEBIAN3.1"
		exit 0
	fi
fi

if [ -f /etc/mandriva-release ]; then
	grep "2006" /etc/mandriva-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "MANDRIVA2006"
		exit 0
	fi
fi

if [ -f /etc/release ]; then
	egrep 'Solaris 10.*X86' /etc/release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "SOLARISX86"
		exit 0
	fi
fi

p=`uname -p`
if [ "x$p" = "xpowerpc" ]; then
	echo "MACOSX"
	exit 0
fi

echo "UNKNOWN"
exit 1
