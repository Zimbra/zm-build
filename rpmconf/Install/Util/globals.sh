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

CORE_PACKAGES="zimbra-core"

PACKAGES="zimbra-ldap \
zimbra-logger \
zimbra-mta \
zimbra-snmp \
zimbra-store \
zimbra-apache \
zimbra-spell"

SERVICES=""

OPTIONAL_PACKAGES="zimbra-qatest"

PACKAGE_DIR=`dirname $0`/packages


LOGFILE="/tmp/install.log.$$"
SAVEDIR="/tmp/saveconfig.$$"

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
