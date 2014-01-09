#!/bin/bash
# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013 Zimbra Software, LLC.
# 
# The contents of this file are subject to the Zimbra Public License
# Version 1.4 ("License"); you may not use this file except in
# compliance with the License.  You may obtain a copy of the License at
# http://www.zimbra.com/license.
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied.
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
  if [ x$DEFAULTFILE = "x" -o x$CLUSTERUPGRADE = "xyes" ]; then
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
    if [ x$DEFAULTFILE = "x" -o x$CLUSTERUPGRADE = "xyes" ]; then
      askYN "Do you agree with the terms of the software license agreement?" "N"
      if [ $response != "yes" ]; then
        exit
      fi
    fi
    echo ""
    echo ""
  fi
  if [ -f ${MYDIR}/docs/oracle_jdk_eula.txt ]; then
    cat $MYDIR/docs/oracle_jdk_eula.txt
    echo ""
    echo ""
    if [ x$DEFAULTFILE = "x" -o x$CLUSTERUPGRADE = "xyes" ]; then
      askYN "Do you agree with the terms of the software license agreement?" "N"
      if [ $response != "yes" ]; then
        exit
      fi
    fi
  fi
  echo ""
}

isFQDN() {
  #fqdn is > 2 dots.  because I said so.
  if [ x"$1" = "xdogfood" ]; then
    echo 1
    return
  fi

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
INSTALL_PACKAGES="$INSTALL_PACKAGES"
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
EOF

}

loadConfig() {
  FILE=$1

  if [ ! -f "$FILE" ]; then
    echo ""
    echo "*** ERROR - can't find configuration file $FILE"
    echo ""
    exit 1
  fi
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

  if [ x"$CLUSTERTYPE" = "xstandby" ]; then
    return
  fi

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
				perl -I/opt/zimbra/zimbramon/lib bin/zmdbintegrityreport -v -r
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

  if [ x"$CLUSTERTYPE" = "xstandby" ]; then
    return
  fi

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
        if [ x$DEFAULTFILE = "x" -o x$CLUSTERUPGRADE = "xyes" ]; then
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

  if [ "x$DISTRIB_ID" = "xUbuntu" -a "x$DISTRIB_RELEASE" != "x10.04" -a "x$DISTRIB_RELEASE" != "x12.04" ]; then
    echo "WARNING: ZCS is currently only supported on Ubuntu Server 10.04 and 12.04 LTS."
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

  echo "Checking for prerequisites..."
  #echo -n "    NPTL..."
  /usr/bin/getconf GNU_LIBPTHREAD_VERSION | grep NPTL > /dev/null 2>&1
  if [ $? != 0 ]; then
    echo "     MISSING:  NPTL"
    GOOD="no"
  else
    echo "     FOUND: NPTL"
  fi

  for i in $PREREQ_PACKAGES; do
    #echo -n "    $i..."
    isInstalled $i
    if [ "x$PKGINSTALLED" != "x" ]; then
      echo "     FOUND: $PKGINSTALLED"
    else
      echo "     MISSING: $i"
      GOOD="no"
    fi
  done

  for i in $PREREQ_LIBS; do
    #echo -n "    $i..."
    if [ -L $i -o -f $i ]; then
      echo "     FOUND: $i"
    else
      echo "     MISSING: $i"
      GOOD="no"
    fi
  done

  echo ""

  SUGGESTED="yes"
  echo "Checking for suggested prerequisites..."
  for i in $PRESUG_PACKAGES; do
    #echo -n "     $i..."
    PKGVERSION="notfound"
    suggestedVersion $i
    if [ "x$PKGINSTALLED" != "x" ]; then
       echo "     FOUND: $i"
    else
       if [ "x$PKGVERSION" = "xnotfound" ]; then
         echo "     MISSING: $i does not appear to be installed."
       else
         echo "     Unable to find expected $i.  Found version $PKGVERSION instead."
       fi
       SUGGESTED="no"
    fi
  done

  if [ $SUGGESTED = "no" -a x$DEFAULTFILE = "x" ]; then
    echo ""
    echo "###WARNING###"
    echo ""
    echo "The suggested version of one or more packages is not installed."
    echo "This could cause problems with the operation of Zimbra."
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
  else
    echo "Prerequisite check complete."
  fi


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

  checkMySQLConfig

}


checkRequiredSpace() {
  # /tmp must have 100MB
  # /opt/zimbra must have 5GB
  echo "Checking required space for zimbra-core"
  TMPKB=`df -Pk /tmp | tail -1 | awk '{print $4}'`
  AVAIL=$(($TMPKB / 1024))
  if [ $AVAIL -lt  100 ]; then
    echo "/tmp must have at least 100MB of availble space to install."
    echo "${AVAIL}MB is not enough space to install ZCS."
    GOOD=no
  fi
 
  isInstalled zimbra-store
  isToBeInstalled zimbra-store
  if [ "x$PKGINSTALLED" != "x" -o "x$PKGTOBEINSTALLED" != "x" ]; then
    echo "Checking space for zimbra-store"
    ZIMBRA=`df -Pk /opt/zimbra | tail -1 | awk '{print $4}'`
    AVAIL=$(($ZIMBRA / 1048576))
    if [ $AVAIL -lt 5 ]; then
      echo "/opt/zimbra requires at least 5GB of space to install."
      echo "${AVAIL}GB is not enough space to install."
      GOOD=no
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
      echo "Installation will contine by request." 
      echo ""
    fi
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
    fi
  done
  for i in $PACKAGES $CORE_PACKAGES; do
    echo -n "    $i..."
    isInstalled $i
    if [ x"$PKGINSTALLED" != "x" ]; then
      echo "FOUND $PKGINSTALLED"
      INSTALLED="yes"
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
  verifyLicenseActivationServer
  verifyLicenseAvailable

  if [ $INSTALLED = "yes" ]; then
    saveExistingConfig
  else
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
  fi

  # if we are removing the install we don't need the rest of the info
  if [ x"$UNINSTALL" = "xyes" ]; then
    return
  fi

  # need way to determine type for other package types
  if [ "x$PACKAGEEXT" = "xrpm" ]; then
    if [ x"`rpm --qf '%{description}' -qp ./packages/zimbra-core* | grep Network`" = "x" ]; then
      ZMTYPE_INSTALLABLE="FOSS"
    else 
      ZMTYPE_INSTALLABLE="NETWORK"
    fi
  elif [ "x$PACKAGEEXT" = "xdeb" ]; then
    if [ x"`dpkg -f ./packages/zimbra-core* Description | grep Network`" = "x" ]; then
      ZMTYPE_INSTALLABLE="FOSS"
    else 
      ZMTYPE_INSTALLABLE="NETWORK"
    fi
  fi
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

verifyLicenseActivationServer() {

  if [ x"$SKIP_ACTIVATION_CHECK" = "xyes" ]; then
    return
  fi

  # sometimes we just don't want to check
  if [ x"$AUTOINSTALL" = "xyes" ] || [ x"$UNINSTALL" = "xyes" ] || [ x"$SOFTWAREONLY" = "yes" ]; then
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

  if [ x"$AUTOINSTALL" = "xyes" ] || [ x"$UNINSTALL" = "xyes" ] || [ x"$SOFTWAREONLY" = "yes" ]; then
    return
  fi

  isInstalled zimbra-store
  if [ x$PKGINSTALLED = "x" ]; then
    return
  fi

  # need to finish for other native packagers
  if [ "x$PACKAGEEXT" = "xrpm" ]; then
    if [ x"`rpm --qf '%{description}' -qp ./packages/zimbra-core* | grep Network`" = "x" ]; then
     return
    fi
  elif [ "x$PACKAGEEXT" = "xdeb" ]; then
    if [ x"`dpkg -f ./packages/zimbra-core* Description | grep Network`" = "x" ]; then
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
    elif [ x"$CLUSTERTYPE" = "xstandby" ]; then
      echo "Not checking for license on cluster stand-by node."
      return
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
  if [ ${ZM_CUR_MAJOR} -lt 6 ]; then
    userProvCommand="zmprov -l gaa 2> /dev/null | wc -l"
    oldUserCheck=1
  elif [ ${ZM_CUR_MAJOR} -eq 6 -a ${ZM_CUR_MICRO} -lt 8 ]; then
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

  if [ $INSTALLED = "yes" ]; then
    
    checkVersionMatches

    echo ""
    echo "The Zimbra Collaboration Server appears already to be installed."
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
    elif [ x$CLUSTERTYPE != "x" ]; then
      REMOVE="no"
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
  echo "   LDAPROOTPW=${ldap_root_password}"
  echo "   LDAPZIMBRAPW=${zimbra_ldap_password}"
  echo "   LDAPPOSTPW=${ldap_postfix_password}"
  echo "   LDAPREPPW=${ldap_replication_password}"
  echo "   LDAPAMAVISPW=${ldap_amavis_password}"
  echo "   LDAPNGINXPW=${ldap_nginx_password}"

}

restoreExistingConfig() {
  if [ -d $RESTORECONFIG ]; then
    RF="$RESTORECONFIG/localconfig.xml"
  fi
  if [ -f $RF ]; then
    echo -n "Restoring existing configuration file from $RF..."
    #while read i; do
      # echo "Setting $i"
      #runAsZimbra "zmlocalconfig -f -e $i"
    #done < $RF
    #if [ -f $RESTORECONFIG/backup.save ]; then
    #  echo -n "Restoring backup schedule..."
    #  runAsZimbra "cat $RESTORECONFIG/backup.save | xargs zmschedulebackup -R"
    #fi
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
  if [ -f "$SAVEDIR/cacerts" ]; then
    cp $SAVEDIR/cacerts /opt/zimbra/java/jre/lib/security/cacerts
    chown zimbra:zimbra /opt/zimbra/java/jre/lib/security/cacerts
  fi
  if [ -f "$SAVEDIR/keystore" -a -d "/opt/zimbra/jetty/etc" ]; then
    cp $SAVEDIR/keystore /opt/zimbra/jetty/etc/keystore
    chown zimbra:zimbra /opt/zimbra/jetty/etc/keystore
  elif [ -f "$SAVEDIR/keystore" -a -d "/opt/zimbra/tomcat/conf" ]; then
    cp $SAVEDIR/keystore /opt/zimbra/tomcat/conf/keystore
    chown zimbra:zimbra /opt/zimbra/tomcat/conf/keystore
  elif [ -f "$SAVEDIR/keystore" -a -d "/opt/zimbra/conf" ]; then
    cp $SAVEDIR/keystore /opt/zimbra/conf/keystore
    chown zimbra:zimbra /opt/zimbra/conf/keystore
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
  elif [ -f "/opt/zimbra/tomcat/conf/keystore" ]; then
    chown zimbra:zimbra /opt/zimbra/tomcat/conf/keystore
  fi
}

saveExistingConfig() {
  echo ""
  echo "Saving existing configuration file to $SAVEDIR"
  if [ ! -d "$SAVEDIR" ]; then
    mkdir -p $SAVEDIR
  fi
  # make copies of existing save files
  for f in localconfig.xml config.save keystore cacerts perdition.pem smtpd.key smtpd.crt slapd.key slapd.crt ca.key backup.save; do
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
  if [ -f "/opt/zimbra/java/jre/lib/security/cacerts" ]; then
    cp -f /opt/zimbra/java/jre/lib/security/cacerts $SAVEDIR
  fi
  if [ -f "/opt/zimbra/jetty/etc/keystore" ]; then
    cp -f /opt/zimbra/jetty/etc/keystore $SAVEDIR
  elif [ -f "/opt/zimbra/tomcat/conf/keystore" ]; then
    cp -f /opt/zimbra/tomcat/conf/keystore $SAVEDIR
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
  if [ -d "/opt/zimbra/tomcat/webapps/service/zimlet" ]; then
    cp -rf /opt/zimbra/tomcat/webapps/service/zimlet $SAVEDIR
  elif [ -d "/opt/zimbra/mailboxd/webapps/service/zimlet" ]; then
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

  if [ -f /opt/zimbra/data/ldap/config/cn\=config.ldif ]; then
    if [ -f /opt/zimbra/data/ldap/config/cn\=config/olcDatabase\=\{2\}mdb/olcOverlay\=*syncprov.ldif ]; then
      touch /opt/zimbra/.enable_replica
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
      if [ x"$LD_LIBRARY_PATH" != "x" ]; then
        OLD_LDR_PATH=$LD_LIBRARY_PATH
        LD_LIBRARY_PATH=/opt/zimbra/bdb/lib:/opt/zimbra/openssl/lib:/opt/zimbra/cyrus-sasl/lib:/opt/zimbra/libtool/lib:/opt/zimbra/openldap/lib:/opt/zimbra/mysql/lib:$LD_LIBRARY_PATH
      fi
      if [ -f "/opt/zimbra/openldap/sbin/slapcat" -a x"$UNINSTALL" != "xyes" -a x"$REMOVE" != "xyes" ]; then
        if [ -f "/opt/zimbra/conf/slapd.conf" -o -d "/opt/zimbra/data/ldap/config" ]; then
          echo ""
          echo -n "Backing up the ldap database..."
          tmpfile=`mktemp -t slapcat.XXXXXX 2> /dev/null` || (echo "Failed to create tmpfile" && exit 1)
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
      if [ $p = "zimbra-store" -a ${ZM_CUR_MAJOR} -lt 6 ]; then
        isInstalled "zimbra-convertd"
        if [ x$PKGINSTALLED != "x" ]; then
          echo -n "   zimbra-convertd..."
          $PACKAGERM zimbra-convertd >/dev/null 2>&1
          echo "done"
        fi
      fi
      if [ $p = "zimbra-store" ]; then
        isInstalled "zimbra-archiving"
        if [ x$PKGINSTALLED != "x" ]; then
          echo -n "   zimbra-archiving..."
          $PACKAGERM zimbra-archiving >/dev/null 2>&1
          echo "done"
        fi
      fi
      isInstalled $p
      if [ x$PKGINSTALLED != "x" ]; then
        echo -n "   $p..."
        $PACKAGERM $p > /dev/null 2>&1
        echo "done"
      fi
    done

    for p in $MOREPACKAGES; do
      isInstalled $p
      if [ x$PKGINSTALLED != "x" ]; then
        echo -n "   $p..."
        $PACKAGERM $p > /dev/null 2>&1
        echo "done"
      fi
    done

    rm -f /etc/ld.so.conf.d/zimbra.ld.conf
    if [ -f "/etc/sudoers" ]; then
      SUDOMODE=`perl -e 'my $mode=(stat("/etc/sudoers"))[2];printf("%04o\n",$mode & 07777);'`
      cat /etc/sudoers | grep -v "^\%zimbra[[:space:]]" > /tmp/sudoers
      cat /tmp/sudoers > /etc/sudoers
      chmod $SUDOMODE /etc/sudoers
      rm -f /tmp/sudoers
    fi
    echo ""
    echo "Removing deployed webapp directories"
    if [ -d "/opt/zimbra/tomcat/webapps/" ]; then
      /bin/rm -rf /opt/zimbra/tomcat/webapps/zimbra
      /bin/rm -rf /opt/zimbra/tomcat/webapps/zimbra.war
      /bin/rm -rf /opt/zimbra/tomcat/webapps/zimbraAdmin
      /bin/rm -rf /opt/zimbra/tomcat/webapps/zimbraAdmin.war
      /bin/rm -rf /opt/zimbra/tomcat/webapps/service
      /bin/rm -rf /opt/zimbra/tomcat/webapps/service.war
      /bin/rm -rf /opt/zimbra/tomcat/work
    elif [ -d "/opt/zimbra/jetty/webapps" ]; then
      /bin/rm -rf /opt/zimbra/jetty/webapps/zimbra
      /bin/rm -rf /opt/zimbra/jetty/webapps/zimbra.war
      /bin/rm -rf /opt/zimbra/jetty/webapps/zimbraAdmin
      /bin/rm -rf /opt/zimbra/jetty/webapps/zimbraAdmin.war
      /bin/rm -rf /opt/zimbra/jetty/webapps/service
      /bin/rm -rf /opt/zimbra/jetty/webapps/service.war
      /bin/rm -rf /opt/zimbra/jetty/work
    fi
  fi

  if [ $REMOVE = "yes" ]; then
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
     
      if [ -e /usr/sbin/sendmail ]; then
        if [ -x /bin/readlink ]; then
          SMPATH=$(/bin/readlink /usr/sbin/sendmail)
          if [ x$SMPATH = x"/opt/zimbra/postfix/sbin/sendmail" ]; then
            /bin/rm -f /usr/sbin/sendmail
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
            if [ -x /usr/bin/service ]; then
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
              if [ $PLATFORM = "RHEL6_64" -o $PLATFORM = "CentOS6_64" ]; then
                sed -i -e 's/^*.info;local0.none;local1.none;mail.none;auth.none/*.info/' /etc/rsyslog.conf
                sed -i -e 's/^*.info;local0.none;local1.none;auth.none/*.info/' /etc/rsyslog.conf
              fi
              if [ -x /etc/init.d/rsyslog ]; then
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

      if [ -f /etc/ld.so.conf ]; then
        echo -n "Cleaning up /etc/ld.so.conf..."
        egrep -q '/opt/zimbra' /etc/ld.so.conf
        if [ $? = 0 ]; then
          sed -i -e '/\/opt\/zimbra/d' /etc/ld.so.conf
          if [ -x /sbin/ldconfig ]; then
           /sbin/ldconfig
          fi
        fi
        echo "done."
      fi

      if [ -f /etc/prelink.conf ]; then
        echo -n "Cleaning up /etc/prelink.conf..."
        egrep -q 'zimbra' /etc/prelink.conf
        if [ $? = 0 ]; then
          sed -i -e '/zimbra/d' -e '/Zimbra/d' /etc/prelink.conf
        fi
        echo "done."
      fi

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

getInstallPackages() {
  
  echo ""
  echo "Select the packages to install"
  if [ $UPGRADE = "yes" ]; then
    echo "    Upgrading zimbra-core"
  fi

  APACHE_SELECTED="no"
  LOGGER_SELECTED="no"
  STORE_SELECTED="no"
  
  CLUSTER_SELECTED="no"

  for i in $AVAILABLE_PACKAGES; do
    # Reset the response before processing the next package.
    response="no"

    # If we're upgrading, and it's installed, don't ask stoopid questions
    if [ $UPGRADE = "yes" ]; then
      echo $INSTALLED_PACKAGES | grep $i > /dev/null 2>&1
      if [ $? = 0 ]; then
        echo "    Upgrading $i"
        if [ $i = "zimbra-core" ]; then
          continue
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
        INSTALL_PACKAGES="$INSTALL_PACKAGES $i"
        if [ $i = "zimbra-apache" ]; then
          APACHE_SELECTED="yes"
        elif [ $i = "zimbra-logger" ]; then
          LOGGER_SELECTED="yes"
        elif [ $i = "zimbra-store" ]; then
          STORE_SELECTED="yes"
        elif [ $i = "zimbra-cluster" ]; then
          CLUSTER_SELECTED="yes"
        fi
        continue
      fi
    fi

    # Only prompt for cluster on supported platforms
    echo $PLATFORM | egrep -q "RHEL|CentOS"
    if [ $? != 0 -a $i = "zimbra-cluster" ]; then
      continue
    fi

    # Cluster is only available clustertype is defined 
    if [ x"$CLUSTERTYPE" = "x" -a "$i" = "zimbra-cluster" ]; then
      continue
    fi

    if [ $UPGRADE = "yes" ]; then
      if [ ${ZM_CUR_MAJOR} -eq 5 -a $i = "zimbra-convertd" ]; then
        echo $INSTALLED_PACKAGES | grep "zimbra-store" > /dev/null 2>&1
        if [ $? = 0 ]; then
          echo $INSTALLED_PACKAGES | grep "zimbra-convertd" > /dev/null 2>&1
          if [ $? != 0 ]; then
            echo $INSTALLED_PACKAGES | grep "zimbra-apache" > /dev/null 2>&1
            if [ $? != 0 ]; then
              INSTALL_PACKAGES="$INSTALL_PACKAGES zimbra-apache $i"
            else
              INSTALL_PACKAGES="$INSTALL_PACKAGES $i"
            fi
            continue
          fi
        fi
      elif [ ${ZM_CUR_MAJOR} -eq 5 -a $i = "zimbra-memcached" ]; then
        echo $INSTALLED_PACKAGES | grep "zimbra-proxy" > /dev/null 2>&1
        if [ $? = 0 ]; then
          askYN "Install $i" "Y"
        else
          askYN "Install $i" "N"
        fi
      elif [ $i = "zimbra-archiving" ]; then
        if [ $STORE_SELECTED = "yes" ]; then
          askYN "Install $i" "N"
        fi
      else
        askYN "Install $i" "N"
      fi
    else
      if [ $i = "zimbra-memcached" ]; then
         askYN "Install $i" "N"
      elif [ $i = "zimbra-proxy" ]; then
         askYN "Install $i" "N"
      elif [ $i = "zimbra-archiving" ]; then
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
      elif [ $i = "zimbra-cluster" -a "x$CLUSTERTYPE" = "x" ]; then
        askYN "Install $i" "N"
      else
        askYN "Install $i" "Y"
      fi
    fi

    if [ $response = "yes" ]; then
      if [ $i = "zimbra-logger" ]; then
        LOGGER_SELECTED="yes"
      elif [ $i = "zimbra-store" ]; then
        STORE_SELECTED="yes"
      elif [ $i = "zimbra-apache" ]; then
        APACHE_SELECTED="yes"
      elif [ $i = "zimbra-cluster" ]; then
        CLUSTER_SELECTED="yes"
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

      # don't force logger to be installed especially on N+M clusters
      #if [ $i = "zimbra-store" -a $LOGGER_SELECTED = "no" -a $CLUSTER_SELECTED = "yes" ]; then
      #  LOGGER_SELECTED="yes"
      #  INSTALL_PACKAGES="$INSTALL_PACKAGES zimbra-logger"
      #fi

      #if [ $i = "zimbra-cluster" -a $STORE_SELECTED = "yes" -a $LOGGER_SELECTED = "no" ]; then
      #  LOGGER_SELECTED="yes"
      #  INSTALL_PACKAGES="$INSTALL_PACKAGES zimbra-logger"
      #fi

      INSTALL_PACKAGES="$INSTALL_PACKAGES $i"
    fi

  done
  checkRequiredSpace

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

isInstalled () {
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
  PLATFORM=`bin/get_plat_tag.sh`
  CONFLICT_PACKAGES=""
  echo $PLATFORM | egrep -q "UBUNTU|DEBIAN"
  if [ $? = 0 ]; then
    checkUbuntuRelease
    PACKAGEINST='dpkg -i'
    PACKAGERM='dpkg --purge'
    PACKAGEQUERY='dpkg -s'
    #CONFLICTQUERY="/usr/bin/dpkg-query -W -f='\${Package}: \${Provides}\n' '*'"
    PACKAGEEXT='deb'
    PACKAGEVERSION="dpkg-query -W -f \${Version}"
    PREREQ_PACKAGES="sudo libidn11 libgmp3c2 libstdc++6"
    CONFLICT_PACKAGES="mail-transport-agent"
    if [ $PLATFORM = "UBUNTU10_64" ]; then
      PREREQ_PACKAGES="netcat-openbsd sudo libidn11 libpcre3 libgmp3c2 libexpat1 libstdc++6 libperl5.10"
      PRESUG_PACKAGES="pax perl-5.10.1 sysstat sqlite3"
    fi
    if [ $PLATFORM = "UBUNTU12_64" ]; then
      PREREQ_PACKAGES="netcat-openbsd sudo libidn11 libpcre3 libgmp3c2 libexpat1 libstdc++6 libperl5.14"
      PRESUG_PACKAGES="pax perl-5.14.2 sysstat sqlite3"
    fi
  else
    PACKAGEINST='rpm -iv'
    PACKAGERM='rpm -ev --nodeps --allmatches'
    PACKAGEQUERY='rpm -q'
    PACKAGEVERIFY='rpm -K'
    PACKAGEEXT='rpm'
    if [ $PLATFORM = "RHEL6_64" -o $PLATFORM = "CentOS6_64" ]; then
      PACKAGEINST='yum -y --disablerepo=* localinstall -v'
      PACKAGERM='yum -y --disablerepo=* erase -v'
      PREREQ_PACKAGES="nc sudo libidn gmp"
      PREREQ_LIBS="/usr/lib64/libstdc++.so.6"
      PRESUG_PACKAGES="perl-5.10.1 sysstat sqlite"
    elif [ $PLATFORM = "SLES11_64" ]; then
      PREREQ_PACKAGES="netcat sudo libidn gmp"
      PREREQ_LIBS="/usr/lib64/libstdc++.so.6"
      PRESUG_PACKAGES="perl-5.10.0 sysstat sqlite3"
    else
      PREREQ_PACKAGES="sudo libidn gmp"
      PREREQ_LIBS="/usr/lib/libstdc++.so.6"
      PRESUG_PACKAGES="sysstat sqlite"
    fi
  fi
}
