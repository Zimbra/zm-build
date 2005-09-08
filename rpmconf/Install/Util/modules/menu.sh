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

doMenu() {

	# doMenu takes a template file as the only argument
	#
	# Assumes file is in $MYDIR/menus
	
	FILE=${1:-"none"}
	
	if [ $FILE = "none" ]; then
		echo "ERROR: bad doMenu call"
		echo ""
		exit 1;
	fi

	FNAME="$MYDIR/menus/$FILE"

	if [ ! -f "$FNAME" ]; then
		echo "ERROR: bad doMenu call $FNAME"
		echo ""
		exit 1;
	fi

	readMenuTemplate $FNAME
	while :; do
		displayMenu
		read selection
	done
}

readMenuTemplate() {

	# Takes a filename (verified to exist)
	#
	# returns the menu in MENU and MENUACTIONS
	#

	FNAME=$1

	I=1

	while read i; do
		echo $i | egrep -q '^(#|$)'
		if [ $? -eq 0 ]; then
			continue
		fi
		TEXT=`echo $i | awk -F+ '{print $1}'`
		TEXT=`eval echo $TEXT`
		CB=`echo $i | awk -F+ '{print $2}'`
		MENU[$I]=`printf "%d> %40s\n" $I "$TEXT"`
		I=`expr $I + 1`
	done < $FNAME
}

displayMenu() {
	echo ""
	LEN=${#MENU[*]}
	I=1
	while [ $I -le $LEN ]; do
		echo "${MENU[$I]}"
		I=`expr $I + 1`
	done
	EXITLINE=`printf "%d> %40s\n" 0 "Done"`
	echo "$EXITLINE"
}
