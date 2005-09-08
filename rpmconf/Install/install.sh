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

MYDIR=`dirname $0`
MYLDAPSEARCH="$MYDIR/bin/ldapsearch"

. ./util/utilfunc.sh

for i in ./util/modules/*sh; do
	. $i
done

UNINSTALL="no"

while [ $# -ne 0 ]; do
	case $1 in
		-r) shift
			RESTORECONFIG=$1
		;;
		-u) UNINSTALL="yes"
		;;
		*) DEFAULTFILE=$1
		;;
	esac
	shift
done

. ./util/globals.sh

mkdir -p $SAVEDIR
chmod 777 $SAVEDIR

echo ""
echo "Operations logged to $LOGFILE"

checkUser

checkRequired

checkPackages

checkConflicts

checkExistingInstall

if [ x$UNINSTALL = "xyes" ]; then
	askYN "Completely remove existing installation?" "N"
	if [ $response = "yes" ]; then
		REMOVE="yes"
		removeExistingInstall
	fi
	exit 1
fi

if [ x$DEFAULTFILE != "x" ]; then
	AUTOINSTALL="yes"
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

if [ $AUTOINSTALL = "no" ]; then
	if [ $INSTALLED = "yes" ]; then
		setDefaultsFromExistingConfig
	fi

	if [ $SNMPNOTIFY = "1" ]; then
		SNMPNOTIFY="yes"
	else
		SNMPNOTIFY="no"
	fi
	if [ $SMTPNOTIFY = "1" ]; then
		SMTPNOTIFY="yes"
	else
		SMTPNOTIFY="no"
	fi

	setHostName
	# setServiceIP
	setRemove
	getInstallPackages
fi

setHereFlags

if [ $AUTOINSTALL = "no" ]; then
	getConfigOptions

	echo ""
	echo "System configuration section complete"
	echo "Package installation ready"

	askYN "Save installation configuration?" "Y"
	if [ $response = "yes" ]; then
		askNonBlank "Filename:" "/tmp/config.$$"
		saveConfig $response
	fi

	if [ $AUTOINSTALL = "no" ]; then
		askYN "Start servers after installation?" "Y"
		STARTSERVERS=$response
	fi

	verifyExecute

else
	verifyLdapServer

	if [ $LDAPOK = "no" ]; then
		echo "LDAP ERROR - auto install canceled"
		exit 1
	fi
fi


removeExistingInstall

echo "Installing packages"
echo ""
for i in $INSTALL_PACKAGES; do
	installPackage "$i"
done

postInstallConfig

if [ $STARTSERVERS = "yes" ]; then
	startServers
fi

/opt/zimbra/bin/zmsyslogsetup

cleanUp

echo ""
echo "Installation complete!"
echo ""
echo "Operations logged to $LOGFILE"
echo ""

exit 0
