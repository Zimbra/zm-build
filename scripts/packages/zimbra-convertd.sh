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

# Shell script to create zimbra convertd package


#-------------------- Configuration ---------------------------

    currentScript=`basename $0 | cut -d "." -f 1`                          # zimbra-convertd
    currentPackage=`echo ${currentScript}build | cut -d "-" -f 2` # convertdbuild

    keyviewVersion=10.13.0.0
    zimbraMimehandlersLdif=${repoDir}/zm-ldap-utilities/build/dist/zimbra_mimehandlers.ldif


#-------------------- Build Package ---------------------------
main()
{
    echo -e "\tCreate package directories" >> ${buildLogFile}
    mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/convertd/bin
    mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/convertd/conf/ldap
    mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/convertd/lib
    mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/keyview-${keyviewVersion}/conf

    cd ${repoDir}/zm-build/${currentPackage}/opt/zimbra
    wget http://${zimbraThirdPartyServer}/ZimbraThirdParty/build-essentials/keyview/keyview-${keyviewVersion}.tgz
    tar xvfz keyview-${keyviewVersion}.tgz
    rm -rf keyview-${keyviewVersion}.tgz

    cd ${repoDir}/zm-build/${currentPackage}/opt/zimbra/convertd/lib
    wget http://${zimbraThirdPartyServer}/ZimbraThirdParty/build-essentials/keyview/libkeyview.so
    wget http://${zimbraThirdPartyServer}/ZimbraThirdParty/build-essentials/keyview/libmod_convert.so

    cd ${repoDir}/zm-build/${currentPackage}/opt/zimbra/convertd/bin
    wget http://${zimbraThirdPartyServer}/ZimbraThirdParty/build-essentials/keyview/converter

    echo -e "\tCopy package files" >> ${buildLogFile}
    chmod -R 755 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/keyview-${keyviewVersion}/FilterSDK/bin/
    chmod -R 755 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/keyview-${keyviewVersion}/ExportSDK/bin/
    cp ${repoDir}/zm-convertd-native/conf/verity/mimetypes.properties ${repoDir}/zm-build/${currentPackage}/opt/zimbra/keyview-${keyviewVersion}/conf
    cp ${repoDir}/zm-convertd-native/conf/verity/nofrills.ini ${repoDir}/zm-build/${currentPackage}/opt/zimbra/keyview-${keyviewVersion}/conf
    chmod -R u+w ${repoDir}/zm-build/${currentPackage}/opt/zimbra/keyview-${keyviewVersion}
    rm -rf ${repoDir}/zm-build/${currentPackage}/opt/zimbra/keyview-${keyviewVersion}/docs
    rm -rf ${repoDir}/zm-build/${currentPackage}/opt/zimbra/keyview-${keyviewVersion}/include
    cp -f ${zimbraMimehandlersLdif} ${repoDir}/zm-build/${currentPackage}/opt/zimbra/convertd/conf/ldap/
    cp -f ${repoDir}/zm-convertd-native/conf/ldap/zimbra_mimehandlers.ldif ${repoDir}/zm-build/${currentPackage}/opt/zimbra/convertd/conf/ldap/convertd_mimehandlers.ldif
    cp -f ${repoDir}/zm-convertd-native/conf/httpd.conf.production ${repoDir}/zm-build/${currentPackage}/opt/zimbra/convertd/conf/httpd.conf

    CreateDebianPackage
}

CreateDebianPackage()
{
    mkdir -p ${repoDir}/zm-build/${currentPackage}/DEBIAN
    cp ${repoDir}/zm-network-build/rpmconf/Spec/Scripts/zimbra-convertd.pre ${repoDir}/zm-build/${currentPackage}/DEBIAN/preinst
    cat ${repoDir}/zm-network-build/rpmconf/Spec/Scripts/zimbra-convertd.post >> ${repoDir}/zm-build/${currentPackage}/DEBIAN/postinst
    cp ${repoDir}/zm-network-build/rpmconf/Spec/Scripts/zimbra-convertd.postun ${repoDir}/zm-build/${currentPackage}/DEBIAN/postrm
    chmod 555 ${repoDir}/zm-build/${currentPackage}/DEBIAN/*

    echo -e "\tCreate debian package" >> ${buildLogFile}
    (cd ${repoDir}/zm-build/${currentPackage}; find . -type f ! -regex '.*.hg.*' ! -regex '.*?debian-binary.*' ! -regex '.*?DEBIAN.*' -print0 | xargs -0 md5sum | sed -e 's| \./| |' \
        > ${repoDir}/zm-build/${currentPackage}/DEBIAN/md5sums)
    cat ${repoDir}/zm-network-build/rpmconf/Spec/${currentScript}.deb | sed -e "s/@@VERSION@@/${release}.${buildNo}.${os/_/.}/" \
        -e "s/@@branch@@/${buildTimeStamp}/" -e "s/@@ARCH@@/${arch}/" -e "s/@@ARCH@@/amd64/" -e "s/^Copyright:/Copyright:/" -e "/^%post$/ r ${currentScript}.post" \
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
