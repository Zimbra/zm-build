#
# spec file for zimbra.rpm
#
Summary: Zimbra SNMP
Name: zimbra-snmp
Version: @@VERSION@@
Release: @@RELEASE@@
Copyright: Various
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

%post

H=`hostname -s`
I=`hostname -i`

#Symlinks

rm -f /opt/zimbra/snmp
ln -s /opt/zimbra/snmp-5.1.2 /opt/zimbra/snmp

egrep -q 'swatch_start' /opt/zimbra/zimbramon/zimbra.cf
if [ $? != 0 ]; then
	cat /opt/zimbra/zimbramon/zimbrasnmp.cf >> /opt/zimbra/zimbramon/zimbra.cf
fi

if [ ! -d /opt/zimbra/zimbramon/mrtg/work/ ]; then
	mkdir -p /opt/zimbra/zimbramon/mrtg/work/
fi

%preun
su - zimbra -c "zmcontrol shutdown"

%files
