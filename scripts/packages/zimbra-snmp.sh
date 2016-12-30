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

# Shell script to create zimbra snmp package


#-------------------- Configuration ---------------------------

    currentScript=`basename $0 | cut -d "." -f 1`                          # zimbra-snmp
    currentPackage=`echo ${currentScript}build | cut -d "-" -f 2` # snmpbuild


#-------------------- Build Package ---------------------------
main()
{
    echo -e "\tCreate package directories" >> ${buildLogFile}
    mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/data/snmp/persist
    mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/data/snmp/state
    mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf
    mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/conf
    mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/share/snmp/mibs


    echo -e "\tCopy package files" >> ${buildLogFile}
    cp ${repoDir}/zm-build/rpmconf/Conf/snmp.conf ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/conf/snmp.conf
    cp ${repoDir}/zm-build/rpmconf/Conf/snmpd.conf.in ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/snmpd.conf.in
    cp ${repoDir}/zm-build/rpmconf/Conf/snmp.conf ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/share/snmp/snmp.conf
    cp ${repoDir}/zm-build/rpmconf/Conf/mibs/*mib ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/share/snmp/mibs

    CreateDebianPackage
}

CreateDebianPackage()
{
    mkdir -p ${repoDir}/zm-build/${currentPackage}/DEBIAN
    cat ${repoDir}/zm-build/rpmconf/Spec/Scripts/${currentScript}.post >> ${repoDir}/zm-build/${currentPackage}/DEBIAN/postinst
    chmod 555 ${repoDir}/zm-build/${currentPackage}/DEBIAN/*

    echo -e "\tCreate debian package" >> ${buildLogFile}
    (cd ${repoDir}/zm-build/${currentPackage}; find . -type f ! -regex '.*.hg.*' ! -regex '.*?debian-binary.*' ! -regex '.*?DEBIAN.*' -print0 | xargs -0 md5sum | sed -e 's| \./| |' \
        > ${repoDir}/zm-build/${currentPackage}/DEBIAN/md5sums)
    cat ${repoDir}/zm-build/rpmconf/Spec/${currentScript}.deb | sed -e "s/@@VERSION@@/${release}.${buildNo}.${os/_/.}/" -e "s/@@branch@@/${buildTimeStamp}/" -e "s/@@ARCH@@/${arch}/" \
        > ${repoDir}/zm-build/${currentPackage}/DEBIAN/control
    (cd ${repoDir}/zm-build/${currentPackage}; dpkg -b ${repoDir}/zm-build/${currentPackage} ${repoDir}/zm-build/${arch})

    if [ $? -ne 0 ]; then
        echo -e "\t### ${currentPackage} package building failed ###" >> ${buildLogFile}
    else
        echo -e "\t*** ${currentPackage} package successfully created ***" >> ${buildLogFile}
    fi
}

############################################################################
main "$@"
