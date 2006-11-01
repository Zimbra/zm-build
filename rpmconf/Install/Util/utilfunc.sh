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
# Portions created by Zimbra are Copyright (C) 2005, 2006 Zimbra, Inc.
# All Rights Reserved.
# 
# Contributor(s):
# 
# ***** END LICENSE BLOCK *****
# 

displayLicense() {
	echo ""
	echo ""
	cat $MYDIR/docs/zcl.txt
	echo ""
	echo ""
	if [ x$DEFAULTFILE = "x" ]; then
		echo -n "Press Return to continue"
		read response
	fi
	echo ""
}

isFQDN() {
	#fqdn is > 2 dots.  because I said so.
	if [ $1 = "dogfood" ]; then
		echo 1
		return
	fi
	NF=`echo $1 | awk -F. '{print NF}'`
	if [ $NF -ge 2 ]; then 
		echo 1
	else 
		echo 0
	fi
}

saveConfig() {
	FILE=$1

cat > $FILE <<EOF
REMOVE=$REMOVE
UPGRADE=$UPGRADE
HOSTNAME=$HOSTNAME
SERVICEIP=$SERVICEIP
LDAPHOST=$LDAPHOST
LDAPPORT=$LDAPPORT
SMTPHOST=$SMTPHOST
SNMPTRAPHOST=$SNMPTRAPHOST
SMTPSOURCE=$SMTPSOURCE
SMTPDEST=$SMTPDEST
SNMPNOTIFY=$SNMPNOTIFY
SMTPNOTIFY=$SMTPNOTIFY
INSTALL_PACKAGES="$INSTALL_PACKAGES"
STARTSERVERS=$STARTSERVERS
LDAPROOTPW=$LDAPROOTPW
LDAPZIMBRAPW=$LDAPZIMBRAPW
CREATEDOMAIN=$CREATEDOMAIN
CREATEADMIN=$CREATEADMIN
CREATEADMINPASS=$CREATEADMINPASS
MODE=$MODE
ALLOWSELFSIGNED=$ALLOWSELFSIGNED
RUNAV=$RUNAV
RUNSA=$RUNSA
AVUSER=$AVUSER
AVDOMAIN=$AVDOMAIN
EOF

}

loadConfig() {
	FILE=$1

	if [ ! -f $FILE ]; then
		echo ""
		echo "*** ERROR - can't find configuration file $FILE"
		echo ""
		exit 1
	fi
	echo ""
	echo -n "Loading configuration data from $FILE..."
	source $FILE
	echo "done"
}

# All ask functions take 2 args:
#	Prompt
#	Default (optional)

ask() {
	PROMPT=$1
	DEFAULT=$2

	echo ""
	echo -n "$PROMPT [$DEFAULT] "
	read response

	if [ -z $response ]; then
		response=$DEFAULT
	fi
}

askNonBlankNoEcho() {
	PROMPT=$1
	DEFAULT=$2

	while [ 1 ]; do
		stty -echo
		ask "$PROMPT" "$DEFAULT"
		stty echo
		echo ""
		if [ ! -z $response ]; then
			break
		fi
		echo "A non-blank answer is required"
	done
}

askNonBlank() {
	PROMPT=$1
	DEFAULT=$2

	while [ 1 ]; do
		ask "$PROMPT" "$DEFAULT"
		if [ ! -z $response ]; then
			break
		fi
		echo "A non-blank answer is required"
	done
}

askYN() {
	PROMPT=$1
	DEFAULT=$2

	if [ "x$DEFAULT" = "xyes" -o "x$DEFAULT" = "xYes" -o "x$DEFAULT" = "xy" -o "x$DEFAULT" = "xY" ]; then
		DEFAULT="Y"
	else
		DEFAULT="N"
	fi

	while [ 1 ]; do
		ask "$PROMPT" "$DEFAULT"
		if [ -z $response ]; then
			:
		else
			if [ $response = "yes" -o $response = "YES" -o $response = "y" -o $response = "Y" ]; then
				response="yes"
				break
			else 
				if [ $response = "no" -o $response = "NO" -o $response = "n" -o $response = "N" ]; then
					response="no"
					break
				fi
			fi
		fi
		echo "A Yes/No answer is required"
	done
}

askInt() {
	PROMPT=$1
	DEFAULT=$2

	while [ 1 ]; do
		ask "$PROMPT" "$DEFAULT"
		if [ -z $response ]; then
			:
		else
			expr $response + 5 > /dev/null 2>&1
			if [ $? = 0 ]; then
				break
			fi
		fi
		echo "A numeric answer is required"
	done
}

checkUser() {
	user=$1
	if [ x`whoami` != x$user ]; then
		echo Error: must be run as $user user
		exit 1
	fi
}

checkRequired() {

	if ! cat /etc/hosts | perl -ne 'if (/^\s*127\.0\.0\.1/ && !/^\s*127\.0\.0\.1\s+localhost/) { exit 11; }'; then
	cat<<EOF

	ERROR: Installation can not proceeed.  Please fix your /etc/hosts file
	to contain:

	127.0.0.1 localhost.localdomain localhost

	Zimbra install grants mysql permissions only to localhost and
	localhost.localdomain users.  But Fedora/RH installs leave lines such
	as these in /etc/hosts:

	127.0.0.1     myhost.mydomain.com myhost localhost.localdomain localhost

	This causes MySQL to reject users coming from 127.0.0.1 as users from
	myhost.mydomain.com.  You can read more details at:

	http://bugs.mysql.com/bug.php?id=11822

EOF

	exit 1
	fi

	if ! cat /etc/hosts | \
		perl -ne 'if (/^\s*\d+\.\d+\.\d+\.\d+\s+(\S+)/ && !/^\s*127\.0\.0\.1/) { my @foo = split (/\./,$1); if ($#foo == "0") {exit 11;} }'; then

	cat<<EOF

	ERROR: Installation can not proceeed.  Please fix your /etc/hosts file
	to contain:

	<ip> <FQHN> <HN>

	Where <IP> is the ip address of the host, 
	<FQHN> is the FULLY QUALIFIED host name, and
	<HN> is the (optional) hostname-only portion

EOF

	exit 1
	fi

	GOOD="yes"
	echo "Checking for prerequisites..."
	echo -n "    NPTL..."
	/usr/bin/getconf GNU_LIBPTHREAD_VERSION | grep NPTL > /dev/null 2>&1
	if [ $? != 0 ]; then
		echo "MISSING"
		GOOD="no"
	else
		echo "FOUND"
	fi

	for i in $PREREQ_PACKAGES; do
		echo -n "    $i..."
		isInstalled $i
		if [ "x$PKGINSTALLED" != "x" ]; then
			echo "FOUND $PKGINSTALLED"
		else
			echo "MISSING"
			GOOD="no"
		fi
	done

	for i in $PREREQ_LIBS; do
		echo -n "    $i..."
		if [ -L $i -o -f $i ]; then
			echo "FOUND"
		else
			echo "MISSING"
			GOOD="no"
		fi
	done

	if [ $GOOD = "no" ]; then
		echo ""
		echo "###ERROR###"
		echo ""
		echo "One or more prerequisite packages are missing."
		echo "Please install them before running this installer."
		echo ""
		echo "Installation cancelled."
		echo ""
		exit 1
	fi
}

checkExistingInstall() {

	echo "Checking for existing installation..."
	for i in $OPTIONAL_PACKAGES; do
		isInstalled $i
		if [ x$PKGINSTALLED != "x" ]; then
			echo "    $i...FOUND $PKGINSTALLED"
			INSTALLED_PACKAGES="$INSTALLED_PACKAGES $i"
		fi
	done
	for i in $PACKAGES $CORE_PACKAGES; do
		echo -n "    $i..."
		isInstalled $i
		if [ x$PKGINSTALLED != "x" ]; then
			echo "FOUND $PKGINSTALLED"
			INSTALLED="yes"
			INSTALLED_PACKAGES="$INSTALLED_PACKAGES $i"
		else
			echo "NOT FOUND"
		fi
	done

  determineVersionType
  verifyLicenseAvailable

	if [ $INSTALLED = "yes" ]; then
		saveExistingConfig
	else
		checkUserInfo
	fi
}

determineVersionType() {

  isInstalled zimbra-core
  if [ x$PKGINSTALLED != "x" ]; then
    ZMVERSION_CURRENT=$PKGVERSION
    if [ -d "/opt/zimbra/zimlets-network" ]; then
      ZMTYPE_CURRENT="NETWORK"
    else 
      ZMTYPE_CURRENT="FOSS"
    fi
  fi
  # need way to determine type for other package types
	if [ $PACKAGEEXT = "rpm" ]; then
    if [ x"`rpm --qf '%{description}' -qp ./packages/zimbra-core* | grep Network`" = "x" ]; then
      ZMTYPE_INSTALLABLE="FOSS"
    else 
      ZMTYPE_INSTALLABLE="NETWORK"
    fi
  fi

  if [ x"$UNINSTALL" = "xyes" ] || [ x"$AUTOINSTALL" = "xyes" ]; then
    return
  fi

  if [ x"$ZMTYPE_CURRENT" = "xNETWORK" ] && [ x"$ZMTYPE_INSTALLABLE" = "xFOSS" ]; then
    echo "Warning: You are about to upgrade from the Network Edition to the"
    echo "Open Source Edition.  This will remove all Network features, including" 
    echo "Attachment Searching, Zimbra Mobile, Backup/Restore, and support for the "
    echo "Zimbra Connector for Outlook."
	  while :; do
	   askYN "Do you wish to continue?" "N"
	   if [ $response = "no" ]; then
	    askYN "Exit?" "N"
	    if [ $response = "yes" ]; then
		    echo "Exiting."
		    exit 1
	    fi
	   else
	    break
	   fi
	  done
  fi
}

verifyLicenseAvailable() {

  if [ x"$AUTOINSTALL" = "xyes" ] || [ x"$UNINSTALL" = "xyes" ] || [ x"$SOFTWAREONLY" = "yes" ]; then
    return
  fi

  isInstalled zimbra-store
  if [ x$PKGINSTALLED = "x" ]; then
    return
  fi

  # need to finish for other native packagers
	if [ $PACKAGEEXT = "rpm" ]; then
    if [ x"`rpm --qf '%{description}' -qp ./packages/zimbra-core* | grep Network`" = "x" ]; then
     return
    fi
  else 
    return
  fi

  echo "Checking for available license file..."

  # use the tool if it exists
  if [ -f "/opt/zimbra/bin/zmlicense" ]; then
    licenseCheck=`su - zimbra -c "zmlicense -c" 2> /dev/null`
    licensedUsers=`su - zimbra -c "zmlicense -p | grep ^AccountsLimit | sed -e 's/AccountsLimit=//'" 2> /dev/null`
  fi

  # parse files is license tool wasn't there or didn't return a valid license
  if [ x"$licenseCheck" = "xlicense not installed" -o x"$licenseCheck" = "x" ]; then
    if [ -f "/opt/zimbra/conf/ZCSLicense.xml" ]; then
      licenseCheck="license is OK"
      licensedUsers=`cat /opt/zimbra/conf/ZCSLicense.xml | grep AccountsLimit | head -1  | awk '{print $3}' | awk -F= '{print $2}' | awk -F\" '{print $2}'`
    elif [ -f "/opt/zimbra/conf/ZCSLicense-Trial.xml" ]; then
      licenseCheck="license is OK"
      licensedUsers=`cat /opt/zimbra/conf/ZCSLicense-Trial.xml | grep AccountsLimit | head -1  | awk '{print $3}' | awk -F= '{print $2}' | awk -F\" '{print $2}'`
    else
      echo "ERROR: The ZCS Network upgrade requires a license to be located in"
      echo "/opt/zimbra/conf/ZCSLicense.xml or a license previously installed."
      echo "The upgrade will not continue without a license."
      echo ""
      echo "Your system has not been modified"
      echo ""
      echo "New customers wanting to purchase or obtain a trial license"
      echo "should contact Zimbra sales.  Contact information for Zimbra is"
      echo "located at http://www.zimbra.com/about/contact_us.html"
      echo "Existing customers can obtain an updated license file via the"
      echo "Zimbra Support page located at http://www.zimbra.com/support."
      echo ""
      exit 1;
    fi
  fi
  if [ x"$licensedUsers" = "x" ]; then
    licensedUsers=0
  fi
  # Check for licensed user count and warn if necessary
  numCurrentUsers=`su - zimbra -c "zmprov gaa 2> /dev/null | wc -l"`;
  numUsersRC=$?
  if [ $numUsersRC -ne 0 ]; then
    numCurrentUsers=`su - zimbra -c "zmprov -l gaa 2> /dev/null | wc -l"`;
    numUsersRC=$?
  fi
  numCurrentUsers=`expr $numCurrentUsers - 3`
  if [ $numCurrentUsers -gt 0 ]; then
    echo "Current Users=$numCurrentUsers Licensed Users=$licensedUsers"
  fi

  if [ "$licensedUsers" = "-1" ]; then
    return
  elif [ $numCurrentUsers -lt 0 ]; then
    echo "Warning: Could not determine the number of users on this system."
    echo "If you exceed the number of licensed users ($licensedUsers) then you will"
    echo "not be able to create new users."
	  while :; do
	   askYN "Do you wish to continue?" "N"
	   if [ $response = "no" ]; then
	    askYN "Exit?" "N"
	    if [ $response = "yes" ]; then
		    echo "Exiting - place a valid license file in /opt/zimbra/conf/ZCSLicense.xml and rerun."
		    exit 1
	    fi
	   else
	    break
	   fi
	  done
  elif [ $numUsersRC -ne 0 ] || [ $numCurrentUsers -gt $licensedUsers ]; then
    echo "Warning: The number of users on this system ($numCurrentUsers) exceeds the licensed number"
    echo "($licensedUsers).  You may continue with the upgrade, but you will not be able to create"
    echo "new users.  Also, initialization of the Document feature will fail.  If you "
    echo "later wish to use the Documents feature you'll need to resolve the licensing "
    echo "issues and then run a separate script available from support to initialize the "
    echo "Documents feature. "
	  while :; do
	   askYN "Do you wish to continue?" "N"
	   if [ $response = "no" ]; then
	    askYN "Exit?" "N"
	    if [ $response = "yes" ]; then
		    echo "Exiting - place a valid license file in /opt/zimbra/conf/ZCSLicense.xml and rerun."
		    exit 1
	    fi
	   else
	    break
	   fi
	  done
  else
    # valid license and user count
    return
  fi

}

checkUserInfo() {
	#Verify that the zimbra user either:
	#  Doesn't exist OR
	#  Exists with:
	#     home: /opt/zimbra
	#     shell: bash
	id zimbra > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		return
	fi
	ZH=`awk -F: '/^zimbra:/ {print $6}' /etc/passwd`
	ZS=`awk -F: '/^zimbra:/ {print $7}' /etc/passwd | sed -e s'|.*/||'`
	if [ x$ZH != "x/opt/zimbra" ]; then
		echo "Error - zimbra user exists with incorrect home directory: $ZH"
		echo "Exiting"
		exit 1
	fi
	if [ x$ZS != "xbash" ]; then
		echo "Error - zimbra user exists with incorrect shell: $ZS"
		echo "Exiting"
		exit 1
	fi
}

runAsZimbra() {
	# echo "Running as zimbra: $1"
	echo "COMMAND: $1" >> $LOGFILE 2>&1
	su - zimbra -c "$1" >> $LOGFILE 2>&1
}

shutDownSystem() {
	runAsZimbra "zmcontrol shutdown"
}

getRunningSchemaVersion() {
	RUNNINGSCHEMAVERSION=`su - zimbra -c "echo \"select value from config where name='db.version';\" | mysql zimbra --skip-column-names"`
	if [ "x$RUNNINGSCHEMAVERSION" = "x" ]; then
		RUNNINGSCHEMAVERSION=0
	fi
}

getPackageSchemaVersion() {
	PACKAGESCHEMAVERSION=`cat data/versions-init.sql  | grep db.version | sed -e s/[^0-9]//g`
}

getRunningIndexVersion() {
	RUNNINGINDEXVERSION=`su - zimbra -c "echo \"select value from config where name='index.version';\" | mysql zimbra --skip-column-names"`
	if [ "x$RUNNINGINDEXVERSION" = "x" ]; then
		RUNNINGINDEXVERSION=0
	fi
}

getPackageIndexVersion() {
	PACKAGEINDEXVERSION=`cat data/versions-init.sql  | grep index.version | sed -e s/[^0-9]//g`
}

checkVersionMatches() {
	VERSIONMATCH="yes"

	# This bombs when mysql isn't around, and was a really bad
	# idea, anyway
	return

	getRunningSchemaVersion
	getPackageSchemaVersion
	getRunningIndexVersion
	getPackageIndexVersion
	if [ $RUNNINGSCHEMAVERSION != $PACKAGESCHEMAVERSION ]; then
		VERSIONMATCH="no"
		return
	fi
	if [ $RUNNINGINDEXVERSION != $PACKAGEINDEXVERSION ]; then
		VERSIONMATCH="no"
		return
	fi
}

setRemove() {

	if [ $INSTALLED = "yes" ]; then
		
		checkVersionMatches

		echo ""
		echo "The Zimbra Collaboration Suite appears already to be installed."
		if [ $VERSIONMATCH = "yes" ]; then
			echo "It can be upgraded with no effect on existing accounts,"
			echo "or the current installation can be completely removed prior"
			echo "to installation for a clean install."
		else
			echo ""
			echo "###WARNING###"
			if [ $RUNNINGSCHEMAVERSION -eq 0 -o $RUNNINGINDEXVERSION -eq 0 ]; then
				echo ""
				echo "It appears that the mysql server is not running"
				echo "This may be the cause of the problem"
				echo ""
			fi
			echo "There is a mismatch in the versions of the installed schema"
			echo "or index and the version included in this package"
			echo "If you wish to upgrade, please correct this problem first."
			askYN "Exit now?" "Y"
			if [ $response = "yes" ]; then
				exit 1;
			fi
		fi

		while :; do
			UPGRADE="yes"
			if [ $VERSIONMATCH = "yes" ]; then
				askYN "Do you wish to upgrade?" "Y"
			else
				UPGRADE="no"
				response="no"
			fi
			if [ $response = "no" ]; then
				echo ""
				echo $INSTALLED_PACKAGES | grep zimbra-ldap > /dev/null 2>&1
				if [ $? = 0 ]; then
					echo "*** WARNING - you are about to delete all existing users and mail"
				else
					echo $INSTALLED_PACKAGES | grep zimbra-store > /dev/null 2>&1
					if [ $? = 0 ]; then
						echo "*** WARNING - you are about to delete users and mail hosted on this server"
					else
						REMOVE="yes"
						UPGRADE="no"
						break
					fi
				fi
				askYN "Delete users/mail?" "N"
				if [ $response = "yes" ]; then
					REMOVE="yes"
					UPGRADE="no"
					break
				fi
			else
				# Check for a history file - create it if it's not there
				isInstalled "zimbra-core"
				if [ ! -f "/opt/zimbra/.install_history" ]; then
					cat > /opt/zimbra/.install_history << EOF
0000000000: INSTALL SESSION START
0000000000: INSTALLED $PKGVERSION
0000000000: INSTALL SESSION COMPLETE
0000000000: CONFIG SESSION START
0000000000: CONFIGURED BEGIN
0000000000: CONFIGURED END
0000000000: CONFIG SESSION COMPLETE
EOF
				fi
				break
			fi
		done
	else 
		# REMOVE = yes for non installed systems, to clean up /opt/zimbra
		REMOVE="yes"
	fi

}

setDefaultsFromExistingConfig() {

	if [ ! -f "$SAVEDIR/config.save" ]; then
		return
	fi
	echo ""
	echo "Setting defaults from saved config in $SAVEDIR/config.save"
	source $SAVEDIR/config.save

	HOSTNAME=${zimbra_server_hostname}
	LDAPHOST=${ldap_host}
	LDAPPORT=${ldap_port}
	SNMPTRAPHOST=${snmp_trap_host:-$SNMPTRAPHOST}
	SMTPSOURCE=${smtp_source:-$SMTPSOURCE}
	SMTPDEST=${smtp_destination:-$SMTPDEST}
	SNMPNOTIFY=${snmp_notify:-0}
	SMTPNOTIFY=${smtp_notify:-0}
	LDAPROOTPW=${ldap_root_password}
	LDAPZIMBRAPW=${zimbra_ldap_password}

	echo "   HOSTNAME=${zimbra_server_hostname}"
	echo "   LDAPHOST=${ldap_host}"
	echo "   LDAPPORT=${ldap_port}"
	echo "   SNMPTRAPHOST=${snmp_trap_host}"
	echo "   SMTPSOURCE=${smtp_source}"
	echo "   SMTPDEST=${smtp_destination}"
	echo "   SNMPNOTIFY=${snmp_notify:-0}"
	echo "   SMTPNOTIFY=${smtp_notify:-0}"
	echo "   LDAPROOTPW=${ldap_root_password}"
	echo "   LDAPZIMBRAPW=${zimbra_ldap_password}"

}

restoreExistingConfig() {
	if [ -d $RESTORECONFIG ]; then
		RF="$RESTORECONFIG/config.save"
	fi
	if [ -f $RF ]; then
		echo -n "Restoring existing configuration file from $RF..."
		while read i; do
			# echo "Setting $i"
			runAsZimbra "zmlocalconfig -f -e $i"
		done < $RF
		if [ -f $RESTORECONFIG/backup.save ]; then
			echo -n "Restoring backup schedule..."
			runAsZimbra "cat $RESTORECONFIG/backup.save | xargs zmschedulebackup -R"
		fi
		echo "done"
	fi
}

restoreCerts() {
	if [ -f "$SAVEDIR/cacerts" ]; then
		cp $SAVEDIR/cacerts /opt/zimbra/java/jre/lib/security/cacerts
	fi
	if [ -f "$SAVEDIR/keystore" -a -d "/opt/zimbra/tomcat/conf" ]; then
		cp $SAVEDIR/keystore /opt/zimbra/tomcat/conf/keystore
	fi
	if [ -f "$SAVEDIR/perdition.key" ]; then
		cp $SAVEDIR/perdition.key /opt/zimbra/conf/perdition.key 
	fi
	if [ -f "$SAVEDIR/perdition.pem" ]; then
		cp $SAVEDIR/perdition.pem /opt/zimbra/conf/perdition.pem 
	fi
	if [ -f "$SAVEDIR/smtpd.key" ]; then
		cp $SAVEDIR/smtpd.key /opt/zimbra/conf/smtpd.key 
	fi
	if [ -f "$SAVEDIR/smtpd.crt" ]; then
		cp $SAVEDIR/smtpd.crt /opt/zimbra/conf/smtpd.crt 
	fi
	if [ -f "$SAVEDIR/slapd.crt" ]; then
		cp $SAVEDIR/slapd.crt /opt/zimbra/conf/slapd.crt 
	fi
	mkdir -p /opt/zimbra/conf/ca
	if [ -f "$SAVEDIR/ca.key" ]; then
		cp $SAVEDIR/ca.key /opt/zimbra/conf/ca/ca.key 
	fi
	if [ -f "$SAVEDIR/ca.pem" ]; then
		cp $SAVEDIR/ca.pem /opt/zimbra/conf/ca/ca.pem 
	fi
	chown zimbra:zimbra /opt/zimbra/java/jre/lib/security/cacerts /opt/zimbra/tomcat/conf/keystore /opt/zimbra/conf/smtpd.key /opt/zimbra/conf/smtpd.crt /opt/zimbra/conf/slapd.crt /opt/zimbra/conf/perdition.pem /opt/zimbra/conf/perdition.key
	chown -R zimbra:zimbra /opt/zimbra/conf/ca
}

saveExistingConfig() {
	echo ""
	echo "Saving existing configuration file to $SAVEDIR"
	# yes, it needs massaging to be fed back in...
	runAsZimbra "zmlocalconfig -s | sed -e \"s/ = \(.*\)/=\'\1\'/\" > $SAVEDIR/config.save"
	cp -f /opt/zimbra/java/jre/lib/security/cacerts $SAVEDIR
	if [ -f "/opt/zimbra/tomcat/conf/keystore" ]; then
		cp -f /opt/zimbra/tomcat/conf/keystore $SAVEDIR
	fi
	if [ -f "/opt/zimbra/conf/perdition.key" ]; then
		cp -f /opt/zimbra/conf/perdition.key $SAVEDIR
	fi
	if [ -f "/opt/zimbra/conf/perdition.pem" ]; then
		cp -f /opt/zimbra/conf/perdition.pem $SAVEDIR
	fi
	if [ -f "/opt/zimbra/conf/smtpd.key" ]; then
		cp -f /opt/zimbra/conf/smtpd.key $SAVEDIR
	fi
	if [ -f "/opt/zimbra/conf/smtpd.crt" ]; then
		cp -f /opt/zimbra/conf/smtpd.crt $SAVEDIR
	fi
	if [ -f "/opt/zimbra/conf/slapd.key" ]; then
		cp -f /opt/zimbra/conf/slapd.key $SAVEDIR
	fi
	if [ -f "/opt/zimbra/conf/slapd.crt" ]; then
		cp -f /opt/zimbra/conf/slapd.crt $SAVEDIR
	fi
	if [ -f "/opt/zimbra/conf/ca/ca.key" ]; then
		cp -f /opt/zimbra/conf/ca/ca.key $SAVEDIR
	fi
	if [ -f "/opt/zimbra/conf/ca/ca.pem" ]; then
		cp -f /opt/zimbra/conf/ca/ca.pem $SAVEDIR
	fi

	if [ -x /opt/zimbra/bin/zmschedulebackup ]; then
		runAsZimbra "zmschedulebackup -s > $SAVEDIR/backup.save"
	fi

	rm -f /opt/zimbra/.enable_replica
	if [ -f /opt/zimbra/conf/slapd.conf ]; then
		egrep -q '^overlay syncprov' /opt/zimbra/conf/slapd.conf > /dev/null
		if [ $? = 0 ]; then
			touch /opt/zimbra/.enable_replica
		else
			egrep -q 'type=refreshAndPersist' /opt/zimbra/conf/slapd.conf > /dev/null
			if [ $? = 0 ]; then
				touch /opt/zimbra/.enable_replica
			fi
		fi
	fi

}

removeExistingInstall() {
	if [ $INSTALLED = "yes" ]; then
		echo ""
		echo "Shutting down zimbra mail"
		shutDownSystem
		if [ -f "/opt/zimbra/bin/zmiptables" ]; then
			/opt/zimbra/bin/zmiptables -u
		fi

		isInstalled "zimbra-ldap"
		if [ x$PKGINSTALLED != "x" ]; then
			echo ""
			echo "Backing up ldap"
			echo ""
			/opt/zimbra/openldap/sbin/slapcat -f /opt/zimbra/conf/slapd.conf \
				-l /opt/zimbra/openldap-data/ldap.bak
		fi

		echo ""
		echo "Removing existing packages"
		echo ""

		for p in $INSTALLED_PACKAGES; do
			if [ $p = "zimbra-core" ]; then
				MOREPACKAGES="$MOREPACKAGES zimbra-core"
				continue
			fi
			if [ $p = "zimbra-apache" ]; then
				MOREPACKAGES="zimbra-apache $MOREPACKAGES"
				continue
			fi
			echo -n "   $p..."
			$PACKAGERM $p > /dev/null 2>&1
			echo "done"
		done

		for p in $MOREPACKAGES; do
			echo -n "   $p..."
			$PACKAGERM $p > /dev/null 2>&1
			echo "done"
		done

		rm -f /etc/ld.so.conf.d/zimbra.ld.conf
    if [ -f "/etc/sudoers" ]; then
		  cat /etc/sudoers | grep -v zimbra > /tmp/sudoers
		  cat /tmp/sudoers > /etc/sudoers
      if [ $PLATFORM = "SuSEES9" -o $PLATFORM = "SuSEES10" -o $PLATFORM = "SuSE10" ]; then
        chmod 640 /etc/sudoers
      else
        chmod 440 /etc/sudoers
      fi
		  rm -f /tmp/sudoers
    fi
		echo ""
		echo "Removing deployed webapp directories"
		/bin/rm -rf /opt/zimbra/tomcat/webapps/zimbra
		/bin/rm -rf /opt/zimbra/tomcat/webapps/zimbra.war
		/bin/rm -rf /opt/zimbra/tomcat/webapps/zimbraAdmin
		/bin/rm -rf /opt/zimbra/tomcat/webapps/zimbraAdmin.war
		/bin/rm -rf /opt/zimbra/tomcat/webapps/service
		/bin/rm -rf /opt/zimbra/tomcat/webapps/service.war
		/bin/rm -rf /opt/zimbra/tomcat/work
	fi

	if [ $REMOVE = "yes" ]; then
		echo ""
		echo "Removing /opt/zimbra"
		umount /opt/zimbra/amavisd/tmp > /dev/null 2>&1
		MOUNTPOINTS=`mount | awk '{print $3}' | grep /opt/zimbra`
		for mp in $MOUNTPOINTS; do
			if [ x$mp != "x/opt/zimbra" ]; then
				/bin/rm -rf ${mp}/*
				umount -f ${mp}
			fi
		done

		/bin/rm -rf /opt/zimbra/*

		for mp in $MOUNTPOINTS; do
			if [ x$mp != "x/opt/zimbra" ]; then
				mkdir -p ${mp}
				mount ${mp}
			fi
		done

	else
		if [ -d /opt/zimbra/openldap/var/openldap-data/ ]; then
			if [ -d /opt/zimbra/openldap-data/ ]; then
				mv -f /opt/zimbra/openldap-data/ /opt/zimbra/openldap-data.BAK
			fi
			mv -f /opt/zimbra/openldap/var/openldap-data/ /opt/zimbra/openldap-data/
		fi
	fi
}

setServiceIP() {
	askNonBlank "Please enter the service IP for this host" "$SERVICEIP"
	SERVICEIP=$response
}

setHostName() {

	OLD=$HOSTNAME
	while :; do
		askNonBlank "Please enter the logical hostname for this host" "$HOSTNAME"

		fq=`isFQDN $response`

		if [ $fq = 1 ]; then
			HOSTNAME=$response
			break
		else
			echo ""
			echo "Please enter a fully qualified hostname"
		fi
	done
	if [ "x$OLD" != "x$HOSTNAME" ]; then
		if [ "x$SMTPHOST" = "x$OLD" ]; then
			SMTPHOST=$HOSTNAME
		fi
		if [ "x$SNMPTRAPHOST" = "x$OLD" ]; then
			SNMPTRAPHOST=$HOSTNAME
		fi
		if [ "x$CREATEDOMAIN" = "x$OLD" ]; then
			CREATEDOMAIN=$HOSTNAME
		fi
	fi
}

checkConflicts() {
	echo ""
	echo "Checking for sendmail/postfix"
	echo ""

	if [ -f /var/lock/subsys/postfix ]; then
		askYN "Postfix appears to be running.  Shut it down?" "Y"
		if [ $response = "yes" ]; then
			/etc/init.d/postfix stop
			chkconfig postfix off
		fi
	fi

	if [ -f /var/lock/subsys/sendmail ]; then
		askYN "Sendmail appears to be running.  Shut it down?" "Y"
		if [ $response = "yes" ]; then
			/etc/init.d/sendmail stop
			chkconfig sendmail off
		fi
	fi

	echo ""
	echo "Checking for mysqld"
	echo ""

	if [ -f /var/lock/subsys/mysqld ]; then
		while :; do
			askYN "Mysql appears to be running.  Shut it down?" "Y"
			if [ $response = "yes" ]; then
				/etc/init.d/mysqld stop
				chkconfig mysqld off
				break
			else
				echo "Installation will probably fail with mysql running"
				askYN "Install anyway?" "N"
				if [ $response = "yes" ]; then
					break
				else
					askYN "Exit?" "N"
					if [ $response = "yes" ]; then
						echo "Exiting - the system is unchanged"
						exit 1
					fi
				fi
			fi
		done
	fi
}

cleanUp() {
	# Dump all the config data to a file
	runAsZimbra "zmlocalconfig -s > .localconfig.save.$$"
	runAsZimbra "zmprov gs $HOSTNAME > .zmprov.$HOSTNAME.save.$$"
	runAsZimbra "zmprov gacf $HOSTNAME > .zmprov.gacf.save.$$"
}

verifyLdapServer() {

	if [ $LDAP_HERE = "yes" ]; then
		LDAPOK="yes"
		return
	fi

	echo ""
	echo -n  "Contacting ldap server $LDAPHOST on $LDAPPORT..."

	$MYLDAPSEARCH -x -h $LDAPHOST -p $LDAPPORT -w $LDAPZIMBRAPW -D "uid=zimbra,cn=admins,cn=zimbra" > /dev/null 2>&1
	LDAPRESULT=$?

	if [ $LDAPRESULT != 0 ]; then
		echo "FAILED"
		LDAPOK="no"
	else
		echo "Success"
		LDAPOK="yes"
	fi
}

getInstallPackages() {
	
	echo ""
	echo "Select the packages to install"
	if [ $UPGRADE = "yes" ]; then
		echo "    Upgrading zimbra-core"
	fi

	APACHE_SELECTED="no"

	for i in $AVAILABLE_PACKAGES; do
		# If we're upgrading, and it's installed, don't ask stoopid questions
		if [ $UPGRADE = "yes" ]; then
			echo $INSTALLED_PACKAGES | grep $i > /dev/null 2>&1
			if [ $? = 0 ]; then
				echo "    Upgrading $i"
				if [ $i = "zimbra-core" ]; then
					continue
				fi
				INSTALL_PACKAGES="$INSTALL_PACKAGES $i"
				if [ $i = "zimbra-apache" ]; then
					APACHE_SELECTED="yes"
				fi
				continue
			fi
		fi

		if [ $i = "zimbra-apache" ]; then
			continue
		fi

		askYN "Install $i" "Y"
		if [ $response = "yes" ]; then
			if [ $i = "zimbra-spell" -a $APACHE_SELECTED = "no" ]; then
				APACHE_SELECTED="yes"
				INSTALL_PACKAGES="$INSTALL_PACKAGES zimbra-apache"
			fi
			INSTALL_PACKAGES="$INSTALL_PACKAGES $i"
		fi

	done

	echo ""
	echo "Installing:"
	for i in $INSTALL_PACKAGES; do
		echo "    $i"
	done
}

setInstallPackages() {
	for i in $OPTIONAL_PACKAGES; do
		isInstalled $i
		if [ x$PKGINSTALLED != "x" ]; then
			INSTALL_PACKAGES="$INSTALL_PACKAGES $i"
		fi
	done
	for i in $PACKAGES $CORE_PACKAGES; do
		isInstalled $i
		if [ x$PKGINSTALLED != "x" ]; then
			INSTALL_PACKAGES="$INSTALL_PACKAGES $i"
		fi
	done
}

setHereFlags() {

	setInstallPackages

	LDAP_HERE="no"
	POSTFIX_HERE="no"
	STORE_HERE="no"
	SNMP_HERE="no"
	LOGGER_HERE="no"

	for i in $INSTALL_PACKAGES; do
		if [ $i = "zimbra-store" ]; then
			STORE_HERE="yes"
		fi
		if [ $i = "zimbra-mta" ]; then
			POSTFIX_HERE="yes"
			# Don't change it if we read in a value from an existing config.
			if [ "x$RUNAV" = "x" ]; then
				RUNAV="yes"
			fi
			if [ "x$RUNSA" = "x" ]; then
				RUNSA="yes"
			fi
		fi
		if [ $i = "zimbra-ldap" ]; then
			LDAP_HERE="yes"
		fi
		if [ $i = "zimbra-snmp" ]; then
			SNMP_HERE="yes"
		fi
		if [ $i = "zimbra-logger" ]; then
			LOGGER_HERE="yes"
		fi
	done
}

startServers() {
	echo -n "Starting servers..."
	runAsZimbra "zmcontrol startup"
	su - zimbra -c "zmcontrol status"
	echo "done"
}

verifyExecute() {
	while :; do
		askYN "The system will be modified.  Continue?" "N"

		if [ $response = "no" ]; then
			askYN "Exit?" "N"
			if [ $response = "yes" ]; then
				echo "Exiting - the system is unchanged"
				exit 1
			fi
		else
			break
		fi
	done
}

setupCrontab() {
	crontab -u zimbra -l > /tmp/crontab.zimbra.orig
	grep ZIMBRASTART /tmp/crontab.zimbra.orig > /dev/null 2>&1
	if [ $? != 0 ]; then
		cat /dev/null > /tmp/crontab.zimbra.orig
	fi
	grep ZIMBRAEND /tmp/crontab.zimbra.orig > /dev/null 2>&1
	if [ $? != 0 ]; then
		cat /dev/null > /tmp/crontab.zimbra.orig
	fi
	cat /tmp/crontab.zimbra.orig | sed -e '/# ZIMBRASTART/,/# ZIMBRAEND/d' > \
		/tmp/crontab.zimbra.proc
	cp -f /opt/zimbra/zimbramon/crontabs/crontab /tmp/crontab.zimbra

	isInstalled zimbra-store
	if [ x$PKGINSTALLED != "x" ]; then
		cat /opt/zimbra/zimbramon/crontabs/crontab.store >> /tmp/crontab.zimbra
	fi

	isInstalled zimbra-logger
	if [ x$PKGINSTALLED != "x" ]; then
		cat /opt/zimbra/zimbramon/crontabs/crontab.logger >> /tmp/crontab.zimbra
	fi

	echo "# ZIMBRAEND -- DO NOT EDIT ANYTHING BETWEEN THIS LINE AND ZIMBRASTART" >> /tmp/crontab.zimbra
	cat /tmp/crontab.zimbra.proc >> /tmp/crontab.zimbra

	crontab -u zimbra /tmp/crontab.zimbra
}

isInstalled () {
	pkg=$1
	PKGINSTALLED=""
	if [ $PACKAGEEXT = "rpm" ]; then
		$PACKAGEQUERY $pkg >/dev/null 2>&1
		if [ $? = 0 ]; then
			PKGVERSION=`$PACKAGEQUERY $pkg 2> /dev/null | sort -u`
			PKGINSTALLED=`$PACKAGEQUERY $pkg | sed -e 's/\.[a-zA-Z].*$//' 2> /dev/null`
		fi
        elif [ $PACKAGEEXT = "ccs" ]; then
		$PACKAGEQUERY $pkg >/dev/null 2>&1
		if [ $? = 0 ]; then
			PKGVERSION=`$PACKAGEQUERY $pkg 2> /dev/null | sort -u`
			PKGINSTALLED=`$PACKAGEQUERY $pkg | sed -e 's/\.[a-zA-Z].*$//' 2> /dev/null`
		fi
	else
		Q=`$PACKAGEQUERY $pkg 2>/dev/null | egrep '^Status: ' `
		if [ "x$Q" != "x" ]; then
			echo $Q | grep 'not-installed' > /dev/null 2>&1
			if [ $? != 0 ]; then
				version=`$PACKAGEQUERY $pkg | egrep '^Version: ' | sed -e 's/Version: //' 2> /dev/null`
				PKGINSTALLED="${pkg}-${version}"
			fi
		fi
	fi
}

getPlatformVars() {
	PLATFORM=`bin/get_plat_tag.sh`
	if [ $PLATFORM = "DEBIAN3.1" -o $PLATFORM = "UBUNTU6" ]; then
		PACKAGEINST='dpkg -i'
		PACKAGERM='dpkg --purge'
		PACKAGEQUERY='dpkg -s'
		PACKAGEEXT='deb'
		PREREQ_PACKAGES="sudo libidn11 curl fetchmail libgmp3 libxml2 libstdc++6 openssl"
		if [ $PLATFORM = "UBUNTU6" ]; then
			PREREQ_PACKAGES="sudo libidn11 curl fetchmail libpcre3 libgmp3c2 libxml2 libstdc++6 openssl"
		fi
	elif echo $PLATFORM | grep RPL > /dev/null 2>&1; then
		PACKAGEINST='conary update'
		PACKAGERM='conary erase'
		PACKAGEQUERY='conary q'
		PACKAGEEXT='ccs'
		PREREQ_PACKAGES="sudo libidn curl fetchmail gmp libxml2 libstdc++ openssl"
	else
		PACKAGEINST='rpm -iv'
		PACKAGERM='rpm -ev --nodeps --noscripts --allmatches'
		PACKAGEQUERY='rpm -q'
		PACKAGEEXT='rpm'
		if [ $PLATFORM = "RHEL4" ]; then
			PREREQ_PACKAGES="sudo libidn curl fetchmail gmp compat-libstdc++-296 compat-libstdc++-33"
			PREREQ_LIBS="/usr/lib/libstdc++.so.5"
		elif [ $PLATFORM = "MANDRIVA2006" ]; then
			PREREQ_PACKAGES="sudo libidn11 curl fetchmail libgmp3 libxml2 libstdc++6 openssl"
		else
			PREREQ_PACKAGES="sudo libidn curl fetchmail gmp"
			if [ $PLATFORM = "FC3" -o $PLATFORM = "FC4" ]; then
				if [ $PLATFORM = "FC3" ]; then
					PREREQ_PACKAGES="sudo libidn curl fetchmail gmp bind-libs"
				fi
				PREREQ_LIBS="/usr/lib/libstdc++.so.5"
			fi
		fi
	fi
}
