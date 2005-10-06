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

fi

if [ -f /etc/SuSE-release ]; then
	grep "SUSE LINUX Enterprise Server 9" /etc/SuSE-release > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "SuSEES9"
		exit 0
	fi
fi

echo "UNKNOWN"
exit 1
