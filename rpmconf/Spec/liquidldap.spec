#
# spec file for liquid.rpm
#
Summary: Liquid LDAP
Name: liquid-ldap
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

egrep -q '^liquid:' /etc/passwd
if [ $? != 0 ]; then
	useradd -g liquid -G tty -d /opt/liquid -s /bin/bash -M -n liquid
fi

%post

H=`hostname -s`
I=`hostname -i`

#Symlinks

rm -f /opt/liquid/openldap
ln -s /opt/liquid/openldap-2.2.26 /opt/liquid/openldap

mkdir -p /opt/liquid/openldap/var/openldap-data
chown -R liquid:liquid /opt/liquid/openldap/var

egrep -q 'ldap_start' /opt/liquid/liquidmon/liquid.cf
if [ $? != 0 ]; then
	cat /opt/liquid/liquidmon/liquidldap.cf >> /opt/liquid/liquidmon/liquid.cf
fi

ldconfig

%preun
su - liquid -c "lqcontrol shutdown"

%files
