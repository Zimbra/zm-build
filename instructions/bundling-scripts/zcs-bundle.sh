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

cd ${repoDir}/zm-build

if [ "${buildType}" = "NETWORK" ]
then
   ZCS_REL=zcs-${buildType}-${releaseNo}_${releaseCandidate}_${buildNo}.${os}.${buildTimeStamp}
else
   ZCS_REL=zcs-${releaseNo}_${releaseCandidate}_${buildNo}.${os}.${buildTimeStamp}
fi

mkdir -p $ZCS_REL/bin
mkdir -p $ZCS_REL/data
mkdir -p $ZCS_REL/docs/en_US
mkdir -p $ZCS_REL/lib/jars
mkdir -p $ZCS_REL/packages
mkdir -p $ZCS_REL/util/modules

cp -f ${repoDir}/zm-build/RE/README.txt                                                 ${ZCS_REL}/
cp -f ${repoDir}/zm-build/rpmconf/Build/checkLicense.pl                                 ${ZCS_REL}/bin
cp -f ${repoDir}/zm-build/rpmconf/Build/checkService.pl                                 ${ZCS_REL}/bin
cp -f ${repoDir}/zm-build/rpmconf/Build/get_plat_tag.sh                                 ${ZCS_REL}/bin
cp -f ${repoDir}/zm-build/rpmconf/Build/zmValidateLdap.pl                               ${ZCS_REL}/bin
cp -f ${repoDir}/zm-build/rpmconf/Install/Util/addUser.sh                               ${ZCS_REL}/util
cp -f ${repoDir}/zm-build/rpmconf/Install/Util/globals.sh                               ${ZCS_REL}/util
cp -f ${repoDir}/zm-build/rpmconf/Install/Util/modules/getconfig.sh                     ${ZCS_REL}/util/modules
cp -f ${repoDir}/zm-build/rpmconf/Install/Util/modules/packages.sh                      ${ZCS_REL}/util/modules
cp -f ${repoDir}/zm-build/rpmconf/Install/Util/modules/postinstall.sh                   ${ZCS_REL}/util/modules
cp -f ${repoDir}/zm-build/rpmconf/Install/Util/utilfunc.sh                              ${ZCS_REL}/util
cp -f ${repoDir}/zm-build/rpmconf/Install/install.sh                                    ${ZCS_REL}/
cp -f ${repoDir}/zm-core-utils/src/libexec/zmdbintegrityreport                          ${ZCS_REL}/bin
cp -f ${repoDir}/zm-mailbox/store/build/dist/versions-init.sql                          ${ZCS_REL}/data

# all local packages to bundle
cp -f ${repoDir}/zm-build/${arch}/*.*                                                   ${ZCS_REL}/packages

for pkgf in ${repoDir}/zm-packages/bundle/*/*.{rpm,deb}
do
   if ! [[ "$pkgf" =~ src.rpm$ ]]
   then
      [ -f "$pkgf" ] && cp -f "$pkgf"                                                   ${ZCS_REL}/packages
   fi
done

chmod 755 ${ZCS_REL}/bin/checkService.pl
chmod 755 ${ZCS_REL}/bin/checkLicense.pl
chmod 755 ${ZCS_REL}/bin/zmValidateLdap.pl
chmod 755 ${ZCS_REL}/bin/zmdbintegrityreport
chmod 755 ${ZCS_REL}/install.sh

cp -f ${repoDir}/zm-admin-help-common/WebRoot/help/en_US/admin/pdf/*.pdf                ${ZCS_REL}/docs/en_US
cp -f ${repoDir}/zm-admin-help-common/WebRoot/help/en_US/admin/txt/readme_binary.txt    ${ZCS_REL}/readme_binary_en_US.txt

if [ "${buildType}" = "NETWORK" ]
then
   cp -f ${repoDir}/zm-admin-help-network/WebRoot/help/en_US/admin/pdf/*.pdf               ${ZCS_REL}/docs/en_US
   cp -f ${repoDir}/zm-admin-help-network/WebRoot/help/en_US/admin/txt/readme_binary.txt   ${ZCS_REL}/readme_binary_en_US.txt

   cp -f ${repoDir}/zm-backup-store/build/dist/backup-version-init.sql                     ${ZCS_REL}/data
   cp -f ${repoDir}/zm-license-tools/build/zm-license-tools-*.jar                          ${ZCS_REL}/lib/jars/zimbra-license-tools.jar

   cp -f ${repoDir}/zm-network-licenses/thirdparty/keyview_eula.txt                        ${ZCS_REL}/docs/keyview_eula.txt
   cp -f ${repoDir}/zm-network-licenses/thirdparty/oracle_jdk_eula.txt                     ${ZCS_REL}/docs/oracle_jdk_eula.txt
   cp -f ${repoDir}/zm-network-licenses/zimbra/zimbra_network_eula.txt                     ${ZCS_REL}/docs/zimbra_network_eula.txt

   cp -f ${repoDir}/zm-network-build/rpmconf/Install/Util/modules/postinstall.sh           ${ZCS_REL}/util/modules
   cp -f ${repoDir}/zm-network-build/rpmconf/Util/checkValidBackup                         ${ZCS_REL}/bin/checkValidBackup

   chmod 755 ${ZCS_REL}/bin/checkValidBackup
else
   cp -f ${repoDir}/zm-licenses/zimbra/zcl.txt                                                        ${ZCS_REL}/docs
fi

##########################################

if [ "${buildType}" == "NETWORK" ]
then
   echo "NETWORK" > ${ZCS_REL}/.BUILD_TYPE
else
   echo "FOSS" > ${ZCS_REL}/.BUILD_TYPE
fi

echo "${os}" > ${ZCS_REL}/.BUILD_PLATFORM

##########################################

tar czf ${ZCS_REL}.tgz  ${ZCS_REL}

echo "ZCS build completed: ${repoDir}/zm-build/${ZCS_REL}.tgz"
