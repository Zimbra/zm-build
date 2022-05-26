#!/bin/bash
# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2005, 2006, 2007, 2008, 2009, 2010, 2013, 2014, 2015, 2016 Synacor, Inc.
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

LOGFILE=`mktemp -t install.log.XXXXXXXX 2> /dev/null` || { echo "Failed to create tmpfile"; exit 1; }
PLATFORM=`bin/get_plat_tag.sh`

CORE_PACKAGES="zimbra-core"

PACKAGES="zimbra-ldap \
zimbra-logger \
zimbra-mta \
zimbra-dnscache \
zimbra-snmp \
zimbra-store \
zimbra-apache \
zimbra-spell \
zimbra-convertd \
zimbra-memcached \
zimbra-proxy \
zimbra-archiving"

SERVICES=""

OPTIONAL_PACKAGES="zimbra-qatest \
zimbra-drive \
zimbra-imapd \
zimbra-license-tools \
zimbra-license-extension \
zimbra-network-store \
zimbra-network-modules-ng"

MYDIR="$(CDPATH= cd "$(dirname "$0")" && pwd)"
if [ "$(cat ${MYDIR}/.BUILD_TYPE)" == "NETWORK" ]; then
   OPTIONAL_PACKAGES="${OPTIONAL_PACKAGES} zimbra-modern-ui zimbra-modern-zimlets zimbra-patch zimbra-mta-patch zimbra-proxy-patch"
fi

CHAT_PACKAGES="zimbra-chat \
zimbra-connect \
zimbra-talk"

PACKAGE_DIR="$(CDPATH= cd "$(dirname "$0")" && pwd)/packages"

SAVEDIR="/opt/zimbra/.saveconfig"

if [ x$RESTORECONFIG = "x" ]; then
	RESTORECONFIG=$SAVEDIR
fi

#
# Initial values
#

AUTOINSTALL="no"
INSTALLED="no"
INSTALLED_PACKAGES=""
REMOVE="no"
UPGRADE="no"
HOSTNAME=`hostname --fqdn`
ZIMBRAINTERNAL=no
echo $HOSTNAME | egrep -qe 'eng.synacor.com$|eng.zimbra.com$|lab.zimbra.com$|zimbradev.com$' > /dev/null 2>&1
if [ $? = 0 ]; then
  ZIMBRAINTERNAL=yes
fi

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
LDAPPOSTPW=""
LDAPREPPW=""
LDAPAMAVISPW=""
LDAPNGINXPW=""
if [ x"$ZIMBRAINTERNAL" = "xno" ]; then
  CREATEDOMAIN=$(hostname -d) # May be empty
  CREATEDOMAIN=${CREATEDOMAIN:-$HOSTNAME} # only go with fqdn if domain is empty
else
  CREATEDOMAIN=$HOSTNAME
fi

CREATEADMIN="admin@${CREATEDOMAIN}"
CREATEADMINPASS=""
MODE="http"
ALLOWSELFSIGNED="yes"
RUNAV=""
RUNSA=""
AVUSER=""
AVDOMAIN=""
