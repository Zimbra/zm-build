#!/bin/bash

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

p=`uname -p`
if [ "x$p" = "xpowerpc" ]; then
	echo "MACOSX"
	exit 0
fi

echo "UNKNOWN"
exit 1
