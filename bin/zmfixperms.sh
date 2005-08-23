
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
# This may not be there, but we don't want to break the zimbramta package
# if it's installed.
if [ -L /opt/zimbra/postfix ]; then

	# Postfix is anal.
	#chown -R root:root /opt/zimbra/conf/*
	if [ ! -d /opt/zimbra/postfix/spool ]; then
		mkdir -p /opt/zimbra/postfix/spool
	fi
	chown -fR root:root /opt/zimbra/postfix*
	chown -fR postfix:postfix /opt/zimbra/postfix/spool
	chown -fR root:postfix /opt/zimbra/postfix/conf
	chown -f root /opt/zimbra/postfix/spool

	chmod 777 /opt/zimbra/postfix/conf
	chmod -fR 644 /opt/zimbra/postfix/conf/*
	chmod -f 755 /opt/zimbra/postfix/conf/postfix-script
	chmod -f 755 /opt/zimbra/postfix/conf/post-install

	# Postfix specific permissions
	if [ -d /opt/zimbra/postfix/spool/public ]; then
		chgrp -f postdrop /opt/zimbra/postfix/spool/public
	fi
	if [ -d /opt/zimbra/postfix/spool/maildrop ]; then
		chgrp -f postdrop /opt/zimbra/postfix/spool/maildrop
	fi
	if [ -d /opt/zimbra/postfix/sbin ]; then
		chgrp -f postdrop /opt/zimbra/postfix/sbin/postqueue
		chgrp -f postdrop /opt/zimbra/postfix/sbin/postdrop
		chmod -f g+s /opt/zimbra/postfix/sbin/postqueue
		chmod -f g+s /opt/zimbra/postfix/sbin/postdrop
	fi

fi

if [ -d /opt/zimbra/clamav-0.85.1 ]; then
	chown zimbra:zimbra /opt/zimbra/clamav-0.85.1
fi

