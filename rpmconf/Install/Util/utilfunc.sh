#!/bin/bash
#
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016 Synacor, Inc.
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

displayLicense() {
  echo ""
  echo ""
  if [ -f ${MYDIR}/docs/zcl.txt ]; then
    cat $MYDIR/docs/zcl.txt
  elif [ -f ${MYDIR}/docs/zimbra_network_eula.txt ]; then
    cat ${MYDIR}/docs/zimbra_network_eula.txt
  fi
  echo ""
  echo ""
  if [ x$DEFAULTFILE = "x" ]; then
    askYN "Do you agree with the terms of the software license agreement?" "N"
    if [ $response != "yes" ]; then
      exit
    fi
  fi
  echo ""
}

displayThirdPartyLicenses() {
  echo ""
  echo ""
  if [ -f ${MYDIR}/docs/keyview_eula.txt ]; then
    cat $MYDIR/docs/keyview_eula.txt
    echo ""
    echo ""
    if [ x$DEFAULTFILE = "x" ]; then
      askYN "Do you agree with the terms of the software license agreement?" "N"
      if [ $response != "yes" ]; then
        exit
      fi
    fi
    echo ""
    echo ""
  fi
  #if [ -f ${MYDIR}/docs/oracle_jdk_eula.txt ]; then
  #  cat $MYDIR/docs/oracle_jdk_eula.txt
  #  echo ""
  #  echo ""
  #  if [ x$DEFAULTFILE = "x" ]; then
  #    askYN "Do you agree with the terms of the software license agreement?" "N"
  #    if [ $response != "yes" ]; then
  #      exit
  #    fi
  #  fi
  #fi
  #echo ""
}

isFQDN() {
  #fqdn is > 2 dots.  because I said so.
  if [ x"$1" = "x" ]; then
    echo 0
    return
  fi

  NF=`echo $1 | awk -F. '{print NF}'`
  if [ $NF -ge 2 ]; then
    echo 1
  else
    echo 0
  fi
}

verifyIPv6() {
    IP=$1
    BAD_IP=`echo $IP | awk -F: '{ RES=0; SHORT=0; LSHORT=0; if (NF > 8) { RES=1 } else { for (BLK = 1; BLK <= NF; BLK++) { if ($BLK !~ /^[0-9a-fA-F]$|^[0-9a-fA-F][0-9a-fA-F]$|^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$|^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$/) { if ($BLK == "") { if (SHORT > 0) { if ((BLK - LSHORT) != 1) { RES = 1 } } SHORT++; LSHORT = BLK } else { RES = 1 } } } } if ((NF == 3) && ($2 != "")) { RES = 1 } if (((SHORT > 2) && (NF != 3)) || ((SHORT == 2) && (!(($2 == "") || ($(NF-1) == ""))))) { RES = 1 } if ((NF - SHORT) > 6 ) { RES = 1 } if ((SHORT == 0) && (NF < 8)) { RES = 1 } print RES }'`
    return ${BAD_IP}
}

verifyMixedIPv6() {
    IP=$1
    BAD_IP=`echo $IP | awk -F: '{ RES=0; SHORT=0; LSHORT=0; if (NF > 8) { RES=1 } else { for (BLK = 1; BLK <= NF; BLK++) { if ($BLK !~ /^[0-9a-fA-F]$|^[0-9a-fA-F][0-9a-fA-F]$|^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$|^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$/) { if ($BLK == "") { if (SHORT > 0) { if ((BLK - LSHORT) != 1) { RES = 1 } } SHORT++; LSHORT = BLK } else { RES = 1 } } } } if ((NF == 3) && ($2 != "")) { RES = 1 } if (((SHORT > 2) && (NF != 3)) || ((SHORT == 2) && (!(($2 == "") || ($(NF-1) == ""))))) { RES = 1 } if ((NF - SHORT) > 6 ) { RES = 1 } if ((SHORT == 0) && (NF < 6)) { RES = 1 } print RES }'`
    return ${BAD_IP}
}

verifyIPv4() {
    IP=$1
    BAD_IP=0;
    if [ "`echo $IP | sed -ne 's/[0-9]//gp'`" != "..." ]
    then
        BAD_IP=1
    else
        BAD_IP=`echo $IP | awk -F. 'BEGIN {BAD_OCTET=0} { for (OCTET = 1; OCTET <= 4; OCTET++) { if (($OCTET !~ /^(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])$/) || ((OCTET == 1) && ($OCTET == "0"))) { BAD_OCTET=1 } } } END { print BAD_OCTET }'`
    fi
    return ${BAD_IP}
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
STARTSERVERS=$STARTSERVERS
LDAPROOTPW=$LDAPROOTPW
LDAPZIMBRAPW=$LDAPZIMBRAPW
LDAPPOSTPW=$LDAPPOSTPW
LDAPREPPW=$LDAPREPPW
LDAPAMAVISPW=$LDAPAMAVISPW
LDAPNGINXPW=$LDAPNGINXPW
CREATEDOMAIN=$CREATEDOMAIN
CREATEADMIN=$CREATEADMIN
CREATEADMINPASS=$CREATEADMINPASS
MODE=$MODE
ALLOWSELFSIGNED=$ALLOWSELFSIGNED
RUNAV=$RUNAV
RUNSA=$RUNSA
AVUSER=$AVUSER
AVDOMAIN=$AVDOMAIN
INSTALL_PACKAGES="$INSTALL_PACKAGES"
INSTALL_WEBAPPS="$INSTALL_WEBAPPS"
USE_ZIMBRA_PACKAGE_SERVER=$USE_ZIMBRA_PACKAGE_SERVER
PACKAGE_SERVER=$PACKAGE_SERVER
EOF

}

loadConfig() {
  FILE="$1"

  if [ ! -f "$FILE" ]; then
    echo ""
    echo "*** ERROR - can't find configuration file $FILE"
    echo ""
    exit 1
  fi
  perl -pi -e 's/\r//' "$FILE"
  echo ""
  echo -n "Loading configuration data from $FILE..."
  source "$FILE"
  echo "done"
}

# All ask functions take 2 args:
#  Prompt
#  Default (optional)

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
    response=$(perl -e "print lc(\"$response\");")
    if [ -z $response ]; then
      :
    else
      if [ $response = "yes" -o $response = "y" ]; then
        response="yes"
        break
      else
        if [ $response = "no" -o $response = "n" ]; then
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

checkMySQLConfig() {
  isInstalled zimbra-store
  if [ x$PKGINSTALLED != "x" ]; then
    if [ -f "/opt/zimbra/conf/my.cnf" ]; then
      BIND_ADDR=`awk '{ if ( $1 ~ /^bind-address$/ ) { print $3 } }' /opt/zimbra/conf/my.cnf`
      while [ "${BIND_ADDR}x" != "127.0.0.1x" -a "${BIND_ADDR}x" != "localhostx" ]; do
        echo "The MySQL bind address is currently not set to \"localhost\" or \"127.0.0.1\".  Due to a"
        echo "MySQL bug (#61713), the MySQL bind address must be set to \"127.0.0.1\".  Please correct"
        echo "the bind-address entry in the \"/opt/zimbra/conf/my.cnf\" file to proceed with the upgrade."
        askYN "Retry validation? (Y/N)?" "Y"
        if [ $response = "no" ]; then
          break
        fi
        BIND_ADDR=`awk '{ if ( $1 ~ /^bind-address$/ ) { print $3 } }' /opt/zimbra/conf/my.cnf`
      done
      if [ "${BIND_ADDR}x" != "127.0.0.1x" -a "${BIND_ADDR}x" != "localhostx" ]; then
        echo ""
        echo "It is recommended that the bind-address setting in the /opt/zimbra/conf/my.cnf file be set"
        echo "to \"127.0.0.1\".  The current setting of \"${BIND_ADDR}\" is not supported within"
        echo "ZCS and may cause the installation to fail."
        askYN "Proceed with installation? (Y/N)?" "N"
        if [ $response != "yes" ]; then
          echo ""
          echo "Aborting installation"
          echo ""
          exit 1
        fi
      fi
    fi
  fi
}

checkDatabaseIntegrity() {

	isInstalled zimbra-store
	if [ x$PKGINSTALLED != "x" ]; then
		if [ -x "bin/zmdbintegrityreport" -a -x "/opt/zimbra/bin/mysqladmin" ]; then
			while :; do
				if [ x$DEFAULTFILE = "x" ]; then
					askYN "Do you want to verify message store database integrity?" "Y"
					if [ $response = "no" ]; then
						break
					fi
				elif [ x$VERIFYMSGDB != "xyes" ]; then
					break
				fi
				echo "Verifying integrity of message store databases.  This may take a while."
				su - zimbra -c "/opt/zimbra/bin/mysqladmin -s ping" 2>/dev/null
				if [ $? != 0 ]; then
					su - zimbra -c "/opt/zimbra/bin/mysql.server start" 2> /dev/null
					for ((i = 0; i < 60; i++)) do
						su - zimbra -c "/opt/zimbra/bin/mysqladmin -s ping" 2>/dev/null
						if [ $? = 0 ]; then
							SQLSTARTED=1
							break
						fi
						sleep 2
					done
				fi
				perl bin/zmdbintegrityreport -v -r
				MAILBOXDBINTEGRITYSTATUS=$?
				if [ x"$SQLSTARTED" != "x" ]; then
					su - zimbra -c "/opt/zimbra/bin/mysqladmin -s ping" 2>/dev/null
					if [ $? = 0 ]; then
						su - zimbra -c "/opt/zimbra/bin/mysql.server stop" 2> /dev/null
						for ((i = 0; i < 60; i++)) do
							su - zimbra -c "/opt/zimbra/bin/mysqladmin -s ping" 2>/dev/null
							if [ $? != 0 ]; then
								break
							fi
							sleep 2
						done
					fi
				fi
				if [ $MAILBOXDBINTEGRITYSTATUS != 0 ]; then
					exit $?
				fi
				break
			done
		fi
	fi
}

checkRecentBackup() {

  isInstalled zimbra-store
  if [ x$PKGINSTALLED != "x" ]; then
    if [ -x "bin/checkValidBackup" ]; then
      echo "Checking for a recent backup"
      `bin/checkValidBackup > /dev/null 2>&1`
      if [ $? != 0 ]; then
        echo "WARNING: Unable to find a full system backup started within the last"
        echo "24hrs.  It is recommended to perform a full system backup and"
        echo "copy it to a safe location prior to performing an upgrade."
        echo ""
        if [ x$DEFAULTFILE = "x" ]; then
          while :; do
            askYN "Do you wish to continue without a backup?" "N"
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
        else
          echo "Automated install detected...continuing."
        fi
      fi
    fi
  fi
}

checkUbuntuRelease() {
  if [ -f "/etc/lsb-release" ]; then
    . /etc/lsb-release
  fi

  if [ x"$DEFAULTFILE" != "x" ]; then
    echo "Automated install detected...continuing."
    return
  fi

  if [ "x$DISTRIB_ID" = "xUbuntu" -a "x$DISTRIB_RELEASE" != "x12.04" -a "x$DISTRIB_RELEASE" != "x14.04" -a "x$DISTRIB_RELEASE" != "x16.04" ]; then
    echo "WARNING: ZCS is currently only supported on Ubuntu Server 12.04, 14.04 and 16.04 LTS."
    echo "You are attempting to install on $DISTRIB_DESCRIPTION which may not work."
    echo "Support will not be provided if you choose to continue."
    echo ""
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

checkVersionDowngrade() {

  if [ x"${ZM_CUR_MAJOR}" = "x" -o x"${ZM_CUR_MINOR}" = "x" -o x"${ZM_CUR_MICRO}" = "x" ]; then
    return
  fi

  if [ x"${ZM_INST_MAJOR}" = "x" -o x"${ZM_INST_MINOR}" = "x" -o x"${ZM_INST_MICRO}" = "x" ]; then
    return
  fi

  if [ ${ZM_CUR_MAJOR} -lt 7 ]; then
	echo "ERROR: You can only upgrade from ZCS 7.0 or later"
	exit 1
  fi

  ZM_CUR_VERSION="${ZM_CUR_MAJOR}.${ZM_CUR_MINOR}.${ZM_CUR_MICRO}"
  ZM_INST_VERSION="${ZM_INST_MAJOR}.${ZM_INST_MINOR}.${ZM_INST_MICRO}"

  DOWNGRADE=0
  if [ ${ZM_CUR_MAJOR} -gt ${ZM_INST_MAJOR} ]; then
    #echo "$ZM_CUR_VERSION is newer then $ZM_INST_VERSION MAJOR"
    DOWNGRADE=1
  elif [ ${ZM_CUR_MAJOR} -eq ${ZM_INST_MAJOR} ]; then
    if [ ${ZM_CUR_MINOR} -gt ${ZM_INST_MINOR} ]; then
      #echo "$ZM_CUR_VERSION is newer then $ZM_INST_VERSION MINOR"
      DOWNGRADE=1
    elif [ ${ZM_CUR_MINOR} -eq ${ZM_INST_MINOR} ]; then
      if [ ${ZM_CUR_MICRO} -gt ${ZM_INST_MICRO} ]; then
        #echo "$ZM_CUR_VERSION is newer then $ZM_INST_VERSION MICRO"
        DOWNGRADE=1
      fi
    fi
  fi

  if [ $DOWNGRADE = 1 ]; then
    echo "Downgrading to version $ZM_INST_VERSION from $ZM_CUR_VERSION is not supported."
    exit 1
  else
    echo "ZCS upgrade from $ZM_CUR_VERSION to $ZM_INST_VERSION will be performed."
  fi

}

checkRequired() {

  if [ -x "/usr/bin/getent" ]; then
    if ! /usr/bin/getent hosts 127.0.0.1 | perl -ne 'if (! m|^\d+\.\d+\.\d+\.\d+\s+localhost\s*| && ! m|^\d+\.\d+\.\d+\.\d+\s+localhost\.localdomain\s*|) { exit 11;}'; then
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

    H_LINE=`sed -e 's/#.*//' /etc/hosts | awk '{ for (i = 2; i <=NF; i++) { if ($i ~ /^'$HOSTNAME'$/) { print $0; } } }'`
    IP=`echo ${H_LINE} | awk '{ print $1 }'`
    INVALID_IP=0

    if [ "`echo ${IP} | tr -d '[0-9a-fA-F:]'`" = "" ]
    then
        verifyIPv6 ${IP}
        if [ $? -ne 0 ]
        then
            INVALID_IP=1
        fi
    elif [ "`echo ${IP} | tr -d '[0-9.]'`" = "" ]
    then
        verifyIPv4 ${IP}
        if [ $? -ne 0 ]
        then
            INVALID_IP=1
        fi
    elif [ "`echo ${IP} | tr -d '[0-9a-fA-F:.]'`" = "" ]
    then
        IPv6=`echo ${IP} | awk -F: '{printf("%s", $1); for (i = 2; i < NF; i++) { printf(":%s", $i) }}'`
        IPv4=`echo ${IP} | sed -ne 's/.*://p'`
        verifyMixedIPv6 ${IPv6}
        if [ $? -eq 0 ]
        then
            verifyIPv4 ${IPv4}
            if [ $? -ne 0 ]
            then
                INVALID_IP=1
            fi
        else
            INVALID_IP=1
        fi
    else
        INVALID_IP=1
    fi
    if [ `echo ${H_LINE} | awk '{ print NF }'` -lt 2 -o ${INVALID_IP} -eq 1 ]
    then
        echo ""
        echo "  ERROR: Installation can not proceeed.  Please fix your /etc/hosts file"
        echo "  to contain:"
        echo ""
        echo "  <ip> <FQHN> <HN>"
        echo ""
        echo "  Where <IP> is the ip address of the host, "
        echo "  <FQHN> is the FULLY QUALIFIED host name, and"
        echo "  <HN> is the (optional) hostname-only portion"
        echo ""
        exit 1
    fi
  fi

  GOOD="yes"

  # limitation of ext3
  if [ -d "/opt/zimbra/db/data" ]; then
    echo "Checking current number of databases..."
    FS_TYPE=`df -T /opt/zimbra/db/data | awk '{ if (NR == 2) { print $2 } }'`
    if [ "${FS_TYPE}"x = "ext3"x ]; then
      DBCOUNT=`find /opt/zimbra/db/data -type d | wc -l | awk '{if ($NF-1 >= 31998) print $NF-1}'`
      if [ x"$DBCOUNT" != "x" ]; then
        echo "You have $DBCOUNT databases on an ext3 FileSystem, which is at"
        echo "or over the limit of 31998 databases. You will need to delete at"
        echo "least one database prior to upgrading or your upgrade will fail."
        echo "/opt/zimbra/db/data/test is a good candidate for removal."
        exit 1
      fi
    fi
  fi

  checkRecentBackup
  checkDatabaseIntegrity
}


checkRequiredSpace() {
  # /tmp must have 100MB
  # /opt/zimbra must have 5GB for fresh installs with zimbra-store
  # /opt/zimbra must have 500MB for upgrades
  GOOD=yes
  echo "Checking required space for zimbra-core"
  TMPKB=`df -Pk /tmp | tail -1 | awk '{print $4}'`
  AVAIL=$(($TMPKB / 1024))
  if [ $AVAIL -lt  100 ]; then
    echo "/tmp must have at least 100MB of availble space to install."
    echo "${AVAIL}MB is not enough space to install ZCS."
    GOOD=no
  fi
  ZIMBRA=`df -Pk /opt/zimbra | tail -1 | awk '{print $4}'`
  if [ $UPGRADE = "yes" ]; then
    AVAIL=$(($ZIMBRA / 1024))
    if [ $AVAIL -lt 500 ]; then
      echo "/opt/zimbra requires at least 500MB of space to upgrade."
      echo "${AVAIL}MB is not enough space to upgrade."
      GOOD=no
    fi
  fi

  isInstalled zimbra-store
  isToBeInstalled zimbra-store
  if [ "x$PKGINSTALLED" != "x" -o "x$PKGTOBEINSTALLED" != "x" ]; then
    echo "Checking space for zimbra-store"
    if [ $UPGRADE = "no" ]; then
      AVAIL=$(($ZIMBRA / 1048576))
      if [ $AVAIL -lt 5 ]; then
        echo "/opt/zimbra requires at least 5GB of space to install."
        echo "${AVAIL}GB is not enough space to install."
        GOOD=no
      fi
    fi
  fi
  if [ $GOOD = "no" ]; then
    if [ x"$SKIPSPACECHECK" != "xyes" ]; then
      echo ""
      echo "Installation cancelled."
      echo ""
      exit 1
    else
      echo ""
      echo "Installation will continue by request."
      echo ""
    fi
  fi
}

checkStoreRequirements() {
  echo "Checking required packages for zimbra-store"
  GOOD="yes"
  if [ x"$ZMTYPE_INSTALLABLE" = "xNETWORK" ]; then
    for i in $STORE_PACKAGES; do
      #echo -n "    $i..."
      isInstalled $i
      if [ "x$PKGINSTALLED" != "x" ]; then
        echo "     FOUND: $PKGINSTALLED"
      else
        echo "     MISSING: $i"
        GOOD="no"
      fi
    done
  fi

  if [ $GOOD = "no" ]; then
    echo ""
    echo "###WARNING###"
    echo ""
    echo "One or more suggested packages for zimbra-store are missing."
    echo "Some features may be disabled due to the missing package(s)."
    echo ""
  else
    echo "zimbra-store package check complete."
  fi


}

checkExistingInstall() {

  echo $PLATFORM | egrep -q "UBUNTU|DEBIAN"
  if [ $? = 0 ]; then
    if [ -L /opt -o -L /opt/zimbra ]; then
      echo "Installation cannot continue if either /opt or /opt/zimbra are symbolic links."
      exit 1
    fi
  fi

  echo "Checking for existing installation..."

  for i in $OPTIONAL_PACKAGES; do
    isInstalled $i
    if [ x$PKGINSTALLED != "x" ]; then
      echo "    $i...FOUND $PKGINSTALLED"
      INSTALLED_PACKAGES="$INSTALLED_PACKAGES $i"
    elif [ x$i != "xzimbra-qatest" ]; then
      echo "    $i...NOT FOUND"
    fi
  done

  for i in $PACKAGES $CORE_PACKAGES; do
    echo -n "    $i..."
    isInstalled $i
    if [ x"$PKGINSTALLED" != "x" ]; then
      echo "FOUND $PKGINSTALLED"
      if [ "$i" != "zimbra-memcached" ]; then
         INSTALLED="yes"
      fi
      INSTALLED_PACKAGES="$INSTALLED_PACKAGES $i"
    else
      if [ x$i = "xzimbra-archiving" ]; then
        if [ -f "/opt/zimbra/lib/ext/zimbra_xmbxsearch/zimbra_xmbxsearch.jar" -a -f "/opt/zimbra/zimlets-network/zimbra_xmbxsearch.zip" ]; then
          echo "FOUND zimbra-cms"
          INSTALLED_PACKAGES="$INSTALLED_PACKAGES zimbra-archiving"
        else
          echo "NOT FOUND"
        fi
      else
         echo "NOT FOUND"
      fi
    fi
  done

  determineVersionType
  if [ $INSTALLED = "yes" ]; then
    verifyUpgrade
  fi
  verifyLicenseActivationServer
  verifyLicenseAvailable

  if [ $INSTALLED != "yes" ]; then
    checkUserInfo
  fi
}

determineVersionType() {

  isInstalled zimbra-core
  if [ x"$PKGINSTALLED" != "x" ]; then
    export ZMVERSION_CURRENT=`echo $PKGVERSION | sed s/^zimbra-core-//`
    if [ -f "/opt/zimbra/bin/zmbackupquery" ]; then
      ZMTYPE_CURRENT="NETWORK"
    else
      ZMTYPE_CURRENT="FOSS"
    fi
    ZM_CUR_MAJOR=$(perl -e '$v=$ENV{ZMVERSION_CURRENT}; $v =~ s/^(\d+\.\d+\.[^_]*_[^_]+_[^.]+).*/\1/; ($maj,$min,$mic) = $v =~ m/^(\d+)\.(\d+)\.(\d+)/; print "$maj\n"')
    ZM_CUR_MINOR=$(perl -e '$v=$ENV{ZMVERSION_CURRENT}; $v =~ s/^(\d+\.\d+\.[^_]*_[^_]+_[^.]+).*/\1/; ($maj,$min,$mic) = $v =~ m/^(\d+)\.(\d+)\.(\d+)/; print "$min\n"')
    ZM_CUR_MICRO=$(perl -e '$v=$ENV{ZMVERSION_CURRENT}; $v =~ s/^(\d+\.\d+\.[^_]*_[^_]+_[^.]+).*/\1/; ($maj,$min,$mic) = $v =~ m/^(\d+)\.(\d+)\.(\d+)/; print "$mic\n"')
    ZM_CUR_BUILD=$(perl -e '$v=$ENV{ZMVERSION_CURRENT}; $v =~ s/^(\d+\.\d+\.[^_]*_[^_]+_[^.]+).*/\1/; ($maj,$min,$mic,$rtype,$build) = $v =~ m/^(\d+)\.(\d+)\.(\d+)\.(\w+)\.(\d+)/; ($maj,$min,$mic,$rtype,$build) = $v =~ m/(\d+)\.(\d+)\.(\d+)_(\w+[^_])_(\d+)/ if ($rtype eq ""); print "$build\n";')
  fi

  # if we are removing the install we don't need the rest of the info
  if [ x"$UNINSTALL" = "xyes" ]; then
    return
  fi

  # need way to determine type for other package types
  ZMTYPE_INSTALLABLE="$(cat ${MYDIR}/.BUILD_TYPE)"

  ZM_INST_MAJOR=$(perl -e '$v=glob("packages/zimbra-core*"); $v =~ s/^packages\/zimbra-core[-_]//; $v =~ s/^(\d+\.\d+\.[^_]*_[^_]+_[^.]+).*/\1/; ($maj,$min,$mic) = $v =~ m/^(\d+)\.(\d+)\.(\d+)/; print "$maj\n"')
  ZM_INST_MINOR=$(perl -e '$v=glob("packages/zimbra-core*"); $v =~ s/^packages\/zimbra-core[-_]//; $v =~ s/^(\d+\.\d+\.[^_]*_[^_]+_[^.]+).*/\1/; ($maj,$min,$mic) = $v =~ m/^(\d+)\.(\d+)\.(\d+)/; print "$min\n"')
  ZM_INST_MICRO=$(perl -e '$v=glob("packages/zimbra-core*"); $v =~ s/^packages\/zimbra-core[-_]//; $v =~ s/^(\d+\.\d+\.[^_]*_[^_]+_[^.]+).*/\1/; ($maj,$min,$mic) = $v =~ m/^(\d+)\.(\d+)\.(\d+)/; print "$mic\n"')
  ZM_INST_RTYPE=$(perl -e '$v=glob("packages/zimbra-core*"); $v =~ s/^packages\/zimbra-core[-_]//; $v =~ s/^(\d+\.\d+\.[^_]*_[^_]+_[^.]+).*/\1/; ($maj,$min,$mic,$rtype,$build) = $v =~ m/^(\d+)\.(\d+)\.(\d+)\.(\w+)\.(\d+)/; ($maj,$min,$mic,$rtype,$build) = $v =~ m/(\d+)\.(\d+)\.(\d+)_(\w+[^_])_(\d+)/ if ($rtype eq ""); print "$rtype\n";')
  ZM_INST_BUILD=$(perl -e '$v=glob("packages/zimbra-core*"); $v =~ s/^packages\/zimbra-core[-_]//; $v =~ s/^(\d+\.\d+\.[^_]*_[^_]+_[^.]+).*/\1/; ($maj,$min,$mic,$rtype,$build) = $v =~ m/^(\d+)\.(\d+)\.(\d+)\.(\w+)\.(\d+)/; ($maj,$min,$mic,$rtype,$build) = $v =~ m/(\d+)\.(\d+)\.(\d+)_(\w+[^_])_(\d+)/ if ($rtype eq ""); print "$build\n";')

  if [ x"$AUTOINSTALL" = "xyes" ]; then
    return
  fi

  #echo "TYPE: CURRENT: $ZMTYPE_CURRENT INSTALLABLE: $ZMTYPE_INSTALLABLE"
  #echo "VERSION: CURRENT: $ZM_CUR_MAJOR INSTALLABLE: $ZM_INST_MAJOR"

  checkVersionDowngrade

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

  if [ x"$ZMTYPE_CURRENT" = "xNETWORK" ]; then
    echo $ZM_INST_RTYPE | grep -v GA$ > /dev/null 2>&1
    if [ $? = 0 ]; then
      if [ ${ZM_CUR_MAJOR} -lt ${ZM_INST_MAJOR} ]; then
        echo "This is a Network Edition ${ZM_INST_RTYPE} build and is not intended for production."
        if [ x"$BETA_SUPPORT" = "x" ]; then
          echo "Upgrades from $ZMVERSION_CURRENT are not supported."
          exit 1
        else
          echo "Support for developer versions of ZCS maybe limited to bugzilla and Zimbra forums."
          #echo "Installing non-GA versions in production is not recommended."
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
      fi
    fi
  fi
}

verifyUpgrade() {

  if [ x"$UNINSTALL" = "xyes" ]; then
    return
  fi

  if [ ${ZM_CUR_MAJOR} -lt 8 ] || [ ${ZM_CUR_MAJOR} -eq 8 -a ${ZM_CUR_MINOR} -lt 7 ]; then
    if [ -x "bin/checkService.pl" ]; then
      echo "Checking for existing proxy service in your environment"
      # echo "Running bin/checkService.pl -s proxy"
      if [ ${ZM_CUR_MAJOR} -lt 8 ]; then
          `bin/checkService.pl -s imapproxy`
      else
          `bin/checkService.pl -s proxy`
      fi
      serviceProxyRC=$?;
      if [ "$serviceProxyRC" != 0 ]; then
          if [ "$serviceProxyRC" = 2 ]; then
              echo "Error: No proxy detected in your environment. Proxy is required for ZCS 8.7+."
              echo "See https://wiki.zimbra.com/wiki/Enabling_Zimbra_Proxy for details on installing proxy."
          else
            echo "Error: Unable to contact the LDAP server."
            exit 1
          fi
      fi

      echo "Checking for existing memcached service in your environment"
      # echo "Running bin/checkService.pl -s memcached"
      `bin/checkService.pl -s memcached`
      serviceMemcachedRC=$?;
      if [ "$serviceMemcachedRC" != 0 ]; then
          if [ "$serviceMemcachedRC" = 2 ]; then
              echo "Error: No memcached detected in your environment. Memcached is required for ZCS 8.7+."
              echo "See https://wiki.zimbra.com/wiki/Enabling_Zimbra_Memcached for details on installing memcached."
          else
            echo "Error: Unable to contact the LDAP server."
            exit 1
          fi
      fi
    fi

    if [ "$serviceProxyRC" != 0 ] || [ "$serviceMemcachedRC" != 0 ]; then
      echo "Proxy and Memcached services must exist. Exiting..."
      exit 1
    fi
  fi

  if [ x"$SKIP_UPGRADE_CHECK" = "xyes" ]; then
    return
  fi

  # sometimes we just don't want to check
  if [ x"$AUTOINSTALL" = "xyes" ] || [ x"$SOFTWAREONLY" = "xyes" ]; then
    return
  fi

  isInstalled "zimbra-ldap"
  if [ x$PKGINSTALLED != "x" ]; then
    runAsZimbra "ldap start"
    # Upgrade tests specific to NE only
    if [ x"$ZMTYPE_CURRENT" = "xNETWORK" ] && [ x"$ZMTYPE_INSTALLABLE" = "xNETWORK" ]; then
      if [ x"$SKIP_ACTIVATION_CHECK" = "xno" ]; then
        if [ -x "bin/checkLicense.pl" ]; then
          echo "Validating existing license is not expired and qualifies for upgrade"
          echo $HOSTNAME | egrep -qe 'eng.vmware.com$|eng.zimbra.com$|lab.zimbra.com$' > /dev/null 2>&1
          if [ $? = 0 ]; then
            # echo "Running bin/checkLicense.pl -i -v $ZM_INST_VERSION"
            `bin/checkLicense.pl -i -v $ZM_INST_VERSION >/dev/null`
          else
            # echo "Running bin/checkLicense.pl -v $ZM_INST_VERSION"
            `bin/checkLicense.pl -v $ZM_INST_VERSION >/dev/null`
          fi
          licenseRC=$?;
          if [ $licenseRC != 0 ]; then
            if [ $licenseRC = 6 ]; then
              echo "Error: Unable to bind to LDAP"
              exit 1
            elif [ $licenseRC = 5 ]; then
              echo "Error: Unable to execute startTLS with LDAP"
              exit 1
            elif [ $licenseRC = 4 ]; then
              echo "Error: Unable to connect to LDAP"
              exit 1
            elif [ $licenseRC = 3 ]; then
              echo "Error: No upgrade version supplied"
              exit 1
            elif [ $licenseRC = 2 ]; then
              echo "Error: No license file found"
              exit 1
            elif [ $licenseRC = 1 ]; then
              echo "Error: License is expired or cannot be upgraded."
              echo "       Aborting upgrade"
              exit 1
            else
              echo "Unknown Error.  It should be impossible to reach this statement."
              exit 1
            fi
          else
           echo "License is valid and supports this upgrade.  Continuing."
          fi
        fi
      fi
    fi
  fi

  # Upgrade tests applicable to everyone
  echo "Validating ldap configuration"
  isInstalled "zimbra-ldap"
  LDAP_OPT=""
  if [ x$PKGINSTALLED != "x" ]; then
    LDAP_OPT="-l"
  fi
  `bin/zmValidateLdap.pl --vmajor ${ZM_CUR_MAJOR} --vminor ${ZM_CUR_MINOR} --vmicro ${ZM_CUR_MICRO} \
     --umajor ${ZM_INST_MAJOR} --uminor ${ZM_INST_MINOR} --umicro ${ZM_INST_MICRO} ${LDAP_OPT} >/dev/null`
  ldapRC=$?;
  if [ $ldapRC != 0 ]; then
    if [ $ldapRC = 1 ]; then
      echo "Error: Unable to create a successful TLS connection to the ldap masters."
      echo "       Fix cert configuration prior to upgrading."
      exit 1
    elif [ $ldapRC = 2 ]; then
      echo "Error: Unable to bind to the LDAP server as the root LDAP user."
      echo "       This is required to upgrade."
      exit 1
    elif [ $ldapRC = 3 ]; then
      echo "Error: Unable to bind to the LDAP server as the zimbra LDAP user."
      echo "       This is required to upgrade."
      exit 1
    elif [ $ldapRC = 4 ]; then
      echo "Error: Unable to search LDAP server as the zimbra LDAP user."
      echo "       This is required to upgrade."
      exit 1
    elif [ $ldapRC = 5 ]; then
      echo "Error: One or more LDAP master servers has not yet been upgraded."
      echo "       It is required for all LDAP master node(s) to be upgraded first."
      exit 1
    else
      echo "Unknown Error: It should be impossible to reach this statement."
      exit 1
   fi
   else
     echo "LDAP validation succeeded.  Continuing."
   fi
}

verifyLicenseActivationServer() {

  if [ x"$SKIP_ACTIVATION_CHECK" = "xyes" -o x"$SKIP_UPGRADE_CHECK" = "xyes" ]; then
    return
  fi

  # sometimes we just don't want to check
  if [ x"$AUTOINSTALL" = "xyes" ] || [ x"$UNINSTALL" = "xyes" ] || [ x"$SOFTWAREONLY" = "xyes" ]; then
    return
  fi

  # make sure this is an upgrade
  isInstalled zimbra-store
  if [ x$PKGINSTALLED = "x" ]; then
    return
  fi

  # make sure the current version we are trying to install is a NE version
  if [ x"$ZMTYPE_INSTALLABLE" != "xNETWORK" ]; then
    return
  fi

  # if we specify an activation presume its valid
  if [ x"$ACTIVATION" != "x" ] && [ -e $ACTIVATION ]; then
    if [ ! -d "/opt/zimbra/conf" ]; then
      mkdir -p /opt/zimbra/conf
    fi
    cp -f $ACTIVATION /opt/zimbra/conf/ZCSLicense-activated.xml
    chown zimbra:zimbra /opt/zimbra/conf/ZCSLicense-activated.xml
    chmod 444 /opt/zimbra/conf/ZCSLicense-activated.xml
    return
  fi

  # if all else fails make sure we can contact the activation server for automated activation
  if [ ${ZM_CUR_MAJOR} -ge "7" ]; then
    if [ ${ZM_CUR_MAJOR} -eq "7" -a ${ZM_CUR_MINOR} -ge "1" ]; then
      /opt/zimbra/bin/zmlicense --ping > /dev/null 2>&1
    elif [ ${ZM_CUR_MAJOR} -gt "7" ]; then
      /opt/zimbra/bin/zmlicense --ping > /dev/null 2>&1
    else
      /opt/zimbra/java/bin/java -XX:ErrorFile=/opt/zimbra/log -client -Xmx256m -Dzimbra.home=/opt/zimbra -Djava.library.path=/opt/zimbra/lib -Djava.ext.dirs=/opt/zimbra/java/jre/lib/ext:/opt/zimbra/lib/jars -classpath ./lib/jars/zimbra-license-tools.jar com.zimbra.cs.license.LicenseCLI --ping > /dev/null 2>&1
    fi
    if [ $? != 0 ]; then
      activationWarning
    fi
  else
    echo $HOSTNAME | egrep -qe 'vmware.com$|zimbra.com$' > /dev/null 2>&1
    if [ $? = 0 ]; then
      url='https://zimbra-stage-license.eng.zimbra.com/zimbraLicensePortal/public/activation?action=test'
    else
      url='https://license.zimbra.com/zimbraLicensePortal/public/activation?action=test'
    fi

    cmd=$(which curl 2>/dev/null)
    if [ -x "$cmd" ]; then
      output=$($cmd --connect-timeout 5 -s -f $url)
      if [ $? != 0 ]; then
        output=$($cmd -k --connect-timeout 5 -s -f $url)
        if [ $? != 0 ]; then
          activationWarning
        else
          return
        fi
      else
        return
      fi
    fi
    cmd=$(which wget 2>/dev/null)
    if [ -x "$cmd" ]; then
      output=$($cmd --tries 1 -T 5 -q -O /tmp/zmlicense.tmp $url)
      if [ $? != 0 ]; then
        output=$($cmd --no-check-certificate --tries 1 -T 5 -q -O /tmp/zmlicense.tmp $url)
        if [ $? != 0 ]; then
          activationWarning
        else
          return
        fi
        activationWarning
      else
        return
      fi
    fi
    activationWarning
  fi
}

activationWarning() {
  echo "ERROR: Unable to reach the Zimbra License Activation Server."
  echo ""
  echo "License Activation is required when upgrading to ZCS 7 or later."
  echo ""
  echo "The ZCS Network upgrade will automatically attempt to activate the"
  echo "current license as long as the activation server can be contacted."
  echo ""
  echo "You can obtain a manual activation key and re-run the upgrade"
  echo "by specifying the -a activation.xml option."
  echo ""
  echo "A manual license activation key can be obtained by either visiting"
  echo "the Zimbra support portal or contacting Zimbra support or sales."
  echo ""
  exit 1;
}

verifyLicenseAvailable() {

  if [ x"$LICENSE" != "x" ] && [ -e $LICENSE ]; then
    if [ ! -d "/opt/zimbra/conf" ]; then
      mkdir -p /opt/zimbra/conf
    fi
    cp -f $LICENSE /opt/zimbra/conf/ZCSLicense.xml
    chown zimbra:zimbra /opt/zimbra/conf/ZCSLicense.xml 2> /dev/null
    chmod 444 /opt/zimbra/conf/ZCSLicense.xml
  fi

  if [ x"$AUTOINSTALL" = "xyes" ] || [ x"$UNINSTALL" = "xyes" ] || [ x"$SOFTWAREONLY" = "xyes" ]; then
    return
  fi

  isInstalled zimbra-store
  if [ x$PKGINSTALLED = "x" ]; then
    return
  fi

  # need to finish for other native packagers
  if [ "$(cat ${MYDIR}/.BUILD_TYPE)" != "NETWORK" ]; then
     return
  fi

  echo "Checking for available license file..."


  # use the tool if it exists
  if [ -f "/opt/zimbra/bin/zmlicense" ]; then
    licenseCheck=`su - zimbra -c "zmlicense -c" 2> /dev/null`
    licensedUsers=`su - zimbra -c "zmlicense -p | grep ^AccountsLimit | sed -e 's/AccountsLimit=//'" 2> /dev/null`
    licenseValidUntil=`su - zimbra -c "zmlicense -p | grep ^ValidUntil= | sed -e 's/ValidUntil=//'" 2> /dev/null`
    licenseType=`su - zimbra -c "zmlicense -p | grep ^InstallType= | sed -e 's/InstallType=//'" 2> /dev/null`
  fi

  # parse files if license tool wasn't there or didn't return a valid license
  if [ x"$licenseCheck" = "xlicense not installed" -o x"$licenseCheck" = "x" ]; then
    if [ -f "/opt/zimbra/conf/ZCSLicense.xml" ]; then
      licenseCheck="license is OK"
      licensedUsers=`cat /opt/zimbra/conf/ZCSLicense.xml | grep AccountsLimit | head -1  | awk '{print $3}' | awk -F= '{print $2}' | awk -F\" '{print $2}'`
      licenseValidUntil=`cat /opt/zimbra/conf/ZCSLicense.xml | awk -F\" '{ if ($2 ~ /^ValidUntil$/) {print $4 } }'`
      licenseType=`cat /opt/zimbra/conf/ZCSLicense.xml | awk -F\" '{ if ($2 ~ /^InstallType$/) {print $4 } }'`
    elif [ -f "/opt/zimbra/conf/ZCSLicense-Trial.xml" ]; then
      licenseCheck="license is OK"
      licensedUsers=`cat /opt/zimbra/conf/ZCSLicense-Trial.xml | grep AccountsLimit | head -1  | awk '{print $3}' | awk -F= '{print $2}' | awk -F\" '{print $2}'`
      licenseValidUntil=`cat /opt/zimbra/conf/ZCSLicense-Trial.xml | awk -F\" '{ if ($2 ~ /^ValidUntil$/) {print $4 } }'`
      licenseType=`cat /opt/zimbra/conf/ZCSLicense-Trial.xml | awk -F\" '{ if ($2 ~ /^InstallType$/) {print $4 } }'`
    else
      echo "ERROR: The ZCS Network upgrade requires a license to be located in"
      echo "/opt/zimbra/conf/ZCSLicense.xml or a license previously installed."
      echo "The upgrade will not continue without a license."
      echo ""
      echo "Your system has not been modified."
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

  now=`date -u "+%Y%m%d%H%M%SZ"`
  if [ \( x"$licenseValidUntil" \< x"$now" -o x"$licenseValidUntil" == x"$now" \) -a x"$ZMTYPE_INSTALLABLE" == x"NETWORK" ]; then
    if [ x"$licenseType" == x"perpetual" ]; then
      echo ""
      echo "ERROR: The ZCS Network upgrade requires a previously installed license"
      echo "or the license file located in /opt/zimbra/conf/ZCSLicense.xml to be"
      echo "valid and not expired."
      echo ""
      echo "The upgrade cannot occur with an expired perpetual license.  In order"
      echo "to perform an upgrade, you will need to have a valid support contract"
      echo "in place."
      echo ""
      echo "Your system has not been modified."
      echo ""
      exit 1;
    else
      echo ""
      echo "WARNING: The ZCS Network upgrade requires a previously installed license"
      echo "or the license file located in /opt/zimbra/conf/ZCSLicense.xml to be"
      echo "valid and not expired."
      echo ""
      echo "The upgrade can continue, but there will be some loss of functionality."
      echo ""
      while :; do
        askYN "Do you wish to continue? " "N"
        if [ $response == "no" ]; then
          askYN "Exit?" "N"
          if [ $response == "yes" ]; then
            echo ""
            echo "Your system has not been modified."
            echo""
            exit 1;
          fi
        else
          break
        fi
      done
    fi
  fi


  if [ x"$licensedUsers" = "x" ]; then
    licensedUsers=0
  fi

  # return immediately if we have an unlimited license
  if [ "$licensedUsers" = "-1" ]; then
    return
  fi

  # Check for licensed user count and warn if necessary
  oldUserCheck=0
  if [ ${ZM_CUR_MAJOR} -eq 6 -a ${ZM_CUR_MICRO} -lt 8 ]; then
    userProvCommand="zmprov -l gaa 2> /dev/null | wc -l"
    oldUserCheck=1
  else
    userProvCommand="zmprov -l cto userAccounts 2> /dev/null"
  fi

  # Make sure zmprov is responsive and able to talk to LDAP before we do anything for real
  zmprovTest="zmprov -l gac 2> /dev/null > /dev/null"
  su - zimbra -c "$zmprovTest"
  zmprovTestRC=$?
  if [ $zmprovTestRC -eq 0 ]; then
    su - zimbra -c "$zmprovTest"
    zmprovTestRC=$?
  fi
  if [ $zmprovTestRC -ne 0 ]; then
    echo ""
    echo "Warning: Unable to determine the number of users on this system via zmprov command."
    echo "Please make sure LDAP services are running."
    echo ""
  fi

  # Passed check to make sure zmprov and LDAP are working.  Now let's get a real count.
  numCurrentUsers=-1;
  if [ $zmprovTestRC -eq 0 ]; then
    numCurrentUsers=`su - zimbra -c "$userProvCommand"`;
    numUsersRC=$?
    if [ $numUsersRC -ne 0 ]; then
      numCurrentUsers=`su - zimbra -c "$userProvCommand"`;
      numUsersRC=$?
    fi
  fi

  # Unable to determine the number of current users
  if [ "$numCurrentUsers"x = "x" ]; then
    numCurrentUsers=-1;
    echo ""
    echo "Warning: Unable to determine the number of users on this system via zmprov command."
    echo "Please make sure LDAP services are running."
    echo ""
  fi

  if [ $oldUserCheck -eq 1 ]; then
    numCurrentUsers=`expr $numCurrentUsers - 3`
  fi
  if [ $numCurrentUsers -gt 0 ]; then
    echo "Current Users=$numCurrentUsers Licensed Users=$licensedUsers"
  fi

  if [ $numCurrentUsers -lt 0 ]; then
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
  if [ -x /usr/bin/getent ]
  then
    ZH=`getent passwd zimbra | awk -F: '{ print $6 }'`
    ZS=`getent passwd zimbra | awk -F: '{ print $7 }' | sed -e s'|.*/||'`
  else
    ZH=`awk -F: '/^zimbra:/ {print $6}' /etc/passwd`
    ZS=`awk -F: '/^zimbra:/ {print $7}' /etc/passwd | sed -e s'|.*/||'`
  fi
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
  # stop all zimbra process that may have been orphaned
  local OS=$(uname -s | tr A-Z a-z)
  if [ x"$OS" = "xlinux" ]; then
    if [ -x /bin/ps -a -x  /usr/bin/awk -a -x /usr/bin/xargs ]; then
      /bin/ps -eFw | /usr/bin/awk '{ if ($1 == "zimbra" && $3 == "1") print $2 }' | /usr/bin/xargs kill -9 > /dev/null 2>&1
    fi
  fi
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

  if [ $INSTALLED = "yes" -o $FORCE_UPGRADE = "yes" ]; then

      checkVersionMatches
      if [ $INSTALLED = "yes" ]; then

      echo ""
      echo "The Zimbra Collaboration Server appears to already be installed."
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
    fi

    while :; do
      UPGRADE="yes"
      if [ $FORCE_UPGRADE = "yes" -o $VERSIONMATCH = "yes" ]; then
        askYN "Do you wish to upgrade?" "Y"
      else
        UPGRADE="no"
        response="no"
      fi
      if [ $response = "no" ]; then
        askYN "Exit now?" "Y"
        if [ $response = "yes" ]; then
          exit 1;
        fi
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
        if [ $FORCE_UPGRADE = "no" ]; then
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
        fi
        break
      fi
    done
  else
    # REMOVE = yes for non installed systems, to clean up /opt/zimbra
    DETECTDIRS="db bin/zmcontrol redolog index store conf/localconfig.xml data"
    for i in $DETECTDIRS; do
      if [ -e "/opt/zimbra/$i" ]; then
        INSTALLED="yes"
      fi
    done
    if [ x$INSTALLED = "xyes" ]; then
      echo ""
      echo "The Zimbra Collaboration Server does not appear to be installed,"
      echo "yet there appears to be a ZCS directory structure in /opt/zimbra."
      askYN "Would you like to delete /opt/zimbra before installing?" "N"
      REMOVE="$response"
    else
      REMOVE="yes"
    fi
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
  LDAPPOSTPW=${ldap_postfix_password}
  LDAPREPPW=${ldap_replication_password}
  LDAPAMAVISPW=${ldap_amavis_password}
  LDAPNGINXPW=${ldap_nginx_password}

  echo "   HOSTNAME=${zimbra_server_hostname}"
  echo "   LDAPHOST=${ldap_host}"
  echo "   LDAPPORT=${ldap_port}"
  echo "   SNMPTRAPHOST=${snmp_trap_host}"
  echo "   SMTPSOURCE=${smtp_source}"
  echo "   SMTPDEST=${smtp_destination}"
  echo "   SNMPNOTIFY=${snmp_notify:-0}"
  echo "   SMTPNOTIFY=${smtp_notify:-0}"
  echo "   LDAPROOTPW=*"
  echo "   LDAPZIMBRAPW=*"
  echo "   LDAPPOSTPW=*"
  echo "   LDAPREPPW=*"
  echo "   LDAPAMAVISPW=*"
  echo "   LDAPNGINXPW=*"

}

restoreExistingConfig() {
  if [ -d $RESTORECONFIG ]; then
    RF="$RESTORECONFIG/localconfig.xml"
  fi
  if [ -f $RF ]; then
    echo -n "Restoring existing configuration file from $RF..."
    cp -f $RF /opt/zimbra/conf/localconfig.xml
    echo "done"
  fi
}

# deprecated by the move of zimlets to /opt/zimbra/zimlets-deployed which isn't removed on upgrade
restoreZimlets() {
  if [ -d $SAVEDIR/zimlet -a -d /opt/zimbra/mailboxd/webapps/service ]; then
    cp -rf $SAVEDIR/zimlet /opt/zimbra/mailboxd/webapps/service/
    chown -R zimbra:zimbra /opt/zimbra/mailboxd/webapps/service/zimlet
    chmod 775 /opt/zimbra/mailboxd/webapps/service/zimlet
  fi
}

restoreCerts() {
  if [ -f "$SAVEDIR/keystore" -a -d "/opt/zimbra/jetty/etc" ]; then
    cp $SAVEDIR/keystore /opt/zimbra/jetty/etc/keystore
    chown zimbra:zimbra /opt/zimbra/jetty/etc/keystore
    chmod u+w /opt/zimbra/jetty/etc/keystore
  elif [ -f "$SAVEDIR/keystore" -a -d "/opt/zimbra/conf" ]; then
    cp $SAVEDIR/keystore /opt/zimbra/conf/keystore
    chown zimbra:zimbra /opt/zimbra/conf/keystore
    chmod u+w /opt/zimbra/conf/keystore
  fi
  if [ -f "$SAVEDIR/smtpd.key" ]; then
    cp $SAVEDIR/smtpd.key /opt/zimbra/conf/smtpd.key
    chown zimbra:zimbra /opt/zimbra/conf/smtpd.key
  fi
  if [ -f "$SAVEDIR/smtpd.crt" ]; then
    cp $SAVEDIR/smtpd.crt /opt/zimbra/conf/smtpd.crt
    chown zimbra:zimbra /opt/zimbra/conf/smtpd.crt
  fi
  if [ -f "$SAVEDIR/slapd.crt" ]; then
    cp $SAVEDIR/slapd.crt /opt/zimbra/conf/slapd.crt
    chown zimbra:zimbra /opt/zimbra/conf/slapd.crt
  fi
  if [ -f "$SAVEDIR/nginx.key" ]; then
    cp $SAVEDIR/nginx.key /opt/zimbra/conf/nginx.key
    chown zimbra:zimbra /opt/zimbra/conf/nginx.key
  fi
  if [ -f "$SAVEDIR/nginx.crt" ]; then
    cp $SAVEDIR/nginx.crt /opt/zimbra/conf/nginx.crt
    chown zimbra:zimbra /opt/zimbra/conf/nginx.crt
  fi
  mkdir -p /opt/zimbra/conf/ca
  if [ -f "$SAVEDIR/ca.key" ]; then
    cp $SAVEDIR/ca.key /opt/zimbra/conf/ca/ca.key
    chown zimbra:zimbra /opt/zimbra/conf/ca/ca.key
  fi
  if [ -f "$SAVEDIR/ca.pem" ]; then
    cp $SAVEDIR/ca.pem /opt/zimbra/conf/ca/ca.pem
    chown zimbra:zimbra /opt/zimbra/conf/ca/ca.pem
  fi
  if [ -f "/opt/zimbra/jetty/etc/keystore" ]; then
    chown zimbra:zimbra /opt/zimbra/jetty/etc/keystore
    chmod u+w /opt/zimbra/jetty/etc/keystore
  fi
}

saveExistingConfig() {
  if [ $UPGRADE != "yes" -o $FORCE_UPGRADE = "yes" ]; then
    return
  fi

  echo ""
  echo "Saving existing configuration file to $SAVEDIR"

  # Since the location to java has changed, we need to fix localconfig.xml before we save the configuration
  # and start the upgrade process

  if [ -x "/opt/zimbra/bin/zmlocalconfig" ]; then
    runAsZimbra "zmlocalconfig -e zimbra_java_home=/opt/zimbra/common/lib/jvm/java"
    runAsZimbra "zmlocalconfig -e mailboxd_truststore=/opt/zimbra/common/lib/jvm/java/jre/lib/security/cacerts"
  fi
  if [ ! -d "$SAVEDIR" ]; then
    mkdir -p $SAVEDIR
  fi
  # make copies of existing save files
  for f in localconfig.xml config.save keystore cacerts smtpd.key smtpd.crt slapd.key slapd.crt ca.key backup.save; do
    if [ -f "${SAVEDIR}/${f}" ]; then
      for (( i=0 ;; i++ )); do
        if [ ! -f "${SAVEDIR}/${ZMVERSION_CURRENT}/${i}/${f}" ]; then
          mkdir -p ${SAVEDIR}/${ZMVERSION_CURRENT}/${i} 2> /dev/null
          mv -f "${SAVEDIR}/${f}" "${SAVEDIR}/${ZMVERSION_CURRENT}/${i}/${f}"
          break
        fi
      done
    fi
  done
  # yes, it needs massaging to be fed back in...
  if [ -x "/opt/zimbra/bin/zmlocalconfig" ]; then
    runAsZimbra "zmlocalconfig -s | sed -e \"s/ = \(.*\)/=\'\1\'/\" > $SAVEDIR/config.save"
  fi
  if [ -f "/opt/zimbra/conf/localconfig.xml" ]; then
    cp -f /opt/zimbra/conf/localconfig.xml $SAVEDIR/localconfig.xml
  fi
  if [ -f "/opt/zimbra/common/lib/jvm/java/jre/lib/security/cacerts" ]; then
    cp -f /opt/zimbra/common/lib/jvm/java/jre/lib/security/cacerts $SAVEDIR
  elif [ -f "/opt/zimbra/java/jre/lib/security/cacerts" ]; then
    cp -f /opt/zimbra/java/jre/lib/security/cacerts $SAVEDIR
  fi
  if [ -f "/opt/zimbra/jetty/etc/keystore" ]; then
    cp -f /opt/zimbra/jetty/etc/keystore $SAVEDIR
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
  if [ -f "/opt/zimbra/conf/nginx.key" ]; then
    cp -f /opt/zimbra/conf/nginx.key $SAVEDIR
  fi
  if [ -f "/opt/zimbra/conf/nginx.crt" ]; then
    cp -f /opt/zimbra/conf/nginx.crt $SAVEDIR
  fi
  if [ -f "/opt/zimbra/conf/ca/ca.key" ]; then
    cp -f /opt/zimbra/conf/ca/ca.key $SAVEDIR
  fi
  if [ -f "/opt/zimbra/conf/ca/ca.pem" ]; then
    cp -f /opt/zimbra/conf/ca/ca.pem $SAVEDIR
  fi
  if [ -d "/opt/zimbra/mailboxd/webapps/service/zimlet" ]; then
    cp -rf /opt/zimbra/mailboxd/webapps/service/zimlet $SAVEDIR
  fi
  if [ -x /opt/zimbra/bin/zmschedulebackup ]; then
    runAsZimbra "zmschedulebackup -s > $SAVEDIR/backup.save"
  fi
  if [ -d /opt/zimbra/wiki ]; then
    cp -rf /opt/zimbra/wiki $SAVEDIR
  fi

  if [ -f "/opt/zimbra/.enable_replica" ]; then
    rm -f /opt/zimbra/.enable_replica
  fi

  if [ -f /opt/zimbra/data/ldap/config/cn\=config.ldif ]; then
    if [ -f /opt/zimbra/data/ldap/config/cn\=config/olcDatabase\=\{2\}mdb/olcOverlay\=*syncprov.ldif ]; then
      touch /opt/zimbra/.enable_replica
    fi
  fi
}

findUbuntuExternalPackageDependencies() {
  # Handle external packages like logwatch, mailutils depends on zimbra-mta.
  if [ $INSTALLED = "yes" -a $ISUBUNTU = "true" ]; then
    $PACKAGERMSIMULATE $INSTALLED_PACKAGES > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      EXTPACKAGESTMP=`$PACKAGERMSIMULATE $INSTALLED_PACKAGES 2>&1 | grep " depends on " | cut -d' ' -f2 | grep -v zimbra`
      for p in $EXTPACKAGESTMP; do
        EXTPACKAGES="$p $EXTPACKAGES"
      done

      if [ -z "$EXTPACKAGES" ]; then
        removeErrorMessage
      else
        echo "External package dependencies found: $EXTPACKAGES"
        $PACKAGERMSIMULATE $INSTALLED_PACKAGES $EXTPACKAGES >> $LOGFILE 2>&1
        if [ $? -eq 0 ]; then
          while :; do
            askYN "$EXTPACKAGES package[s] will be removed. Continue?" "N"
            if [ $response = "no" ]; then
              askYN "Exit?" "N"
              if [ $response = "yes" ]; then
                removeErrorMessage
              fi
            else
              break
            fi
          done
        fi
      fi
    fi
  fi
}

removeErrorMessage() {
  echo "Can not remove packages. Check $LOGFILE for details."
  echo "Exiting - the system is unchanged"
  exit 1
}

removeExistingPackages() {
  echo ""
  echo "Removing existing packages"
  echo ""
  if [ $ISUBUNTU = "true" ] && [ ! -z "$EXTPACKAGES" ]; then
    echo -n "$EXTPACKAGES ..."
    apt-get remove -y $EXTPACKAGES >> $LOGFILE 2>&1
    if [ $? -ne 0 ]; then
      echo "Failed to remove $EXTPACKAGES"
      exit 1;
    fi
    echo "done"
  fi

  for p in $INSTALLED_PACKAGES; do
    if [ $p = "zimbra-core" ]; then
      MOREPACKAGES="$MOREPACKAGES zimbra-core"
      continue
    fi
    if [ $p = "zimbra-apache" ]; then
      MOREPACKAGES="zimbra-apache $MOREPACKAGES"
      continue
    fi
    if [ $p = "zimbra-store" ]; then

      isInstalled "zimbra-archiving"
      if [ x$PKGINSTALLED != "x" ]; then
        echo -n "   zimbra-archiving..."
        $PACKAGERM zimbra-archiving >/dev/null 2>&1
        echo "done"
      fi

      isInstalled "zimbra-chat"
      if [ x$PKGINSTALLED != "x" ]; then
        echo -n "   zimbra-chat..."
        $PACKAGERM zimbra-chat >/dev/null 2>&1
        echo "done"
      fi

      isInstalled "zimbra-drive"
      if [ x$PKGINSTALLED != "x" ]; then
        echo -n "   zimbra-drive..."
        $PACKAGERM zimbra-drive >/dev/null 2>&1
        echo "done"
      fi

      isInstalled "zimbra-network-modules-ng"
      if [ x$PKGINSTALLED != "x" ]; then
        echo -n "   zimbra-network-modules-ng..."
        $PACKAGERM zimbra-network-modules-ng >/dev/null 2>&1
        echo "done"
      fi
    fi
    isInstalled $p

    if [ x$PKGINSTALLED != "x" ]; then
      echo -n "   $p..."
	  if [ x$p = "xzimbra-memcached" ]; then
        isInstalled "zimbra-memcached-base"
        if [ x$PKGINSTALLED != "x" ]; then
          $REPORM zimbra-memcached-base >>$LOGFILE 2>&1
        else
          $PACKAGERM $p > /dev/null 2>&1
        fi
      else
        $PACKAGERM $p > /dev/null 2>&1
	  fi
      if [ x$p = "xzimbra-dnscache" ]; then
        $REPORM zimbra-dnscache-base >>$LOGFILE 2>&1
      fi
      if [ x$p = "xzimbra-ldap" ]; then
        $REPORM zimbra-ldap-base >>$LOGFILE 2>&1
      fi
      if [ x$p = "xzimbra-mta" ]; then
        $REPORM zimbra-mta-base >>$LOGFILE 2>&1
      fi
      if [ x$p = "xzimbra-proxy" ]; then
        $REPORM zimbra-proxy-base >>$LOGFILE 2>&1
      fi
      if [ x$p = "xzimbra-snmp" ]; then
        $REPORM zimbra-snmp-base >>$LOGFILE 2>&1
      fi
      if [ x$p = "xzimbra-spell" ]; then
        $REPORM zimbra-spell-base >>$LOGFILE 2>&1
      fi
      if [ x$p = "xzimbra-store" ]; then
        $REPORM zimbra-store-base >>$LOGFILE 2>&1
      fi
      echo "done"
    fi
  done

  for p in $MOREPACKAGES; do
    isInstalled $p
    if [ x$PKGINSTALLED != "x" ]; then
      echo -n "   $p..."
      $PACKAGERM $p > /dev/null 2>&1
      if [ x$p = "xzimbra-core" ]; then
        $REPORM zimbra-base >>$LOGFILE 2>&1
      fi
      if [ x$p = "xzimbra-apache" ]; then
        $REPORM zimbra-apache-base >>$LOGFILE 2>&1
      fi
      echo "done"
    fi
  done
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
      if ( test -x "/opt/zimbra/common/sbin/slapcat" || test -x "/opt/zimbra/openldap/sbin/slapcat" ) && test x"$UNINSTALL" != "xyes" && test x"$REMOVE" != "xyes"; then
        if [ -d "/opt/zimbra/data/ldap/config" ]; then
          echo ""
          echo -n "Backing up the ldap database..."
          tmpfile=`mktemp -t slapcat.XXXXXX 2> /dev/null` || { echo "Failed to create tmpfile"; exit 1; }
          mkdir -p /opt/zimbra/data/ldap
          chown -R zimbra:zimbra /opt/zimbra/data/ldap
          runAsZimbra "/opt/zimbra/libexec/zmslapcat /opt/zimbra/data/ldap"
          if [ $? != 0 ]; then
            echo "failed."
          else
            echo "done."
          fi
          chmod 640 /opt/zimbra/data/ldap/ldap.bak
          if [ -x /opt/zimbra/libexec/zmslapadd ]; then
            if [ -f /opt/zimbra/data/ldap/config/cn\=config/olcDatabase\=\{3\}mdb.ldif -o -f /opt/zimbra/data/ldap/config/cn\=config/olcDatabase\=\{3\}hdb.ldif ]; then
              echo ""
              echo -n "Backing up the ldap accesslog database..."
              runAsZimbra "/opt/zimbra/libexec/zmslapcat -a /opt/zimbra/data/ldap"
              if [ $? != 0 ]; then
                echo "failed."
              else
                echo "done."
              fi
              chmod 640 /opt/zimbra/data/ldap/ldap-accesslog.bak
            fi
          fi
        fi
      fi
      if [ x"$OLD_LDR_PATH" != "x" ]; then
        LD_LIBRARY_PATH=$OLD_LDR_PATH
      fi
    fi
    if [ "$UPGRADE" = "yes" -a "$POST87UPGRADE" = "true" -a "$FORCE_UPGRADE" != "yes" -a "$ZM_CUR_BUILD" != "$ZM_INST_BUILD" ]; then
      echo "Upgrading the remote packages"
    else
      removeExistingPackages
    fi
    if egrep -q '^%zimbra[[:space:]]' /etc/sudoers 2>/dev/null; then
      local sudotmp=`mktemp -t zsudoers.XXXXX 2> /dev/null` || { echo "Failed to create tmpfile"; exit 1; }
      SUDOMODE=`perl -e 'my $mode=(stat("/etc/sudoers"))[2];printf("%04o\n",$mode & 07777);'`
      egrep -v "^\%zimbra[[:space:]]" /etc/sudoers > $sudotmp
      mv -f $sudotmp /etc/sudoers
      chmod $SUDOMODE /etc/sudoers
    fi
    echo ""
    if [ -d "/opt/zimbra/jetty/webapps" ]; then
      echo "Removing deployed webapp directories"
      deleteWebApp zimbra jetty
      deleteWebApp zimbraAdmin jetty
      deleteWebApp service jetty
      /bin/rm -rf /opt/zimbra/jetty/work
    fi
  fi

  if [ $REMOVE = "yes" ]; then
    isInstalled zimbra-base
    if [ x$PKGINSTALLED != "x" ]; then
        echo -n "   zimbra-base..."
        $REPORM zimbra-base >>$LOGFILE 2>&1
        echo "done"
    fi

    if [ ! -L "/opt/zimbra" ]; then
      echo ""
      echo "Removing /opt/zimbra"
      umount /opt/zimbra/amavisd/tmp > /dev/null 2>&1
      MOUNTPOINTS=`mount | awk '{print $3}' | grep /opt/zimbra/`
      for mp in $MOUNTPOINTS; do
        if [ x$mp != "x/opt/zimbra" ]; then
          /bin/rm -rf ${mp}/*
          umount -f ${mp}
        fi
      done

      for i in `ls /opt/zimbra`; do
        if [ x$i != "xlost+found" ]; then
          /bin/rm -rf /opt/zimbra/$i
        fi
      done

      if [ -e "/opt/zimbra/.enable_replica" ]; then
        /bin/rm -f /opt/zimbra/.enable_replica
      fi

      if [ -x /usr/bin/crontab ]; then
        echo -n "Removing zimbra crontab entry..."
        /usr/bin/crontab -u zimbra -r 2> /dev/null
        echo "done."
      fi

      if [ -L /usr/sbin/sendmail ]; then
        if [ -x /bin/readlink ]; then
          SMPATH=$(/bin/readlink /usr/sbin/sendmail)
          if [ x$SMPATH = x"/opt/zimbra/postfix/sbin/sendmail" -o x$SMPATH = x"/opt/zimbra/common/sbin/sendmail" ]; then
            /bin/rm -f /usr/sbin/sendmail
          fi
        fi
      fi

      if [ -L /etc/aliases ]; then
        if [ -x /bin/readlink ]; then
          SMPATH=$(/bin/readlink /etc/aliases)
          if [ x$SMPATH = x"/opt/zimbra/postfix/conf/aliases" -o x$SMPATH = x"/opt/zimbra/common/conf/aliases" ]; then
            rm -f /etc/aliases
          fi
        fi
      fi

      if [ -f /etc/syslog-ng/syslog-ng.conf ]; then
        egrep -q 'zimbra' /etc/syslog-ng/syslog-ng.conf
        if [ $? = 0 ]; then
          echo -n "Cleaning up /etc/syslog-ng/syslog-ng.conf..."
          sed -i -e '/zimbra/d' /etc/syslog-ng/syslog-ng.conf
          sed -i -e 's/filter f_messages   { not facility(news, mail) and not filter(f_iptables) and/filter f_messages   { not facility(news, mail) and not filter(f_iptables); };/' /etc/syslog-ng/syslog-ng.conf
          sed -i -e 's/^                               local4, local5, local6, local7) and not/                               local4, local5, local6, local7); };/' /etc/syslog-ng/syslog-ng.conf
          if [ -x /sbin/rcsyslog ]; then
            /sbin/rcsyslog restart > /dev/null 2>&1
            echo "done."
          else
            echo "Unable to restart syslog-ng service. Please do it manually."
          fi
        fi
      elif [ -f /etc/rsyslog.conf ]; then
        if [ -d /etc/rsyslog.d ]; then
          if [ -f /etc/rsyslog.d/60-zimbra.conf ]; then
            echo -n "Cleaning up /etc/rsyslog.d..."
            rm -f /etc/rsyslog.d/60-zimbra.conf
            if [ -x /usr/bin/systemctl ]; then
              /usr/sbin/systemctl restart rsyslog.service >/dev/null 2>&1
              echo "done."
            elif [ -x /usr/bin/service ]; then
              /usr/sbin/service rsyslog restart >/dev/null 2>&1
              echo "done."
            elif [ -x /etc/init.d/rsyslog ]; then
              /etc/init.d/rsyslog restart > /dev/null 2>&1
              echo "done."
            else
              echo "Unable to restart rsyslog service. Please do it manually."
            fi
          else
            egrep -q 'zimbra' /etc/rsyslog.conf
            if [ $? = 0 ]; then
              echo -n "Cleaning up /etc/rsyslog.conf..."
              sed -i -e '/zimbra/d' /etc/rsyslog.conf
              if [ $PLATFORM = "RHEL6_64" -o $PLATFORM = "RHEL7_64" ]; then
                sed -i -e 's/^*.info;local0.none;local1.none;mail.none;auth.none/*.info/' /etc/rsyslog.conf
                sed -i -e 's/^*.info;local0.none;local1.none;auth.none/*.info/' /etc/rsyslog.conf
              fi
              if [ -x /usr/bin/systemctl ]; then
                /usr/sbin/systemctl restart rsyslog.service >/dev/null 2>&1
                echo "done."
              elif [ -x /usr/bin/service ]; then
                /usr/sbin/service rsyslog restart >/dev/null 2>&1
                echo "done."
              elif [ -x /etc/init.d/rsyslog ]; then
                /etc/init.d/rsyslog restart > /dev/null 2>&1
                echo "done."
              else
                echo "Unable to restart rsyslog service. Please do it manually."
              fi
            fi
          fi
        fi
      fi

      echo -n "Cleaning up zimbra init scripts..."
      if [ -x /sbin/chkconfig ]; then
        /sbin/chkconfig zimbra off 2> /dev/null
        /sbin/chkconfig --del zimbra 2> /dev/null
      else
        /bin/rm -f /etc/rc*.d/S99zimbra 2> /dev/null
        /bin/rm -f /etc/rc*.d/K01zimbra 2> /dev/null
      fi
      if [ -f /etc/init.d/zimbra ]; then
        /bin/rm -f /etc/init.d/zimbra
      fi
      echo "done."

      if [ -f /etc/logrotate.d/zimbra ]; then
        echo -n "Cleaning up /etc/logrotate.d/zimbra..."
        /bin/rm -f /etc/logrotate.d/zimbra 2> /dev/null
        echo "done."
      fi

      if [ -f /etc/security/limits.conf ]; then
        echo -n "Cleaning up /etc/security/limits.conf..."
        egrep -q '^zimbra|^liquid' /etc/security/limits.conf
        if [ $? = 0 ]; then
          sed -i -e '/^zimbra/d' -e '/^liquid/d' /etc/security/limits.conf
        fi
        echo "done."
      fi

      if [ -f /etc/security/limits.d/80-zimbra.conf ]; then
        echo -n "Cleaning up /etc/security/limits.d/80-zimbra.conf..."
        rm -f /etc/security/limits.d/80-zimbra.conf
        echo "done."
      fi

      if [ -f /etc/security/limits.d/10-zimbra.conf ]; then
        echo -n "Cleaning up /etc/security/limits.d/10-zimbra.conf..."
        rm -f /etc/security/limits.d/10-zimbra.conf
        echo "done."
      fi

      for mp in $MOUNTPOINTS; do
        if [ x$mp != "x/opt/zimbra" ]; then
          mkdir -p ${mp}
          mount ${mp}
        fi
      done

      echo ""
      echo "Finished removing Zimbra Collaboration Server."
      echo ""
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
      if [ -x /sbin/chkconfig ]; then
        /sbin/chkconfig postfix off
      fi
    fi
  fi

  if [ -f /var/lock/subsys/sendmail ]; then
    askYN "Sendmail appears to be running.  Shut it down?" "Y"
    if [ $response = "yes" ]; then
      /etc/init.d/sendmail stop
      if [ -x /sbin/chkconfig ]; then
        /sbin/chkconfig sendmail off
      fi
    fi
  fi

  echo ""
  echo "Checking for exim4"
  echo ""

  if [ -f /var/run/exim4/exim.pid ]; then
    askYN "Exim4 appears to be running.  Shut it down?" "Y"
    if [ $response = "yes" ]; then
      /etc/init.d/exim4 stop
      /usr/sbin/update-rc.d -f exim4 remove
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
        if [ -x /sbin/chkconfig ]; then
          /sbin/chkconfig mysqld off
        fi
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

configurePackageServer() {
  echo -e ""
  response="no"
  TMP_PACKAGE_SERVER="repo.zimbra.com"
  if [ x"$USE_ZIMBRA_PACKAGE_SERVER" = "x" ]; then
    askYN "Use Zimbra's package repository" "Y"
    if [ $response = "yes" ]; then
      USE_ZIMBRA_PACKAGE_SERVER="yes"
      PACKAGE_SERVER="repo.zimbra.com"
      response="no"
      echo $HOSTNAME | egrep -qe 'eng.vmware.com$|eng.zimbra.com$|lab.zimbra.com$' > /dev/null 2>&1
      if [ $? = 0 ]; then
        askYN "Use internal development repo" "N"
        if [ $response = "yes" ]; then
          PACKAGE_SERVER="repo-dev.eng.zimbra.com"
        else
          response="no"
          askYN "Use internal production mirror" "N"
          if [ $response = "yes" ]; then
            PACKAGE_SERVER="repo.eng.zimbra.com"
          fi
        fi
      fi
    fi
  fi

  if [ x"$USE_ZIMBRA_PACKAGE_SERVER" = "xyes" ]; then # Handle automated installations correctly
    echo "";
    if [ x"$PACKAGE_SERVER" = "x" ]; then # Allow config files w/ no PACKAGE_SERVER variable set
      PACKAGE_SERVER=$TMP_PACKAGE_SERVER
    fi
    echo $PLATFORM | egrep -q "UBUNTU|DEBIAN"
    if [ $? = 0 ]; then
      if [ $PLATFORM = "UBUNTU16_64" ]; then
        repo="xenial"
      elif [ $PLATFORM = "UBUNTU14_64" ]; then
        repo="trusty"
      elif [ $PLATFORM = "UBUNTU12_64" ]; then
        repo="precise"
      else
        print "Aborting, unknown platform: $PLATFORM"
        exit 1
      fi
      apt-key list | grep -w 9BE6ED79 >/dev/null
      if [ $? -ne 0 ]; then
        echo "Importing Zimbra GPG key"
        apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 9BE6ED79 >>$LOGFILE 2>&1
        if [ $? -ne 0 ]; then
          echo "ERROR: Unable to retrive Zimbra GPG key for package validation"
          echo "Please fix system to allow normal package installation before proceeding"
          exit 1
        fi
      fi
      echo
      echo "Configuring package repository"
      apt-get install -y apt-transport-https >>$LOGFILE 2>&1
      if [ $? -ne 0 ]; then
        echo "ERROR: Unable to install packages via apt-get"
        echo "Please fix system to allow normal package installation before proceeding"
        exit 1
      fi
cat > /etc/apt/sources.list.d/zimbra.list << EOF
deb     [arch=amd64] https://$PACKAGE_SERVER/apt/87 $repo zimbra
deb-src [arch=amd64] https://$PACKAGE_SERVER/apt/87 $repo zimbra
EOF
      apt-get update >>$LOGFILE 2>&1
      if [ $? -ne 0 ]; then
        echo "ERROR: Unable to install packages via apt-get"
        echo "Please fix system to allow normal package installation before proceeding"
        exit 1
      fi
    else
      if [ $PLATFORM = "RHEL6_64" ]; then
        repo="rhel6"
      elif [ $PLATFORM = "RHEL7_64" ]; then
        repo="rhel7"
      else
        print "Aborting, unknown platform: $PLATFORM"
        exit 1
      fi
      rpm -q gpg-pubkey-0f30c305-5564be70 > /dev/null
      if [ $? -ne 0 ]; then
        echo "Importing Zimbra GPG key"
        rpm --import https://files.zimbra.com/downloads/security/public.key >>$LOGFILE 2>&1
        if [ $? -ne 0 ]; then
          echo "ERROR: Unable to retrive Zimbra GPG key for package validation"
          echo "Please fix system to allow normal package installation before proceeding"
          exit 1
        fi
      fi
      echo
      echo "Configuring package repository"
cat > /etc/yum.repos.d/zimbra.repo <<EOF
[zimbra]
name=Zimbra RPM Repository
baseurl=https://$PACKAGE_SERVER/rpm/87/$repo
gpgcheck=1
enabled=1
EOF
      yum --disablerepo=* --enablerepo=zimbra clean metadata >>$LOGFILE 2>&1
      yum check-update --disablerepo=* --enablerepo=zimbra --noplugins >>$LOGFILE 2>&1
      if [ $? -ne 0 -a $? -ne 100 ]; then
        echo "ERROR: yum check-update failed"
        echo "Please validate ability to install packages"
        exit 1
      fi
    fi
  fi
}

getInstallPackages() {

  echo ""
  if [ $UPGRADE = "yes" ]; then
    echo "Scanning for any new or additional packages available for installation"
    echo "Existing packages will be upgraded"
    echo "    Upgrading zimbra-core"
  else
    echo "Select the packages to install"
  fi

  APACHE_SELECTED="no"
  LOGGER_SELECTED="no"
  STORE_SELECTED="no"
  MTA_SELECTED="no"

  for i in $AVAILABLE_PACKAGES; do
    if [ $i = "zimbra-core" ]; then
      continue
    fi
    # Reset the response before processing the next package.
    response="no"

    # If we're upgrading, and it's installed, don't ask stoopid questions
    if [ $UPGRADE = "yes" ]; then
      echo $INSTALLED_PACKAGES | grep $i > /dev/null 2>&1
      if [ $? = 0 ]; then
        echo "    Upgrading $i"
        if [ $i = "zimbra-mta" ]; then
          CONFLICTS="no"
          for j in $CONFLICT_PACKAGES; do
            conflictInstalled $j
            if [ "x$CONFLICTINSTALLED" != "x" ]; then
              echo "     Conflicting package: $CONFLICTINSTALLED"
              CONFLICTS="yes"
            fi
          done
          if [ $CONFLICTS = "yes" ]; then
            echo ""
            echo "###ERROR###"
            echo ""
            echo "One or more package conflicts exists."
            echo "Please remove them before running this installer."
            echo ""
            echo "Installation cancelled."
            echo ""
            exit 1
          fi
        fi
        INSTALL_PACKAGES="$INSTALL_PACKAGES $i"
        if [ $i = "zimbra-apache" ]; then
          APACHE_SELECTED="yes"
        elif [ $i = "zimbra-logger" ]; then
          LOGGER_SELECTED="yes"
        elif [ $i = "zimbra-store" ]; then
          STORE_SELECTED="yes"
        elif [ $i = "zimbra-mta" ]; then
          MTA_SELECTED="yes"
        fi
        continue
      fi
    fi

    if [ $UPGRADE = "yes" ]; then

      if [ $i = "zimbra-archiving" ]; then
        if [ $STORE_SELECTED = "yes" ]; then
          askYN "Install $i" "N"
        fi

      elif [ $i = "zimbra-chat" ]; then
        if [ $STORE_SELECTED = "yes" ]; then
          askYN "Install $i" "N"
        fi

      elif [ $i = "zimbra-drive" ]; then
        if [ $STORE_SELECTED = "yes" ]; then
          askYN "Install $i" "N"
        fi

      elif [ $i = "zimbra-network-modules-ng" ]; then
        if [ $STORE_SELECTED = "yes" ]; then
          askYN "Install $i" "N"
        fi

      elif [ $i = "zimbra-rpost" ]; then
        if [ $STORE_SELECTED = "yes" ]; then
          INSTALL_PACKAGES="$INSTALL_PACKAGES zimbra-rpost"
        fi

      else
        askYN "Install $i" "N"
      fi

    else

      if [ $i = "zimbra-archiving" ]; then
        # only prompt to install archiving if zimbra-store is selected
        if [ $STORE_SELECTED = "yes" ]; then
          askYN "Install $i" "N"
        fi

      elif [ $i = "zimbra-convertd" ]; then
        if [ $STORE_SELECTED = "yes" ]; then
          askYN "Install $i" "Y"
        else
          askYN "Install $i" "N"
        fi

      elif [ $i = "zimbra-chat" ]; then
        if [ $STORE_SELECTED = "yes" ]; then
          askYN "Install $i" "Y"
        fi

      elif [ $i = "zimbra-drive" ]; then
        if [ $STORE_SELECTED = "yes" ]; then
          askYN "Install $i" "Y"
        fi

      elif [ $i = "zimbra-network-modules-ng" ]; then
        if [ $STORE_SELECTED = "yes" ]; then
          askYN "Install $i" "Y"
        fi

      elif [ $i = "zimbra-imapd" ]; then
          askYN "Install $i (BETA - for evaluation only)" "N"

      elif [ $i = "zimbra-dnscache" ]; then
        if [ $MTA_SELECTED = "yes" ]; then
          askYN "Install $i" "Y"
        else
          askYN "Install $i" "N"
        fi
      else
        if [ $i = "zimbra-rpost" ]; then
          if [ $STORE_SELECTED = "yes" ]; then
            INSTALL_PACKAGES="$INSTALL_PACKAGES zimbra-rpost"
          fi
        else
          askYN "Install $i" "Y"
        fi
      fi
    fi

    if [ $response = "yes" ]; then
      if [ $i = "zimbra-logger" ]; then
        LOGGER_SELECTED="yes"
      elif [ $i = "zimbra-store" ]; then
        STORE_SELECTED="yes"
      elif [ $i = "zimbra-apache" ]; then
        APACHE_SELECTED="yes"
      elif [ $i = "zimbra-mta" ]; then
        MTA_SELECTED="yes"
      fi

      if [ $i = "zimbra-network-modules-ng" ]; then
          echo "###WARNING###"
          echo ""
          echo "Network Modules NG needs to bind on TCP ports 8735 and 8736 in order"
          echo "to operate, for inter-instance communication."
          echo "Please verify no other service listens on these ports and that "
          echo "ports 8735 and 8736 are properly filtered from public access "
          echo "by your firewall."
          echo ""
          echo "Please remember that the Backup NG module needs to be initialized in order"
          echo "to be functional. This is a one-time operation only that can be performed"
          echo "by clicking the 'Initialize' button within the Backup section of the"
          echo "Network NG Modules in the Administration Console or by running"
          echo "\`zxsuite backup doSmartScan\` as the zimbra user."
          echo ""
      fi

      if [ $i = "zimbra-mta" ]; then
        CONFLICTS="no"
        for j in $CONFLICT_PACKAGES; do
          conflictInstalled $j
          if [ "x$CONFLICTINSTALLED" != "x" ]; then
            echo "     Conflicting package: $CONFLICTINSTALLED"
            CONFLICTS="yes"
          fi
        done
        if [ $CONFLICTS = "yes" ]; then
          echo ""
          echo "###ERROR###"
          echo ""
          echo "One or more package conflicts exists."
          echo "Please remove them before running this installer."
          echo ""
          echo "Installation cancelled."
          echo ""
          exit 1
        fi
      fi
      if [ $i = "zimbra-spell" -a $APACHE_SELECTED = "no" ]; then
        APACHE_SELECTED="yes"
        INSTALL_PACKAGES="$INSTALL_PACKAGES zimbra-apache"
      fi

      if [ $i = "zimbra-convertd" -a $APACHE_SELECTED = "no" ]; then
        APACHE_SELECTED="yes"
        INSTALL_PACKAGES="$INSTALL_PACKAGES zimbra-apache"
      fi

      INSTALL_PACKAGES="$INSTALL_PACKAGES $i"
    fi

  done
  checkRequiredSpace

  isInstalled zimbra-store
  isToBeInstalled zimbra-store
  if [ "x$PKGINSTALLED" != "x" -o "x$PKGTOBEINSTALLED" != "x" ]; then
    checkStoreRequirements
  fi

  echo ""
  echo "Installing:"
  for i in $INSTALL_PACKAGES; do
    echo "    $i"
  done
}

deleteWebApp() {
  WEBAPPNAME=$1
  CONTAINERDIR=$2

  /bin/rm -rf /opt/zimbra/$CONTAINERDIR/webapps/$WEBAPPNAME
  /bin/rm -rf /opt/zimbra/$CONTAINERDIR/webapps/$WEBAPPNAME.war
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
  cp -f /opt/zimbra/conf/crontabs/crontab /tmp/crontab.zimbra

  isInstalled zimbra-store
  if [ x$PKGINSTALLED != "x" ]; then
    cat /opt/zimbra/conf/crontabs/crontab.store >> /tmp/crontab.zimbra
  fi

  isInstalled zimbra-logger
  if [ x$PKGINSTALLED != "x" ]; then
    cat /opt/zimbra/conf/crontabs/crontab.logger >> /tmp/crontab.zimbra
  fi

  echo "# ZIMBRAEND -- DO NOT EDIT ANYTHING BETWEEN THIS LINE AND ZIMBRASTART" >> /tmp/crontab.zimbra
  cat /tmp/crontab.zimbra.proc >> /tmp/crontab.zimbra

  crontab -u zimbra /tmp/crontab.zimbra
}

isToBeInstalled() {
  pkg=$1
  PKGTOBEINSTALLED=""
  for i in $INSTALL_PACKAGES; do
    if [ "x$pkg" = "x$i" ]; then
      PKGTOBEINSTALLED=$i
      continue
    fi
  done
}

isInstalled() {
  pkg=$1
  PKGINSTALLED=""
  if [ "x$PACKAGEEXT" = "xrpm" ]; then
    $PACKAGEQUERY $pkg >/dev/null 2>&1
    if [ $? = 0 ]; then
      PKGVERSION=`$PACKAGEQUERY $pkg 2> /dev/null | sort -u`
      PKGINSTALLED=`$PACKAGEQUERY $pkg | sed -e 's/\.[a-zA-Z].*$//' 2> /dev/null`
    fi
  elif [ "x$PACKAGEEXT" = "xccs" ]; then
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
        echo $Q | grep 'deinstall ok' > /dev/null 2>&1
        if [ $? != 0 ]; then
          PKGVERSION=`$PACKAGEQUERY $pkg | egrep '^Version: ' | sed -e 's/Version: //' 2> /dev/null`
          PKGINSTALLED="${pkg}-${PKGVERSION}"
        fi
      fi
    fi
  fi
}

conflictInstalled() {
  pkg=$1
  CONFLICTINSTALLED=""
  QP=`dpkg-query -W -f='\${Package}: \${Provides}\n' '*' | grep ": .*$pkg" | sed -e 's/:.*//'`
  while [ "x$QP" != "x" ]; do
    QF=`echo $QP | sed -e 's/\s.*//'`
    QP=`echo $QP | sed -e 's/\S*\s*//'`
    isInstalled $QF
    if [ x$PKGINSTALLED != "x" ]; then
      CONFLICTINSTALLED=$QF
      if [ x$CONFLICTINSTALLED = "xzimbra-mta" ]; then
        CONFLICTINSTALLED=""
      fi
    fi
  done
}

suggestedVersion() {
  pkg=$1
  PKGINSTALLED=""
  if [ "x$PACKAGEEXT" = "xrpm" ]; then
    $PACKAGEQUERY $pkg >/dev/null 2>&1
    if [ $? = 0 ]; then
      PKGINSTALLED=`$PACKAGEQUERY $pkg | sed -e 's/\.[a-zA-Z].*$//' 2> /dev/null`
    else
      sugpkg=${pkg%-*}
      PKGVERSION=`$PACKAGEQUERY $sugpkg 2> /dev/null | sort -u | grep -v 'not installed$'`
      PKGVERSION=${PKGVERSION:-notfound}
    fi
  elif [ $PACKAGEEXT = "ccs" ]; then
    $PACKAGEQUERY $pkg >/dev/null 2>&1
    if [ $? = 0 ]; then
      PKGINSTALLED=`$PACKAGEQUERY $pkg | sed -e 's/\.[a-zA-Z].*$//' 2> /dev/null`
    else
      sugpkg=${pkg%=*}
      PKGVERSION=`$PACKAGEQUERY $sugpkg 2> /dev/null | sort -u`
    fi
  else
    sugpkg=${pkg%-*}
    sugversion=${pkg#*-}
    Q=`$PACKAGEQUERY $sugpkg 2>/dev/null | egrep '^Status: ' `
    if [ "x$Q" != "x" ]; then
      echo $Q | grep 'not-installed' > /dev/null 2>&1
      if [ $? != 0 ]; then
        PKGVERSION=`$PACKAGEVERSION $sugpkg 2> /dev/null`
        if [ x"$sugversion" != x"$sugpkg" ]; then
	  if [[ "$PKGVERSION" == "$sugversion"* ]]; then
            PKGINSTALLED="${sugpkg}-${PKGVERSION}"
          fi
        else
          PKGINSTALLED="${sugpkg}-${PKGVERSION}"
        fi
      fi
    fi
  fi
}

getPlatformVars() {
  CONFLICT_PACKAGES=""
  echo $PLATFORM | egrep -q "UBUNTU|DEBIAN"
  if [ $? = 0 ]; then
    ISUBUNTU=true
    checkUbuntuRelease
    REPOINST='apt-get install -y'
    PACKAGEDOWNLOAD='apt-get --download-only install -y --force-yes'
    REPORM='apt-get -y --purge purge'
    PACKAGEINST='dpkg -i'
    PACKAGERM='dpkg --purge'
    PACKAGERMSIMULATE='dpkg --purge --dry-run'
    PACKAGEQUERY='dpkg -s'
    PACKAGEEXT='deb'
    PACKAGEVERSION="dpkg-query -W -f \${Version}"
    CONFLICT_PACKAGES="mail-transport-agent"
    if [ $PLATFORM = "UBUNTU12_64" -o $PLATFORM = "UBUNTU14_64" -o $PLATFORM = "UBUNTU16_64" ]; then
      STORE_PACKAGES="libreoffice"
    fi
    LocalPackageDepList() {
       local pkg_f="$1"; shift;
       LANG="en_US.UTF-8" LANGUAGE="en_US" \
         dpkg -I "$pkg_f" \
            | sed -n -e '/Depends:/ { s/.*:\s*//; s/,\s*/\n/g; p; }' \
            | sed -n -e '/^zimbra-/ { s/\s*(.*//; p; }'
    }
    RepoPackageDepList() {
       local pkg="$1"; shift;
       LANG="en_US.UTF-8" LANGUAGE="en_US" \
         apt-cache depends "^$pkg$" \
            | sed -e 's/[<]\([a-z]\)/\1/g' \
                  -e 's/\([a-z]\)[>]/\1/g' \
            | sed -n -e '/Depends:\s*zimbra-/ { s/.*:\s*//; p; }'
    }
    LocatePackageInRepo() {
       local pkg="$1"; shift;
       LANG="en_US.UTF-8" LANGUAGE="en_US" \
         apt-cache search --names-only "^$pkg" 2>/dev/null
    }
  else
      ISUBUNTU=false
      REPOINST='yum -y install'
      REPORM='yum erase -y'
      PACKAGEINST='yum -y --disablerepo=* localinstall -v'
      # TODO: This should kept in os-requirement.
      yum -y install --downloadonly dummyxxxxxxx 2>&1 | grep "no such option: --downloadonly" >/dev/null 2>&1
      if [ $? -eq 0 ]; then
        echo "Installing yum-plugin-downloadonly."
        yum -y install yum-plugin-downloadonly
        if [ $? -ne 0 ]; then
          echo "yum --downloadonly should be available. To continue installation."
          exit 1;
        fi
      fi
      PACKAGEDOWNLOAD='yum -y install --downloadonly'
      PACKAGERM='yum -y --disablerepo=* erase -v'
      PACKAGERMSIMULATE='yum -n --disablerepo=* erase -v'
      PACKAGEEXT='rpm'
      PACKAGEQUERY='rpm -q'
      PACKAGEVERIFY='rpm -K'
      if [ $PLATFORM = "RHEL6_64" -o $PLATFORM = "RHEL7_64" ]; then
         STORE_PACKAGES="libreoffice libreoffice-headless"
      fi
      LocalPackageDepList() {
         local pkg_f="$1"; shift;
         LANG="en_US.UTF-8" LANGUAGE="en_US" \
            rpm -q --requires -p "$pkg_f" \
               | sed -n -e '/^zimbra-/ { s/\s*[<=>].*//; p; }'
      }
      RepoPackageDepList() {
         local pkg="$1"; shift;
         LANG="en_US.UTF-8" LANGUAGE="en_US" \
            yum deplist "$pkg" \
               | sed -n -e '/dependency:\s*zimbra-/ { s/^[^:]*:\s*//; s/\s*[<=>].*//; p }'
      }
      LocatePackageInRepo() {
         local pkg="$1"; shift;
         LANG="en_US.UTF-8" LANGUAGE="en_US" \
            yum --showduplicates list available -q -e 0 "$pkg" 2>/dev/null
      }
  fi
}
