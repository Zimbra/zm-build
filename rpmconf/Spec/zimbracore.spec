#
# spec file for zimbra.rpm
#
Summary: Zimbra Core
Name: zimbra-core
Version: @@VERSION@@
Release: @@RELEASE@@
Copyright: Copyright 2005 Zimbra, Inc.
Group: Applications/Messaging
URL: http://www.zimbra.com
Vendor: Zimbra, Inc.
Packager: Zimbra, Inc.
BuildRoot: /opt/zimbra
AutoReqProv: no
requires: libidn
requires: curl
requires: fetchmail

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

egrep -q '/opt/zimbra/lib' /etc/ld.so.conf
if [ $? != 0 ]; then
	echo "/opt/zimbra/lib" >> /etc/ld.so.conf
fi  

egrep -q '/opt/zimbra/sleepycat/lib' /etc/ld.so.conf
if [ $? != 0 ]; then
    echo "/opt/zimbra/sleepycat/lib" >> /etc/ld.so.conf
fi  

egrep -q '/opt/zimbra/openldap/lib' /etc/ld.so.conf
if [ $? != 0 ]; then
	echo "/opt/zimbra/openldap/lib" >> /etc/ld.so.conf
fi  

egrep -q '/opt/zimbra/cyrus-sasl/lib' /etc/ld.so.conf
if [ $? != 0 ]; then
	echo "/opt/zimbra/cyrus-sasl/lib" >> /etc/ld.so.conf
fi  

crontab -u zimbra /opt/zimbra/zimbramon/crontab

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

egrep -q '/var/log/zimbra.log' /etc/syslog.conf
if [ $? != 0 ]; then
	mv /etc/syslog.conf /etc/syslog.conf.zimbra
	sed -e 's:\(.*[a-z*]\).*\(\t/var/log/messages\)$:\1;local0.none\t\2:' \
		/etc/syslog.conf.zimbra > /etc/syslog.conf
	echo "local0.*                /var/log/zimbra.log" >> /etc/syslog.conf
	touch /var/log/zimbra.log
	chown zimbra:zimbra /var/log/zimbra.log
	killall -HUP syslogd
fi

# Setup iptables
iptables -t nat -F
/sbin/chkconfig iptables on

/opt/zimbra/bin/zmiptables -i

cp /opt/zimbra/bin/zimbra /etc/init.d/zimbra
chmod 755 /etc/init.d/zimbra
chkconfig --add zimbra 
chkconfig zimbra on

su - zimbra -c "cd /opt/zimbra/lib; tar xzf curl.tgz"
su - zimbra -c "cd /opt/zimbra/lib; tar xzf idn.tgz"

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
