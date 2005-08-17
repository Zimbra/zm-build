#!/bin/sh

DATE=`date +%Y%m%d%H%M`
cp -f /opt/liquid/tomcat/logs/catalina.out \
	/opt/liquid/tomcat/logs/catalina.out.$DATE

cat /dev/null > /opt/liquid/tomcat/logs/catalina.out

gzip /opt/liquid/tomcat/logs/catalina.out.$DATE


