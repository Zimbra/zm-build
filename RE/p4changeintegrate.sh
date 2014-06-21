#!/bin/bash
# 
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2005, 2009, 2010, 2013 Zimbra, Inc.
# 
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software Foundation,
# version 2 of the License.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with this program.
# If not, see <http://www.gnu.org/licenses/>.
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

