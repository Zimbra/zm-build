#!/bin/bash

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
			p4 integrate $SOURCEFILE $DESTFILE
		done < /tmp/change.$$
	fi
	rm /tmp/change.$$

	shift
done

p4 diff -du | less

#p4 resolve

#p4 submit

