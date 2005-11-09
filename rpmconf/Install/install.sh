#!/bin/bash
# 
# ***** BEGIN LICENSE BLOCK *****
# Version: MPL 1.1
# 
# The contents of this file are subject to the Mozilla Public License
# Version 1.1 ("License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://www.zimbra.com/license
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations
# under the License.
# 
# The Original Code is: Zimbra Collaboration Suite Server.
# 
# The Initial Developer of the Original Code is Zimbra, Inc.
# Portions created by Zimbra are Copyright (C) 2005 Zimbra, Inc.
# All Rights Reserved.
# 
# Contributor(s):
# 
# ***** END LICENSE BLOCK *****
# 

MYDIR=`dirname $0`

. ./util/utilfunc.sh

for i in ./util/modules/*sh; do
	. $i
done

UNINSTALL="no"
SOFTWAREONLY="no"

while [ $# -ne 0 ]; do
	case $1 in
		-r) shift
			RESTORECONFIG=$1
		;;
		-u) UNINSTALL="yes"
		;;
		-s) SOFTWAREONLY="yes"
		;;
		*) DEFAULTFILE=$1
		;;
	esac
	shift
done

. ./util/globals.sh

getPlatformVars

mkdir -p $SAVEDIR
chmod 777 $SAVEDIR

echo ""
echo "Operations logged to $LOGFILE"

if [ x$DEFAULTFILE != "x" ]; then
	AUTOINSTALL="yes"
fi

checkExistingInstall

if [ x$UNINSTALL = "xyes" ]; then
	askYN "Completely remove existing installation?" "N"
	if [ $response = "yes" ]; then
		REMOVE="yes"
		removeExistingInstall
	fi
	exit 1
fi

displayLicense

checkUser root

checkRequired

checkPackages

if [ $AUTOINSTALL = "no" ]; then
	setRemove
	getInstallPackages

	verifyExecute

else
	loadConfig $DEFAULTFILE

	checkVersionMatches

	if [ $VERSIONMATCH = "no" ]; then
		if [ $UPGRADE = "yes" ]; then
			echo ""
			echo "###ERROR###"
			echo ""
			echo "There is a mismatch in the versions of the installed schema"
			echo "or index and the version included in this package"
			echo ""
			echo "Automatic upgrade cancelled"
			echo ""
			exit 1
		fi
	fi
fi

removeExistingInstall

echo "Installing packages"
echo ""
for i in $INSTALL_PACKAGES; do
	installPackage "$i"
done

if [ "x$UPGRADE" = "xno" ]; then
	touch /opt/zimbra/.newinstall
fi

if [ $SOFTWAREONLY = "yes" ]; then
	
	echo ""
	echo "Software Installation complete!"
	echo ""
	echo "Operations logged to $LOGFILE"
	echo ""
	echo "Run /opt/zimbra/libexec/zmsetup.pl to configure the system"
	echo ""

	exit 0
fi

#
# Installation complete, now configure
#

if [ x$RESTORECONFIG != "x" ]; then
	SAVEDIR=$RESTORECONFIG
fi

if [ x$SAVEDIR != "x" -a x$REMOVE = "xno" ]; then
    setDefaultsFromExistingConfig
fi

if [ $UPGRADE = "yes" ]; then

	restoreExistingConfig

	restoreCerts

fi

if [ x$DEFAULTFILE != "x" ]; then
	/opt/zimbra/libexec/zmsetup.pl -c $DEFAULTFILE
else
	/opt/zimbra/libexec/zmsetup.pl
fi
