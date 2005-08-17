
# This may not be there, but we don't want to break the liquidmta package
# if it's installed.
if [ -L /opt/liquid/postfix ]; then

	# Postfix is anal.
	#chown -R root:root /opt/liquid/conf/*
	if [ ! -d /opt/liquid/postfix/spool ]; then
		mkdir -p /opt/liquid/postfix/spool
	fi
	chown -fR root:root /opt/liquid/postfix*
	chown -fR postfix:postfix /opt/liquid/postfix/spool
	chown -fR root:postfix /opt/liquid/postfix/conf
	chown -f root /opt/liquid/postfix/spool

	chmod 777 /opt/liquid/postfix/conf
	chmod -fR 644 /opt/liquid/postfix/conf/*
	chmod -f 755 /opt/liquid/postfix/conf/postfix-script
	chmod -f 755 /opt/liquid/postfix/conf/post-install

	# Postfix specific permissions
	if [ -d /opt/liquid/postfix/spool/public ]; then
		chgrp -f postdrop /opt/liquid/postfix/spool/public
	fi
	if [ -d /opt/liquid/postfix/spool/maildrop ]; then
		chgrp -f postdrop /opt/liquid/postfix/spool/maildrop
	fi
	if [ -d /opt/liquid/postfix/sbin ]; then
		chgrp -f postdrop /opt/liquid/postfix/sbin/postqueue
		chgrp -f postdrop /opt/liquid/postfix/sbin/postdrop
		chmod -f g+s /opt/liquid/postfix/sbin/postqueue
		chmod -f g+s /opt/liquid/postfix/sbin/postdrop
	fi

fi

if [ -d /opt/liquid/clamav-0.85.1 ]; then
	chown liquid:liquid /opt/liquid/clamav-0.85.1
fi

