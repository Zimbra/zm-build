#!/bin/bash

PROGDIR=`dirname $0`
cd $PROGDIR
PATHDIR=`pwd`
BUILDTHIRDPARTY=no
RELEASE=main

usage() {
	echo ""
	echo "Usage: "`basename $0`" -t" >&2
	echo "-t: Build third party as well as ZCS"
}

while [ $# -gt 0 ]; do
	case $1 in
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
#echo "RELEASE $RELEASE"

if [ x$BUILDTHIRDPARTY = x"yes" ]; then
	if [ -x "../ThirdParty/buildThirdParty.sh" ]; then
		RC=`${PATHDIR}/../ThirdParty/buildThirdParty.sh -c -r ${RELEASE}`;
		if [ RC != 0 ]; then
			echo "Error: Building third party failed"
			exit 1;

	else
		echo "Error: ${PATHDIR}/../ThirdParty/BuildThirdParty.sh does not exit"
		exit 1;
	fi
fi

cd $PATHDIR
make -f Makefile ajaxtar sourcetar all
exit 0;
