#!/bin/bash
#
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2009, 2010, 2011, 2013, 2014, 2015, 2016 Synacor, Inc.
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software Foundation,
# version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with this program.
# If not, see <https://www.gnu.org/licenses/>.
# ***** END LICENSE BLOCK *****


#-------------------- Configuration ---------------------------

	currentScript=`basename $0 | cut -d "." -f 1`
	currentPackage=`echo ${currentScript}build | cut -d "-" -f 2`


#-------------------- Build Package ---------------------------

	echo -e "\tCreate package directories" >> ${buildLogFile}
	mkdir -p ${repoDir}/zm-build/${currentPackage}/etc/sudoers.d
	mkdir -p ${repoDir}/zm-build/${currentPackage}/DEBIAN
	mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin
	mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/templates

	echo -e "\tCopy package files" >> ${buildLogFile}

	echo -e "\tCopy etc files" >> ${buildLogFile}
	cp ${repoDir}/zm-build/rpmconf/Env/sudoers.d/02_${currentScript} ${repoDir}/zm-build/${currentPackage}/etc/sudoers.d/02_${currentScript}
	cat ${repoDir}/zm-build/rpmconf/Spec/Scripts/${currentScript}.post >> ${repoDir}/zm-build/${currentPackage}/DEBIAN/postinst
	chmod 555 ${repoDir}/zm-build/${currentPackage}/DEBIAN/*

	echo -e "\tCopy bin files of /opt/zimbra/" >> ${buildLogFile}
	cp -f ${repoDir}/zm-hsm/src/bin/zmhsm ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmhsm
	cp -f ${repoDir}/zm-archive-utils/src/bin/zmarchiveconfig ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmarchiveconfig
	cp -f ${repoDir}/zm-archive-utils/src/bin/zmarchivesearch ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmarchivesearch
	cp -f ${repoDir}/zm-sync-tools/src/bin/zmsyncreverseproxy ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmsyncreverseproxy
	cp -f ${repoDir}/zm-sync-store/src/bin/zmdevicesstats ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmdevicesstats
	cp -f ${repoDir}/zm-sync-store/src/bin/zmgdcutil ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmgdcutil

	echo -e "\tCopy conf files of /opt/zimbra/" >> ${buildLogFile}
	cp -f ${repoDir}/zm-store-conf/conf/globs2 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf
	cp -f ${repoDir}/zm-store-conf/conf/magic ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf
	cp -f ${repoDir}/zm-store-conf/conf/magic.zimbra ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf
	cp -f ${repoDir}/zm-store-conf/conf/globs2.zimbra ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf
	cp -f ${repoDir}/zm-store-conf/conf/spnego_java_options.in ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf
	cp -f ${repoDir}/zm-store-conf/conf/contacts/zimbra-contact-fields.xml ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/zimbra-contact-fields.xml
## On hold as location/repo not present/decided
	#cp -f ${repoDir}/zm-build/../ZimbraMigrationTools/zmztozmig.conf ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/zmztozmig.conf
	cp -fr ${repoDir}/zm-web-client/WebRoot/templates/* ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/templates

	echo -e "\tCopy extensions-extra files of /op/zimbra/" >> ${buildLogFile}
	mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/extensions-extra/openidconsumer
	cp -f ${repoDir}/zm-openid-consumer-store/build/dist ${repoDir}/zm-build/${currentPackage}/opt/zimbra/extensions-extra/openidconsumer


	echo -e "\tCopy extensions-network-extra files of /op/zimbra/" >> ${buildLogFile}
	mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/extensions-network-extra
	cp -rf ${repoDir}/zm-saml-consumer-store/build/dist/saml ${repoDir}/zm-build/${currentPackage}/opt/zimbra/extensions-network-extra/

	echo -e "\tCopy jetty-distribution-9.3.5.v20151012 files of /op/zimbra/" >> ${buildLogFile}


	echo -e "\tCopy lib files of /opt/zimbra/" >> ${buildLogFile}

	echo -e "\t\tCopy ext files of /opt/zimbra/lib/" >> ${buildLogFile}
	mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/ext/backup
	mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/ext/zimbra-archive
	mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/ext/voice
	mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/ext/cisco
	mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/ext/mitel
    cp -rf ${repoDir}/zm-backup-store/build/dist ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/ext/backup
    cp -rf ${repoDir}/zm-archive-store/build/dist ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/ext/zimbra-archive
    cp -rf ${repoDir}/zm-voice-store/build/dist ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/ext/zimbra-voice-store
    cp -rf ${repoDir}/zm-voice-cisco-store/build/dist ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/ext/zimbra-voice-cisco-store
    cp -rf ${repoDir}/zm-voice-mitel-store/build/dist ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/ext/zimbra-voice-mitel-store

	echo -e "\t\tCopy ext-common files of /opt/zimbra/lib/" >> ${buildLogFile}

	echo -e "\t\tCopy jars files of /opt/zimbra/lib/" >> ${buildLogFile}


	echo -e "\tCopy libexec files of /opt/zimbra/" >> ${buildLogFile}


	echo -e "\tCopy log files of /opt/zimbra/" >> ${buildLogFile}


	echo -e "\tCopy zimlets files of /opt/zimbra/" >> ${buildLogFile}


	echo -e "\tCopy zimlets-network files of /opt/zimbra/" >> ${buildLogFile}


	echo -e "\tCreate debian package" >> ${buildLogFile}
	(cd ${repoDir}/zm-build/${currentPackage}; find . -type f ! -regex '.*jetty-distribution-.*/webapps/zimbra/WEB-INF/jetty-env.xml' ! -regex '.*jetty-distribution-.*/webapps/zimbraAdmin/WEB-INF/jetty-env.xml' ! -regex '.*jetty-distribution-.*/modules/setuid.mod' ! -regex '.*jetty-distribution-.*/etc/krb5.ini' ! -regex '.*jetty-distribution-.*/etc/spnego.properties' ! -regex '.*jetty-distribution-.*/etc/jetty.xml' ! -regex '.*jetty-distribution-.*/etc/spnego.conf' ! -regex '.*jetty-distribution-.*/webapps/zimbraAdmin/WEB-INF/web.xml' ! -regex '.*jetty-distribution-.*/webapps/zimbra/WEB-INF/web.xml' ! -regex '.*jetty-distribution-.*/webapps/service/WEB-INF/web.xml' ! -regex '.*jetty-distribution-.*/work/.*' ! -regex '.*.hg.*' ! -regex '.*?debian-binary.*' ! -regex '.*?DEBIAN.*' -print0 | xargs -0 md5sum | sed -e 's| \./| |' > ${repoDir}/zm-build/${currentPackage}/DEBIAN/md5sums)
	cat ${repoDir}/zm-build/rpmconf/Spec/${currentScript}.deb | sed -e "s/@@VERSION@@/${release}.${buildNo}.${os/_/.}/" -e "s/@@branch@@/${buildTimeStamp}/" -e "s/@@ARCH@@/${arch}/" -e "s/@@ARCH@@/amd64/" -e "s/^Copyright:/Copyright:/" -e "/^%post$/ r ${currentScript}.post" > ${repoDir}/zm-build/${currentPackage}/DEBIAN/control
	(cd ${repoDir}/zm-build/${currentPackage}; dpkg -b ${repoDir}/zm-build/${currentPackage} ${repoDir}/zm-build/${arch})

	if [ $? -ne 0 ]; then
		echo -e "\t### ${currentPackage} package building failed ###" >> ${buildLogFile}
	else
		echo -e "\t*** ${currentPackage} package successfully created ***" >> ${buildLogFile}
	fi
