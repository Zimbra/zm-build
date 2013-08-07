#!/bin/bash
# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2005, 2006, 2007, 2008, 2009, 2010, 2011 Zimbra Software, LLC.
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

PKGDIR=$1
TEMPLATE=$2

get_size_from_pkg() {
	pkg=$1
	bpkg=`basename $pkg`
	NAME=`echo $bpkg | awk -F. '{print $1}'| sed -e 's/zimbra-//' -e 'y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/'`
	SIZE=`cat ${pkg}/Contents/Info.plist |  sed -ne '/IFPkgFlagInstalledSize/{n;p;}'| sed -ne '/integer/ s/<integer>//p' | sed -e 's/<\/integer>//' -e 's/ //g' -e 's/	//g'`
}

get_build_num() {
	DIR=`dirname $0`
	MAJOR=`cat $DIR/../../RE/MAJOR`
	MINOR=`cat $DIR/../../RE/MINOR`
	MICRO=`cat $DIR/../../RE/MICRO`
	BUILDNUM=`cat $DIR/../../RE/BUILD`
}

get_build_num

for i in ${PKGDIR}/*.pkg; do
	get_size_from_pkg $i
	VAR=${NAME}SIZE
	eval $VAR=$SIZE
done

cat $TEMPLATE | sed -e "s/@@CORESIZE@@/$CORESIZE/g" \
	-e "s/@@LDAPSIZE@@/$LDAPSIZE/g" \
	-e "s/@@LOGGERSIZE@@/$LOGGERSIZE/g" \
	-e "s/@@ARCHIVINGSIZE@@/$ARCHIVINGSIZE/g" \
	-e "s/@@APACHESIZE@@/$APACHESIZE/g" \
	-e "s/@@STORESIZE@@/$STORESIZE/g" \
	-e "s/@@CONVERTDSIZE@@/$CONVERTDSIZE/g" \
	-e "s/@@MEMCACHEDSIZE@@/$MEMCACHEDSIZE/g" \
	-e "s/@@MTASIZE@@/$MTASIZE/g" \
	-e "s/@@PROXYSIZE@@/$PROXYSIZE/g" \
	-e "s/@@SNMPSIZE@@/$SNMPSIZE/g" \
	-e "s/@@SPELLSIZE@@/$SPELLSIZE/g" \
	-e "s/@@MAJOR@@/$MAJOR/g" \
	-e "s/@@MINOR@@/$MINOR/g" \
	-e "s/@@MICRO@@/$MICRO/g" \
	-e "s/@@BUILDNUM@@/$BUILDNUM/g" 


