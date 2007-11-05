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

ID=`id -u`

if [ "x$ID" != "x0" ]; then
	echo "Run as root!"
	exit 1
fi

MYDIR=`dirname $0`

. ./util/utilfunc.sh

for i in ./util/modules/*sh; do
	. $i
done

UNINSTALL="no"
SOFTWAREONLY="no"

usage() {
  echo "$0 [-r <file> -l <file> -u -s -c type -x -h] [defaultsfile]"
  echo ""
  echo "-c|--cluster type     Cluster install type active|standby."
  echo "-h|--help             Usage"
  echo "-l|--license <file>   License file to install."
  echo "-r|--restore <file>   Restore contents of <file> to localconfig" 
  echo "-s|--softwareonly     Software only installation."
  echo "-u|--uninstall        Uninstall ZCS"
  echo "-x|--skipspacecheck   Skip filesystem capacity checks."
  echo "[defaultsfile]        File containing default install values."
  echo ""
  exit
}

while [ $# -ne 0 ]; do
	case $1 in
		-r|--config) 
      shift
			RESTORECONFIG=$1
		;;
		-l|--license) 
      shift
			LICENSE=$1
		;;
		-u|--uninstall) 
      UNINSTALL="yes"
		  ;;
		-s|--softwareonly) 
      SOFTWAREONLY="yes"
		  ;;
		-c|--cluster)
      shift
      CLUSTERTYPE=$1
		  ;;
		-x|--skipspacecheck) 
      SKIPSPACECHECK="yes"
		  ;;
    -h|-help|--help)
      usage
      ;;
		*) 
      DEFAULTFILE=$1
      if [ ! -f "$DEFAULTFILE" ]; then
        echo "ERROR: Unknown option $DEFAULTFILE"
        usage
      fi
		  ;;
	esac
	shift
done

. ./util/globals.sh

if [ x"$CLUSTERTYPE" != "x" -a -f "./util/clusterfunc.sh" ]; then
  . ./util/clusterfunc.sh
  checkClusterTypeArgs
fi

getPlatformVars

mkdir -p $SAVEDIR
chown zimbra:zimbra $SAVEDIR
chmod 750 $SAVEDIR

echo ""
echo "Operations logged to $LOGFILE"

if [ x$DEFAULTFILE != "x" ]; then
	AUTOINSTALL="yes"
fi

if [ x"$LICENSE" != "x" ] && [ -e $LICENSE ]; then
  if [ ! -d "/opt/zimbra/conf" ]; then
    mkdir -p /opt/zimbra/conf
  fi
  cp $LICENSE /opt/zimbra/conf/ZCSLicense.xml
  chown zimbra:zimbra /opt/zimbra/conf/ZCSLicense.xml
  chmod 444 /opt/zimbra/conf/ZCSLicense.xml
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

if [ x"$CLUSTERTYPE" != "x" ]; then
  clusterPreInstall
fi

if [ $AUTOINSTALL = "no" ]; then
	setRemove
	getInstallPackages

    findLatestPackage zimbra-core
	f=`basename $file`
	p=`bin/get_plat_tag.sh`
	echo $f | grep -q $p > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "You appear to be installing packages on a platform different"
		echo "than the platform for which they were built"
		echo ""
		echo "This platform is $p"
		echo "Packages found: $f"
		echo "This may or may not work"
		echo ""
		askYN "Install anyway?" "N"
		if [ $response = "no" ]; then
			echo "Exiting..."
			exit 1
		fi
	fi

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
D=`date +%s`
echo "${D}: INSTALL SESSION START" >> /opt/zimbra/.install_history
for i in $INSTALL_PACKAGES; do
	installPackage "$i"
done
D=`date +%s`
echo "${D}: INSTALL SESSION COMPLETE" >> /opt/zimbra/.install_history

if [ x$RESTORECONFIG != "x" ]; then
	SAVEDIR=$RESTORECONFIG
fi

if [ x$SAVEDIR != "x" -a x$REMOVE = "xno" ]; then
    setDefaultsFromExistingConfig
fi

if [ $UPGRADE = "yes" ]; then

	restoreExistingConfig

	restoreCerts

  restoreZimlets

fi

if [ "x$LICENSE" != "x" ] && [ -f "$LICENSE" ]; then
  echo "Installing /opt/zimbra/conf/ZCSLicense.xml"
  if [ ! -d "/opt/zimbra/conf" ]; then
    mkdir -p /opt/zimbra/conf
  fi
  cp -f $LICENSE /opt/zimbra/conf/ZCSLicense.xml
  chown zimbra:zimbra /opt/zimbra/conf/ZCSLicense.xml
  chmod 644 /opt/zimbra/conf/ZCSLicense.xml
fi


if [ $SOFTWAREONLY = "yes" ]; then
	
	echo ""
	echo "Software Installation complete!"
	echo ""
	echo "Operations logged to $LOGFILE"
	echo ""
	echo "Run /opt/zimbra/libexec/zmsetup.pl to configure the system"
	echo ""

  if [ x"$CLUSTERTYPE" = "xstandby" ]; then
    clusterStandbyPostInstall
  fi

	exit 0
fi

#
# Installation complete, now configure
#
if [ "x$DEFAULTFILE" != "x" ]; then
	/opt/zimbra/libexec/zmsetup.pl -c $DEFAULTFILE
else
	/opt/zimbra/libexec/zmsetup.pl
fi
