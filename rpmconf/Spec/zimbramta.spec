#
# spec file for zimbra.rpm
#
Summary: Liquid MTA
Name: zimbra-mta
Version: @@VERSION@@
Release: @@RELEASE@@
Copyright: Copyright 2005 Zimbra, Inc.
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

egrep -q '^postdrop:' /etc/group
if [ $? != 0 ]; then
	groupadd postdrop
fi

egrep -q '^zimbra:' /etc/passwd
if [ $? != 0 ]; then
	useradd -g zimbra -G postfix,tty -d /opt/zimbra -s /bin/bash zimbra
fi

# Fix incase the account existed but the groups were wrong
usermod -g zimbra -G postfix,tty zimbra

egrep -q '^postfix:' /etc/passwd
if [ $? != 0 ]; then
	useradd -g postfix -d /opt/zimbra/postfix postfix
	/bin/rm -rf /opt/zimbra/postfix
fi

%post

#Symlinks

rm -f /opt/zimbra/postfix
ln -s /opt/zimbra/postfix-2.2.3 /opt/zimbra/postfix

rm -f /opt/zimbra/clamav
ln -s /opt/zimbra/clamav-0.85.1 /opt/zimbra/clamav

rm -f /opt/zimbra/sleepycat
ln -s /opt/zimbra/sleepycat-4.2.52.2 /opt/zimbra/sleepycat

rm -f /opt/zimbra/cyrus-sasl
ln -s /opt/zimbra/cyrus-sasl-2.1.21.ZIMBRA /opt/zimbra/cyrus-sasl

H=`hostname -s`
I=`hostname -i`

egrep -q '/opt/zimbra/postfix/' /etc/sudoers
if [ $? != 0 ]; then
	echo "%zimbra   ALL=NOPASSWD:/opt/zimbra/postfix/sbin/postfix, /opt/zimbra/postfix/sbin/postalias, /opt/zimbra/postfix/sbin/qshape.pl" >> /etc/sudoers
fi

egrep -q 'postfix_start' /opt/zimbra/zimbramon/zimbra.cf
if [ $? != 0 ]; then
	cat /opt/zimbra/zimbramon/zimbramta.cf >> /opt/zimbra/zimbramon/zimbra.cf
fi

cp /opt/zimbra/postfix/conf/master.cf /opt/zimbra/postfix/conf/master.cf.in
sed -e '/^smtp.*smtpd/ s/^smtp/7075/' /opt/zimbra/postfix/conf/master.cf.in \
	> /opt/zimbra/postfix/conf/master.cf
chown postfix /opt/zimbra/postfix/conf/master.cf
chmod 644 /opt/zimbra/postfix/conf/master.cf
rm -f /opt/zimbra/postfix/conf/master.cf.in

if [ ! -d /opt/zimbra/zimbramon/mrtg/work/ ]; then
	mkdir -p /opt/zimbra/zimbramon/mrtg/work/
fi
chown -R zimbra:zimbra /opt/zimbra/zimbramon/mrtg

mkdir -p /opt/zimbra/amavisd/db
mkdir -p /opt/zimbra/amavisd/tmp
mkdir -p /opt/zimbra/amavisd/var
mkdir -p /opt/zimbra/amavisd/quarantine
chown -R zimbra:zimbra /opt/zimbra/amavisd/*

mkdir -p /opt/zimbra/clamav/db
chown -R zimbra:zimbra /opt/zimbra/clamav/db

/opt/zimbra/bin/zmfixperms.sh

egrep -q '/opt/zimbra/amavisd/tmp' /etc/fstab
if [ $? != 0 ]; then
	uid=`id -u zimbra`
	gid=`id -g zimbra`
	echo "/dev/shm	/opt/zimbra/amavisd/tmp	tmpfs	defaults,users,size=150m,mode=777 0 0" >> /etc/fstab
fi

ldconfig

%preun
su - zimbra -c "zmcontrol shutdown" 

%files
