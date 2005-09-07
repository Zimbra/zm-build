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

CORE_PACKAGES="zimbra-core"

PACKAGES="zimbra-ldap \
zimbra-mta \
zimbra-snmp \
zimbra-store"

SERVICES=""

PREREQ_PACKAGES="libidn curl fetchmail"

OPTIONAL_PACKAGES="zimbra-qatest"

LEGACY_PACKAGES="liquid-snmp liquid-ldap liquid-mta liquid-store liquid-core"

PACKAGE_DIR=`dirname $0`/packages

LOGFILE="/tmp/install.log.$$"
SAVEDIR="/tmp/saveconfig.$$"

if [ x$RESTORECONFIG = "x" ]; then
	RESTORECONFIG=$SAVEDIR
fi

mkdir -p $SAVEDIR
chmod 777 $SAVEDIR

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

#
# Initial values
#

AUTOINSTALL="no"
INSTALLED="no"
INSTALLED_PACKAGES=""
REMOVE="no"
UPGRADE="no"
HOSTNAME=`hostname --fqdn`
LDAPHOST=""
LDAPPORT=389
fq=`isFQDN $HOSTNAME`

if [ $fq = 0 ]; then
	HOSTNAME=""
fi

SERVICEIP=`hostname -i`

SMTPHOST=$HOSTNAME
SNMPTRAPHOST=$HOSTNAME
SMTPSOURCE="none"
SMTPDEST="none"
SNMPNOTIFY="0"
SMTPNOTIFY="0"
INSTALL_PACKAGES="zimbra-core"
STARTSERVERS="yes"
LDAPROOTPW=""
LDAPZIMBRAPW=""
CREATEDOMAIN=$HOSTNAME
CREATEADMIN="admin@${CREATEDOMAIN}"
CREATEADMINPASS=""
MODE="http"
ALLOWSELFSIGNED="yes"
RUNAV=""
RUNSA=""
AVUSER=""
AVDOMAIN=""

echo ""
echo "Operations logged to $LOGFILE"

# All ask functions take 2 args:
#	Prompt
#	Default (optional)

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
	if [ x`whoami` != xroot ]; then
		echo Error: must be run as root user
		exit 1
	fi
}

checkRequired() {
	GOOD="yes"
	echo "Checking for prerequisites..."
	for i in $PREREQ_PACKAGES; do
		echo -n "    $i..."
		rpm -q $i >/dev/null 2>&1
		if [ $? = 0 ]; then
			version=`rpm -q $i 2> /dev/null`
			echo "FOUND $version"
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
		rpm -q $i >/dev/null 2>&1
		if [ $? = 0 ]; then
			echo -n "    $i..."
			version=`rpm -q $i 2> /dev/null`
			echo "FOUND $version"
			INSTALLED="yes"
			INSTALLED_PACKAGES="$INSTALLED_PACKAGES $i"
		fi
	done
	for i in $PACKAGES $CORE_PACKAGES; do
		echo -n "    $i..."
		rpm -q $i >/dev/null 2>&1
		if [ $? != 0 ]; then
			echo "not found"
		else
			version=`rpm -q $i 2> /dev/null`
			echo "FOUND $version"
			INSTALLED="yes"
			INSTALLED_PACKAGES="$INSTALLED_PACKAGES $i"
		fi
	done
	if [ $INSTALLED = "yes" ]; then
		saveExistingConfig
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
				break
			fi
		done
	else 
		# REMOVE = yes for non installed systems, to clean up /opt/zimbra
		REMOVE="yes"
	fi

}

setDefaultsFromExistingConfig() {

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
	echo -n "Restoring existing configuration file from $RF..."
	while read i; do
		# echo "Setting $i"
		runAsZimbra "zmlocalconfig -f -e $i"
	done < $RF
	if [ -f $SAVEDIR/backup.save ]; then
		runAsZimbra "cat $RESTORECONFIG/backup.save | xargs zmschedulebackup -R"
	fi
	echo "done"
}

restoreCerts() {
	cp $SAVEDIR/cacerts /opt/zimbra/java/jre/lib/security/cacerts
	cp $SAVEDIR/keystore /opt/zimbra/tomcat/conf/keystore
	cp $SAVEDIR/smtpd.key /opt/zimbra/conf/smtpd.key 
	cp $SAVEDIR/smtpd.crt /opt/zimbra/conf/smtpd.crt 
	chown zimbra:zimbra /opt/zimbra/java/jre/lib/security/cacerts /opt/zimbra/tomcat/conf/keystore /opt/zimbra/conf/smtpd.key /opt/zimbra/conf/smtpd.crt
}

saveExistingConfig() {
	echo ""
	echo "Saving existing configuration file to $SAVEDIR"
	# yes, it needs massaging to be fed back in...
	runAsZimbra "zmlocalconfig -s | sed -e \"s/ = \(.*\)/=\'\1\'/\" > $SAVEDIR/config.save"
	cp /opt/zimbra/java/jre/lib/security/cacerts $SAVEDIR
	cp /opt/zimbra/tomcat/conf/keystore $SAVEDIR
	cp /opt/zimbra/conf/smtpd.key $SAVEDIR
	cp /opt/zimbra/conf/smtpd.crt $SAVEDIR
	if [ -x /opt/zimbra/bin/zmschedulebackup ]; then
		runAsZimbra "zmschedulebackup -s > $SAVEDIR/backup.save"
	fi
}

removeExistingInstall() {
	if [ $INSTALLED = "yes" ]; then
		echo ""
		echo "Shutting down zimbra mail"
		shutDownSystem

		echo ""
		echo "Removing legacy packages"
		echo ""

		if [ -f /opt/liquid/liquidmon/lqcontrol ]; then
			su - liquid -c "lqcontrol shutdown"
		fi
		for i in $LEGACY_PACKAGES; do
				rpm -q $i >/dev/null 2>&1
				if [ $? = 0 ]; then
					echo -n "   $i..."
					rpm -ev --noscripts --allmatches $i
					echo "done"
				fi
		done		    

		echo ""
		echo "Removing existing packages"
		echo ""

		for p in $INSTALLED_PACKAGES; do
			echo -n "   $p..."
			rpm -ev --noscripts --allmatches $p
			echo "done"
		done

		rm -f /etc/ld.so.conf.d/zimbra.ld.conf

		cat /etc/sudoers | grep -v postfix | grep -v Cmnd_Alias > /tmp/sudoers
		cat /tmp/sudoers > /etc/sudoers
		rm -f /tmp/sudoers
		echo ""
		echo "Removing deployed webapp directories"
		/bin/rm -rf /opt/zimbra/tomcat/webapps/zimbra
		/bin/rm -rf /opt/zimbra/tomcat/webapps/zimbra.war
		/bin/rm -rf /opt/zimbra/tomcat/webapps/zimbraAdmin
		/bin/rm -rf /opt/zimbra/tomcat/webapps/zimbraAdmin.war
		/bin/rm -rf /opt/zimbra/tomcat/webapps/service
		/bin/rm -rf /opt/zimbra/tomcat/webapps/service.war
	fi

	if [ $REMOVE = "yes" ]; then
		echo ""
		echo "Removing /opt/zimbra"
		umount /opt/zimbra/amavisd/tmp > /dev/null 2>&1
		/bin/rm -rf /opt/zimbra/*

		echo ""
		echo "Removing users/groups"
		echo ""
		userdel zimbra > /dev/null 2>&1
		userdel postfix > /dev/null 2>&1
		groupdel postdrop > /dev/null 2>&1
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
}

installPackage() {
	PKG=$1
	echo -n "    $PKG..."
	# file=`ls $PACKAGE_DIR/$i*.rpm`
	findLatestPackage $PKG
	f=`basename $file`
	echo -n "...$f..."
	rpm -iv $file >> $LOGFILE 2>&1
	if [ $? = 0 ]; then
		echo "done"
	else
		echo -n "FAILED"
		echo ""
		echo "###ERROR###"
		echo ""
		echo "$f installation failed"
		echo ""
		echo "Installation cancelled"
		echo ""
		exit 1
	fi
}

findLatestPackage() {
	package=$1

	latest=""
	himajor=0
	himinor=0
	histamp=0

	files=`ls $PACKAGE_DIR/$package*.rpm 2> /dev/null`
	for q in $files; do
		# zimbra-core-2.0_RHEL4-20050622123009_HEAD.i386.rpm

		f=`basename $q`
		id=`echo $f | awk -F- '{print $3}'`
		version=`echo $id | awk -F_ '{print $1}'`
		major=`echo $version | awk -F. '{print $1}'`
		minor=`echo $version | awk -F. '{print $2}'`
		micro=`echo $version | awk -F. '{print $3}'`
		stamp=`echo $f | awk -F_ '{print $2}' | awk -F. '{print $1}'`

		if [ $major -gt $himajor ]; then
			himajor=$major
			himinor=$minor
			histamp=$stamp
			latest=$q
			continue
		fi
		if [ $minor -gt $himinor ]; then
			himajor=$major
			himinor=$minor
			histamp=$stamp
			latest=$q
			continue
		fi
		if [ $stamp -gt $histamp ]; then
			himajor=$major
			himinor=$minor
			histamp=$stamp
			latest=$q
			continue
		fi
	done

	file=$latest
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

checkPackages() {
	echo ""
	echo "Checking for installable packages"
	echo ""

	for i in $CORE_PACKAGES; do
		findLatestPackage $i
		if [ ! -f "$file" ]; then
			echo "ERROR: Required Core package $i not found in $PACKAGE_DIR"
			echo "Exiting"
			exit 1
		else
			echo "Found $i"
		fi
	done

	AVAILABLE_PACKAGES=""

	for i in $PACKAGES $OPTIONAL_PACKAGES; do
		findLatestPackage $i
		if [ -f "$file" ]; then
			echo "Found $i"
			AVAILABLE_PACKAGES="$AVAILABLE_PACKAGES $i"
		fi
	done

	echo ""
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

getConfigOptions() {
	echo ""
	echo "Configuration section"
	if [ $STORE_HERE = "yes" -a $POSTFIX_HERE = "no" ]; then
		askNonBlank "Please enter the hostname for zimbraSmtpHostname" \
			"$SMTPHOST"
		SMTPHOST=$response
	fi
	if [ $STORE_HERE = "yes" ]; then
		while :; do
			askNonBlank "Enter web server mode (http, https, mixed)" "$MODE"
			MODE=$response
			if [ $MODE = "http" -o $MODE = "https" -o $MODE = "mixed" ]; then
				break
			else
				echo "Please enter a valid mode"
			fi
		done
		if [ $ALLOWSELFSIGNED = "true" -o $ALLOWSELFSIGNED = "yes" ]; then
			ALLOWSELFSIGNED="yes"
		else
			ALLOWSELFSIGNED="no"
		fi
		# Hardcoding for bootstrap install. 20050725 MEM
		ALLOWSELFSIGNED="true"
#		askYN "Allow self-signed certificates?" $ALLOWSELFSIGNED
#		if [ $response = "yes" ]; then
#			ALLOWSELFSIGNED="true"
#		else
#			ALLOWSELFSIGNED="false"
#		fi
	fi

	if [ $LDAP_HERE = "yes" ]; then
		LDAPHOST=$HOSTNAME
		LDAPPORT=389
	else
		while :; do

			askNonBlank "Please enter the hostname for the ldap server" "$LDAPHOST"
			LDAPHOST=$response
			askInt "Please enter the port for the ldap server" "$LDAPPORT"
			LDAPPORT=$response

			if [ $LDAP_HERE = "no" -a $UPGRADE = "no" ]; then
				askNonBlank "Enter the root ldap password for $LDAPHOST:" \
					"$LDAPROOTPW"
				LDAPROOTPW=$response
				askNonBlank "Enter the zimbra ldap password for $LDAPHOST:" \
					"$LDAPZIMBRAPW"
				LDAPZIMBRAPW=$response
			fi

			verifyLdapServer
			
			if [ $LDAPOK = "yes" ]; then
				break
			fi
		done

	fi

	if [ $UPGRADE = "no" ]; then

		if [ $POSTFIX_HERE = "yes" ]; then
			askYN "Enable Clam Anti-virus services?" "$RUNAV"
			RUNAV=$response
			if [ $RUNAV = "yes" ]; then
				if [ "x$AVUSER" = "x" ]; then
					AVUSER="notify@${HOSTNAME}"
				fi
				askNonBlank "Notification address for AV alerts?" "$AVUSER"
				AVUSER=$response
				AVDOMAIN=`echo $AVUSER | awk -F@ '{print $2}'`
			fi
			askYN "Enable SpamAssassin anti-spam services?" "$RUNSA"
			RUNSA=$response
		fi

		if [ $SNMP_HERE = "yes" ]; then
			askYN "Notify via SNMP?" "$SNMPNOTIFY"
			SNMPNOTIFY=$response
			if [ $SNMPNOTIFY = "yes" ]; then
				askNonBlank "SNMP Trap host?" "$SNMPTRAPHOST"
				SNMPTRAPHOST=$response
				SNMPNOTIFY=1
			else
				SNMPNOTIFY=0
			fi
			askYN "Notify via SMTP?" "$SMTPNOTIFY"
			SMTPNOTIFY=$response
			if [ $SMTPNOTIFY = "yes" ]; then
				askNonBlank "SMTP Source email address?" "$SMTPSOURCE"
				SMTPSOURCE=$response
				askNonBlank "SMTP Destination email address?" "$SMTPDEST"
				SMTPDEST=$response
				SMTPNOTIFY=1
			else
				SMTPNOTIFY=0
			fi
		fi

		askYN "Create a domain?" "Y"
		if [ $response = "yes" ]; then
			askNonBlank "Enter domain to create:" "$CREATEDOMAIN"
			CREATEDOMAIN=$response
			while :; do
				askYN "Create an admin account?" "Y"
				if [ $response = "yes" ]; then
					CREATEADMIN="admin@${CREATEDOMAIN}"
					askNonBlank "Enter admin account to create:" "$CREATEADMIN"
					CREATEADMIN=$response
					while :; do
						askNonBlankNoEcho "Enter admin password (min 6 chars):" ""
						len=`echo $response | wc -m`
						# Not sure why, but wc -m reports one too many
						if [ $len -gt 6 ]; then
							CREATEADMINPASS=$response
							askNonBlankNoEcho "Re-enter admin password (min 6 chars):" ""
							if [ $CREATEADMINPASS = $response ]; then
								break
							else
								echo "Passwords do not match!"
							fi
						else
							echo "Please enter a password 6 characters or longer"
						fi
					done
					admindomain=`echo $CREATEADMIN | awk -F@ '{print $2}'`
					if [ x$admindomain = x$CREATEDOMAIN ]; then
						break
					else
						echo "You must create an admin account under the domain $CREATEDOMAIN"
					fi
				else
					break
				fi
			done
		else
			CREATEDOMAIN=""
			CREATEADMIN=""
			CREATEADMINPASS=""
		fi
	fi

}

getInstallPackages() {
	
	echo ""
	echo "Select the packages to install"
	if [ $UPGRADE = "yes" ]; then
		echo "    Upgrading zimbra-core"
	fi

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
				continue
			fi
		fi

		askYN "Install $i" "Y"
		if [ $response = "yes" ]; then
			INSTALL_PACKAGES="$INSTALL_PACKAGES $i"
		fi
	done

	echo ""
	echo "Installing:"
	for i in $INSTALL_PACKAGES; do
		echo "    $i"
	done
}

setHereFlags() {
	LDAP_HERE="no"
	POSTFIX_HERE="no"
	STORE_HERE="no"
	SNMP_HERE="no"

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
	done
}

startServers() {
	echo -n "Starting servers..."
	runAsZimbra "zmcontrol startup"
	su - zimbra -c "zmcontrol status"
	echo "done"
}

postInstallConfig() {
	echo ""
	echo "Post installation configuration"
	echo ""

	chmod 755 /opt/zimbra

	if [ $UPGRADE = "yes" ]; then
		#restore old config, then overwrite...
		restoreExistingConfig
	fi

	if [ $UPGRADE = "no" -a $STORE_HERE = "yes" ]; then
		echo -n "Creating db..."
		runAsZimbra "/opt/zimbra/libexec/zmmyinit"
		echo "done"
	fi

	echo -n "Setting the hostname to $HOSTNAME..."
	runAsZimbra "zmlocalconfig -e zimbra_server_hostname=${HOSTNAME}"
	echo "done"

	echo -n "Setting the LDAP host to $LDAPHOST..."
	runAsZimbra "zmlocalconfig -e ldap_host=$LDAPHOST"
	runAsZimbra "zmlocalconfig -e ldap_port=$LDAPPORT"
	echo "done"

	SERVERCREATED="no"
	if [ $UPGRADE = "no" ]; then
		if [ $LDAP_HERE = "yes" ]; then
			echo -n "Initializing ldap..."
			runAsZimbra "/opt/zimbra/libexec/zmldapinit"
			echo "done"
		else
			# set the ldap password in localconfig only
			echo -n "Setting the ldap passwords..."
			runAsZimbra "zmlocalconfig -f -e ldap_root_password=$LDAPROOTPW"
			runAsZimbra "zmlocalconfig -f -e zimbra_ldap_password=$LDAPZIMBRAPW"
			echo "done"
		fi

		echo -n "Creating server $HOSTNAME..."
		runAsZimbra "zmprov cs $HOSTNAME"
		if [ $? = 0 ]; then
			SERVERCREATED="yes"
		fi
		echo "done"

		if [ x$CREATEDOMAIN != "x" ]; then
			echo -n "Creating domain $CREATEDOMAIN..."
			runAsZimbra "zmprov cd $CREATEDOMAIN"
			runAsZimbra "zmprov mcf zimbraDefaultDomainName $CREATEDOMAIN"
			echo "done"
			if [ x$CREATEADMIN != "x" ]; then
				echo -n "Creating admin account $CREATEADMIN..."
				runAsZimbra "zmprov ca $CREATEADMIN $CREATEADMINPASS zimbraIsAdminAccount TRUE"
				LOCALHOSTNAME=`hostname --fqdn`
				if [ $LOCALHOSTNAME = $CREATEDOMAIN ]; then
					runAsZimbra "zmprov aaa $CREATEADMIN postmaster@$HOSTNAME"
				fi
				echo "done"
			fi
		fi
	else
		if [ $LDAP_HERE = "yes" ]; then
			echo -n "Starting ldap..."
			runAsZimbra "ldap start"
			runAsZimbra "zmldapapplyldif"
			echo "done"
		fi
	fi

	if [ $LDAP_HERE = "yes" ]; then
		SERVICES="zimbraServiceInstalled ldap"
	fi

	if [ $STORE_HERE = "yes" ]; then
		if [ $SERVERCREATED = "yes" ]; then
			echo -n "Setting smtp host to $SMTPHOST..."
			runAsZimbra "zmprov ms $HOSTNAME zimbraSmtpHostname $SMTPHOST"
			echo "done"
		fi

		echo -n "Adding $HOSTNAME to zimbraMailHostPool in default COS..."
		runAsZimbra "id=\`zmprov gs $HOSTNAME | grep zimbraId | awk '{print \$2}'\`; for i in \`zmprov gc default | grep zimbraMailHostPool | sed 's/zimbraMailHostPool: //'\`; do host=\"\$host zimbraMailHostPool \$i\"; done; zmprov mc default \$host zimbraMailHostPool \$id"
		echo "done"

		SERVICES="$SERVICES zimbraServiceInstalled mailbox"
	fi

	if [ $POSTFIX_HERE = "yes" ]; then
		echo -n "Initializing mta config..."
		runAsZimbra "/opt/zimbra/libexec/zmmtainit $LDAPHOST"
		echo "done"

		# zmprov isn't very friendly

		SERVICES="$SERVICES zimbraServiceInstalled mta"

		if [ $RUNAV = "yes" ]; then
			SERVICES="$SERVICES zimbraServiceInstalled antivirus"
			runAsZimbra "zmlocalconfig -e av_notify_user=$AVUSER"
			runAsZimbra "zmlocalconfig -e av_notify_domain=$AVDOMAIN"
		fi
		if [ $RUNSA = "yes" ]; then
			SERVICES="$SERVICES zimbraServiceInstalled antispam"
		fi
	fi

	if [ $SNMP_HERE = "yes" ]; then
		echo -n "Configuring SNMP..."
		runAsZimbra "zmlocalconfig -e snmp_notify=$SNMPNOTIFY"
		runAsZimbra "zmlocalconfig -e smtp_notify=$SMTPNOTIFY"
		runAsZimbra \
			"zmlocalconfig -e snmp_trap_host=$SNMPTRAPHOST"
		runAsZimbra "zmlocalconfig -e smtp_source=$SMTPSOURCE"
		runAsZimbra \
			"zmlocalconfig -e smtp_destination=$SMTPDEST"
		runAsZimbra "zmsnmpinit"
		echo "done"
		SERVICES="$SERVICES zimbraServiceInstalled snmp"
	fi

	echo -n "Setting services on $HOSTNAME..."
	runAsZimbra "zmprov ms $HOSTNAME $SERVICES"
	if [ $UPGRADE = "no" ]; then
		ENABLEDSERVICES=`echo $SERVICES | sed -e 's/zimbraServiceInstalled/zimbraServiceEnabled/g'`
		runAsZimbra "zmprov ms $HOSTNAME $ENABLEDSERVICES"
	fi
	LOCALSERVICES=`echo $SERVICES | sed -e 's/zimbraServiceInstalled //g'`
	runAsZimbra "zmlocalconfig -e zimbra_services=\"$LOCALSERVICES\""
	echo "done"

	if [ $STORE_HERE = "yes" -o $POSTFIX_HERE = "yes" ]; then
		echo -n "Setting up SSL..."
		runAsZimbra "zmcreatecert"
		if [ $STORE_HERE = "yes" ]; then
			runAsZimbra "zmcertinstall mailbox"
			runAsZimbra "zmtlsctl $MODE"
		fi
		if [ $POSTFIX_HERE = "yes" ]; then
			runAsZimbra "zmcertinstall mta /opt/zimbra/ssl/ssl/server/smtpd.crt /opt/zimbra/ssl/ssl/ca/ca.key"
		fi

		runAsZimbra "zmlocalconfig -e ssl_allow_untrusted_certs=$ALLOWSELFSIGNED"
		echo "done"
		if [ $UPGRADE = "yes" ]; then
			restoreCerts
		fi
	fi

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

cleanUp

echo ""
echo "Installation complete!"
echo ""
echo "Operations logged to $LOGFILE"
echo ""

exit 0
