#
# spec file for zimbra.rpm
#
Summary: Zimbra Mail
Name: zimbra-logger
Version: @@VERSION@@
Release: @@RELEASE@@
Copyright: ZPL and other
Group: Applications/Messaging
URL: http://www.zimbra.com
Vendor: Zimbra, Inc.
Packager: Zimbra, Inc.
BuildRoot: /opt/zimbra
AutoReqProv: no
requires: zimbra-core

%description
Best email money can buy

%prep

%build

%install

%pre

# Perhaps we're installing for the second time
if [ "$1" != 1 ]; then
	echo "Installing package number $1"
fi

# Create group, user for zimbra and postfix.
egrep -q '^zimbra:' /etc/group
if [ $? != 0 ]; then
	groupadd zimbra
fi

egrep -q '^postfix:' /etc/group
if [ $? != 0 ]; then
	groupadd postfix
fi

egrep -q '^zimbra:' /etc/passwd
if [ $? != 0 ]; then
	useradd -g zimbra -G postfix,tty -d /opt/zimbra -s /bin/bash zimbra
fi

# Fix incase the account existed but the groups were wrong
usermod -g zimbra -G postfix,tty zimbra

egrep -q 'zimbra' /etc/security/limits.conf
if [ $? != 0 ]; then
	echo "zimbra soft nofile 10000" >> /etc/security/limits.conf
	echo "zimbra hard nofile 10000" >> /etc/security/limits.conf
fi

%post

H=`hostname -s`
I=`hostname -i`

#Symlinks
rm -f /opt/zimbra/mysql
ln -s /opt/zimbra/mysql-standard-4.1.10a-pc-linux-gnu-i686 /opt/zimbra/mysql

mv /opt/zimbra/db/db.sql /opt/zimbra/db/db.sql.in
sed -e "/server.hostname/ s/local/$H/" /opt/zimbra/db/db.sql.in > /opt/zimbra/db/db.sql

egrep -q 'logmysql_start' /opt/zimbra/zimbramon/zimbra.cf
if [ $? != 0 ]; then
    cat /opt/zimbra/zimbramon/zimbralogger.cf >> /opt/zimbra/zimbramon/zimbra.cf
fi

%preun
su - zimbra -c "zmcontrol shutdown"

%files
