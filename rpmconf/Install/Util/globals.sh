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

CORE_PACKAGES="zimbra-core"

PACKAGES="zimbra-ldap \
zimbra-logger \
zimbra-mta \
zimbra-snmp \
zimbra-store \
zimbra-apache \
zimbra-spell \
zimbra-proxy \
zimbra-archiving \
zimbra-cluster"

SERVICES=""

OPTIONAL_PACKAGES="zimbra-qatest"

PACKAGE_DIR=`dirname $0`/packages


LOGFILE="/tmp/install.log.$$"
touch $LOGFILE
chmod 600 $LOGFILE

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
CREATEDOMAIN=$HOSTNAME
CREATEADMIN="admin@${CREATEDOMAIN}"
CREATEADMINPASS=""
MODE="http"
ALLOWSELFSIGNED="yes"
RUNAV=""
RUNSA=""
AVUSER=""
AVDOMAIN=""
