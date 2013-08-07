#!/bin/bash
# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2005, 2009, 2010, 2011 Zimbra Software, LLC.
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

TOBRANCH=$1
shift

if [ x$TOBRANCH = "x" -o $# -eq 0 ]; then
	echo $0 '<to branch> <change> [<change>...]'
	exit 1
fi

while [ $# -gt 0 ]; do
	echo "Integrating change $1"

	p4 describe -s $1 | egrep '^\.\.\.' > /tmp/change.$$ 2>&1
	if [ $? -gt 0 ]; then
		echo "Change $1 not found!"
	else
		while read i; do
			SOURCEFILE=`echo $i | awk '{print $2}'`
			DESTFILE=`echo $SOURCEFILE | sed -e "s|//depot/[^/]*|//depot/$TOBRANCH|" -e 's/#[0-9]*$//'`
			echo "file $SOURCEFILE"
			echo "	$DESTFILE"
			p4 integrate -d $SOURCEFILE $DESTFILE
		done < /tmp/change.$$
	fi
	rm /tmp/change.$$

	shift
done

p4 diff -du | less

#p4 resolve

#p4 submit

