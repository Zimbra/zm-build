#!/bin/bash

PROGDIR=`dirname $0`
cd $PROGDIR
PATHDIR=`pwd`
BUILDTHIRDPARTY=no
BUILDNETWORK=no

usage() {
	echo ""
	echo "Usage: "`basename $0`" [-t] [-n]" >&2
	echo "-n: Perform a Network Edition build"
	echo "-t: Build third party as well as ZCS"
}

while [ $# -gt 0 ]; do
	case $1 in
		-h|--help)
			usage;
			exit 0;
			;;
		-n|--network)
			BUILDNETWORK=yes
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

echo "Checking for prerequisite binaries"
for req in ant java
do
	echo "  Checking $req"
	`which $req 2>/dev/null`
	RC=$?
	if [ $RC != 0 ]; then
		echo "Error: $req not found"
		exit 1;
	fi
done

TARGETS="sourcetar all"
if [ x$BUILDNETWORK = x"yes" ]; then
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
if [ x$BUILDNETWORK = x"no" ]; then
	TARGETS="ajaxtar $TARGETS"
fi

if [ x$BUILDNETWORK = x"no" ]; then
	cd $PATHDIR
else
	cd $PATHDIR/../ZimbraNetwork/ZimbraBuild/Makefile
fi
echo "Starting ZCS build"
make -f Makefile $TARGETS
exit 0;
