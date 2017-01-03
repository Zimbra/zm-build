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

mkdir -p zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/bin
mkdir -p zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/data
mkdir -p zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/docs/en_US
mkdir -p zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/lib/jars
mkdir -p zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/packages
mkdir -p zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/util/modules

cp -f ${repoDir}/zm-build/RE/README.txt                                                 zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/
cp -f ${repoDir}/zm-build/rpmconf/Build/checkLicense.pl                                 zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/bin
cp -f ${repoDir}/zm-build/rpmconf/Build/checkService.pl                                 zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/bin
cp -f ${repoDir}/zm-build/rpmconf/Build/get_plat_tag.sh                                 zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/bin
cp -f ${repoDir}/zm-build/rpmconf/Build/zmValidateLdap.pl                               zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/bin
cp -f ${repoDir}/zm-build/rpmconf/Install/Util/addUser.sh                               zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/util
cp -f ${repoDir}/zm-build/rpmconf/Install/Util/globals.sh                               zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/util
cp -f ${repoDir}/zm-build/rpmconf/Install/Util/modules/getconfig.sh                     zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/util/modules
cp -f ${repoDir}/zm-build/rpmconf/Install/Util/modules/packages.sh                      zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/util/modules
cp -f ${repoDir}/zm-build/rpmconf/Install/Util/modules/postinstall.sh                   zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/util/modules
cp -f ${repoDir}/zm-build/rpmconf/Install/Util/utilfunc.sh                              zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/util
cp -f ${repoDir}/zm-build/rpmconf/Install/install.sh                                    zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/
cp -f ${repoDir}/zm-core-utils/src/libexec/zmdbintegrityreport                          zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/bin
cp -f ${repoDir}/zm-store/build/dist/versions-init.sql                                  zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/data
cp -f ${repoDir}/zm-build/${arch}/*.*                                                   zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/packages

chmod 755 zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/bin/checkService.pl
chmod 755 zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/bin/checkLicense.pl
chmod 755 zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/bin/zmValidateLdap.pl
chmod 755 zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/bin/zmdbintegrityreport
chmod 755 zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/install.sh

cp -f ${repoDir}/zm-admin-help-common/WebRoot/help/en_US/admin/pdf/*.pdf                zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/docs/en_US
cp -f ${repoDir}/zm-admin-help-common/WebRoot/help/en_US/admin/txt/readme_binary.txt    zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/readme_binary_en_US.txt

if [ "${buildType}" == "NETWORK" ]
then
   cp -f ${repoDir}/zm-admin-help-network/WebRoot/help/en_US/admin/pdf/*.pdf               zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/docs/en_US
   cp -f ${repoDir}/zm-admin-help-network/WebRoot/help/en_US/admin/txt/readme_binary.txt   zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/readme_binary_en_US.txt

   cp -f ${repoDir}/zm-backup-store/build/dist/backup-version-init.sql                     zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/data
   cp -f ${repoDir}/zm-license-tools/build/zm-license-tools-*.jar                          zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/lib/jars/zimbra-license-tools.jar

   cp -f ${repoDir}/zm-network-licenses/thirdparty/keyview_eula.txt                        zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/docs/keyview_eula.txt
   cp -f ${repoDir}/zm-network-licenses/thirdparty/oracle_jdk_eula.txt                     zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/docs/oracle_jdk_eula.txt
   cp -f ${repoDir}/zm-network-licenses/zimbra/zimbra_network_eula.txt                     zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/docs/zimbra_network_eula.txt

   cp -f ${repoDir}/zm-network-build/rpmconf/Install/Util/modules/postinstall.sh           zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/util/modules
   cp -f ${repoDir}/zm-network-build/rpmconf/Util/checkValidBackup                         zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/bin/checkValidBackup

   chmod 755 zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}/bin/checkValidBackup
fi

tar czf zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}.tgz                 zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}

echo "Zcs build completed: ${repoDir}/zm-build/zcs-${buildType}-${release}_${buildNo}.${os}.${buildTimeStamp}.tgz"
