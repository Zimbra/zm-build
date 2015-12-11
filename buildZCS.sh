#!/bin/bash
# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2009, 2010, 2011, 2013, 2014 Zimbra, Inc.
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

PROGDIR=`dirname $0`
cd $PROGDIR
PATHDIR=`pwd`
BUILDTHIRDPARTY=no
UTILITIES=no
BUILDTYPE=foss
PMIRROR=no

usage() {
	echo ""
	echo "Usage: "`basename $0`" [-d] [-t [-u]]" >&2
	echo "-d: Perform a Zimbra Desktop build"
	echo "-t: Build third party as well as ZCS"
	echo "-u: Install build utilities, must be used the first time when building ZCS (requires -t, sudo access)"
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
		-p|--private)
			PMIRROR=yes
			shift;
			;;
		-t|--thirdparty)
			BUILDTHIRDPARTY=yes
			shift;
			;;
		-u|--utilities)
			UTILITIES=yes
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
			VERSION=`$command -version | sed -e 's/Apache Ant.* version //' -e 's/ compiled on .*$//'`
			MAJOR=`echo $VERSION | awk -F. '{print $1}'`
			MINOR=`echo $VERSION | awk -F. '{print $2}'`
			PATCH=`echo $VERSION | awk -F. '{print $3}'`
			if [ $MAJOR -eq 1 -a $MINOR -lt 9 -a $PATCH -lt 1 ]; then
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
			if [ $MAJOR -eq 1 -a $MINOR -ne 7 ]; then
				echo "Error: Unsupported version of $req: $VERSION"
				echo "You can obtain $req from:"
				echo "http://www.oracle.com/technetwork/java/index.html"
				echo "Make sure the downloaded version appears first in your path"
				exit 1;
			fi
		fi
	else
		echo "Error: $req not found in path"
		if [ x$req = x"ant" ]; then
			echo "You can obtain $req from:"
			echo "http://ant.apache.org/bindownload.cgi"
		elif [ x$req = x"java" ]; then
			echo "Please obtain JDK 1.7 from:"
			echo "http://www.oracle.com/technetwork/java/index.html"
			echo "and add it to user binary path"
		fi
		exit 1;
	fi
done

if [ x$BUILDTHIRDPARTY = x"yes" -a x$BUILDTYPE = x"desktop" ]; then
	echo "Error: ThirdParty builds and Desktop builds are mutually exclusive"
	exit 1;
fi

if [ x$BUILDTHIRDPARTY = x"no" -a x$PMIRROR = x"yes" ]; then
	echo "Error: Cannot use -p without -t"
	exit 1;
fi

if [ x$BUILDTHIRDPARTY = x"no" -a x$UTILITIES = x"yes" ]; then
	echo "Error: Cannot use -u without -t"
	exit 1;
fi

TPOPTS="-c"
if [ x$PMIRROR = x"yes" ]; then
	TPOPTS="$TPOPTS -p"
fi

if [ x$UTILITIES = x"yes" ]; then
	TPOPTS="$TPOPTS -t"
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

TARGETS="all"
if [ x$BUILDTYPE = x"foss" ]; then
	TARGETS="ajaxtar $TARGETS"
fi

if [ x$BUILDTYPE = x"foss" ]; then
	cd $PATHDIR
elif [ x$BUILDTYPE = x"desktop" ]; then
	cd $PATHDIR/../ZimbraOffline
else
	echo "Error: Unknown build type $BUILDTYPE"
	exit 1;
fi

echo "Starting ZCS build"
mkdir -p $PATHDIR/../logs
mkdir -p $PATHDIR/../ZimbraCommon/jars-internal/jars
if [ x$BUILDTYPE = x"foss" ]; then
	make -f Makefile allclean
	make -f Makefile $TARGETS | tee $PATHDIR/../logs/FOSS-build.log
else
	ant -f installer-ant.xml | tee $PATHDIR/../logs/Desktop-build.log
fi
exit 0;
