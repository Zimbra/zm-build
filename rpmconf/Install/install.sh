#!/bin/bash
# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2005, 2006, 2007, 2008, 2009, 2010 Zimbra, Inc.
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
  echo "$0 [-r <file> -l <file> -a <file> -u -s -c type -x -h] [defaultsfile]"
  echo ""
  echo "-c|--cluster type       Cluster install type active|standby."
  echo "-h|--help               Usage"
  echo "-l|--license <file>     License file to install."
  echo "-a|--activation <file>  License activation file to install."
  echo "-r|--restore <file>     Restore contents of <file> to localconfig" 
  echo "-s|--softwareonly       Software only installation."
  echo "-u|--uninstall          Uninstall ZCS"
  echo "-x|--skipspacecheck     Skip filesystem capacity checks."
  echo "--beta-support          Allows installer to upgrade Network Edition Betas."
  echo "--platform-override     Allows installer to continue on an unknown OS."
  echo "--skip-activation-check Allows installer to continue if license activation checks fail."
  echo "[defaultsfile]          File containing default install values."
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
      if [ x"$LICENSE" = "x" ]; then
        echo "Valid license file required for -l."
        usage
      fi

      if [ ! -f "$LICENSE" ]; then
        echo "Valid license file required for -l."
        echo "${LICENSE}: file not found."
        usage
      fi
		;;
		-a|--activation) 
      shift
			ACTIVATION=$1
      if [ x"$ACTIVATION" = "x" ]; then
        echo "Valid license activation file required for -a."
        usage
      fi

      if [ ! -f "$ACTIVATION" ]; then
        echo "Valid license activation file required for -a."
        echo "${ACTIVATION}: file not found."
        usage
      fi
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
		-platform-override|--platform-override) 
      ALLOW_PLATFORM_OVERRIDE="yes"
		  ;;
		-beta-support|--beta-support) 
      BETA_SUPPORT="yes"
		  ;;
		-skip-activation-check|--skip-activation-check) 
      SKIP_ACTIVATION_CHECK="yes"
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

getPlatformVars

if [ x"$CLUSTERTYPE" != "x" -a -f "./util/clusterfunc.sh" ]; then
  . ./util/clusterfunc.sh
  checkClusterTypeArgs
fi

if [ x"$CLUSTERTYPE" != "x" ]; then
  clusterPreInstall
fi

mkdir -p $SAVEDIR
chown zimbra:zimbra $SAVEDIR 2> /dev/null
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
  chown zimbra:zimbra /opt/zimbra/conf/ZCSLicense.xml 2> /dev/null
  chmod 444 /opt/zimbra/conf/ZCSLicense.xml
fi

if [ x"$ACTIVATION" != "x" ] && [ -e $ACTIVATION ]; then
  if [ ! -d "/opt/zimbra/conf" ]; then
    mkdir -p /opt/zimbra/conf
  fi
  cp $ACTIVATION /opt/zimbra/conf/ZCSLicense-activated.xml
  chown zimbra:zimbra /opt/zimbra/conf/ZCSLicense-activated.xml 2> /dev/null
  chmod 444 /opt/zimbra/conf/ZCSLicense-activated.xml
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

if [ $AUTOINSTALL = "yes" ]; then
	loadConfig $DEFAULTFILE
fi

checkRequired

checkPackages

if [ $AUTOINSTALL = "no" ]; then
  setRemove

  getInstallPackages

  findLatestPackage zimbra-core
	p=`bin/get_plat_tag.sh`
	if [ x"$p" != x"$installable_platform" ]; then
    echo ""
		echo "You appear to be installing packages on a platform different"
		echo "than the platform for which they were built."
		echo ""
		echo "This platform is $p"
		echo "Packages found: $installable_platform"
		echo "This may or may not work."
		echo ""

    if [ x"${ALLOW_PLATFORM_OVERRIDE}" = "xyes" ]; then

      echo "Using packages for a platform in which they were not designed for"
      echo "may result in an installation that is NOT usable. Your support"
      echo "options may be limited if you choose to continue."
      echo ""
		  askYN "Install anyway?" "N"
		  if [ $response = "no" ]; then
			  echo "Exiting..."
			  exit 1
		  fi
    else 
      echo "Installation can not continue without manual override."
      echo "You can override this safety check with $0 --platform-override"
      echo ""
      echo "WARNING: Bypassing this check may result in an install or"
      echo "upgrade that is NOT usable."
      echo ""
      exit 1
    fi
	fi

	verifyExecute

else
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

  # deprecated by move of zimlets to /opt/zimbra/zimlets-deployed which isn't removed on upgrade
  #restoreZimlets

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
if [ "x$ACTIVATION" != "x" ] && [ -f "$ACTIVATION" ]; then
  echo "Installing /opt/zimbra/conf/ZCSLicense.xml"
  if [ ! -d "/opt/zimbra/conf" ]; then
    mkdir -p /opt/zimbra/conf
  fi
  cp -f $ACTIVATION /opt/zimbra/conf/ZCSLicense-activated.xml
  chown zimbra:zimbra /opt/zimbra/conf/ZCSLicense-activated.xml
  chmod 644 /opt/zimbra/conf/ZCSLicense-activated.xml
fi


if [ $SOFTWAREONLY = "yes" ]; then
	
	echo ""
	echo "Software Installation complete!"
	echo ""
	echo "Operations logged to $LOGFILE"
	echo ""

  if [ x"$CLUSTERTYPE" = "xstandby" ]; then
    clusterStandbyPostInstall
  else
	  echo "Run /opt/zimbra/libexec/zmsetup.pl to configure the system"
	  echo ""
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
RC=$?
if [ $RC -ne 0 ]; then
	exit $RC
fi

# Cluster postinstall for active node. 
if [ x"$CLUSTERTYPE" = "xactive" ]; then
  clusterActivePostInstall
fi
