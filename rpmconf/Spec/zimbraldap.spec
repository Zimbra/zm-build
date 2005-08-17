#
# spec file for zimbra.rpm
#
Summary: Liquid LDAP
Name: zimbra-ldap
Version: @@VERSION@@
Release: @@RELEASE@@
Copyright: Copyright 2004 Liquid Systems
Group: Applications/Messaging
URL: http://www.zimbra.com
Vendor: Liquid Systems, Inc.
Packager: Liquid Systems, Inc.
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

egrep -q '^zimbra:' /etc/passwd
if [ $? != 0 ]; then
	useradd -g zimbra -G tty -d /opt/zimbra -s /bin/bash -M -n zimbra
fi

%post

H=`hostname -s`
I=`hostname -i`

#Symlinks

rm -f /opt/zimbra/openldap
ln -s /opt/zimbra/openldap-2.2.26 /opt/zimbra/openldap

mkdir -p /opt/zimbra/openldap/var/openldap-data
chown -R zimbra:zimbra /opt/zimbra/openldap/var

egrep -q 'ldap_start' /opt/zimbra/zimbramon/zimbra.cf
if [ $? != 0 ]; then
	cat /opt/zimbra/zimbramon/zimbraldap.cf >> /opt/zimbra/zimbramon/zimbra.cf
fi

ldconfig

%preun
su - zimbra -c "zmcontrol shutdown"

%files
