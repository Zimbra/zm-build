#!/bin/bash
# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2013, 2014 Zimbra, Inc.
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

installPackage() {
	PKG=$1
	echo -n "    $PKG..."
	findLatestPackage $PKG
	if [ x$PKG != "xzimbra-memcached" ]; then
		if [ ! -f "$file" ]; then
			echo "file not found."
			return
		fi
		f=`basename $file`
	else
		if [[ $PLATFORM == "DEBIAN"* || $PLATFORM == "UBUNTU"* ]]; then
			f=`apt-cache show zimbra-memcached | grep ^Version:`
			f=${f#*: }
		elif [[ $PLATFORM == "RHEL"* ]]; then
			ver=`yum info zimbra-memcached | grep ^Version`;
			rel=`yum info zimbra-memcached | grep ^Release`;
			ver=${ver#*: }
			rel=${rel#*: }
			f="${ver}-${rel}"
		fi
	fi
	echo -n "...$f..."
	if [ x$PKG = "xzimbra-core" ]; then
		$REPOINST zimbra-core-components >>$LOGFILE 2>&1
                if [ $? != 0 ]; then
                  pkgError
                fi
	fi
	if [ x$PKG = "xzimbra-apache" ]; then
		$REPOINST zimbra-apache-components >>$LOGFILE 2>&1
                if [ $? != 0 ]; then
                  pkgError
                fi
	fi
	if [ x$PKG = "xzimbra-dnscache" ]; then
		$REPOINST zimbra-dnscache-components >>$LOGFILE 2>&1
                if [ $? != 0 ]; then
                  pkgError
                fi
	fi
	if [ x$PKG = "xzimbra-ldap" ]; then
		$REPOINST zimbra-ldap-components >>$LOGFILE 2>&1
                if [ $? != 0 ]; then
                  pkgError
                fi
	fi
	if [ x$PKG = "xzimbra-mta" ]; then
		$REPOINST zimbra-mta-components >>$LOGFILE 2>&1
                if [ $? != 0 ]; then
                  pkgError
                fi
	fi
	if [ x$PKG = "xzimbra-memcached" ]; then
		$REPOINST zimbra-memcached >>$LOGFILE 2>&1
                if [ $? != 0 ]; then
                  pkgError
                fi
	fi
	if [ x$PKG = "xzimbra-proxy" ]; then
		$REPOINST zimbra-proxy-components >>$LOGFILE 2>&1
                if [ $? != 0 ]; then
                  pkgError
                fi
	fi
	if [ x$PKG = "xzimbra-snmp" ]; then
		$REPOINST zimbra-snmp-components >>$LOGFILE 2>&1
                if [ $? != 0 ]; then
                  pkgError
                fi
	fi
	if [ x$PKG = "xzimbra-spell" ]; then
		$REPOINST zimbra-spell-components >>$LOGFILE 2>&1
                if [ $? != 0 ]; then
                  pkgError
                fi
	fi
	if [ x$PKG = "xzimbra-store" ]; then
		$REPOINST zimbra-store-components >>$LOGFILE 2>&1
                if [ $? != 0 ]; then
                  pkgError
                fi
	fi
	INSTRESULT=0
	if [ x$PKG != "xzimbra-memcached" ]; then
		$PACKAGEINST $file >> $LOGFILE 2>&1
		INSTRESULT=$?
	fi
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

pkgError() {
  echo ""
  echo "ERRROR: Unable to install required package"
  echo "Validate ability to connect to upstream package servers"
  exit 1
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
		if [ x"$PACKAGEEXT" = "xrpm" ]; then
			id=`echo $f | awk -F- '{print $3}'`
			version=`echo $id | awk -F_ '{print $1}'`
			major=`echo $version | awk -F. '{print $1}'`
			minor=`echo $version | awk -F. '{print $2}'`
			micro=`echo $version | awk -F. '{print $3}'`
			stamp=`echo $f | awk -F_ '{print $3}' | awk -F. '{print $1}'`
		elif [ x"$PACKAGEEXT" = "xdeb" ]; then
			id=`basename $f .deb | awk -F_ '{print $2"_"$3}'`
			id=`echo $id | sed -e 's/_i386$//'`
			id=`echo $id | sed -e 's/_amd64$//'`
			version=`echo $id | awk -F. '{print $1"."$2"."$3"_"$4}'`
			major=`echo $version | awk -F. '{print $1}'`
			minor=`echo $version | awk -F. '{print $2}'`
			micro=`echo $version | awk -F. '{print $3}'`
			stamp=`echo $id | awk -F. '{print $4}'`
		else
			id=`echo $f | awk -F_ '{print $2}'`
			version=`echo $id | awk -F_ '{print $1}'`
			major=`echo $version | awk -F. '{print $1}'`
			minor=`echo $version | awk -F. '{print $2}'`
			micro=`echo $version | awk -F. '{print $3}'`
			stamp=`echo $f | awk -F_ '{print $3}' | awk -F. '{print $1}'`
		fi
		if [ x"$PACKAGEEXT" = "xdeb" ]; then
			debos=`echo $id | awk -F. '{print $6}'`
			hwbits=`echo $id | awk -F. '{print $7}'`
			if [ x"$hwbits" = "x64" ]; then
				installable_platform=${debos}_${hwbits}
			else
				installable_platform=${debos}
			fi
		else
			installable_platform=`echo $id | awk -F. '{print $4}'`
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

	if [[ $PLATFORM == "DEBIAN"* || $PLATFORM == "UBUNTU"* ]]; then
		LOCALPROC=`dpkg --print-architecture`
		if [ x"$LOCALPROC" == "xamd64" ]; then
			LOCALPROC="x86_64"
		fi
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
			if [ x"$PACKAGEVERIFY" != "x" ]; then
				`$PACKAGEVERIFY $file > /dev/null 2>&1`
				if [ $? = 0 ]; then
					if [ x"$i" = "xzimbra-proxy" ]; then
						AVAILABLE_PACKAGES="$AVAILABLE_PACKAGES zimbra-memcached"
						AVAILABLE_PACKAGES="$AVAILABLE_PACKAGES $i"
						echo "Found zimbra-memcached"
					else
						AVAILABLE_PACKAGES="$AVAILABLE_PACKAGES $i"
					fi
					echo "Found $i"
				else 
					echo "Found $i but package is not installable. (possibly corrupt)"
					echo "Unable to continue. Please correct package corruption and rerun the installation."
					exit 1
				fi
			else 
				if [ x"$i" = "xzimbra-proxy" ]; then
					AVAILABLE_PACKAGES="$AVAILABLE_PACKAGES zimbra-memcached"
					AVAILABLE_PACKAGES="$AVAILABLE_PACKAGES $i"
					echo "Found zimbra-memcached"
				else
					AVAILABLE_PACKAGES="$AVAILABLE_PACKAGES $i"
				fi
                                echo "Found $i"
			fi
		fi
	done
	echo ""
}
