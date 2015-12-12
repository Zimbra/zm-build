#!/bin/bash
# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014 Zimbra, Inc.
# 
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software Foundation,
# version 2 of the License.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with this program.
# If not, see <http://www.gnu.org/licenses/>.
# ***** END LICENSE BLOCK *****
# 


if [ -f /etc/redhat-release ]; then

	i=`uname -i`
	if [ "x$i" = "xx86_64" ]; then
		i="_64"
	else 
		i=""
	fi

	grep "Red Hat Enterprise Linux.*release 7" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "RHEL7${i}"
		exit 0
	fi
	grep "Red Hat Enterprise Linux.*release 6" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "RHEL6${i}"
		exit 0
	fi

	grep "CentOS Linux release 7" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "RHEL7${i}"
		exit 0
	fi
	grep "CentOS release 6" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "RHEL6${i}"
		exit 0
	fi

	grep "Scientific Linux release 7" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "RHEL7${i}"
		exit 0
	fi
	
	grep "Scientific Linux release 6" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "RHEL6${i}"
		exit 0
	fi
	
	grep "Red Hat Enterprise Linux.*release" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "RHELUNKNOWN${i}"
		exit 0
	fi
	grep "CentOS release" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "CentOSUNKNOWN${i}"
		exit 0
	fi
	grep "CentOS Linux release" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "CentOSUNKNOWN${i}"
		exit 0
	fi
	grep "Fedora Core release" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "FCUNKNOWN${i}"
		exit 0
	fi
fi

if [ -f /etc/SuSE-release ]; then

	grep "SUSE Linux Enterprise Server" /etc/SuSE-release >/dev/null 2>&1
	if [ $? = 0 ]; then
		echo "SLESUNKNOWN${i}"
		exit 0
	fi
	grep "openSUSE" /etc/SuSE-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "openSUSEUNKNOWN${i}"
		exit 0
	fi
fi

if [ -f /etc/debian_version ]; then
	if [ ! -f /etc/lsb-release ]; then
		i=`dpkg --print-architecture`
		if [ "x$i" = "xamd64" ]; then
			i="_64"
		else 
			i=""
		fi
	        echo "DEBIANUNKNOWN${i}"
	       	exit 0
	fi
fi

if [ -f /etc/lsb-release ]; then
	i=`dpkg --print-architecture`
	if [ "x$i" = "xamd64" ]; then
		i="_64"
	else 
		i=""
	fi
	grep "DISTRIB_ID=Ubuntu" /etc/lsb-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo -n "UBUNTU"
		grep "DISTRIB_RELEASE=12" /etc/lsb-release > /dev/null 2>&1
		if [ $? = 0 ]; then
			echo "12${i}"
			exit 0
		fi
		grep "DISTRIB_RELEASE=14" /etc/lsb-release > /dev/null 2>&1
		if [ $? = 0 ]; then
			echo "14${i}"
			exit 0
		else
			echo "UNKNOWN${i}"
			exit 0
		fi
	fi
	echo "DEBIANUNKNOWN${i}"
	exit 0
fi

a=`uname -a | awk '{print $1}'`
p=`uname -p`

if [ "x$a" = "xDarwin" ]; then
  v=`sw_vers | grep ^ProductVersion | awk '{print $NF}' | awk -F. '{print $1"."$2}'`
  if [ "x$v" = "x10.4" ]; then
	  if [ "x$p" = "xi386" ]; then
		  echo "MACOSXx86"
		  exit 0
	  fi

    if [ "x$p" = "xpowerpc" ]; then
	    echo "MACOSX"
	    exit 0
    fi
  else
    if [ "x$p" = "xi386" ]; then
      p=x86
    fi
    echo "MACOSX${p}_${v}"
    exit 0
  fi
fi

echo "UNKNOWN${i}"
exit 1
