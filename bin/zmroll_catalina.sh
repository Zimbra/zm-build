#!/bin/sh

DATE=`date +%Y%m%d%H%M`
cp -f /opt/zimbra/tomcat/logs/catalina.out \
	/opt/zimbra/tomcat/logs/catalina.out.$DATE

cat /dev/null > /opt/zimbra/tomcat/logs/catalina.out

gzip /opt/zimbra/tomcat/logs/catalina.out.$DATE


