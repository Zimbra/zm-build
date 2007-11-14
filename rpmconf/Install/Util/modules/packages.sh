#!/bin/bash
# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2005, 2006, 2007 Zimbra, Inc.
# 
# The contents of this file are subject to the Yahoo! Public License
# Version 1.0 ("License"); you may not use this file except in
# compliance with the License.  You may obtain a copy of the License at
# http://www.zimbra.com/license.
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied.
# ***** END LICENSE BLOCK *****
# 

installPackage() {
	PKG=$1
	echo -n "    $PKG..."
	findLatestPackage $PKG
  if [ ! -f "$file" ]; then
    echo "file not found."
    return
  fi
	f=`basename $file`
	echo -n "...$f..."
	$PACKAGEINST $file >> $LOGFILE 2>&1
	INSTRESULT=$?
	if [ $UPGRADE = "yes" ]; then
		ST="UPGRADED"
	else
		ST="INSTALLED"
	fi
	D=`date +%s`
	if [ $INSTRESULT = 0 ]; then
		echo "done"
		echo "${D}: $ST $f" >> /opt/zimbra/.install_history
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

	files=`ls $PACKAGE_DIR/$package*.$PACKAGEEXT 2> /dev/null`
	for q in $files; do

		
		f=`basename $q`
		if [ $PACKAGEEXT = "rpm" ]; then
			id=`echo $f | awk -F- '{print $3}'`
			version=`echo $id | awk -F_ '{print $1}'`
			major=`echo $version | awk -F. '{print $1}'`
			minor=`echo $version | awk -F. '{print $2}'`
			micro=`echo $version | awk -F. '{print $3}'`
			#micro=${micro}_`echo $version | awk -F_ '{print $3}'`
			stamp=`echo $f | awk -F_ '{print $3}' | awk -F. '{print $1}'`
		else
			id=`echo $f | awk -F_ '{print $2}'`
			version=`echo $id | awk -F_ '{print $1}'`
			major=`echo $version | awk -F. '{print $1}'`
			minor=`echo $version | awk -F. '{print $2}'`
			micro=`echo $version | awk -F. '{print $3}'`
			#micro=${micro}_`echo $version | awk -F_ '{print $3}'`
			stamp=`echo $f | awk -F_ '{print $3}' | awk -F. '{print $1}'`
		fi

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
			echo $file | grep -q i386
			if [ $? -eq 0 ]; then
				PROC="i386"
			else
				PROC="x86_64"
			fi
			echo "Found $i"
		fi
	done

	if [ $PLATFORM = "DEBIAN3.1" -o $PLATFORM = "MANDRIVA2006" -o $PLATFORM = "UBUNTU6" -o $PLATFORM = "UBUNTU7" -o $PLATFORM = "DEBIAN4.0" ]; then
		LOCALPROC=$PROC
	else
		LOCALPROC=`uname -i`
	fi

	if [ x$LOCALPROC != x$PROC ]; then
		echo "Error: attempting to install $PROC packages on a $LOCALPROC OS."
		echo "Exiting..."
		echo ""
		exit 1
	fi

	AVAILABLE_PACKAGES=""

	for i in $PACKAGES $OPTIONAL_PACKAGES; do
		findLatestPackage $i
		if [ -f "$file" ]; then

      # only make zimbra-cluster available on supported OS's 
      echo $PLATFORM | egrep -q "RHEL|CentOS"
      if [ $? != 0 -a $i = "zimbra-cluster" ]; then
        continue
      fi

      if [ x"$PACKAGEVERIFY" != "x" ]; then
        `$PACKAGEVERIFY $file > /dev/null 2>&1`
        if [ $? = 0 ]; then
          echo "Found $i"
			    AVAILABLE_PACKAGES="$AVAILABLE_PACKAGES $i"
        else 
          echo "Found $i but package is not installable. (possibly corrupt)"
        fi
      else 
			  echo "Found $i"
			  AVAILABLE_PACKAGES="$AVAILABLE_PACKAGES $i"
      fi
    fi
	done

	echo ""
}
