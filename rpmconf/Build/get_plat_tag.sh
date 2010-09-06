#!/bin/bash
# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2005, 2006, 2007, 2008, 2009, 2010 Zimbra, Inc.
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


if [ -f /etc/redhat-release ]; then

	i=`uname -i`
	if [ "x$i" = "xx86_64" ]; then
		i="_64"
	else 
		i=""
	fi

	grep "Red Hat Enterprise Linux.*release 6" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "RHEL6${i}"
		exit 0
	fi
	grep "Red Hat Enterprise Linux.*release 5" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "RHEL5${i}"
		exit 0
	fi
	grep "Red Hat Enterprise Linux.*release 4" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "RHEL4${i}"
		exit 0
	fi

	grep "Fedora release 11" /etc/redhat-release >/dev/null 2>&1
	if [ $? = 0 ]; then
		echo "F11${i}"
		exit 0
	fi
	grep "Fedora release 10" /etc/redhat-release >/dev/null 2>&1
	if [ $? = 0 ]; then
		echo "F10${i}"
		exit 0
	fi
	grep "Fedora release 7" /etc/redhat-release >/dev/null 2>&1
	if [ $? = 0 ]; then
		echo "F7${i}"
		exit 0
	fi
	grep "Fedora Core release 6" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "FC6${i}"
		exit 0
	fi
	grep "Fedora Core release 5" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "FC5${i}"
		exit 0
	fi
	grep "Fedora Core release 4" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "FC4${i}"
		exit 0
	fi
	grep "Fedora Core release 3" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "FC3${i}"
		exit 0
	fi

	grep "CentOS release 6" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "CentOS6${i}"
		exit 0
	fi
	grep "CentOS release 5" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "CentOS5${i}"
		exit 0
	fi
	grep "CentOS release 4" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "CentOS4${i}"
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
	grep "Fedora Core release" /etc/redhat-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "FCUNKNOWN${i}"
		exit 0
	fi
fi

if [ -f /etc/SuSE-release ]; then

	i=`uname -i`
	if [ "x$i" = "xx86_64" ]; then
		i="_64"
	else 
		i=""
	fi

	grep "SUSE Linux Enterprise Server 11" /etc/SuSE-release >/dev/null 2>&1
	if [ $? = 0 ]; then
		echo "SLES11${i}"
		exit 0
	fi
	grep "SUSE Linux Enterprise Server 10 (x86_64)" /etc/SuSE-release >/dev/null 2>&1
	if [ $? = 0 ]; then
		echo "SLES10_64"
		exit 0
	fi
	grep "SUSE Linux Enterprise Server 10" /etc/SuSE-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "SuSEES10"
		exit 0
	fi
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
	grep "openSUSE 10.1" /etc/SuSE-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "openSUSE_10.1"
		exit 0
	fi
	grep "openSUSE 10.2" /etc/SuSE-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "openSUSE_10.2"
		exit 0
	fi
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
		grep "3.1" /etc/debian_version > /dev/null 2>&1
		if [ $? = 0 ]; then
			echo "DEBIAN3.1${i}"
			exit 0
		fi
		grep "4.0" /etc/debian_version > /dev/null 2>&1
		if [ $? = 0 ]; then
			echo "DEBIAN4.0${i}"
			exit 0
		fi
		grep "5.0" /etc/debian_version > /dev/null 2>&1
		if [ $? = 0 ]; then
			echo "DEBIAN5${i}"
			exit 0
		else
	        	echo "DEBIANUNKNOWN${i}"
	        	exit 0
		fi
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
		grep "DISTRIB_RELEASE=6" /etc/lsb-release > /dev/null 2>&1
		if [ $? = 0 ]; then
			echo "6${i}"
			exit 0
		fi
		grep "DISTRIB_RELEASE=7" /etc/lsb-release > /dev/null 2>&1
		if [ $? = 0 ]; then
			echo "7${i}"
			exit 0
		fi 
		grep "DISTRIB_RELEASE=8" /etc/lsb-release > /dev/null 2>&1
		if [ $? = 0 ]; then
			echo "8${i}"
			exit 0
		fi
		grep "DISTRIB_RELEASE=10" /etc/lsb-release > /dev/null 2>&1
		if [ $? = 0 ]; then
			echo "10${i}"
			exit 0
		else
			echo "UNKNOWN${i}"
			exit 0
		fi
	fi
	grep "DISTRIB_ID=Debian" /etc/lsb-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		grep "3.1" /etc/debian_version > /dev/null 2>&1
		if [ $? = 0 ]; then
			echo "DEBIAN3.1${i}"
			exit 0
		fi
		grep "4.0" /etc/debian_version > /dev/null 2>&1
		if [ $? = 0 ]; then
			echo "DEBIAN4.0${i}"
			exit 0
		fi
		grep "5.0" /etc/debian_version > /dev/null 2>&1
		if [ $? = 0 ]; then
			echo "DEBIAN5${i}"
			exit 0
		else
	        	echo "DEBIANUNKNOWN${i}"
	        	exit 0
		fi
	fi
	echo "DEBIANUNKNOWN${i}"
	exit 0
fi

if [ -f /etc/mandriva-release ]; then
	grep "2007" /etc/mandriva-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "MANDRIVA2007"
		exit 0
	fi
	grep "2006" /etc/mandriva-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "MANDRIVA2006"
		exit 0
	fi
	echo "MANDRIVAUNKNOWN"
	exit 0
fi

if [ -f /etc/release ]; then
	egrep 'Solaris 10.*X86' /etc/release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "SOLARISX86"
		exit 0
	fi
	echo "SOLARISUNKNOWN"
fi

if [ -f /etc/distro-release ]; then
        echo "RPL1"
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
