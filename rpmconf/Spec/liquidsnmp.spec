#
# spec file for liquid.rpm
#
Summary: Liquid SNMP
Name: liquid-snmp
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

egrep -q '^liquid:' /etc/passwd
if [ $? != 0 ]; then
	useradd -g liquid -G postfix,tty -d /opt/liquid -s /bin/bash liquid
fi

# Fix incase the account existed but the groups were wrong
usermod -g liquid -G postfix,tty liquid

%post

H=`hostname -s`
I=`hostname -i`

#Symlinks

rm -f /opt/liquid/snmp
ln -s /opt/liquid/snmp-5.1.2 /opt/liquid/snmp

egrep -q 'swatch_start' /opt/liquid/liquidmon/liquid.cf
if [ $? != 0 ]; then
	cat /opt/liquid/liquidmon/liquidsnmp.cf >> /opt/liquid/liquidmon/liquid.cf
fi

if [ ! -d /opt/liquid/liquidmon/mrtg/work/ ]; then
	mkdir -p /opt/liquid/liquidmon/mrtg/work/
fi

%preun
su - liquid -c "lqcontrol shutdown"

%files
