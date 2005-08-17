#
# spec file for liquid.rpm
#
Summary: Liquid Core
Name: liquid-core
Version: @@VERSION@@
Release: @@RELEASE@@
Copyright: Copyright 2004 Liquid Systems
Group: Applications/Messaging
URL: http://www.liquid.com
Vendor: Liquid Systems, Inc.
Packager: Liquid Systems, Inc.
BuildRoot: /opt/liquid
AutoReqProv: no

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
	useradd -g liquid -G tty -d /opt/liquid -s /bin/bash liquid
fi

%post
H=`hostname --fqdn`
I=`hostname -i`

#Symlinks
rm -f /opt/liquid/java
ln -s /opt/liquid/jdk1.5.0_04 /opt/liquid/java

cat /opt/liquid/liquidmon/liquid.cf.in > /opt/liquid/liquidmon/liquid.cf

echo "LOCALHOST $H" > /opt/liquid/liquidmon/state.cf
chown liquid:liquid /opt/liquid/liquidmon/state.cf

egrep -q '/opt/liquid/lib' /etc/ld.so.conf
if [ $? != 0 ]; then
	echo "/opt/liquid/lib" >> /etc/ld.so.conf
fi  

egrep -q '/opt/liquid/sleepycat/lib' /etc/ld.so.conf
if [ $? != 0 ]; then
    echo "/opt/liquid/sleepycat/lib" >> /etc/ld.so.conf
fi  

egrep -q '/opt/liquid/openldap/lib' /etc/ld.so.conf
if [ $? != 0 ]; then
	echo "/opt/liquid/openldap/lib" >> /etc/ld.so.conf
fi  

egrep -q '/opt/liquid/cyrus-sasl/lib' /etc/ld.so.conf
if [ $? != 0 ]; then
	echo "/opt/liquid/cyrus-sasl/lib" >> /etc/ld.so.conf
fi  

crontab -u liquid /opt/liquid/liquidmon/crontab

if [ ! -d /opt/liquid/liquidmon/mrtg/work/ ]; then
	mkdir -p /opt/liquid/liquidmon/mrtg/work/
fi
chown -R liquid:liquid /opt/liquid/liquidmon/mrtg

ldconfig

# Setup syslog

if [ ! -f /etc/logrotate.d/liquid ]; then
	if [ -d /etc/logrotate.d ]; then
		cp /opt/liquid/bin/lqlogrotate /etc/logrotate.d/liquid
	fi
fi

egrep -q '/var/log/liquid.log' /etc/syslog.conf
if [ $? != 0 ]; then
	mv /etc/syslog.conf /etc/syslog.conf.liquid
	sed -e 's:\(.*[a-z*]\).*\(\t/var/log/messages\)$:\1;local0.none\t\2:' \
		/etc/syslog.conf.liquid > /etc/syslog.conf
	echo "local0.*                /var/log/liquid.log" >> /etc/syslog.conf
	touch /var/log/liquid.log
	chown liquid:liquid /var/log/liquid.log
	killall -HUP syslogd
fi

# Setup iptables
iptables -t nat -F
/sbin/chkconfig iptables on

/opt/liquid/bin/lqiptables -i

cp /opt/liquid/bin/liquid /etc/init.d/liquid
chmod 755 /etc/init.d/liquid
chkconfig --add liquid 
chkconfig liquid on

su - liquid -c "cd /opt/liquid/lib; tar xzf curl.tgz"
su - liquid -c "cd /opt/liquid/lib; tar xzf idn.tgz"

mkdir -p /opt/liquid/log
chown liquid:liquid /opt/liquid/log
chown liquid:liquid /opt/liquid

%preun
su - liquid -c "lqcontrol shutdown" 

rm -rf /tmp/swatch.out

chkconfig --del liquid 
rm -rf /etc/init.d/liquid

%postun

if [ -f /etc/syslog.conf.liquid ]; then
	mv /etc/syslog.conf.liquid /etc/syslog.conf
	killall -HUP syslogd
fi

%files
