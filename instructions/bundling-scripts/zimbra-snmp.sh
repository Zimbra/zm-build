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
    cp ${repoDir}/zm-build/rpmconf/Conf/snmpd.conf.in ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/snmpd.conf.in
    cp ${repoDir}/zm-build/rpmconf/Conf/snmp.conf ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/share/snmp/snmp.conf
    cp ${repoDir}/zm-build/rpmconf/Conf/mibs/*mib ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/share/snmp/mibs

    CreatePackage "${os}"
}

#-------------------- Util Functions ---------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$SCRIPT_DIR/utils.sh"

CreateDebianPackage()
{
    mkdir -p ${repoDir}/zm-build/${currentPackage}/DEBIAN
    cat ${repoDir}/zm-build/rpmconf/Spec/Scripts/${currentScript}.post >> ${repoDir}/zm-build/${currentPackage}/DEBIAN/postinst
    chmod 555 ${repoDir}/zm-build/${currentPackage}/DEBIAN/*

    echo -e "\tCreate debian package" >> ${buildLogFile}
    (cd ${repoDir}/zm-build/${currentPackage}; find . -type f ! -regex '.*.hg.*' ! -regex '.*?debian-binary.*' ! -regex '.*?DEBIAN.*' -print0 | xargs -0 md5sum | sed -e 's| \./| |' \
        > ${repoDir}/zm-build/${currentPackage}/DEBIAN/md5sums)
    cat ${repoDir}/zm-build/rpmconf/Spec/${currentScript}.deb | sed -e "s/@@VERSION@@/${releaseNo}.${releaseCandidate}.${buildNo}.${os/_/.}/" -e "s/@@branch@@/${buildTimeStamp}/" -e "s/@@ARCH@@/${arch}/" \
        > ${repoDir}/zm-build/${currentPackage}/DEBIAN/control
    (cd ${repoDir}/zm-build/${currentPackage}; dpkg -b ${repoDir}/zm-build/${currentPackage} ${repoDir}/zm-build/${arch})

}

CreateRhelPackage()
{
    cat ${repoDir}/zm-build/rpmconf/Spec/${currentScript}.spec | \
    	sed -e "s/@@VERSION@@/${releaseNo}_${releaseCandidate}_${buildNo}.${os}/" \
    	-e "s/@@RELEASE@@/${buildTimeStamp}/" \
    	-e "s/^Copyright:/Copyright:/" \
    	> ${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(755, zimbra, zimbra) /opt/zimbra/data/snmp" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(755, zimbra, zimbra) /opt/zimbra/conf" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(644, zimbra, zimbra) /opt/zimbra/conf/*" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(775, root, zimbra) /opt/zimbra/common/conf" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(644, root, root) /opt/zimbra/common/conf/snmp.conf" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(755, root, root) /opt/zimbra/common/share/snmp" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(644, root, root) /opt/zimbra/common/share/snmp/snmp.conf" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(755, root, root) /opt/zimbra/common/share/snmp/mibs" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(644, root, root) /opt/zimbra/common/share/snmp/mibs/zimbra.mib" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(644, root, root) /opt/zimbra/common/share/snmp/mibs/zimbra_traps.mib" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "" >> ${repoDir}/zm-build/${currentScript}.spec
    echo "%clean" >> ${repoDir}/zm-build/${currentScript}.spec
    (cd ${repoDir}/zm-build/${currentPackage}; \
    	rpmbuild --target ${arch} --define '_rpmdir ../' --buildroot=${repoDir}/zm-build/${currentPackage} -bb ${repoDir}/zm-build/${currentScript}.spec )

}


############################################################################
main "$@"
