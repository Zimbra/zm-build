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

# Shell script to create zimbra core package


#-------------------- Configuration ---------------------------

currentScript="$(basename "$0" | cut -d "." -f 1)"               # zimbra-core
currentPackage="$(echo ${currentScript}build | cut -d "-" -f 2)" # corebuild

#-------------------- Util Functions ---------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$SCRIPT_DIR/utils.sh"

CreateDebianPackage()
{
   echo -e "\tCreate debian package" >> ${buildLogFile}

   mkdir -p "${repoDir}/zm-build/${currentPackage}/DEBIAN";

   cat ${repoDir}/zm-build/rpmconf/Spec/Scripts/${currentScript}.post > ${repoDir}/zm-build/${currentPackage}/DEBIAN/postinst
   cat ${repoDir}/zm-build/rpmconf/Spec/Scripts/${currentScript}.pre  > ${repoDir}/zm-build/${currentPackage}/DEBIAN/preinst

   chmod 555 ${repoDir}/zm-build/${currentPackage}/DEBIAN/preinst
   chmod 555 ${repoDir}/zm-build/${currentPackage}/DEBIAN/postinst

   (
      set -e;
      cd ${repoDir}/zm-build/${currentPackage}
      find . -type f -print0 \
         | xargs -0 md5sum \
         | grep -v -w "DEBIAN/.*" \
         | sed -e "s@ [.][/]@ @" \
         | sort \
   ) > ${repoDir}/zm-build/${currentPackage}/DEBIAN/md5sums

   (
      set -e;
      MORE_DEPENDS="$(find ${repoDir}/zm-packages/ -name \*.deb \
                         | xargs -n1 basename \
                         | sed -e 's/_[0-9].*//' \
                         | grep zimbra-common- \
                         | sed '1s/^/, /; :a; {N;s/\n/, /;ba}')";

      cat ${repoDir}/zm-build/rpmconf/Spec/${currentScript}.deb \
         | sed -e "s/@@VERSION@@/${releaseNo}.${releaseCandidate}.${buildNo}.${os/_/.}/" \
               -e "s/@@branch@@/${buildTimeStamp}/" \
               -e "s/@@ARCH@@/${arch}/" \
               -e "s/@@MORE_DEPENDS@@/${MORE_DEPENDS}/" \
               -e "/^%post$/ r ${currentScript}.post"
   ) > ${repoDir}/zm-build/${currentPackage}/DEBIAN/control

   (
      set -e;
      cd ${repoDir}/zm-build/${currentPackage}
      dpkg -b ${repoDir}/zm-build/${currentPackage} ${repoDir}/zm-build/${arch}
   )
}

CreateRhelPackage()
{
    MORE_DEPENDS="$(find ${repoDir}/zm-packages/ -name \*.rpm \
                       | xargs -n1 basename \
                       | sed -e 's/-[0-9].*//' \
                       | grep zimbra-common- \
                       | sed '1s/^/, /; :a; {N;s/\n/, /;ba}')";

    cat ${repoDir}/zm-build/rpmconf/Spec/${currentScript}.spec | \
    	sed -e "s/@@VERSION@@/${releaseNo}_${releaseCandidate}_${buildNo}.${os}/" \
            	-e "s/@@RELEASE@@/${buildTimeStamp}/" \
                -e "s/@@MORE_DEPENDS@@/${MORE_DEPENDS}/" \
            	-e "/^%pre$/ r ${repoDir}/zm-build/rpmconf/Spec/Scripts/${currentScript}.pre" \
            	-e "/Best email money can buy/ a Network edition" \
            	-e "/^%post$/ r ${repoDir}/zm-build/rpmconf/Spec/Scripts/${currentScript}.post" > ${repoDir}/zm-build/${currentScript}.spec
    (cd ${repoDir}/zm-build/corebuild; find opt -maxdepth 2 -type f -o -type l \
    	| sed -e 's|^|%attr(-, zimbra, zimbra) /|' >> \
    	${repoDir}/zm-build/${currentScript}.spec )
    echo "%attr(440, root, root) /etc/sudoers.d/01_zimbra" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(440, root, root) /etc/sudoers.d/02_zimbra-core" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(755, root, root) /opt/zimbra/bin" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(755, zimbra, zimbra) /opt/zimbra/docs" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(444, zimbra, zimbra) /opt/zimbra/docs/*" >> \
    	${repoDir}/zm-build/${currentScript}.spec

    if [ "${buildType}" == "NETWORK" ]
    then
      echo "%attr(755, zimbra, zimbra) /opt/zimbra/docs/rebranding" >> \
         ${repoDir}/zm-build/${currentScript}.spec
      echo "%attr(444, zimbra, zimbra) /opt/zimbra/docs/rebranding/*" >> \
         ${repoDir}/zm-build/${currentScript}.spec
    fi

    echo "%attr(755, root, root) /opt/zimbra/contrib" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(755, root, root) /opt/zimbra/libexec" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(755, zimbra, zimbra) /opt/zimbra/logger" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(755, zimbra, zimbra) /opt/zimbra/conf" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(644, zimbra, zimbra) /opt/zimbra/conf/*" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(755, zimbra, zimbra) /opt/zimbra/conf/externaldirsync" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(644, zimbra, zimbra) /opt/zimbra/conf/externaldirsync/*" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(755, zimbra, zimbra) /opt/zimbra/conf/sasl2" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(644, zimbra, zimbra) /opt/zimbra/conf/sasl2/*" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(755, zimbra, zimbra) /opt/zimbra/conf/zmconfigd" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(644, zimbra, zimbra) /opt/zimbra/conf/zmconfigd/*" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(-, zimbra, zimbra) /opt/zimbra/db" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(-, root, root) /opt/zimbra/lib" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(-, zimbra, zimbra) /opt/zimbra/conf/crontabs" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(-, root, root) /opt/zimbra/common/lib/jylibs" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(-, root, root) /opt/zimbra/common/lib/perl5/Zimbra" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "%attr(755, zimbra, zimbra) /opt/zimbra/logger/db/work" >> \
    	${repoDir}/zm-build/${currentScript}.spec
    echo "" >> ${repoDir}/zm-build/${currentScript}.spec
    echo "%clean" >> ${repoDir}/zm-build/${currentScript}.spec
    (cd ${repoDir}/zm-build/${currentPackage}; \
    	rpmbuild --target ${arch} --define '_rpmdir ../' --buildroot=${repoDir}/zm-build/${currentPackage} -bb ${repoDir}/zm-build/${currentScript}.spec )
}

#-------------------- main packaging ---------------------------

main()
{
   set -e

   Copy ${repoDir}/zm-build/rpmconf/Env/sudoers.d/01_zimbra                                         ${repoDir}/zm-build/${currentPackage}/etc/sudoers.d/01_zimbra
   Copy ${repoDir}/zm-build/rpmconf/Env/sudoers.d/02_zimbra-core                                    ${repoDir}/zm-build/${currentPackage}/etc/sudoers.d/02_zimbra-core

   Copy ${repoDir}/zm-amavis/conf/amavisd.conf.in                                                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/amavisd.conf.in
   Copy ${repoDir}/zm-amavis/conf/amavisd/amavisd-custom.conf                                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/amavisd-custom.conf
   Copy ${repoDir}/zm-amavis/conf/dspam.conf.in                                                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/dspam.conf.in

   Copy ${repoDir}/zm-build/lib/Zimbra/DB/DB.pm                                                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/perl5/Zimbra/DB/DB.pm
   Copy ${repoDir}/zm-build/lib/Zimbra/LDAP.pm                                                      ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/perl5/Zimbra/LDAP.pm
   Copy ${repoDir}/zm-build/lib/Zimbra/LocalConfig.pm                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/perl5/Zimbra/LocalConfig.pm
   Copy ${repoDir}/zm-build/lib/Zimbra/Mon/Logger.pm                                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/perl5/Zimbra/Mon/Logger.pm
   Copy ${repoDir}/zm-build/lib/Zimbra/Mon/LoggerSchema.pm                                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/perl5/Zimbra/Mon/LoggerSchema.pm
   Copy ${repoDir}/zm-build/lib/Zimbra/Mon/Zmstat.pm                                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/perl5/Zimbra/Mon/Zmstat.pm
   Copy ${repoDir}/zm-build/lib/Zimbra/SMTP.pm                                                      ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/perl5/Zimbra/SMTP.pm
   Copy ${repoDir}/zm-build/lib/Zimbra/SOAP/Soap.pm                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/perl5/Zimbra/SOAP/Soap.pm
   Copy ${repoDir}/zm-build/lib/Zimbra/SOAP/Soap11.pm                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/perl5/Zimbra/SOAP/Soap11.pm
   Copy ${repoDir}/zm-build/lib/Zimbra/SOAP/Soap12.pm                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/perl5/Zimbra/SOAP/Soap12.pm
   Copy ${repoDir}/zm-build/lib/Zimbra/SOAP/XmlDoc.pm                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/perl5/Zimbra/SOAP/XmlDoc.pm
   Copy ${repoDir}/zm-build/lib/Zimbra/SOAP/XmlElement.pm                                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/perl5/Zimbra/SOAP/XmlElement.pm
   Copy ${repoDir}/zm-build/lib/Zimbra/Util/Common.pm                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/perl5/Zimbra/Util/Common.pm
   Copy ${repoDir}/zm-build/lib/Zimbra/Util/LDAP.pm                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/perl5/Zimbra/Util/LDAP.pm
   Copy ${repoDir}/zm-build/lib/Zimbra/Util/Timezone.pm                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/perl5/Zimbra/Util/Timezone.pm
   Copy ${repoDir}/zm-build/lib/Zimbra/ZmClient.pm                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/perl5/Zimbra/ZmClient.pm

   Copy ${repoDir}/zm-build/rpmconf/Build/get_plat_tag.sh                                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/get_plat_tag.sh
   Copy ${repoDir}/zm-build/rpmconf/Build/get_plat_tag.sh                                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/installer/bin/get_plat_tag.sh
   Copy ${repoDir}/zm-build/rpmconf/Conf/auditswatchrc                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/auditswatchrc.in
   Copy ${repoDir}/zm-build/rpmconf/Conf/logswatchrc                                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/logswatchrc
   Copy ${repoDir}/zm-build/rpmconf/Conf/swatchrc                                                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/swatchrc.in
   Copy ${repoDir}/zm-build/rpmconf/Conf/zmssl.cnf.in                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/zmssl.cnf.in
   Copy ${repoDir}/zm-build/rpmconf/Env/crontabs/crontab                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/crontabs/crontab
   Copy ${repoDir}/zm-build/rpmconf/Env/crontabs/crontab.ldap                                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/crontabs/crontab.ldap
   Copy ${repoDir}/zm-build/rpmconf/Env/crontabs/crontab.logger                                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/crontabs/crontab.logger
   Copy ${repoDir}/zm-build/rpmconf/Env/crontabs/crontab.mta                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/crontabs/crontab.mta
   Copy ${repoDir}/zm-build/rpmconf/Env/crontabs/crontab.store                                      ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/crontabs/crontab.store
   Copy ${repoDir}/zm-build/rpmconf/Env/zimbra.bash_profile                                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/.bash_profile
   Copy ${repoDir}/zm-build/rpmconf/Env/zimbra.bashrc                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/.bashrc
   Copy ${repoDir}/zm-build/rpmconf/Env/zimbra.exrc                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/.exrc
   Copy ${repoDir}/zm-build/rpmconf/Env/zimbra.ldaprc                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/.ldaprc
   Copy ${repoDir}/zm-build/rpmconf/Env/zimbra.platform                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/.platform
   Copy ${repoDir}/zm-build/rpmconf/Env/zimbra.viminfo                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/.viminfo
   Copy ${repoDir}/zm-build/rpmconf/Img/connection_failed.gif                                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/logger/db/work/connection_failed.gif
   Copy ${repoDir}/zm-build/rpmconf/Img/data_not_available.gif                                      ${repoDir}/zm-build/${currentPackage}/opt/zimbra/logger/db/work/data_not_available.gif
   Copy ${repoDir}/zm-build/rpmconf/Install/Util/addUser.sh                                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/addUser.sh
   Copy ${repoDir}/zm-build/rpmconf/Install/Util/addUser.sh                                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/installer/util/addUser.sh
   Copy ${repoDir}/zm-build/rpmconf/Install/Util/globals.sh                                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/installer/util/globals.sh
   Copy ${repoDir}/zm-build/rpmconf/Install/Util/modules/getconfig.sh                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/installer/util/modules/getconfig.sh
   Copy ${repoDir}/zm-build/rpmconf/Install/Util/modules/packages.sh                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/installer/util/modules/packages.sh
   Copy ${repoDir}/zm-build/rpmconf/Install/Util/modules/postinstall.sh                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/installer/util/modules/postinstall.sh
   Copy ${repoDir}/zm-build/rpmconf/Install/Util/utilfunc.sh                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/installer/util/utilfunc.sh
   Copy ${repoDir}/zm-build/rpmconf/Install/install.sh                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/installer/install.sh
   Copy ${repoDir}/zm-build/rpmconf/Install/postinstall.pm                                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/postinstall.pm
   Copy ${repoDir}/zm-build/rpmconf/Install/preinstall.pm                                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/preinstall.pm
   Copy ${repoDir}/zm-build/rpmconf/Install/zmsetup.pl                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmsetup.pl
   Copy ${repoDir}/zm-build/rpmconf/Upgrade/zmupgrade.pm                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmupgrade.pm

   Copy ${repoDir}/zm-core-utils/conf/dhparam.pem.zcs                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/dhparam.pem.zcs
   Copy ${repoDir}/zm-core-utils/conf/zmlogrotate                                                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/zmlogrotate
   Copy ${repoDir}/zm-core-utils/src/bin/antispam-mysql                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/antispam-mysql
   Copy ${repoDir}/zm-core-utils/src/bin/antispam-mysql.server                                      ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/antispam-mysql.server
   Copy ${repoDir}/zm-core-utils/src/bin/antispam-mysqladmin                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/antispam-mysqladmin
   Copy ${repoDir}/zm-core-utils/src/bin/ldap.production                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/ldap
   Copy ${repoDir}/zm-core-utils/src/bin/mysql                                                      ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/mysql
   Copy ${repoDir}/zm-core-utils/src/bin/mysql.server                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/mysql.server
   Copy ${repoDir}/zm-core-utils/src/bin/mysqladmin                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/mysqladmin
   Copy ${repoDir}/zm-core-utils/src/bin/postconf                                                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/postconf
   Copy ${repoDir}/zm-core-utils/src/bin/postfix                                                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/postfix
   Copy ${repoDir}/zm-core-utils/src/bin/qshape                                                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/qshape
   Copy ${repoDir}/zm-core-utils/src/bin/zmaccts                                                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmaccts
   Copy ${repoDir}/zm-core-utils/src/bin/zmamavisdctl                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmamavisdctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmantispamctl                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmantispamctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmantispamdbpasswd                                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmantispamdbpasswd
   Copy ${repoDir}/zm-core-utils/src/bin/zmantivirusctl                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmantivirusctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmapachectl                                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmapachectl
   Copy ${repoDir}/zm-core-utils/src/bin/zmarchivectl                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmarchivectl
   Copy ${repoDir}/zm-core-utils/src/bin/zmauditswatchctl                                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmauditswatchctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmblobchk                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmblobchk
   Copy ${repoDir}/zm-core-utils/src/bin/zmcaldebug                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmcaldebug
   Copy ${repoDir}/zm-core-utils/src/bin/zmcbpadmin                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmcbpadmin
   Copy ${repoDir}/zm-core-utils/src/bin/zmcbpolicydctl                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmcbpolicydctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmcertmgr                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmcertmgr
   Copy ${repoDir}/zm-core-utils/src/bin/zmclamdctl                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmclamdctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmconfigdctl                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmconfigdctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmcontrol                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmcontrol
   Copy ${repoDir}/zm-core-utils/src/bin/zmdedupe                                                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmdedupe
   Copy ${repoDir}/zm-core-utils/src/bin/zmdhparam                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmdhparam
   Copy ${repoDir}/zm-core-utils/src/bin/zmdnscachectl                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmdnscachectl
   Copy ${repoDir}/zm-core-utils/src/bin/zmdumpenv                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmdumpenv
   Copy ${repoDir}/zm-core-utils/src/bin/zmfixcalendtime                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmfixcalendtime
   Copy ${repoDir}/zm-core-utils/src/bin/zmfixcalprio                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmfixcalprio
   Copy ${repoDir}/zm-core-utils/src/bin/zmfreshclamctl                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmfreshclamctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmgsautil                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmgsautil
   Copy ${repoDir}/zm-core-utils/src/bin/zmhostname                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmhostname
   Copy ${repoDir}/zm-core-utils/src/bin/zminnotop                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zminnotop
   Copy ${repoDir}/zm-core-utils/src/bin/zmitemdatafile                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmitemdatafile
   Copy ${repoDir}/zm-core-utils/src/bin/zmjava                                                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmjava
   Copy ${repoDir}/zm-core-utils/src/bin/zmjavaext                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmjavaext
   Copy ${repoDir}/zm-core-utils/src/bin/zmldappasswd                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmldappasswd
   Copy ${repoDir}/zm-core-utils/src/bin/zmldapupgrade                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmldapupgrade
   Copy ${repoDir}/zm-core-utils/src/bin/zmlmtpinject                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmlmtpinject
   Copy ${repoDir}/zm-core-utils/src/bin/zmlocalconfig                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmlocalconfig
   Copy ${repoDir}/zm-core-utils/src/bin/zmloggerctl                                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmloggerctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmloggerhostmap                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmloggerhostmap
   Copy ${repoDir}/zm-core-utils/src/bin/zmlogswatchctl                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmlogswatchctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmmailbox                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmmailbox
   Copy ${repoDir}/zm-core-utils/src/bin/zmmailboxdctl                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmmailboxdctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmmemcachedctl                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmmemcachedctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmmetadump                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmmetadump
   Copy ${repoDir}/zm-core-utils/src/bin/zmmigrateattrs                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmmigrateattrs
   Copy ${repoDir}/zm-core-utils/src/bin/zmmilterctl                                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmmilterctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmmtactl                                                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmmtactl
   Copy ${repoDir}/zm-core-utils/src/bin/zmmypasswd                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmmypasswd
   Copy ${repoDir}/zm-core-utils/src/bin/zmmysqlstatus                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmmysqlstatus
   Copy ${repoDir}/zm-core-utils/src/bin/zmmytop                                                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmmytop
   Copy ${repoDir}/zm-core-utils/src/bin/zmopendkimctl                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmopendkimctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmplayredo                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmplayredo
   Copy ${repoDir}/zm-core-utils/src/bin/zmprov                                                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmprov
   Copy ${repoDir}/zm-core-utils/src/bin/zmproxyconf                                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmproxyconf
   Copy ${repoDir}/zm-core-utils/src/bin/zmproxyctl                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmproxyctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmpython                                                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmpython
   Copy ${repoDir}/zm-core-utils/src/bin/zmredodump                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmredodump
   Copy ${repoDir}/zm-core-utils/src/bin/zmresolverctl                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmresolverctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmsaslauthdctl                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmsaslauthdctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmshutil                                                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmshutil
   Copy ${repoDir}/zm-core-utils/src/bin/zmskindeploy                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmskindeploy
   Copy ${repoDir}/zm-core-utils/src/bin/zmsoap                                                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmsoap
   Copy ${repoDir}/zm-core-utils/src/bin/zmspellctl                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmspellctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmsshkeygen                                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmsshkeygen
   Copy ${repoDir}/zm-core-utils/src/bin/zmstat-chart                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmstat-chart
   Copy ${repoDir}/zm-core-utils/src/bin/zmstat-chart-config                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmstat-chart-config
   Copy ${repoDir}/zm-core-utils/src/bin/zmstatctl                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmstatctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmstorectl                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmstorectl
   Copy ${repoDir}/zm-core-utils/src/bin/zmswatchctl                                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmswatchctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmthrdump                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmthrdump
   Copy ${repoDir}/zm-core-utils/src/bin/zmtlsctl                                                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmtlsctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmtotp                                                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmtotp
   Copy ${repoDir}/zm-core-utils/src/bin/zmtrainsa                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmtrainsa
   Copy ${repoDir}/zm-core-utils/src/bin/zmtzupdate                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmtzupdate
   Copy ${repoDir}/zm-core-utils/src/bin/zmupdateauthkeys                                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmupdateauthkeys
   Copy ${repoDir}/zm-core-utils/src/bin/zmvolume                                                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmvolume
   Copy ${repoDir}/zm-core-utils/src/bin/zmzimletctl                                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmzimletctl
   Copy ${repoDir}/zm-core-utils/src/contrib/zmfetchercfg                                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/contrib/zmfetchercfg
   Copy ${repoDir}/zm-core-utils/src/libexec/600.zimbra                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/600.zimbra
   Copy ${repoDir}/zm-core-utils/src/libexec/client_usage_report.py                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/client_usage_report.py
   Copy ${repoDir}/zm-core-utils/src/libexec/configrewrite                                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/configrewrite
   Copy ${repoDir}/zm-core-utils/src/libexec/icalmig                                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/icalmig
   Copy ${repoDir}/zm-core-utils/src/libexec/libreoffice-installer.sh                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/libreoffice-installer.sh
   Copy ${repoDir}/zm-core-utils/src/libexec/zcs                                                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zcs
   Copy ${repoDir}/zm-core-utils/src/libexec/zimbra                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zimbra
   Copy ${repoDir}/zm-core-utils/src/libexec/zmaltermimeconfig                                      ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmaltermimeconfig
   Copy ${repoDir}/zm-core-utils/src/libexec/zmantispamdbinit                                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmantispamdbinit
   Copy ${repoDir}/zm-core-utils/src/libexec/zmantispammycnf                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmantispammycnf
   Copy ${repoDir}/zm-core-utils/src/libexec/zmcbpolicydinit                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmcbpolicydinit
   Copy ${repoDir}/zm-core-utils/src/libexec/zmcheckduplicatemysqld                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmcheckduplicatemysqld
   Copy ${repoDir}/zm-core-utils/src/libexec/zmcheckexpiredcerts                                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmcheckexpiredcerts
   Copy ${repoDir}/zm-core-utils/src/libexec/zmcleantmp                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmcleantmp
   Copy ${repoDir}/zm-core-utils/src/libexec/zmclientcertmgr                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmclientcertmgr
   Copy ${repoDir}/zm-core-utils/src/libexec/zmcompresslogs                                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmcompresslogs
   Copy ${repoDir}/zm-core-utils/src/libexec/zmcomputequotausage                                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmcomputequotausage
   Copy ${repoDir}/zm-core-utils/src/libexec/zmconfigd                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmconfigd
   Copy ${repoDir}/zm-core-utils/src/libexec/zmcpustat                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmcpustat
   Copy ${repoDir}/zm-core-utils/src/libexec/zmdailyreport                                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmdailyreport
   Copy ${repoDir}/zm-core-utils/src/libexec/zmdbintegrityreport                                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmdbintegrityreport
   Copy ${repoDir}/zm-core-utils/src/libexec/zmdiaglog                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmdiaglog
   Copy ${repoDir}/zm-core-utils/src/libexec/zmdkimkeyutil                                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmdkimkeyutil
   Copy ${repoDir}/zm-core-utils/src/libexec/zmdnscachealign                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmdnscachealign
   Copy ${repoDir}/zm-core-utils/src/libexec/zmdomaincertmgr                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmdomaincertmgr
   Copy ${repoDir}/zm-core-utils/src/libexec/zmexplainslow                                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmexplainslow
   Copy ${repoDir}/zm-core-utils/src/libexec/zmexplainsql                                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmexplainsql
   Copy ${repoDir}/zm-core-utils/src/libexec/zmextractsql                                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmextractsql
   Copy ${repoDir}/zm-core-utils/src/libexec/zmfixperms                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmfixperms
   Copy ${repoDir}/zm-core-utils/src/libexec/zmfixreminder                                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmfixreminder
   Copy ${repoDir}/zm-core-utils/src/libexec/zmgenentitlement                                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmgenentitlement
   Copy ${repoDir}/zm-core-utils/src/libexec/zmgsaupdate                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmgsaupdate
   Copy ${repoDir}/zm-core-utils/src/libexec/zmhspreport                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmhspreport
   Copy ${repoDir}/zm-core-utils/src/libexec/zminiutil                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zminiutil
   Copy ${repoDir}/zm-core-utils/src/libexec/zmiostat                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmiostat
   Copy ${repoDir}/zm-core-utils/src/libexec/zmiptool                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmiptool
   Copy ${repoDir}/zm-core-utils/src/libexec/zmjavawatch                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmjavawatch
   Copy ${repoDir}/zm-core-utils/src/libexec/zmjsprecompile                                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmjsprecompile
   Copy ${repoDir}/zm-core-utils/src/libexec/zmlogger                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmlogger
   Copy ${repoDir}/zm-core-utils/src/libexec/zmloggerinit                                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmloggerinit
   Copy ${repoDir}/zm-core-utils/src/libexec/zmlogprocess                                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmlogprocess
   Copy ${repoDir}/zm-core-utils/src/libexec/zmmsgtrace                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmmsgtrace
   Copy ${repoDir}/zm-core-utils/src/libexec/zmmtainit                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmmtainit
   Copy ${repoDir}/zm-core-utils/src/libexec/zmmtastatus                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmmtastatus
   Copy ${repoDir}/zm-core-utils/src/libexec/zmmycnf                                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmmycnf
   Copy ${repoDir}/zm-core-utils/src/libexec/zmmyinit                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmmyinit
   Copy ${repoDir}/zm-core-utils/src/libexec/zmnotifyinstall                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmnotifyinstall
   Copy ${repoDir}/zm-core-utils/src/libexec/zmpostfixpolicyd                                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmpostfixpolicyd
   Copy ${repoDir}/zm-core-utils/src/libexec/zmproxyconfgen                                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmproxyconfgen
   Copy ${repoDir}/zm-core-utils/src/libexec/zmproxyconfig                                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmproxyconfig
   Copy ${repoDir}/zm-core-utils/src/libexec/zmproxypurge                                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmproxypurge
   Copy ${repoDir}/zm-core-utils/src/libexec/zmqaction                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmqaction
   Copy ${repoDir}/zm-core-utils/src/libexec/zmqstat                                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmqstat
   Copy ${repoDir}/zm-core-utils/src/libexec/zmqueuelog                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmqueuelog
   Copy ${repoDir}/zm-core-utils/src/libexec/zmrc                                                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmrc
   Copy ${repoDir}/zm-core-utils/src/libexec/zmrcd                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmrcd
   Copy ${repoDir}/zm-core-utils/src/libexec/zmresetmysqlpassword                                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmresetmysqlpassword
   Copy ${repoDir}/zm-core-utils/src/libexec/zmrrdfetch                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmrrdfetch
   Copy ${repoDir}/zm-core-utils/src/libexec/zmsacompile                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmsacompile
   Copy ${repoDir}/zm-core-utils/src/libexec/zmsaupdate                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmsaupdate
   Copy ${repoDir}/zm-core-utils/src/libexec/zmserverips                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmserverips
   Copy ${repoDir}/zm-core-utils/src/libexec/zmsetservername                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmsetservername
   Copy ${repoDir}/zm-core-utils/src/libexec/zmsnmpinit                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmsnmpinit
   Copy ${repoDir}/zm-core-utils/src/libexec/zmspamextract                                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmspamextract
   Copy ${repoDir}/zm-core-utils/src/libexec/zmstat-allprocs                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmstat-allprocs
   Copy ${repoDir}/zm-core-utils/src/libexec/zmstat-cleanup                                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmstat-cleanup
   Copy ${repoDir}/zm-core-utils/src/libexec/zmstat-convertd                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmstat-convertd
   Copy ${repoDir}/zm-core-utils/src/libexec/zmstat-cpu                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmstat-cpu
   Copy ${repoDir}/zm-core-utils/src/libexec/zmstat-df                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmstat-df
   Copy ${repoDir}/zm-core-utils/src/libexec/zmstat-fd                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmstat-fd
   Copy ${repoDir}/zm-core-utils/src/libexec/zmstat-io                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmstat-io
   Copy ${repoDir}/zm-core-utils/src/libexec/zmstat-mtaqueue                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmstat-mtaqueue
   Copy ${repoDir}/zm-core-utils/src/libexec/zmstat-mysql                                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmstat-mysql
   Copy ${repoDir}/zm-core-utils/src/libexec/zmstat-nginx                                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmstat-nginx
   Copy ${repoDir}/zm-core-utils/src/libexec/zmstat-proc                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmstat-proc
   Copy ${repoDir}/zm-core-utils/src/libexec/zmstat-vm                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmstat-vm
   Copy ${repoDir}/zm-core-utils/src/libexec/zmstatuslog                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmstatuslog
   Copy ${repoDir}/zm-core-utils/src/libexec/zmsyslogsetup                                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmsyslogsetup
   Copy ${repoDir}/zm-core-utils/src/libexec/zmthreadcpu                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmthreadcpu
   Copy ${repoDir}/zm-core-utils/src/libexec/zmunbound                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmunbound
   Copy ${repoDir}/zm-core-utils/src/libexec/zmupdatedownload                                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmupdatedownload
   Copy ${repoDir}/zm-core-utils/src/libexec/zmupdatezco                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmupdatezco
   Copy ${repoDir}/zm-core-utils/src/perl/migrate20131014-removezca.pl                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20131014-removezca.pl

   Copy ${repoDir}/zm-db-conf/src/db/migration/Migrate.pm                                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/Migrate.pm
   Copy ${repoDir}/zm-db-conf/src/db/migration/clearArchivedFlag.pl                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/clearArchivedFlag.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/fixConversationCounts.pl                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/fixConversationCounts.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/fixZeroChangeIdItems.pl                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/fixZeroChangeIdItems.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/fixup20080410-SetRsvpTrue.pl                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/fixup20080410-SetRsvpTrue.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate-ComboUpdater.pl                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate-ComboUpdater.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20050517-AddUnreadColumn.pl                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20050517-AddUnreadColumn.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20050531-RemoveCascadingDeletes.pl            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20050531-RemoveCascadingDeletes.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20050609-AddDateIndex.pl                      ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20050609-AddDateIndex.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20050628-ShrinkSyncColumns.pl                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20050628-ShrinkSyncColumns.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20050701-SchemaCleanup.pl                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20050701-SchemaCleanup.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20050721-MailItemIndexes.pl                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20050721-MailItemIndexes.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20050727-RemoveTypeInvite.pl                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20050727-RemoveTypeInvite.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20050727a-Volume.pl                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20050727a-Volume.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20050804-SpamToJunk.pl                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20050804-SpamToJunk.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20050809-AddConfig.pl                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20050809-AddConfig.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20050811-WipeAppointments.pl                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20050811-WipeAppointments.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20050818-TagsFlagsIndexes.pl                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20050818-TagsFlagsIndexes.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20050822-TrackChangeDate.pl                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20050822-TrackChangeDate.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20050824-AddMailTransport.sh                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20050824-AddMailTransport.sh
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20050824a-Volume.pl                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20050824a-Volume.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20050831-SecondaryMsgVolume.pl                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20050831-SecondaryMsgVolume.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20050916-Volume.pl                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20050916-Volume.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20050920-CompressionThreshold.pl              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20050920-CompressionThreshold.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20050927-DropRedologSequence.pl               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20050927-DropRedologSequence.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20051021-UniqueVolume.pl                      ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20051021-UniqueVolume.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20060120-Appointment.pl                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20060120-Appointment.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20060412-NotebookFolder.pl                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20060412-NotebookFolder.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20060515-AddImapId.pl                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20060515-AddImapId.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20060518-EmailedContactsFolder.pl             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20060518-EmailedContactsFolder.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20060708-FlagCalendarFolder.pl                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20060708-FlagCalendarFolder.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20060803-CreateMailboxMetadata.pl             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20060803-CreateMailboxMetadata.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20060807-WikiDigestFixup.sh                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20060807-WikiDigestFixup.sh
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20060810-PersistFolderCounts.pl               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20060810-PersistFolderCounts.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20060911-MailboxGroup.pl                      ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20060911-MailboxGroup.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20060929-TypedTombstones.pl                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20060929-TypedTombstones.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20061101-IMFolder.pl                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20061101-IMFolder.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20061117-TasksFolder.pl                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20061117-TasksFolder.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20061120-AddNameColumn.pl                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20061120-AddNameColumn.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20061204-CreatePop3MessageTable.pl            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20061204-CreatePop3MessageTable.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20061205-UniqueAppointmentIndex.pl            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20061205-UniqueAppointmentIndex.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20061212-RepairMutableIndexIds.pl             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20061212-RepairMutableIndexIds.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20061221-RecalculateFolderSizes.pl            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20061221-RecalculateFolderSizes.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20070302-NullContactVolumeId.pl               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20070302-NullContactVolumeId.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20070306-Pop3MessageUid.pl                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20070306-Pop3MessageUid.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20070606-WidenMetadata.pl                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20070606-WidenMetadata.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20070614-BriefcaseFolder.pl                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20070614-BriefcaseFolder.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20070627-BackupTime.pl                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20070627-BackupTime.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20070629-IMTables.pl                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20070629-IMTables.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20070630-LastSoapAccess.pl                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20070630-LastSoapAccess.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20070703-ScheduledTask.pl                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20070703-ScheduledTask.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20070706-DeletedAccount.pl                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20070706-DeletedAccount.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20070713-NullContactBlobDigest.pl             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20070713-NullContactBlobDigest.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20070725-CreateRevisionTable.pl               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20070725-CreateRevisionTable.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20070726-ImapDataSource.pl                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20070726-ImapDataSource.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20070809-Signatures.pl                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20070809-Signatures.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20070921-ImapDataSourceUidValidity.pl         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20070921-ImapDataSourceUidValidity.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20070928-ScheduledTaskIndex.pl                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20070928-ScheduledTaskIndex.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20071128-AccountId.pl                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20071128-AccountId.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20071202-DeleteSignatures.pl                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20071202-DeleteSignatures.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20071204-deleteOldLDAPUsers.pl                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20071204-deleteOldLDAPUsers.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20071206-WidenSizeColumns.pl                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20071206-WidenSizeColumns.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20080130-ImapFlags.pl                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20080130-ImapFlags.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20080213-IndexDeferredColumn.pl               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20080213-IndexDeferredColumn.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20080909-DataSourceItemTable.pl               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20080909-DataSourceItemTable.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20080930-MucService.pl                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20080930-MucService.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20090315-MobileDevices.pl                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20090315-MobileDevices.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20090406-DataSourceItemTable.pl               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20090406-DataSourceItemTable.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20090430-highestindexed.pl                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20090430-highestindexed.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20100106-MobileDevices.pl                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20100106-MobileDevices.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20100913-Mysql51.pl                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20100913-Mysql51.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20100926-Dumpster.pl                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20100926-Dumpster.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20101123-MobileDevices.pl                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20101123-MobileDevices.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20110314-MobileDevices.pl                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20110314-MobileDevices.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20110330-RecipientsColumn.pl                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20110330-RecipientsColumn.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20110705-PendingAclPush.pl                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20110705-PendingAclPush.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20110810-TagTable.pl                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20110810-TagTable.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20110928-MobileDevices.pl                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20110928-MobileDevices.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20110929-VersionColumn.pl                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20110929-VersionColumn.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20111005-ItemIdCheckpoint.pl                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20111005-ItemIdCheckpoint.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20120125-uuidAndDigest.pl                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20120125-uuidAndDigest.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20120222-LastPurgeAtColumn.pl                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20120222-LastPurgeAtColumn.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20120229-DropIMTables.pl                      ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20120229-DropIMTables.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20120319-Name255Chars.pl                      ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20120319-Name255Chars.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20120410-BlobLocator.pl                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20120410-BlobLocator.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20120611_7to8_bundle.pl                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20120611_7to8_bundle.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20121009-VolumeBlobs.pl                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20121009-VolumeBlobs.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20130226_alwayson.pl                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20130226_alwayson.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20130227-UpgradeCBPolicyDSchema.sql           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20130227-UpgradeCBPolicyDSchema.sql
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20130606-UpdateCBPolicydSchema.sql            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20130606-UpdateCBPolicydSchema.sql
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20130819-UpgradeQuotasTable.sql               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20130819-UpgradeQuotasTable.sql
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20140319-MailItemPrevFolders.pl               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20140319-MailItemPrevFolders.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20140328-EnforceTableCharset.pl               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20140328-EnforceTableCharset.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20140624-DropMysqlIndexes.pl                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20140624-DropMysqlIndexes.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20150401-ZmgDevices.pl                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20150401-ZmgDevices.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20150515-DataSourcePurgeTables.pl             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20150515-DataSourcePurgeTables.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20150623-ZmgDevices.pl                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20150623-ZmgDevices.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20150702-ZmgDevices.pl                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20150702-ZmgDevices.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20170301-ZimbraChat.pl                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20170301-ZimbraChat.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrateAmavisLdap20050810.pl                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrateAmavisLdap20050810.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrateClearSpamFlag.pl                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrateClearSpamFlag.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrateLargeMetadata.pl                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrateLargeMetadata.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrateLogger1-index.pl                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrateLogger1-index.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrateLogger2-config.pl                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrateLogger2-config.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrateLogger3-diskindex.pl                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrateLogger3-diskindex.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrateLogger4-loghostname.pl                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrateLogger4-loghostname.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrateLogger5-qid.pl                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrateLogger5-qid.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrateLogger6-qid.pl                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrateLogger6-qid.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrateMailItemTimestamps.pl                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrateMailItemTimestamps.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migratePreWidenSizeColumns.pl                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migratePreWidenSizeColumns.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrateRemoveMailboxId.pl                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrateRemoveMailboxId.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrateRemoveTagIndexes.pl                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrateRemoveTagIndexes.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrateRenameIdentifiers.pl                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrateRenameIdentifiers.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrateSyncSequence.pl                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrateSyncSequence.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrateToSplitTables.pl                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrateToSplitTables.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrateUpdateAppointment.pl                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrateUpdateAppointment.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/optimizeMboxgroups.pl                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/optimizeMboxgroups.pl
   Copy ${repoDir}/zm-db-conf/src/db/mysql/create_database.sql                                      ${repoDir}/zm-build/${currentPackage}/opt/zimbra/db/create_database.sql
   Copy ${repoDir}/zm-db-conf/src/db/mysql/db.sql                                                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/db/db.sql

   Copy ${repoDir}/zm-freshclam/freshclam.conf.in                                                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/freshclam.conf.in

   Copy ${repoDir}/zm-jython/jylibs/commands.py                                                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/jylibs/commands.py
   Copy ${repoDir}/zm-jython/jylibs/conf.py                                                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/jylibs/conf.py
   Copy ${repoDir}/zm-jython/jylibs/config.py                                                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/jylibs/config.py
   Copy ${repoDir}/zm-jython/jylibs/globalconfig.py                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/jylibs/globalconfig.py
   Copy ${repoDir}/zm-jython/jylibs/ldap.py                                                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/jylibs/ldap.py
   Copy ${repoDir}/zm-jython/jylibs/listener.py                                                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/jylibs/listener.py
   Copy ${repoDir}/zm-jython/jylibs/localconfig.py                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/jylibs/localconfig.py
   Copy ${repoDir}/zm-jython/jylibs/logmsg.py                                                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/jylibs/logmsg.py
   Copy ${repoDir}/zm-jython/jylibs/miscconfig.py                                                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/jylibs/miscconfig.py
   Copy ${repoDir}/zm-jython/jylibs/mtaconfig.py                                                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/jylibs/mtaconfig.py
   Copy ${repoDir}/zm-jython/jylibs/serverconfig.py                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/jylibs/serverconfig.py
   Copy ${repoDir}/zm-jython/jylibs/state.py                                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/common/lib/jylibs/state.py

   Copy ${repoDir}/zm-launcher/build/dist/zmmailboxdmgr                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmmailboxdmgr
   Copy ${repoDir}/zm-launcher/build/dist/zmmailboxdmgr.unrestricted                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmmailboxdmgr.unrestricted 

   Copy ${repoDir}/zm-ldap-utilities/conf/externaldirsync/Exchange2000.xml                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/externaldirsync/Exchange2000.xml
   Copy ${repoDir}/zm-ldap-utilities/conf/externaldirsync/Exchange2003.xml                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/externaldirsync/Exchange2003.xml
   Copy ${repoDir}/zm-ldap-utilities/conf/externaldirsync/Exchange5.5.xml                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/externaldirsync/Exchange5.5.xml
   Copy ${repoDir}/zm-ldap-utilities/conf/externaldirsync/domino.xml                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/externaldirsync/domino.xml
   Copy ${repoDir}/zm-ldap-utilities/conf/externaldirsync/novellGroupWise.xml                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/externaldirsync/novellGroupWise.xml
   Copy ${repoDir}/zm-ldap-utilities/conf/externaldirsync/openldap.xml                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/externaldirsync/openldap.xml
   Copy ${repoDir}/zm-ldap-utilities/conf/freshclam.conf.in                                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/freshclam.conf.in
   Copy ${repoDir}/zm-ldap-utilities/conf/zmconfigd.cf                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/zmconfigd.cf
   Copy ${repoDir}/zm-ldap-utilities/conf/zmconfigd.log4j.properties                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/zmconfigd.log4j.properties
   Copy ${repoDir}/zm-ldap-utilities/src/ldap/migration/migrate20110615-AddDynlist.pl               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20110615-AddDynlist.pl
   Copy ${repoDir}/zm-ldap-utilities/src/ldap/migration/migrate20110721-AddUnique.pl                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20110721-AddUnique.pl
   Copy ${repoDir}/zm-ldap-utilities/src/ldap/migration/migrate20111019-UniqueZimbraId.pl           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20111019-UniqueZimbraId.pl
   Copy ${repoDir}/zm-ldap-utilities/src/ldap/migration/migrate20120210-AddSearchNoOp.pl            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20120210-AddSearchNoOp.pl
   Copy ${repoDir}/zm-ldap-utilities/src/ldap/migration/migrate20120507-UniqueDKIMSelector.pl       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20120507-UniqueDKIMSelector.pl
   Copy ${repoDir}/zm-ldap-utilities/src/ldap/migration/migrate20140728-AddSSHA512.pl               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20140728-AddSSHA512.pl
   Copy ${repoDir}/zm-ldap-utilities/src/ldap/migration/migrate20141022-AddTLSBits.pl               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20141022-AddTLSBits.pl
   Copy ${repoDir}/zm-ldap-utilities/src/ldap/migration/migrate20150930-AddSyncpovSessionlog.pl     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20150930-AddSyncpovSessionlog.pl
   Copy ${repoDir}/zm-ldap-utilities/src/libexec/zmldapanon                                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmldapanon
   Copy ${repoDir}/zm-ldap-utilities/src/libexec/zmldapapplyldif                                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmldapapplyldif
   Copy ${repoDir}/zm-ldap-utilities/src/libexec/zmldapenable-mmr                                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmldapenable-mmr
   Copy ${repoDir}/zm-ldap-utilities/src/libexec/zmldapenablereplica                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmldapenablereplica
   Copy ${repoDir}/zm-ldap-utilities/src/libexec/zmldapinit                                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmldapinit
   Copy ${repoDir}/zm-ldap-utilities/src/libexec/zmldapmmrtool                                      ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmldapmmrtool
   Copy ${repoDir}/zm-ldap-utilities/src/libexec/zmldapmonitordb                                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmldapmonitordb
   Copy ${repoDir}/zm-ldap-utilities/src/libexec/zmldappromote-replica-mmr                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmldappromote-replica-mmr
   Copy ${repoDir}/zm-ldap-utilities/src/libexec/zmldapreplicatool                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmldapreplicatool
   Copy ${repoDir}/zm-ldap-utilities/src/libexec/zmldapschema                                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmldapschema
   Copy ${repoDir}/zm-ldap-utilities/src/libexec/zmldapupdateldif                                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmldapupdateldif
   Copy ${repoDir}/zm-ldap-utilities/src/libexec/zmreplchk                                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmreplchk
   Copy ${repoDir}/zm-ldap-utilities/src/libexec/zmslapadd                                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmslapadd
   Copy ${repoDir}/zm-ldap-utilities/src/libexec/zmslapcat                                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmslapcat
   Copy ${repoDir}/zm-ldap-utilities/src/libexec/zmslapd                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmslapd
   Copy ${repoDir}/zm-ldap-utilities/src/libexec/zmslapindex                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmslapindex
   Copy ${repoDir}/zm-ldap-utilities/src/libexec/zmstat-ldap                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmstat-ldap

   Copy ${repoDir}/zm-licenses/zimbra/ypl-full.txt                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/YPL.txt
   Copy ${repoDir}/zm-licenses/zimbra/zpl-full.txt                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/ZPL.txt

   Copy ${repoDir}/zm-migration-tools/ReadMe.txt                                                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/zmztozmig.txt

   Copy ${repoDir}/zm-mta/cbpolicyd.conf.in                                                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/cbpolicyd.conf.in
   Copy ${repoDir}/zm-mta/clamd.conf.in                                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/clamd.conf.in
   Copy ${repoDir}/zm-mta/opendkim-localnets.conf.in                                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/opendkim-localnets.conf.in
   Copy ${repoDir}/zm-mta/opendkim.conf.in                                                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/opendkim.conf.in
   Copy ${repoDir}/zm-mta/postfix_header_checks.in                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/postfix_header_checks.in
   Copy ${repoDir}/zm-mta/postfix_sasl_smtpd.conf                                                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/sasl2/smtpd.conf.in
   Copy ${repoDir}/zm-mta/salocal.cf.in                                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/salocal.cf.in
   Copy ${repoDir}/zm-mta/saslauthd.conf.in                                                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/saslauthd.conf.in
   Copy ${repoDir}/zm-mta/zmconfigd/postfix_content_filter.cf                                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/zmconfigd/postfix_content_filter.cf
   Copy ${repoDir}/zm-mta/zmconfigd/smtpd_end_of_data_restrictions.cf                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/zmconfigd/smtpd_end_of_data_restrictions.cf
   Copy ${repoDir}/zm-mta/zmconfigd/smtpd_recipient_restrictions.cf                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/zmconfigd/smtpd_recipient_restrictions.cf
   Copy ${repoDir}/zm-mta/zmconfigd/smtpd_relay_restrictions.cf                                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/zmconfigd/smtpd_relay_restrictions.cf
   Copy ${repoDir}/zm-mta/zmconfigd/smtpd_sender_login_maps.cf                                      ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/zmconfigd/smtpd_sender_login_maps.cf
   Copy ${repoDir}/zm-mta/zmconfigd/smtpd_sender_restrictions.cf                                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/zmconfigd/smtpd_sender_restrictions.cf

   Copy ${repoDir}/zm-timezones/conf/timezones.ics                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/timezones.ics

   Cpy2 ${repoDir}/junixsocket/junixsocket-native/build/junixsocket-native-*.nar                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/
   Cpy2 ${repoDir}/junixsocket/junixsocket-native/build/libjunixsocket-native-*.so                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/

   local zimbrathirdpartyjars=(
      "ant-1.7.0-ziputil-patched.jar"
      "ant-contrib-1.0b2.jar"
      "ant-tar-patched.jar"
      "antlr-3.2.jar"
      "apache-jsieve-core-0.5.jar"
      "apache-log4j-extras-1.0.jar"
      "asm-3.3.1.jar"
      "bcprov-jdk15-1.46.jar"
      "commons-cli-1.2.jar"
      "commons-codec-1.7.jar"
      "commons-collections-3.2.2.jar"
      "commons-compress-1.10.jar"
      "commons-csv-1.2.jar"
      "commons-dbcp-1.4.jar"
      "commons-fileupload-1.2.2.jar"
      "commons-httpclient-3.1.jar"
      "commons-io-1.4.jar"
      "commons-lang-2.6.jar"
      "commons-net-3.3.jar"
      "commons-pool-1.6.jar"
      "concurrentlinkedhashmap-lru-1.3.1.jar"
      "curator-client-2.0.1-incubating.jar"
      "curator-client-2.0.1-incubating.jar"
      "curator-framework-2.0.1-incubating.jar"
      "curator-recipes-2.0.1-incubating.jar"
      "curator-x-discovery-2.0.1-incubating.jar"
      "cxf-2.7.18.jar"
      "dom4j-1.5.2.jar"
      "freemarker-2.3.19.jar"
      "ganymed-ssh2-build210.jar"
      "gifencoder-0.9.jar"
      "gmbal-api-only-2.2.6.jar"
      "guava-13.0.1.jar"
      "helix-core-0.6.1-incubating.jar"
      "httpasyncclient-4.1.2.jar"
      "httpclient-4.5.2.jar"
      "httpcore-4.4.5.jar"
      "httpcore-nio-4.4.5.jar"
      "ical4j-0.9.16-patched.jar"
      "icu4j-4.8.1.1.jar"
      "jackson-mapper-asl-1.9.13.jar"
      "jamm-0.2.5.jar"
      "javax.servlet-api-3.1.0.jar"
      "javax.ws.rs-api-2.0-m10.jar"
      "jaxb-api-2.2.6.jar"
      "jaxb-impl-2.2.6.jar"
      "jaxen-1.1.3.jar"
      "jaxws-api-2.2.6.jar"
      "jaxws-rt-2.2.6.jar"
      "jcharset-2.0.jar"
      "jcommon-1.0.21.jar"
      "jcs-1.3.jar"
      "jdom-1.1.jar"
      "jersey-client-1.11.jar"
      "jersey-core-1.11.jar"
      "jersey-json-1.11.jar"
      "jersey-multipart-1.11.jar"
      "jersey-server-1.11.jar"
      "jersey-servlet-1.11.jar"
      "jetty-continuation-9.3.5.v20151012.jar"
      "jetty-http-9.3.5.v20151012.jar"
      "jetty-io-9.3.5.v20151012.jar"
      "jetty-rewrite-9.3.5.v20151012.jar"
      "jetty-security-9.3.5.v20151012.jar"
      "jetty-server-9.3.5.v20151012.jar"
      "jetty-servlet-9.3.5.v20151012.jar"
      "jetty-servlets-9.3.5.v20151012.jar"
      "jetty-util-9.3.5.v20151012.jar"
      "jfreechart-1.0.15.jar"
      "jna-3.4.0.jar"
      "jsr181-api-1.0-MR1.jar"
      "jsr311-api-1.1.1.jar"
      "junixsocket-common-2.0.4.jar"
      "junixsocket-demo-2.0.4.jar"
      "junixsocket-mysql-2.0.4.jar"
      "junixsocket-rmi-2.0.4.jar"
      "jython-standalone-2.5.2.jar"
      "jzlib-1.0.7.jar"
      "libidn-1.24.jar"
      "log4j-1.2.16.jar"
      "lucene-analyzers-3.5.0.jar"
      "lucene-core-3.5.0.jar"
      "lucene-smartcn-3.5.0.jar"
      "mail-1.4.5.jar"
      "mariadb-java-client-1.1.8.jar"
      "mina-core-2.0.4.jar"
      "neethi-3.0.2.jar"
      "nekohtml-1.9.13.1z.jar"
      "oauth-20100527.jar"
      "owasp-java-html-sanitizer-r239.jar"
      "policy-2.3.jar"
      "slf4j-api-1.6.4.jar"
      "slf4j-log4j12-1.6.4.jar"
      "smack-3.1.0.jar"
      "smackx-3.1.0.jar"
      "smackx-debug-3.2.1.jar"
      "smackx-jingle-3.2.1.jar"
      "spring-aop-3.0.7.RELEASE.jar"
      "spring-asm-3.0.7.RELEASE.jar"
      "spring-beans-3.0.7.RELEASE.jar"
      "spring-context-3.0.7.RELEASE.jar"
      "spring-core-3.0.7.RELEASE.jar"
      "spring-expression-3.0.7.RELEASE.jar"
      "spymemcached-2.12.1.jar"
      "jedis-2.9.0.jar"
      "commons-pool2-2.4.2.jar"
      "sqlite-jdbc-3.7.15-M1.jar"
      "stax-ex-1.7.7.jar"
      "stax2-api-3.1.1.jar"
      "streambuffer-2.2.6.jar"
      "syslog4j-0.9.46.jar"
      "unboundid-ldapsdk-2.3.5.jar"
      "woodstox-core-asl-4.2.0.jar"
      "wsdl4j-1.6.3.jar"
      "xercesImpl-2.9.1-patch-01.jar"
      "xmlschema-core-2.0.3.jar"
      "yuicompressor-2.4.2-zimbra.jar"
      "zkclient-0.1.0.jar"
      "zookeeper-3.4.5.jar"
      "zm-ews-stub-1.0.jar"
      "ehcache-3.1.2.jar"
   )

   for i in "${zimbrathirdpartyjars[@]}"
   do
      Cpy2 ${repoDir}/zm-zcs-lib/build/dist/${i}                                                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/jars
   done

   Copy ${repoDir}/zm-zcs-lib/build/dist/zm-charset-*.jar                                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/jars/zimbra-charset.jar
   Copy ${repoDir}/zm-zcs-lib/build/dist/zm-native-*.jar                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/jars/zimbra-native.jar
   Copy ${repoDir}/zm-zcs-lib/build/dist/zm-common-*.jar                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/jars/zimbracommon.jar
   Copy ${repoDir}/zm-zcs-lib/build/dist/zm-soap-*.jar                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/jars/zimbrasoap.jar
   Copy ${repoDir}/zm-zcs-lib/build/dist/zm-client-*.jar                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/jars/zimbraclient.jar
   Copy ${repoDir}/zm-zcs-lib/build/dist/zm-store-*.jar                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/jars/zimbrastore.jar
   Copy ${repoDir}/zm-zcs-lib/build/dist/ant-1.6.5.jar                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/jars-ant/ant-1.6.5.jar
   Copy ${repoDir}/zm-zcs-lib/build/dist/json-20090211.jar                                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/jars/json.jar
   Copy ${repoDir}/zm-zcs-lib/build/dist/commons-logging-1.1.1.jar                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/jars/commons-logging.jar

   Copy ${repoDir}/zm-bulkprovision-store/build/dist/commons-csv-1.2.jar                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/ext/com_zimbra_bulkprovision/commons-csv-1.2.jar
   Copy ${repoDir}/zm-bulkprovision-store/build/dist/zm-bulkprovision-store*.jar                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/ext/com_zimbra_bulkprovision/com_zimbra_bulkprovision.jar

   Copy ${repoDir}/zm-certificate-manager-store/build/zm-certificate-manager-store*.jar             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/ext/com_zimbra_cert_manager/com_zimbra_cert_manager.jar 

   Copy ${repoDir}/zm-clientuploader-store/build/zm-clientuploader-store*.jar                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/ext/com_zimbra_clientuploader/com_zimbra_clientuploader.jar

   # Copy SSDB Ephemeral storage extension + dependencies
   Cpy2 ${repoDir}/zm-ssdb-ephemeral-store/build/dist/zm-ssdb-ephemeral-store*.jar                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/ext/com_zimbra_ssdb_ephemeral_store/
   Cpy2 ${repoDir}/zm-zcs-lib/build/dist/jedis-2.9.0.jar                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/ext/com_zimbra_ssdb_ephemeral_store/
   Cpy2 ${repoDir}/zm-zcs-lib/build/dist/commons-pool2-2.4.2.jar                                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/ext/com_zimbra_ssdb_ephemeral_store/

   if [ "${buildType}" == "NETWORK" ]
   then
      Copy ${repoDir}/zm-backup-store/docs/backup.txt                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/backup.txt
      Copy ${repoDir}/zm-backup-store/docs/mailboxMove.txt                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/mailboxMove.txt
      Copy ${repoDir}/zm-backup-store/docs/soapbackup.txt                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/soapbackup.txt
      Copy ${repoDir}/zm-backup-store/docs/xml-meta.txt                                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/xml-meta.txt
      Copy ${repoDir}/zm-backup-store/build/dist/backup-version-init.sql                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/db/backup-version-init.sql

      Copy ${repoDir}/zm-backup-utilities/src/bin/zmbackup                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmbackup
      Copy ${repoDir}/zm-backup-utilities/src/bin/zmbackupabort                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmbackupabort
      Copy ${repoDir}/zm-backup-utilities/src/bin/zmbackupquery                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmbackupquery
      Copy ${repoDir}/zm-backup-utilities/src/bin/zmmboxmove                                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmmboxmove
      Copy ${repoDir}/zm-backup-utilities/src/bin/zmmboxmovequery                                      ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmmboxmovequery
      Copy ${repoDir}/zm-backup-utilities/src/bin/zmpurgeoldmbox                                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmpurgeoldmbox
      Copy ${repoDir}/zm-backup-utilities/src/bin/zmrestore                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmrestore
      Copy ${repoDir}/zm-backup-utilities/src/bin/zmrestoreldap                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmrestoreldap
      Copy ${repoDir}/zm-backup-utilities/src/bin/zmrestoreoffline                                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmrestoreoffline
      Copy ${repoDir}/zm-backup-utilities/src/bin/zmschedulebackup                                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmschedulebackup
      Copy ${repoDir}/zm-backup-utilities/src/db/backup_schema.sql                                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/db/backup_schema.sql
      Copy ${repoDir}/zm-backup-utilities/src/libexec/zmbackupldap                                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmbackupldap
      Copy ${repoDir}/zm-backup-utilities/src/libexec/zmbackupqueryldap                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmbackupqueryldap

      Copy ${repoDir}/zm-convertd-native/conf/convertd.log4j.properties                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/conf/convertd.log4j.properties
      Copy ${repoDir}/zm-convertd-native/src/bin/zmconvertctl                                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmconvertctl
      Copy ${repoDir}/zm-convertd-native/src/libexec/zmconvertdmod                                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/zmconvertdmod

      Copy ${repoDir}/zm-hsm/docs/soap-admin.txt                                                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/hsm-soap-admin.txt

      Copy ${repoDir}/zm-license-tools/build/zm-license-tools*.jar                                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/ext-common/zimbra-license-tools.jar
      Copy ${repoDir}/zm-license-tools/src/bin/zmlicense                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmlicense

      Copy ${repoDir}/zm-network-build/rpmconf/Install/Util/modules/postinstall.sh                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/installer/util/modules/postinstall.sh
      Copy ${repoDir}/zm-network-build/rpmconf/Install/postinstall.pm                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/postinstall.pm
      Copy ${repoDir}/zm-network-build/rpmconf/Install/preinstall.pm                                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/preinstall.pm

      Copy ${repoDir}/zm-network-licenses/thirdparty/keyview_eula.txt                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/keyview_eula.txt
      Copy ${repoDir}/zm-network-licenses/thirdparty/oracle_jdk_eula.txt                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/oracle_jdk_eula.txt

      Copy ${repoDir}/zm-network-store/src/bin/zmhactl                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmhactl
      Copy ${repoDir}/zm-network-store/src/bin/zmmboxsearch                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmmboxsearch
      Copy ${repoDir}/zm-network-store/src/libexec/vmware-heartbeat                                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/vmware-heartbeat

      Copy ${repoDir}/zm-postfixjournal/build/dist/postjournal                                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/postjournal

      Copy ${repoDir}/zm-rebranding-docs/docs/rebranding/DE_Rebranding_directions.txt                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/rebranding/DE_Rebranding_directions.txt
      Copy ${repoDir}/zm-rebranding-docs/docs/rebranding/ES_Rebranding_directions.txt                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/rebranding/ES_Rebranding_directions.txt
      Copy ${repoDir}/zm-rebranding-docs/docs/rebranding/FR_Rebranding_directions.txt                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/rebranding/FR_Rebranding_directions.txt
      Copy ${repoDir}/zm-rebranding-docs/docs/rebranding/IT_Rebranding_directions.txt                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/rebranding/IT_Rebranding_directions.txt
      Copy ${repoDir}/zm-rebranding-docs/docs/rebranding/JA_Rebranding_directions.txt                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/rebranding/JA_Rebranding_directions.txt
      Copy ${repoDir}/zm-rebranding-docs/docs/rebranding/NL_Rebranding_directions.txt                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/rebranding/NL_Rebranding_directions.txt
      Copy ${repoDir}/zm-rebranding-docs/docs/rebranding/RU_Rebranding_directions.txt                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/rebranding/RU_Rebranding_directions.txt
      Copy ${repoDir}/zm-rebranding-docs/docs/rebranding/en_US_Rebranding_directions.txt               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/rebranding/en_US_Rebranding_directions.txt
      Copy ${repoDir}/zm-rebranding-docs/docs/rebranding/pt_BR_Rebranding_directions.txt               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/rebranding/pt_BR_Rebranding_directions.txt
      Copy ${repoDir}/zm-rebranding-docs/docs/rebranding/zh_CN_Rebranding_directions.txt               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/rebranding/zh_CN_Rebranding_directions.txt
      Copy ${repoDir}/zm-rebranding-docs/docs/rebranding/zh_HK_Rebranding_directions.txt               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/rebranding/zh_HK_Rebranding_directions.txt

      Copy ${repoDir}/zm-twofactorauth-store/docs/twofactorauth.md                                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/twofactorauth.md

      Copy ${repoDir}/zm-vmware-appmonitor/build/dist/libexec/vmware-appmonitor                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/vmware-appmonitor
      Copy ${repoDir}/zm-vmware-appmonitor/build/dist/lib/libappmonitorlib.so                          ${repoDir}/zm-build/${currentPackage}/opt/zimbra/lib/libappmonitorlib.so

      Copy ${repoDir}/zm-voice-store/docs/ZimbraVoice-Extension.txt                                    ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/ZimbraVoice-Extension.txt
      Copy ${repoDir}/zm-voice-store/docs/soap-voice-admin.txt                                         ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/soap-voice-admin.txt
      Copy ${repoDir}/zm-voice-store/docs/soap-voice.txt                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/docs/soap-voice.txt
   fi

   CreatePackage "${os}"
}

############################################################################
main "$@"
