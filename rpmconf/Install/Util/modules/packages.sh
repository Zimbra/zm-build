#!/bin/bash
# 
# ***** BEGIN LICENSE BLOCK *****
# Version: ZPL 1.1
# 
# The contents of this file are subject to the Zimbra Public License
# Version 1.1 ("License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://www.zimbra.com/license
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations
# under the License.
# 
# The Original Code is: Zimbra Collaboration Suite.
# 
# The Initial Developer of the Original Code is Zimbra, Inc.
# Portions created by Zimbra are Copyright (C) 2005 Zimbra, Inc.
# All Rights Reserved.
# 
# Contributor(s):
# 
# ***** END LICENSE BLOCK *****
# 

installPackage() {
	PKG=$1
	echo -n "    $PKG..."
	# file=`ls $PACKAGE_DIR/$i*.rpm`
	findLatestPackage $PKG
	f=`basename $file`
	echo -n "...$f..."
	rpm -iv $file >> $LOGFILE 2>&1
	if [ $? = 0 ]; then
		echo "done"
	else
		echo -n "FAILED"
		echo ""
		echo "###ERROR###"
		echo ""
		echo "$f installation failed"
		echo ""
		echo "Installation cancelled"
		echo ""
		exit 1
	fi
}

findLatestPackage() {
	package=$1

	latest=""
	himajor=0
	himinor=0
	histamp=0

	files=`ls $PACKAGE_DIR/$package*.rpm 2> /dev/null`
	for q in $files; do
		# zimbra-core-2.0_RHEL4-20050622123009_HEAD.i386.rpm

		f=`basename $q`
		id=`echo $f | awk -F- '{print $3}'`
		version=`echo $id | awk -F_ '{print $1}'`
		major=`echo $version | awk -F. '{print $1}'`
		minor=`echo $version | awk -F. '{print $2}'`
		micro=`echo $version | awk -F. '{print $3}'`
		stamp=`echo $f | awk -F_ '{print $2}' | awk -F. '{print $1}'`

		if [ $major -gt $himajor ]; then
			himajor=$major
			himinor=$minor
			histamp=$stamp
			latest=$q
			continue
		fi
		if [ $minor -gt $himinor ]; then
			himajor=$major
			himinor=$minor
			histamp=$stamp
			latest=$q
			continue
		fi
		if [ $stamp -gt $histamp ]; then
			himajor=$major
			himinor=$minor
			histamp=$stamp
			latest=$q
			continue
		fi
	done

	file=$latest
}

checkPackages() {
	echo ""
	echo "Checking for installable packages"
	echo ""

	for i in $CORE_PACKAGES; do
		findLatestPackage $i
		if [ ! -f "$file" ]; then
			echo "ERROR: Required Core package $i not found in $PACKAGE_DIR"
			echo "Exiting"
			exit 1
		else
			echo "Found $i"
		fi
	done

	AVAILABLE_PACKAGES=""

	for i in $PACKAGES $OPTIONAL_PACKAGES; do
		findLatestPackage $i
		if [ -f "$file" ]; then
			echo "Found $i"
			AVAILABLE_PACKAGES="$AVAILABLE_PACKAGES $i"
		fi
	done

	echo ""
}
