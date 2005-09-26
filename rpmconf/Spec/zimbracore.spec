#
# spec file for zimbra.rpm
#
Summary: Zimbra Core
Name: zimbra-core
Version: @@VERSION@@
Release: @@RELEASE@@
Copyright: Various
Group: Applications/Messaging
URL: http://www.zimbra.com
Vendor: Zimbra, Inc.
Packager: Zimbra, Inc.
BuildRoot: /opt/zimbra
AutoReqProv: no
requires: libidn
requires: curl
requires: fetchmail
requires: openssl

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
	useradd -g zimbra -G tty -d /opt/zimbra -s /bin/bash zimbra
fi

%post
H=`hostname --fqdn`
I=`hostname -i`

#Symlinks
rm -f /opt/zimbra/java
ln -s /opt/zimbra/jdk1.5.0_04 /opt/zimbra/java

cat /opt/zimbra/zimbramon/zimbra.cf.in > /opt/zimbra/zimbramon/zimbra.cf

echo "LOCALHOST $H" > /opt/zimbra/zimbramon/state.cf
chown zimbra:zimbra /opt/zimbra/zimbramon/state.cf

cp -f /opt/zimbra/conf/zimbra.ld.conf /etc/ld.so.conf.d

if [ ! -d /opt/zimbra/zimbramon/mrtg/work/ ]; then
	mkdir -p /opt/zimbra/zimbramon/mrtg/work/
fi
chown -R zimbra:zimbra /opt/zimbra/zimbramon/mrtg

ldconfig

# Setup syslog

if [ ! -f /etc/logrotate.d/zimbra ]; then
	if [ -d /etc/logrotate.d ]; then
		cp /opt/zimbra/bin/zmlogrotate /etc/logrotate.d/zimbra
	fi
fi

/opt/zimbra/bin/zmsyslogsetup local

# Setup iptables
iptables -t nat -F
/sbin/chkconfig iptables on

/opt/zimbra/bin/zmiptables -i

cp /opt/zimbra/bin/zimbra /etc/init.d/zimbra
chmod 755 /etc/init.d/zimbra
chkconfig --add zimbra 
chkconfig zimbra on

mkdir -p /opt/zimbra/log
chown zimbra:zimbra /opt/zimbra/log
chown zimbra:zimbra /opt/zimbra

%preun
su - zimbra -c "zmcontrol shutdown" 

rm -rf /tmp/swatch.out

chkconfig --del zimbra 
rm -rf /etc/init.d/zimbra

%postun

if [ -f /etc/syslog.conf.zimbra ]; then
	mv /etc/syslog.conf.zimbra /etc/syslog.conf
	killall -HUP syslogd
fi

%files
