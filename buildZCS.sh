#!/bin/bash

PROGDIR=`dirname $0`
cd $PROGDIR
PATHDIR=`pwd`
BUILDTHIRDPARTY=no
BUILDTYPE=foss

usage() {
	echo ""
	echo "Usage: "`basename $0`" [-t] [-n]" >&2
	echo "-d: Perform a Zimbra Desktop build"
	echo "-n: Perform a Network Edition build"
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

echo "Checking for prerequisite binaries"
for req in ant java
do
	echo "  Checking $req"
	if [ ! -x /usr/local/$req/bin/$req ]; then
		echo "Error: /usr/local/$req/bin/$req not found"
		exit 1;
	fi
done

if [ ! -x /usr/bin/rpmbuild -a ! -x /usr/bin/dpkg -a ! -x /Developer/Applications/Utilities/PackageMaker.app/Contents/MacOS/PackageMaker ]; then
	echo "Error: No package building software found."
	echo "Make sure one of rpmbuild, dpkg, or PackageMaker is available"
	exit 1;
fi

if [ x$BUILDTHIRDPARTY = x"yes" -a x$BUILDTYPE = x"desktop" ]; then
	echo "Error: ThirdParty builds and Desktop builds are mutually exclusive"
	exit 1;
fi

if [ x$BUILDTHIRDPARTY = x"yes" ]; then
	echo "Starting 3rd Party build"
	if [ -x "../ThirdParty/buildThirdParty.sh" ]; then
		${PATHDIR}/../ThirdParty/buildThirdParty.sh -c
		RC=$?
		if [ $RC != 0 ]; then
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
elif [ x$BUILDTYPE = x"dekstop" ]; then
	cd $PATHDIR/../ZimbraOffline
else
	echo "Error: Unknown build type $BUILDTYPE"
	exit 1;
fi

echo "Starting ZCS build"
mkdir -p $PATHDIR/../logs
if [ x$BUILDTYPE = x"network" ]; then
	make -f $PATHDIR/../ZimbraNetwork/ZimbraBuild/Makefile clean
	make -f $PATHDIR/../ZimbraNetwork/ZimbraBuild/Makefile $TARGETS | tee $PATHDIR/../logs/NE-build.log
elif [ x$BUILDTYPE = x"foss" ]; then
	make -f Makefile clean
	make -f Makefile $TARGETS | tee $PATHDIR/../logs/FOSS-build.log
else
	ant -f installer-ant.xml | tee $PATHDIR/../logs/Desktop-build.log
fi
exit 0;
