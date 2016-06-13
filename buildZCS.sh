#!/bin/bash
# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2009, 2010, 2011, 2013, 2014, 2015, 2016 Synacor, Inc.
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software Foundation,
# version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with this program.
# If not, see <https://www.gnu.org/licenses/>.
# ***** END LICENSE BLOCK *****
# 

PROGDIR=`dirname $0`
cd $PROGDIR
PATHDIR=`pwd`
BUILDTYPE=foss

usage() {
	echo ""
	echo "Usage: \"`basename $0`\"" >&2
}

while [ $# -gt 0 ]; do
	case $1 in
		-h|--help)
			usage;
			exit 0;
			;;
		*)
			echo "Usage: $0"
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
				echo "Or use OpenJDK"
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
                        echo "Alternatively, install openjdk 1.7 via your distribution"
		fi
		exit 1;
	fi
done

TARGETS="ajaxtar all"
cd $PATHDIR

echo "Starting ZCS build"
mkdir -p $PATHDIR/../logs
mkdir -p $PATHDIR/../ZimbraCommon/jars-internal/jars
make -f Makefile allclean
make -f Makefile $TARGETS | tee $PATHDIR/../logs/FOSS-build.log
exit 0;
