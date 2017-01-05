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

# Shell script to create zimbra archiving package


#-------------------- Configuration ---------------------------

    currentScript=`basename $0 | cut -d "." -f 1`                          # zimbra-archiving
    currentPackage=`echo ${currentScript}build | cut -d "-" -f 2` # archivingbuild

    jarDir=${repoDir}/zm-xmbxsearch-store/build/dist/
    archiveZimletDir=${repoDir}/zm-archive-admin-zimlet/build/dist/
    xmbxZimletDir=${repoDir}/zm-xmbxsearch-zimlet/build/dist/


#-------------------- Build Package ---------------------------
main()
{
    echo -e "\tCreate package directories" >> ${buildLogFile}
    mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/ext/com_zimbra_xmbxsearch
    mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/zimlets-network


    echo -e "\tCopy package files" >> ${buildLogFile}
    cp ${jarDir}zm-xmbxsearch-store.jar ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/ext/com_zimbra_xmbxsearch/com_zimbra_xmbxsearch.jar
    cp ${archiveZimletDir}com_zimbra_archive.zip ${repoDir}/zm-build/${currentPackage}/opt/zimbra/zimlets-network/com_zimbra_archive.zip
    cp ${xmbxZimletDir}com_zimbra_xmbxsearch.zip ${repoDir}/zm-build/${currentPackage}/opt/zimbra/zimlets-network/com_zimbra_xmbxsearch.zip

    CreatePackage "${os}"
}

#-------------------- Util Functions ---------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$SCRIPT_DIR/utils.sh"

CreateDebianPackage()
{
    mkdir -p ${repoDir}/zm-build/${currentPackage}/DEBIAN
    cat ${repoDir}/zm-network-build/rpmconf/Spec/Scripts/${currentScript}.post >> ${repoDir}/zm-build/${currentPackage}/DEBIAN/postinst
    chmod 555 ${repoDir}/zm-build/${currentPackage}/DEBIAN/*
    echo -e "\tCreate debian package" >> ${buildLogFile}
    (cd ${repoDir}/zm-build/${currentPackage}; find . -type f ! -regex '.*?debian-binary.*' ! -regex '.*?DEBIAN.*' -print0 | xargs -0 md5sum | sed -e 's| \./| |' \
        > ${repoDir}/zm-build/${currentPackage}/DEBIAN/md5sums)
    cat ${repoDir}/zm-network-build/rpmconf/Spec/${currentScript}.deb | sed -e "s/@@VERSION@@/${release}.${buildNo}.${os/_/.}/" -e "s/@@branch@@/${buildTimeStamp}/" -e "s/@@ARCH@@/${arch}/" \
        > ${repoDir}/zm-build/${currentPackage}/DEBIAN/control
    (cd ${repoDir}/zm-build/${currentPackage}; dpkg -b ${repoDir}/zm-build/${currentPackage} ${repoDir}/zm-build/${arch})

}

CreateRhelPackage()
{
    cp ${repoDir}/zm-network-build/rpmconf/Spec/Scripts/${currentScript}.pre ${repoDir}/zm-build/
    cp ${repoDir}/zm-network-build/rpmconf/Spec/Scripts/${currentScript}.post ${repoDir}/zm-build/

    cat ${repoDir}/zm-network-build/rpmconf/Spec/${currentScript}.spec | \
        sed -e "s/@@VERSION@@/${release}.${buildNo}.${os}/" \
            -e "s/@@RELEASE@@/${buildTimeStamp}/" \
            -e "s/^Copyright:/Copyright:/" \
            -e "/^%pre$/ r ${currentScript}.pre" \
            -e "/^%post$/ r ${currentScript}.post" > ${repoDir}/zm-build/${currentScript}.spec
    rm -f ${repoDir}/zm-build/${currentScript}.post
    rm -f ${repoDir}/zm-build/${currentScript}.pre
    echo "%attr(-, root, root) /opt/zimbra/lib" >> ${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(-, zimbra, zimbra) /opt/zimbra/zimlets-network" >> \
        ${repoDir}/zm-build/${currentScript}.spec
    echo "" >> ${repoDir}/zm-build/${currentScript}.spec
    echo "%clean" >> ${repoDir}/zm-build/${currentScript}.spec
    (cd ${repoDir}/zm-build/${currentPackage}; \
    rpmbuild --target ${arch} --define '_rpmdir ../' --buildroot=${repoDir}/zm-build/${currentPackage} -bb ${repoDir}/zm-build/${currentScript}.spec )
}

############################################################################
main "$@"
