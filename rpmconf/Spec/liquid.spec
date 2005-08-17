#
# spec file for liquid.rpm
#
Summary: Liquid Mail
Name: liquid-store
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

egrep -q 'liquid' /etc/security/limits.conf
if [ $? != 0 ]; then
	echo "liquid soft nofile 10000" >> /etc/security/limits.conf
	echo "liquid hard nofile 10000" >> /etc/security/limits.conf
fi

%post

H=`hostname -s`
I=`hostname -i`

#Symlinks
rm -f /opt/liquid/mysql
ln -s /opt/liquid/mysql-standard-4.1.10a-pc-linux-gnu-i686 /opt/liquid/mysql

mv /opt/liquid/db/db.sql /opt/liquid/db/db.sql.in
sed -e "/server.hostname/ s/local/$H/" /opt/liquid/db/db.sql.in > /opt/liquid/db/db.sql

rm -rf /opt/liquid/tomcat
ln -s /opt/liquid/jakarta-tomcat-5.5.7 /opt/liquid/tomcat
mkdir -p /opt/liquid/tomcat/logs
chown liquid:liquid /opt/liquid/tomcat/logs

egrep -q 'tomcat_start' /opt/liquid/liquidmon/liquid.cf
if [ $? != 0 ]; then
    cat /opt/liquid/liquidmon/liquidmail.cf >> /opt/liquid/liquidmon/liquid.cf
fi

egrep -q 'ARP_TOOLS' /etc/sudoers
if [ $? != 0 ]; then
	echo "Cmnd_Alias ARP_TOOLS=/sbin/arping,/opt/liquid/libexec/send_arp" >> /etc/sudoers
	echo "Cmnd_Alias IFCONFIG=/sbin/ifconfig" >> /etc/sudoers
	echo "%liquid ALL=NOPASSWD:ARP_TOOLS,IFCONFIG" >> /etc/sudoers
fi

su - liquid -c "mkdir -p /opt/liquid/tomcat/webapps/service; cd /opt/liquid/tomcat/webapps/service; jar xf ../service.war"
su - liquid -c "mkdir -p /opt/liquid/tomcat/webapps/liquid; cd /opt/liquid/tomcat/webapps/liquid; jar xf ../liquid.war"

%preun
su - liquid -c "lqcontrol shutdown"

%files
