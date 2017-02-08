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

# Shell script to create zimbra mta package


#-------------------- Configuration ---------------------------

    currentScript=`basename $0 | cut -d "." -f 1`                          # zimbra-mta
    currentPackage=`echo ${currentScript}build | cut -d "-" -f 2` # mtabuild


#-------------------- Build Package ---------------------------
main()
{
    echo -e "\tCreate package directories" >> ${buildLogFile}
    mkdir -p ${repoDir}/zm-build/${currentPackage}/etc/sudoers.d
    mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/conf
    mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/data/amavisd/mysql
    mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/data/altermime
    mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/data/cbpolicyd/db
    mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/data/clamav
    mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/data/opendkim
    mkdir -p ${repoDir}/zm-build/${currentPackage}/opt/zimbra/data/postfix


    echo -e "\tCopy package files" >> ${buildLogFile}
    cp ${repoDir}/zm-build/rpmconf/Env/sudoers.d/02_${currentScript} ${repoDir}/zm-build/${currentPackage}/etc/sudoers.d/02_${currentScript}
    cp ${repoDir}/zm-postfix/conf/postfix/master.cf.in ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/conf/master.cf.in
    cp ${repoDir}/zm-postfix/conf/postfix/tag_as_foreign.re.in ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/conf/tag_as_foreign.re.in
    cp ${repoDir}/zm-postfix/conf/postfix/tag_as_originating.re.in ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/conf/tag_as_originating.re.in
    cp -f ${repoDir}/zm-amavis/conf/amavisd/mysql/antispamdb.sql ${repoDir}/zm-build/${currentPackage}/opt/zimbra/data/amavisd/mysql/antispamdb.sql

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
    (cd ${repoDir}/zm-build/${currentPackage}; find . -type f ! -regex '.*opt/zimbra/postfix-.*/conf/master.cf' ! -regex '.*.hg.*' ! -regex '.*?debian-binary.*' ! -regex '.*?DEBIAN.*' -print0 | \
        xargs -0 md5sum | sed -e 's| \./| |' > ${repoDir}/zm-build/${currentPackage}/DEBIAN/md5sums)
    cat ${repoDir}/zm-build/rpmconf/Spec/${currentScript}.deb | sed -e "s/@@VERSION@@/${releaseNo}.${releaseCandidate}.${buildNo}.${os/_/.}/" -e "s/@@branch@@/${buildTimeStamp}/" \
        -e "s/@@ARCH@@/${arch}/" -e "s/@@ARCH@@/amd64/" -e "s/^Copyright:/Copyright:/" -e "/^%post$/ r ${currentScript}.post" > ${repoDir}/zm-build/${currentPackage}/DEBIAN/control
    (cd ${repoDir}/zm-build/${currentPackage}; dpkg -b ${repoDir}/zm-build/${currentPackage} ${repoDir}/zm-build/${arch})

}

CreateRhelPackage()
{
    cat ${repoDir}/zm-build/rpmconf/Spec/${currentScript}.spec | \
        sed -e "s/@@VERSION@@/${releaseNo}_${releaseCandidate}_${buildNo}.${os}/" \
            -e "s/@@RELEASE@@/${buildTimeStamp}/" \
            -e "s/@@MTA_PROVIDES@@/smtpdaemon/" \
            -e "s/^Copyright:/Copyright:/" \
            -e "/^%post$/ r ${repoDir}/zm-build/rpmconf/Spec/Scripts/${currentScript}.post" > ${repoDir}/zm-build/${currentScript}.spec
    (cd ${repoDir}/zm-build/mtabuild; find opt -maxdepth 2 -type f -o -type l \
        | sed -e 's|^|%attr(-, zimbra, zimbra) /|' >> \
        ${repoDir}/zm-build/${currentScript}.spec )
    echo "%attr(440, root, root) /etc/sudoers.d/02_zimbra-mta" >> \
        ${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(-, zimbra, zimbra) /opt/zimbra/common/conf/master.cf.in" >> \
        ${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(-, zimbra, zimbra) /opt/zimbra/common/conf/tag_as_foreign.re.in" >> \
        ${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(-, zimbra, zimbra) /opt/zimbra/common/conf/tag_as_originating.re.in" >> \
        ${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(-, zimbra, zimbra) /opt/zimbra/data/amavisd" >> \
        ${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(-, zimbra, zimbra) /opt/zimbra/data/clamav" >> \
        ${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(-, zimbra, zimbra) /opt/zimbra/data/cbpolicyd" >> \
        ${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(-, zimbra, zimbra) /opt/zimbra/data/opendkim" >> \
        ${repoDir}/zm-build/${currentScript}.spec
    (cd ${repoDir}/zm-build/${currentPackage}; \
        rpmbuild --target ${arch} --define '_rpmdir ../' --buildroot=${repoDir}/zm-build/${currentPackage} -bb ${repoDir}/zm-build/${currentScript}.spec )
}

############################################################################
main "$@"
