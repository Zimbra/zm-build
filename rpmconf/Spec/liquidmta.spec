#
# spec file for liquid.rpm
#
Summary: Liquid MTA
Name: liquid-mta
Version: @@VERSION@@
Release: @@RELEASE@@
Copyright: Copyright 2004 Liquid Systems
Group: Applications/Messaging
URL: http://www.liquid.com
Vendor: Liquid Systems, Inc.
Packager: Liquid Systems, Inc.
BuildRoot: /opt/liquid
AutoReqProv: no
requires: liquid-core

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

# Create group, user for liquid and postfix.
egrep -q '^liquid:' /etc/group
if [ $? != 0 ]; then
	groupadd liquid
fi

egrep -q '^postfix:' /etc/group
if [ $? != 0 ]; then
	groupadd postfix
fi

egrep -q '^postdrop:' /etc/group
if [ $? != 0 ]; then
	groupadd postdrop
fi

egrep -q '^liquid:' /etc/passwd
if [ $? != 0 ]; then
	useradd -g liquid -G postfix,tty -d /opt/liquid -s /bin/bash liquid
fi

# Fix incase the account existed but the groups were wrong
usermod -g liquid -G postfix,tty liquid

egrep -q '^postfix:' /etc/passwd
if [ $? != 0 ]; then
	useradd -g postfix -d /opt/liquid/postfix postfix
	/bin/rm -rf /opt/liquid/postfix
fi

%post

#Symlinks

rm -f /opt/liquid/postfix
ln -s /opt/liquid/postfix-2.2.3 /opt/liquid/postfix

rm -f /opt/liquid/clamav
ln -s /opt/liquid/clamav-0.85.1 /opt/liquid/clamav

rm -f /opt/liquid/sleepycat
ln -s /opt/liquid/sleepycat-4.2.52.2 /opt/liquid/sleepycat

rm -f /opt/liquid/cyrus-sasl
ln -s /opt/liquid/cyrus-sasl-2.1.21.LIQUID /opt/liquid/cyrus-sasl

H=`hostname -s`
I=`hostname -i`

egrep -q '/opt/liquid/postfix/' /etc/sudoers
if [ $? != 0 ]; then
	echo "%liquid   ALL=NOPASSWD:/opt/liquid/postfix/sbin/postfix, /opt/liquid/postfix/sbin/postalias, /opt/liquid/postfix/sbin/qshape.pl" >> /etc/sudoers
fi

egrep -q 'postfix_start' /opt/liquid/liquidmon/liquid.cf
if [ $? != 0 ]; then
	cat /opt/liquid/liquidmon/liquidmta.cf >> /opt/liquid/liquidmon/liquid.cf
fi

cp /opt/liquid/postfix/conf/master.cf /opt/liquid/postfix/conf/master.cf.in
sed -e '/^smtp.*smtpd/ s/^smtp/7075/' /opt/liquid/postfix/conf/master.cf.in \
	> /opt/liquid/postfix/conf/master.cf
chown postfix /opt/liquid/postfix/conf/master.cf
chmod 644 /opt/liquid/postfix/conf/master.cf
rm -f /opt/liquid/postfix/conf/master.cf.in

if [ ! -d /opt/liquid/liquidmon/mrtg/work/ ]; then
	mkdir -p /opt/liquid/liquidmon/mrtg/work/
fi
chown -R liquid:liquid /opt/liquid/liquidmon/mrtg

mkdir -p /opt/liquid/amavisd/db
mkdir -p /opt/liquid/amavisd/tmp
mkdir -p /opt/liquid/amavisd/var
mkdir -p /opt/liquid/amavisd/quarantine
chown -R liquid:liquid /opt/liquid/amavisd/*

mkdir -p /opt/liquid/clamav/db
chown -R liquid:liquid /opt/liquid/clamav/db

/opt/liquid/bin/lqfixperms.sh

egrep -q '/opt/liquid/amavisd/tmp' /etc/fstab
if [ $? != 0 ]; then
	uid=`id -u liquid`
	gid=`id -g liquid`
	echo "/dev/shm	/opt/liquid/amavisd/tmp	tmpfs	defaults,users,size=150m,mode=777 0 0" >> /etc/fstab
fi

ldconfig

%preun
su - liquid -c "lqcontrol shutdown" 

%files
