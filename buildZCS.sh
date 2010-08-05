#!/bin/bash
# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2009, 2010 Zimbra, Inc.
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

PROGDIR=`dirname $0`
cd $PROGDIR
PATHDIR=`pwd`
BUILDTHIRDPARTY=no
BUILDTYPE=foss
PMIRROR=no

usage() {
	echo ""
	echo "Usage: "`basename $0`" [-d] [-t [-p]] [-n]" >&2
	echo "-d: Perform a Zimbra Desktop build"
	echo "-n: Perform a Network Edition build"
	echo "-p: Use private Perl mirror when building 3rd party"
	echo "-t: Build third party as well as ZCS"
}

while [ $# -gt 0 ]; do
	case $1 in
		-d|--desktop)
			BUILDTYPE=desktop
			shift;
			;;
		-h|--help)
			usage;
			exit 0;
			;;
		-n|--network)
			BUILDTYPE=network
			shift;
			;;
		-p|--private)
			PMIRROR=yes
			shift;
			;;
		-t|--thirdparty)
			BUILDTHIRDPARTY=yes
			shift;
			;;
		*)
			echo "Usage: $0 [-t]"
			exit 1;
			;;
	esac
done

RELEASE=${PATHDIR%/*}
RELEASE=${RELEASE##*/}

PLAT=`$PATHDIR/../ZimbraBuild/rpmconf/Build/get_plat_tag.sh`;

echo "Checking for prerequisite binaries"
for req in ant java
do
	echo "  Checking $req"
	command=`which $req 2>/dev/null`
	RC=$?
	if [ $RC -eq 0 ]; then
		if [ x$req = x"ant" ]; then
			VERSION=`$command -version | sed -e 's/Apache Ant version //' -e 's/ compiled on .*$//'`
			MAJOR=`echo $VERSION | awk -F. '{print $1}'`
			MINOR=`echo $VERSION | awk -F. '{print $2}'`
			PATCH=`echo $VERSION | awk -F. '{print $3}'`
			if [ $MAJOR -eq 1 -a $MINOR -lt 6  -a $PATCH -lt 5 ]; then
				echo "Error: Unsupported version of $req: $VERSION"
				echo "You can obtain $req from:"
				echo "http://ant.apache.org/bindownload.cgi"
				exit 1;
			fi
		elif [ x$req = x"java" ]; then
			VERSION=$(${command} -version 2>&1 | grep "java version" | sed -e 's/"//g' | awk '{print $NF}' | awk -F_ '{print $1}')
			MAJOR=`echo $VERSION | awk -F. '{print $1}'`
			MINOR=`echo $VERSION | awk -F. '{print $2}'`
			PATCH=`echo $VERSION | awk -F. '{print $3}'`
			if [ $MAJOR -eq 1 -a $MINOR -lt 6 ]; then
				echo "Error: Unsupported version of $req: $VERSION"
				echo "You can obtain $req from:"
				echo "http://java.sun.com/javase/downloads/index_jdk5.jsp"
				echo "Make sure the downloaded version appears first in your path"
				exit 1;
			fi
		fi
	else
		echo "Error: $req not found"
		if [ x$req = x"ant" ]; then
			echo "You can obtain $req from:"
			echo "http://ant.apache.org/bindownload.cgi"
		elif [ x$req = x"java" ]; then
			if [[ $PLAT == "MACOSX"* ]]; then
				echo "Please create a symlink from:"
				echo "/System/Library/Frameworks/JavaVM.framework/Home to /usr/local/$req"
				echo "cd /usr/local"
				echo "ln -s /System/Library/Frameworks/JavaVM.framework/Home $req"
			else
				echo "Please obtain JDK 1.5 from:"
				echo "http://java.sun.com/javase/downloads/index_jdk5.jsp"
				echo "And install it in /usr/local"
				echo "Then symlink it to /usr/local/java"
			fi
		fi
		exit 1;
	fi
done

JVERSION=`grep ^JAVA_VERSION $PATHDIR/defs/plat_common.def | sed -e 's/JAVA_VERSION[\t]*:=[\t]*[ ]*//'`
echo "Checking for required JDK tarball"
if [[ $PLAT == *"_64" ]]; then
	if [ ! -f $PATHDIR/../ThirdPartyBuilds/x86_64/java/jdk${JVERSION}.tgz ]; then
		echo "Error: jdk file needed for ZCS packaging not available"
		echo "Necessary version is: $JVERSION"
		echo "Please create $PATHDIR/../ThirdPartyBuilds/x86_64/java/jdk${JVERSION}.tgz"
		echo "Which is an extracted then retarred version of JDK 1.5 downloaded from"
		echo "http://java.sun.com/javase/downloads/index_jdk5.jsp"
		exit 1;
	fi
elif [[ $PLAT != "MACOSX"* ]]; then
	if [ ! -f $PATHDIR/../ThirdPartyBuilds/i386/java/jdk${JVERSION}.tgz ]; then
		echo "Error: jdk file needed for ZCS packaging not available"
		echo "Necessary version is: $JVERSION"
		echo "Please create $PATHDIR/../ThirdPartyBuilds/i386/java/jdk${JVERSION}.tgz"
		echo "Which is an extracted then retarred version of JDK 1.5 downloaded from"
		echo "http://java.sun.com/javase/downloads/index_jdk5.jsp"
		exit 1;
	fi
fi

if [ ! -x /usr/bin/rpmbuild -a ! -x /usr/bin/dpkg -a ! -x /Developer/Applications/Utilities/PackageMaker.app/Contents/MacOS/PackageMaker ]; then
	echo "Error: No package building software found."
	echo "Make sure one of rpmbuild, dpkg, or PackageMaker is available"
	exit 1;
fi

if [ x$BUILDTHIRDPARTY = x"yes" -a x$BUILDTYPE = x"desktop" ]; then
	echo "Error: ThirdParty builds and Desktop builds are mutually exclusive"
	exit 1;
fi

if [ x$BUILDTHIRDPARTY = x"no" -a x$PMIRROR = x"yes" ]; then
	echo "Error: Cannot use -p without -t"
	exit 1;
fi

TPOPTS="-c"
if [ x$PMIRROR = x"yes" ]; then
	TPOPTS="$TPOPTS -p"
fi

if [ x$BUILDTHIRDPARTY = x"yes" ]; then
	echo "Starting 3rd Party build"
	if [ -x "../ThirdParty/buildThirdParty.sh" ]; then
		${PATHDIR}/../ThirdParty/buildThirdParty.sh $TPOPTS
		RC=$?
		if [ $RC -ne 0 ]; then
			echo "Error: Building third party failed"
			echo "Please fix and retry"
			exit 1;
		fi
	else
		echo "Error: ${PATHDIR}/../ThirdParty/BuildThirdParty.sh does not exit"
		exit 1;
	fi
fi

TARGETS="sourcetar all"
if [ x$BUILDTYPE = x"network" ]; then
	if [ -f "$PATHDIR/../ZimbraNetwork/ZimbraBuild/Makefile" ]; then
		if [ x$RELEASE = x"main" ]; then
			TARGETS="$TARGETS velodrome"
		elif [[ $RELEASE == "FRANKLIN"* ]]; then
			TARGETS="$TARGETS velodrome customercare"
		fi
	else
		echo "Error: ZimbraNetwork is not available"
		exit 1;
	fi
fi
if [ x$BUILDTYPE = x"foss" ]; then
	TARGETS="ajaxtar $TARGETS"
fi

if [ x$BUILDTYPE = x"network" -o x$BUILDTYPE = x"foss" ]; then
	cd $PATHDIR
elif [ x$BUILDTYPE = x"desktop" ]; then
	cd $PATHDIR/../ZimbraOffline
else
	echo "Error: Unknown build type $BUILDTYPE"
	exit 1;
fi

echo "Starting ZCS build"
mkdir -p $PATHDIR/../logs
if [ x$BUILDTYPE = x"network" ]; then
	make -f $PATHDIR/../ZimbraNetwork/ZimbraBuild/Makefile allclean
	make -f $PATHDIR/../ZimbraNetwork/ZimbraBuild/Makefile $TARGETS | tee $PATHDIR/../logs/NE-build.log
elif [ x$BUILDTYPE = x"foss" ]; then
	make -f Makefile allclean
	make -f Makefile $TARGETS | tee $PATHDIR/../logs/FOSS-build.log
else
	ant -f installer-ant.xml | tee $PATHDIR/../logs/Desktop-build.log
fi
exit 0;
