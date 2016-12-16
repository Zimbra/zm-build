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

PrepareEtcDir()
{
   local dirset=$1; shift;

   echo -e "\tCopy etc/$dirset files" >> ${buildLogFile}

   mkdir -p "${repoDir}/zm-build/${currentPackage}/etc/$dirset"
}

PrepareDeployDir()
{
   local dirset=$1; shift;

   echo -e "\tCopy opt/zimbra/$dirset files" >> ${buildLogFile}

   mkdir -p "${repoDir}/zm-build/${currentPackage}/opt/zimbra/$dirset"
}

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
      cat ${repoDir}/zm-build/rpmconf/Spec/${currentScript}.deb \
         | sed -e "s/@@VERSION@@/${release}.${buildNo}.${os/_/.}/" \
               -e "s/@@branch@@/${buildTimeStamp}/" \
               -e "s/@@ARCH@@/${arch}/" \
               -e "s/@@ARCH@@/amd64/" \
               -e "s/^Copyright:/Copyright:/" \
               -e "/^%post$/ r ${currentScript}.post"
   ) > ${repoDir}/zm-build/${currentPackage}/DEBIAN/control

   (
      set -e;
      cd ${repoDir}/zm-build/${currentPackage}
      dpkg -b ${repoDir}/zm-build/${currentPackage} ${repoDir}/zm-build/${arch}
   )

   if [ $? -ne 0 ]; then
       echo -e "\t### ${currentPackage} package building failed ###" >> ${buildLogFile}
   else
       echo -e "\t*** ${currentPackage} package successfully created ***" >> ${buildLogFile}
   fi
}

Copy()
{
   local src="$1"; shift;
   local dest="$1"; shift;

   cp -f "$src" "$dest"
}

#-------------------- main packaging ---------------------------

main()
{
   set -e

   PrepareEtcDir "sudoers.d"
# etc/sudoers.d/01_zimbra
# etc/sudoers.d/02_zimbra-core

   PrepareDeployDir ""
# opt/zimbra/.bash_profile
# opt/zimbra/.bashrc
# opt/zimbra/.exrc
# opt/zimbra/.ldaprc
# opt/zimbra/.platform
# opt/zimbra/.viminfo

   PrepareDeployDir "common/lib/jylibs"
# opt/zimbra/common/lib/jylibs/commands.py
# opt/zimbra/common/lib/jylibs/conf.py
# opt/zimbra/common/lib/jylibs/config.py
# opt/zimbra/common/lib/jylibs/globalconfig.py
# opt/zimbra/common/lib/jylibs/ldap.py
# opt/zimbra/common/lib/jylibs/listener.py
# opt/zimbra/common/lib/jylibs/localconfig.py
# opt/zimbra/common/lib/jylibs/logmsg.py
# opt/zimbra/common/lib/jylibs/miscconfig.py
# opt/zimbra/common/lib/jylibs/mtaconfig.py
# opt/zimbra/common/lib/jylibs/serverconfig.py
# opt/zimbra/common/lib/jylibs/state.py

   PrepareDeployDir "common/lib/perl5/Zimbra"
# opt/zimbra/common/lib/perl5/Zimbra/DB/DB.pm
# opt/zimbra/common/lib/perl5/Zimbra/Mon/Logger.pm
# opt/zimbra/common/lib/perl5/Zimbra/Mon/LoggerSchema.pm
# opt/zimbra/common/lib/perl5/Zimbra/Mon/Zmstat.pm
# opt/zimbra/common/lib/perl5/Zimbra/SOAP/Soap.pm
# opt/zimbra/common/lib/perl5/Zimbra/SOAP/Soap11.pm
# opt/zimbra/common/lib/perl5/Zimbra/SOAP/Soap12.pm
# opt/zimbra/common/lib/perl5/Zimbra/SOAP/XmlDoc.pm
# opt/zimbra/common/lib/perl5/Zimbra/SOAP/XmlElement.pm
# opt/zimbra/common/lib/perl5/Zimbra/Util/Common.pm
# opt/zimbra/common/lib/perl5/Zimbra/Util/LDAP.pm
# opt/zimbra/common/lib/perl5/Zimbra/Util/Timezone.pm
# opt/zimbra/common/lib/perl5/Zimbra/ZmClient.pm

   PrepareDeployDir "conf"
   PrepareDeployDir "conf/crontabs"
   PrepareDeployDir "conf/attrs"
   PrepareDeployDir "conf/msgs"
   PrepareDeployDir "conf/zmconfigd"
   PrepareDeployDir "conf/rights"
   PrepareDeployDir "conf/externaldirsync"
   PrepareDeployDir "conf/sasl2"

# opt/zimbra/conf/amavisd-custom.conf
# opt/zimbra/conf/amavisd.conf.in
# opt/zimbra/conf/auditswatchrc.in
# opt/zimbra/conf/cbpolicyd.conf.in
# opt/zimbra/conf/clamd.conf.in
# opt/zimbra/conf/convertd.log4j.properties
# opt/zimbra/conf/datasource.xml
# opt/zimbra/conf/dhparam.pem.zcs
# opt/zimbra/conf/dspam.conf.in
# opt/zimbra/conf/freshclam.conf.in
# opt/zimbra/conf/localconfig.xml
# opt/zimbra/conf/log4j.properties.in
# opt/zimbra/conf/logswatchrc
# opt/zimbra/conf/milter.log4j.properties
# opt/zimbra/conf/mta_milter_options.in
# opt/zimbra/conf/opendkim-localnets.conf.in
# opt/zimbra/conf/opendkim.conf.in
# opt/zimbra/conf/postfix_header_checks.in
# opt/zimbra/conf/salocal.cf.in
# opt/zimbra/conf/saslauthd.conf.in
# opt/zimbra/conf/stats.conf.in
# opt/zimbra/conf/swatchrc.in
# opt/zimbra/conf/timezones.ics
# opt/zimbra/conf/unbound.conf.in
# opt/zimbra/conf/zmconfigd.cf
# opt/zimbra/conf/zmconfigd.log4j.properties
# opt/zimbra/conf/zmlogrotate
# opt/zimbra/conf/zmssl.cnf.in

# opt/zimbra/conf/crontabs/crontab
# opt/zimbra/conf/crontabs/crontab.ldap
# opt/zimbra/conf/crontabs/crontab.logger
# opt/zimbra/conf/crontabs/crontab.mta
# opt/zimbra/conf/crontabs/crontab.store

# opt/zimbra/conf/attrs/amavisd-new-attrs.xml
# opt/zimbra/conf/attrs/zimbra-attrs.xml
# opt/zimbra/conf/attrs/zimbra-ocs.xml

# opt/zimbra/conf/msgs/L10nMsg.properties
# opt/zimbra/conf/msgs/ZsMsg.properties
# opt/zimbra/conf/msgs/ZsMsgRights.properties
# opt/zimbra/conf/msgs/ZsMsgRights_ar.properties
# opt/zimbra/conf/msgs/ZsMsgRights_da.properties
# opt/zimbra/conf/msgs/ZsMsgRights_de.properties
# opt/zimbra/conf/msgs/ZsMsgRights_en_AU.properties
# opt/zimbra/conf/msgs/ZsMsgRights_en_GB.properties
# opt/zimbra/conf/msgs/ZsMsgRights_es.properties
# opt/zimbra/conf/msgs/ZsMsgRights_eu.properties
# opt/zimbra/conf/msgs/ZsMsgRights_fr.properties
# opt/zimbra/conf/msgs/ZsMsgRights_fr_CA.properties
# opt/zimbra/conf/msgs/ZsMsgRights_hi.properties
# opt/zimbra/conf/msgs/ZsMsgRights_hu.properties
# opt/zimbra/conf/msgs/ZsMsgRights_in.properties
# opt/zimbra/conf/msgs/ZsMsgRights_it.properties
# opt/zimbra/conf/msgs/ZsMsgRights_iw.properties
# opt/zimbra/conf/msgs/ZsMsgRights_ja.properties
# opt/zimbra/conf/msgs/ZsMsgRights_ko.properties
# opt/zimbra/conf/msgs/ZsMsgRights_lo.properties
# opt/zimbra/conf/msgs/ZsMsgRights_ms.properties
# opt/zimbra/conf/msgs/ZsMsgRights_nl.properties
# opt/zimbra/conf/msgs/ZsMsgRights_pl.properties
# opt/zimbra/conf/msgs/ZsMsgRights_pt.properties
# opt/zimbra/conf/msgs/ZsMsgRights_pt_BR.properties
# opt/zimbra/conf/msgs/ZsMsgRights_ro.properties
# opt/zimbra/conf/msgs/ZsMsgRights_ru.properties
# opt/zimbra/conf/msgs/ZsMsgRights_sl.properties
# opt/zimbra/conf/msgs/ZsMsgRights_sv.properties
# opt/zimbra/conf/msgs/ZsMsgRights_th.properties
# opt/zimbra/conf/msgs/ZsMsgRights_tr.properties
# opt/zimbra/conf/msgs/ZsMsgRights_uk.properties
# opt/zimbra/conf/msgs/ZsMsgRights_zh_CN.properties
# opt/zimbra/conf/msgs/ZsMsgRights_zh_HK.properties
# opt/zimbra/conf/msgs/ZsMsgRights_zh_TW.properties
# opt/zimbra/conf/msgs/ZsMsg_ar.properties
# opt/zimbra/conf/msgs/ZsMsg_da.properties
# opt/zimbra/conf/msgs/ZsMsg_de.properties
# opt/zimbra/conf/msgs/ZsMsg_en.properties
# opt/zimbra/conf/msgs/ZsMsg_en_AU.properties
# opt/zimbra/conf/msgs/ZsMsg_en_GB.properties
# opt/zimbra/conf/msgs/ZsMsg_es.properties
# opt/zimbra/conf/msgs/ZsMsg_eu.properties
# opt/zimbra/conf/msgs/ZsMsg_fr.properties
# opt/zimbra/conf/msgs/ZsMsg_fr_CA.properties
# opt/zimbra/conf/msgs/ZsMsg_fr_FR.properties
# opt/zimbra/conf/msgs/ZsMsg_hi.properties
# opt/zimbra/conf/msgs/ZsMsg_hu.properties
# opt/zimbra/conf/msgs/ZsMsg_in.properties
# opt/zimbra/conf/msgs/ZsMsg_it.properties
# opt/zimbra/conf/msgs/ZsMsg_iw.properties
# opt/zimbra/conf/msgs/ZsMsg_ja.properties
# opt/zimbra/conf/msgs/ZsMsg_ko.properties
# opt/zimbra/conf/msgs/ZsMsg_lo.properties
# opt/zimbra/conf/msgs/ZsMsg_ms.properties
# opt/zimbra/conf/msgs/ZsMsg_nl.properties
# opt/zimbra/conf/msgs/ZsMsg_pl.properties
# opt/zimbra/conf/msgs/ZsMsg_pt.properties
# opt/zimbra/conf/msgs/ZsMsg_pt_BR.properties
# opt/zimbra/conf/msgs/ZsMsg_ro.properties
# opt/zimbra/conf/msgs/ZsMsg_ru.properties
# opt/zimbra/conf/msgs/ZsMsg_sl.properties
# opt/zimbra/conf/msgs/ZsMsg_sv.properties
# opt/zimbra/conf/msgs/ZsMsg_th.properties
# opt/zimbra/conf/msgs/ZsMsg_tr.properties
# opt/zimbra/conf/msgs/ZsMsg_uk.properties
# opt/zimbra/conf/msgs/ZsMsg_zh_CN.properties
# opt/zimbra/conf/msgs/ZsMsg_zh_HK.properties
# opt/zimbra/conf/msgs/ZsMsg_zh_TW.properties

# opt/zimbra/conf/zmconfigd/postfix_content_filter.cf
# opt/zimbra/conf/zmconfigd/smtpd_end_of_data_restrictions.cf
# opt/zimbra/conf/zmconfigd/smtpd_recipient_restrictions.cf
# opt/zimbra/conf/zmconfigd/smtpd_relay_restrictions.cf
# opt/zimbra/conf/zmconfigd/smtpd_sender_login_maps.cf
# opt/zimbra/conf/zmconfigd/smtpd_sender_restrictions.cf

# opt/zimbra/conf/rights/adminconsole-ui.xml
# opt/zimbra/conf/rights/zimbra-rights-adminconsole-domainadmin.xml
# opt/zimbra/conf/rights/zimbra-rights-adminconsole.xml
# opt/zimbra/conf/rights/zimbra-rights-domainadmin.xml
# opt/zimbra/conf/rights/zimbra-rights-roles.xml
# opt/zimbra/conf/rights/zimbra-rights.xml
# opt/zimbra/conf/rights/zimbra-user-rights.xml

# opt/zimbra/conf/sasl2/smtpd.conf.in

# opt/zimbra/conf/externaldirsync/Exchange2000.xml
# opt/zimbra/conf/externaldirsync/Exchange2003.xml
# opt/zimbra/conf/externaldirsync/Exchange5.5.xml
# opt/zimbra/conf/externaldirsync/domino.xml
# opt/zimbra/conf/externaldirsync/novellGroupWise.xml
# opt/zimbra/conf/externaldirsync/openldap.xml


   PrepareDeployDir "contrib"
# opt/zimbra/contrib/zmfetchercfg


   PrepareDeployDir "libexec"
# opt/zimbra/libexec/600.zimbra
# opt/zimbra/libexec/addUser.sh
# opt/zimbra/libexec/client_usage_report.py
# opt/zimbra/libexec/configrewrite
# opt/zimbra/libexec/get_plat_tag.sh
# opt/zimbra/libexec/icalmig
# opt/zimbra/libexec/libreoffice-installer.sh
# opt/zimbra/libexec/postinstall.pm
# opt/zimbra/libexec/postjournal
# opt/zimbra/libexec/preinstall.pm
# opt/zimbra/libexec/vmware-appmonitor
# opt/zimbra/libexec/vmware-heartbeat
# opt/zimbra/libexec/zcs
# opt/zimbra/libexec/zimbra
# opt/zimbra/libexec/zmaltermimeconfig
# opt/zimbra/libexec/zmantispamdbinit
# opt/zimbra/libexec/zmantispammycnf
# opt/zimbra/libexec/zmbackupldap
# opt/zimbra/libexec/zmbackupqueryldap
# opt/zimbra/libexec/zmcbpolicydinit
# opt/zimbra/libexec/zmcheckduplicatemysqld
# opt/zimbra/libexec/zmcheckexpiredcerts
# opt/zimbra/libexec/zmcleantmp
# opt/zimbra/libexec/zmclientcertmgr
# opt/zimbra/libexec/zmcompresslogs
# opt/zimbra/libexec/zmcomputequotausage
# opt/zimbra/libexec/zmconfigd
# opt/zimbra/libexec/zmconvertdmod
# opt/zimbra/libexec/zmcpustat
# opt/zimbra/libexec/zmdailyreport
# opt/zimbra/libexec/zmdbintegrityreport
# opt/zimbra/libexec/zmdiaglog
# opt/zimbra/libexec/zmdkimkeyutil
# opt/zimbra/libexec/zmdnscachealign
# opt/zimbra/libexec/zmdomaincertmgr
# opt/zimbra/libexec/zmexplainslow
# opt/zimbra/libexec/zmexplainsql
# opt/zimbra/libexec/zmextractsql
# opt/zimbra/libexec/zmfixperms
# opt/zimbra/libexec/zmfixreminder
# opt/zimbra/libexec/zmgenentitlement
# opt/zimbra/libexec/zmgsaupdate
# opt/zimbra/libexec/zmhspreport
# opt/zimbra/libexec/zminiutil
# opt/zimbra/libexec/zmiostat
# opt/zimbra/libexec/zmiptool
# opt/zimbra/libexec/zmjavawatch
# opt/zimbra/libexec/zmjsprecompile
# opt/zimbra/libexec/zmldapanon
# opt/zimbra/libexec/zmldapapplyldif
# opt/zimbra/libexec/zmldapenable-mmr
# opt/zimbra/libexec/zmldapenablereplica
# opt/zimbra/libexec/zmldapinit
# opt/zimbra/libexec/zmldapmmrtool
# opt/zimbra/libexec/zmldapmonitordb
# opt/zimbra/libexec/zmldappromote-replica-mmr
# opt/zimbra/libexec/zmldapreplicatool
# opt/zimbra/libexec/zmldapschema
# opt/zimbra/libexec/zmldapupdateldif
# opt/zimbra/libexec/zmlogger
# opt/zimbra/libexec/zmloggerinit
# opt/zimbra/libexec/zmlogprocess
# opt/zimbra/libexec/zmmailboxdmgr
# opt/zimbra/libexec/zmmailboxdmgr.unrestricted
# opt/zimbra/libexec/zmmsgtrace
# opt/zimbra/libexec/zmmtainit
# opt/zimbra/libexec/zmmtastatus
# opt/zimbra/libexec/zmmycnf
# opt/zimbra/libexec/zmmyinit
# opt/zimbra/libexec/zmnotifyinstall
# opt/zimbra/libexec/zmpostfixpolicyd
# opt/zimbra/libexec/zmproxyconfgen
# opt/zimbra/libexec/zmproxyconfig
# opt/zimbra/libexec/zmproxypurge
# opt/zimbra/libexec/zmqaction
# opt/zimbra/libexec/zmqstat
# opt/zimbra/libexec/zmqueuelog
# opt/zimbra/libexec/zmrc
# opt/zimbra/libexec/zmrcd
# opt/zimbra/libexec/zmreplchk
# opt/zimbra/libexec/zmresetmysqlpassword
# opt/zimbra/libexec/zmrrdfetch
# opt/zimbra/libexec/zmsacompile
# opt/zimbra/libexec/zmsaupdate
# opt/zimbra/libexec/zmserverips
# opt/zimbra/libexec/zmsetservername
# opt/zimbra/libexec/zmsetup.pl
# opt/zimbra/libexec/zmslapadd
# opt/zimbra/libexec/zmslapcat
# opt/zimbra/libexec/zmslapd
# opt/zimbra/libexec/zmslapindex
# opt/zimbra/libexec/zmsnmpinit
# opt/zimbra/libexec/zmspamextract
# opt/zimbra/libexec/zmstat-allprocs
# opt/zimbra/libexec/zmstat-cleanup
# opt/zimbra/libexec/zmstat-convertd
# opt/zimbra/libexec/zmstat-cpu
# opt/zimbra/libexec/zmstat-df
# opt/zimbra/libexec/zmstat-fd
# opt/zimbra/libexec/zmstat-io
# opt/zimbra/libexec/zmstat-ldap
# opt/zimbra/libexec/zmstat-mtaqueue
# opt/zimbra/libexec/zmstat-mysql
# opt/zimbra/libexec/zmstat-nginx
# opt/zimbra/libexec/zmstat-proc
# opt/zimbra/libexec/zmstat-vm
# opt/zimbra/libexec/zmstatuslog
# opt/zimbra/libexec/zmsyslogsetup
# opt/zimbra/libexec/zmthreadcpu
# opt/zimbra/libexec/zmunbound
# opt/zimbra/libexec/zmupdatedownload
# opt/zimbra/libexec/zmupdatezco
# opt/zimbra/libexec/zmupgrade.pm

   PrepareDeployDir "libexec/scripts"
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
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20140319-MailItemPrevFolders.pl               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20140319-MailItemPrevFolders.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20140328-EnforceTableCharset.pl               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20140328-EnforceTableCharset.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20140624-DropMysqlIndexes.pl                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20140624-DropMysqlIndexes.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20150401-ZmgDevices.pl                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20150401-ZmgDevices.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20150515-DataSourcePurgeTables.pl             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20150515-DataSourcePurgeTables.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20150623-ZmgDevices.pl                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20150623-ZmgDevices.pl
   Copy ${repoDir}/zm-db-conf/src/db/migration/migrate20150702-ZmgDevices.pl                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20150702-ZmgDevices.pl
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

   Copy ${repoDir}/zm-ldap-utilities/src/ldap/migration/migrate20110615-AddDynlist.pl               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20110615-AddDynlist.pl
   Copy ${repoDir}/zm-ldap-utilities/src/ldap/migration/migrate20110721-AddUnique.pl                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20110721-AddUnique.pl
   Copy ${repoDir}/zm-ldap-utilities/src/ldap/migration/migrate20111019-UniqueZimbraId.pl           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20111019-UniqueZimbraId.pl
   Copy ${repoDir}/zm-ldap-utilities/src/ldap/migration/migrate20120210-AddSearchNoOp.pl            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20120210-AddSearchNoOp.pl
   Copy ${repoDir}/zm-ldap-utilities/src/ldap/migration/migrate20120507-UniqueDKIMSelector.pl       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20120507-UniqueDKIMSelector.pl
   Copy ${repoDir}/zm-ldap-utilities/src/ldap/migration/migrate20140728-AddSSHA512.pl               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20140728-AddSSHA512.pl
   Copy ${repoDir}/zm-ldap-utilities/src/ldap/migration/migrate20141022-AddTLSBits.pl               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20141022-AddTLSBits.pl
   Copy ${repoDir}/zm-ldap-utilities/src/ldap/migration/migrate20150930-AddSyncpovSessionlog.pl     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/libexec/scripts/migrate20150930-AddSyncpovSessionlog.pl

# opt/zimbra/libexec/scripts/migrate20130227-UpgradeCBPolicyDSchema.sql       :: NOT_IN_REPO :: [FOUND_HERE] /home/shriram/Stash/zcs-full/ZimbraServer/src/cbpolicyd/migration/migrate20130227-UpgradeCBPolicyDSchema.sql
# opt/zimbra/libexec/scripts/migrate20130606-UpdateCBPolicydSchema.sql        :: NOT_IN_REPO :: [FOUND_HERE] /home/shriram/Stash/zcs-full/ZimbraServer/src/cbpolicyd/migration/migrate20130606-UpdateCBPolicydSchema.sql
# opt/zimbra/libexec/scripts/migrate20130819-UpgradeQuotasTable.sql           :: NOT_IN_REPO :: [FOUND_HERE] /home/shriram/Stash/zcs-full/ZimbraServer/src/cbpolicyd/migration/migrate20130819-UpgradeQuotasTable.sql
# opt/zimbra/libexec/scripts/migrate20131014-removezca.pl                     :: NOT_IN_REPO :: [FOUND_HERE] /home/shriram/Stash/zcs-full/ZimbraServer/src/zca/migration/migrate20131014-removezca.pl


   PrepareDeployDir "libexec/installer"
   PrepareDeployDir "libexec/installer/bin"
   PrepareDeployDir "libexec/installer/util"

# opt/zimbra/libexec/installer/bin/get_plat_tag.sh
# opt/zimbra/libexec/installer/install.sh
# opt/zimbra/libexec/installer/util/addUser.sh
# opt/zimbra/libexec/installer/util/globals.sh
# opt/zimbra/libexec/installer/util/modules/getconfig.sh
# opt/zimbra/libexec/installer/util/modules/packages.sh
# opt/zimbra/libexec/installer/util/modules/postinstall.sh
# opt/zimbra/libexec/installer/util/utilfunc.sh

   PrepareDeployDir "db"
# opt/zimbra/db/backup-version-init.sql
# opt/zimbra/db/backup_schema.sql
# opt/zimbra/db/create_database.sql
# opt/zimbra/db/db.sql
# opt/zimbra/db/versions-init.sql

   PrepareDeployDir "logger/db/work"
# opt/zimbra/logger/db/work/connection_failed.gif
# opt/zimbra/logger/db/work/data_not_available.gif

   PrepareDeployDir "bin"
   Copy ${repoDir}/zm-core-utils/src/bin/antispam-mysql                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/antispam-mysql
   Copy ${repoDir}/zm-core-utils/src/bin/antispam-mysql.server                                      ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/antispam-mysql.server
   Copy ${repoDir}/zm-core-utils/src/bin/antispam-mysqladmin                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/antispam-mysqladmin
# opt/zimbra/bin/ldap                                                         :: IN_REPO :: [FOUND_HERE][DIFF] /home/shriram/Stash/zm-core-utils/src/bin/ldap
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
   Copy ${repoDir}/zm-backup-utilities/src/bin/zmbackup                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmbackup
   Copy ${repoDir}/zm-backup-utilities/src/bin/zmbackupabort                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmbackupabort
   Copy ${repoDir}/zm-backup-utilities/src/bin/zmbackupquery                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmbackupquery
   Copy ${repoDir}/zm-core-utils/src/bin/zmblobchk                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmblobchk
   Copy ${repoDir}/zm-core-utils/src/bin/zmcaldebug                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmcaldebug
   Copy ${repoDir}/zm-core-utils/src/bin/zmcbpadmin                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmcbpadmin
   Copy ${repoDir}/zm-core-utils/src/bin/zmcbpolicydctl                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmcbpolicydctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmcertmgr                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmcertmgr
   Copy ${repoDir}/zm-core-utils/src/bin/zmclamdctl                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmclamdctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmconfigdctl                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmconfigdctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmcontrol                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmcontrol
# opt/zimbra/bin/zmconvertctl                                                 :: IN_REPO :: [FOUND_HERE][DIFF] /home/shriram/Stash/zm-convertd-native/src/bin/zmconvertctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmdedupe                                                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmdedupe
   Copy ${repoDir}/zm-core-utils/src/bin/zmdhparam                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmdhparam
   Copy ${repoDir}/zm-core-utils/src/bin/zmdnscachectl                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmdnscachectl
   Copy ${repoDir}/zm-core-utils/src/bin/zmdumpenv                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmdumpenv
   Copy ${repoDir}/zm-core-utils/src/bin/zmfixcalendtime                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmfixcalendtime
   Copy ${repoDir}/zm-core-utils/src/bin/zmfixcalprio                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmfixcalprio
   Copy ${repoDir}/zm-core-utils/src/bin/zmfreshclamctl                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmfreshclamctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmgsautil                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmgsautil
   Copy ${repoDir}/zm-network-store/src/bin/zmhactl                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmhactl
   Copy ${repoDir}/zm-core-utils/src/bin/zmhostname                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmhostname
   Copy ${repoDir}/zm-core-utils/src/bin/zminnotop                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zminnotop
   Copy ${repoDir}/zm-core-utils/src/bin/zmitemdatafile                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmitemdatafile
   Copy ${repoDir}/zm-core-utils/src/bin/zmjava                                                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmjava
   Copy ${repoDir}/zm-core-utils/src/bin/zmjavaext                                                  ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmjavaext
   Copy ${repoDir}/zm-core-utils/src/bin/zmldappasswd                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmldappasswd
   Copy ${repoDir}/zm-core-utils/src/bin/zmldapupgrade                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmldapupgrade
# opt/zimbra/bin/zmlicense                                                    :: NOT_IN_REPO :: [FOUND_HERE] /home/shriram/Stash/zcs-full/ZimbraLicenseTools/src/bin/zmlicense
   Copy ${repoDir}/zm-core-utils/src/bin/zmlmtpinject                                               ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmlmtpinject
   Copy ${repoDir}/zm-core-utils/src/bin/zmlocalconfig                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmlocalconfig
   Copy ${repoDir}/zm-core-utils/src/bin/zmloggerctl                                                ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmloggerctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmloggerhostmap                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmloggerhostmap
   Copy ${repoDir}/zm-core-utils/src/bin/zmlogswatchctl                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmlogswatchctl
# opt/zimbra/bin/zmmailbox                                                    :: IN_REPO :: [FOUND_HERE][DIFF] /home/shriram/Stash/zm-core-utils/src/bin/zmmailbox
   Copy ${repoDir}/zm-core-utils/src/bin/zmmailboxdctl                                              ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmmailboxdctl
   Copy ${repoDir}/zm-backup-utilities/src/bin/zmmboxmove                                           ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmmboxmove
   Copy ${repoDir}/zm-backup-utilities/src/bin/zmmboxmovequery                                      ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmmboxmovequery
   Copy ${repoDir}/zm-network-store/src/bin/zmmboxsearch                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmmboxsearch
   Copy ${repoDir}/zm-core-utils/src/bin/zmmemcachedctl                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmmemcachedctl
   Copy ${repoDir}/zm-core-utils/src/bin/zmmetadump                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmmetadump
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
   Copy ${repoDir}/zm-backup-utilities/src/bin/zmpurgeoldmbox                                       ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmpurgeoldmbox
   Copy ${repoDir}/zm-core-utils/src/bin/zmpython                                                   ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmpython
   Copy ${repoDir}/zm-core-utils/src/bin/zmredodump                                                 ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmredodump
# opt/zimbra/bin/zmresolverctl                                                :: IN_REPO :: [FOUND_HERE][DIFF] /home/shriram/Stash/zm-core-utils/src/bin/zmresolverctl
   Copy ${repoDir}/zm-backup-utilities/src/bin/zmrestore                                            ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmrestore
   Copy ${repoDir}/zm-backup-utilities/src/bin/zmrestoreldap                                        ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmrestoreldap
   Copy ${repoDir}/zm-backup-utilities/src/bin/zmrestoreoffline                                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmrestoreoffline
   Copy ${repoDir}/zm-core-utils/src/bin/zmsaslauthdctl                                             ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmsaslauthdctl
   Copy ${repoDir}/zm-backup-utilities/src/bin/zmschedulebackup                                     ${repoDir}/zm-build/${currentPackage}/opt/zimbra/bin/zmschedulebackup
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


   PrepareDeployDir "docs"
   PrepareDeployDir "docs/rebranding"
# opt/zimbra/docs/INSTALL-DEV-MAC-UBUNTU-VM.md
# opt/zimbra/docs/INSTALL-DEV-MULTISERVER.txt
# opt/zimbra/docs/INSTALL-DEV-UBUNTU12_64.txt
# opt/zimbra/docs/INSTALL-OSX.md
# opt/zimbra/docs/INSTALL-SVN-WIN32.txt
# opt/zimbra/docs/INSTALL-VOICE.txt
# opt/zimbra/docs/INSTALL-win.txt
# opt/zimbra/docs/Notification.md
# opt/zimbra/docs/OAuthConsumer.txt
# opt/zimbra/docs/RedoableOperations.txt
# opt/zimbra/docs/ServerLocalization.txt
# opt/zimbra/docs/YPL.txt
# opt/zimbra/docs/ZPL.txt
# opt/zimbra/docs/ZimbraVoice-Extension.txt
# opt/zimbra/docs/abook.md
# opt/zimbra/docs/accesscontrol.txt
# opt/zimbra/docs/acl.md
# opt/zimbra/docs/admin_soap_white_list.txt
# opt/zimbra/docs/alarm.md
# opt/zimbra/docs/autoprov.txt
# opt/zimbra/docs/backup.txt
# opt/zimbra/docs/caches.txt
# opt/zimbra/docs/cal-todos.md
# opt/zimbra/docs/certauth.txt
# opt/zimbra/docs/changepasswordlistener.txt
# opt/zimbra/docs/clienturls.txt
# opt/zimbra/docs/customauth-hosted.txt
# opt/zimbra/docs/customauth.txt
# opt/zimbra/docs/dav.txt
# opt/zimbra/docs/delegatedadmin.txt
# opt/zimbra/docs/extensions.md
# opt/zimbra/docs/externalldapauth.txt
# opt/zimbra/docs/familymailboxes.md
# opt/zimbra/docs/file-upload.txt
# opt/zimbra/docs/freebusy-interop.md
# opt/zimbra/docs/gal.txt
# opt/zimbra/docs/groups.md
# opt/zimbra/docs/hsm-soap-admin.txt
# opt/zimbra/docs/idn.txt
# opt/zimbra/docs/jetty.txt
# opt/zimbra/docs/junk-notjunk.md
# opt/zimbra/docs/keyview_eula.txt
# opt/zimbra/docs/krb5.txt
# opt/zimbra/docs/ldap.txt
# opt/zimbra/docs/ldap_replication_howto.txt
# opt/zimbra/docs/lockout.txt
# opt/zimbra/docs/logging.md
# opt/zimbra/docs/login.txt
# opt/zimbra/docs/mailboxMove.txt
# opt/zimbra/docs/mysql-monitoring.txt
# opt/zimbra/docs/notes.txt
# opt/zimbra/docs/open_source_licenses_zcs-windows.txt
# opt/zimbra/docs/oracle_jdk_eula.txt
# opt/zimbra/docs/pop-imap.txt
# opt/zimbra/docs/postfix-ldap-tables.txt
# opt/zimbra/docs/postfix-split-domain.md
# opt/zimbra/docs/preauth.md
# opt/zimbra/docs/qatests.txt
# opt/zimbra/docs/query.md
# opt/zimbra/docs/rest-admin.txt
# opt/zimbra/docs/rest.txt
# opt/zimbra/docs/rights-adminconsole.txt
# opt/zimbra/docs/rights-ext.txt
# opt/zimbra/docs/rights.txt
# opt/zimbra/docs/share.md
# opt/zimbra/docs/snmp.txt
# opt/zimbra/docs/soap-admin.txt
# opt/zimbra/docs/soap-calendar.txt
# opt/zimbra/docs/soap-context-extension.txt
# opt/zimbra/docs/soap-document.txt
# opt/zimbra/docs/soap-im.txt
# opt/zimbra/docs/soap-mobile.txt
# opt/zimbra/docs/soap-right.txt
# opt/zimbra/docs/soap-voice-admin.txt
# opt/zimbra/docs/soap-voice.txt
# opt/zimbra/docs/soap-waitset.txt
# opt/zimbra/docs/soap.txt
# opt/zimbra/docs/soapbackup.txt
# opt/zimbra/docs/spnego.txt
# opt/zimbra/docs/sync.txt
# opt/zimbra/docs/testharness.txt
# opt/zimbra/docs/twofactorauth.md
# opt/zimbra/docs/urls.md
# opt/zimbra/docs/using-gdb.txt
# opt/zimbra/docs/webdav-mountpoint.txt
# opt/zimbra/docs/xml-meta.txt
# opt/zimbra/docs/zdesktop-dev-howto.txt
# opt/zimbra/docs/zmztozmig.txt

# opt/zimbra/docs/rebranding/DE_Rebranding_directions.txt
# opt/zimbra/docs/rebranding/ES_Rebranding_directions.txt
# opt/zimbra/docs/rebranding/FR_Rebranding_directions.txt
# opt/zimbra/docs/rebranding/IT_Rebranding_directions.txt
# opt/zimbra/docs/rebranding/JA_Rebranding_directions.txt
# opt/zimbra/docs/rebranding/NL_Rebranding_directions.txt
# opt/zimbra/docs/rebranding/RU_Rebranding_directions.txt
# opt/zimbra/docs/rebranding/en_US_Rebranding_directions.txt
# opt/zimbra/docs/rebranding/pt_BR_Rebranding_directions.txt
# opt/zimbra/docs/rebranding/zh_CN_Rebranding_directions.txt
# opt/zimbra/docs/rebranding/zh_HK_Rebranding_directions.txt

   PrepareDeployDir "lib"
# opt/zimbra/lib/libappmonitorlib.so
# opt/zimbra/lib/libjunixsocket-linux-1.5-amd64.so
# opt/zimbra/lib/libzimbra-native.so

   PrepareDeployDir "lib/jars"
   PrepareDeployDir "lib/ext-common"
   PrepareDeployDir "lib/jars-ant"
   PrepareDeployDir "lib/ext"
# opt/zimbra/lib/jars/ant-1.7.0-ziputil-patched.jar
# opt/zimbra/lib/jars/ant-contrib-1.0b1.jar
# opt/zimbra/lib/jars/ant-tar-patched.jar
# opt/zimbra/lib/jars/antlr-3.2.jar
# opt/zimbra/lib/jars/apache-jsieve-core-0.5.jar
# opt/zimbra/lib/jars/apache-log4j-extras-1.0.jar
# opt/zimbra/lib/jars/asm-3.3.1.jar
# opt/zimbra/lib/jars/bcprov-jdk15-146.jar
# opt/zimbra/lib/jars/commons-cli-1.2.jar
# opt/zimbra/lib/jars/commons-codec-1.7.jar
# opt/zimbra/lib/jars/commons-collections-3.2.2.jar
# opt/zimbra/lib/jars/commons-compress-1.10.jar
# opt/zimbra/lib/jars/commons-dbcp-1.4.jar
# opt/zimbra/lib/jars/commons-fileupload-1.2.2.jar
# opt/zimbra/lib/jars/commons-httpclient-3.1.jar
# opt/zimbra/lib/jars/commons-io-1.4.jar
# opt/zimbra/lib/jars/commons-lang-2.6.jar
# opt/zimbra/lib/jars/commons-logging.jar
# opt/zimbra/lib/jars/commons-net-3.3.jar
# opt/zimbra/lib/jars/commons-pool-1.6.jar
# opt/zimbra/lib/jars/concurrentlinkedhashmap-lru-1.3.1.jar
# opt/zimbra/lib/jars/curator-client-2.0.1-incubating.jar
# opt/zimbra/lib/jars/curator-framework-2.0.1-incubating.jar
# opt/zimbra/lib/jars/curator-recipes-2.0.1-incubating.jar
# opt/zimbra/lib/jars/curator-x-discovery-2.0.1-incubating.jar
# opt/zimbra/lib/jars/cxf-2.7.18.jar
# opt/zimbra/lib/jars/dom4j-1.5.2.jar
# opt/zimbra/lib/jars/ehcache-core-2.5.1.jar
# opt/zimbra/lib/jars/ews_2010.jar
# opt/zimbra/lib/jars/freemarker-2.3.19.jar
# opt/zimbra/lib/jars/ganymed-ssh2-build210.jar
# opt/zimbra/lib/jars/gifencoder.jar
# opt/zimbra/lib/jars/gmbal-api-only-2.2.6.jar
# opt/zimbra/lib/jars/guava-13.0.1.jar
# opt/zimbra/lib/jars/helix-core-0.6.1-incubating.jar
# opt/zimbra/lib/jars/httpasyncclient-4.0-beta3.jar
# opt/zimbra/lib/jars/httpclient-4.2.1.jar
# opt/zimbra/lib/jars/httpcore-4.2.2.jar
# opt/zimbra/lib/jars/httpcore-nio-4.2.2.jar
# opt/zimbra/lib/jars/ical4j-0.9.16-patched.jar
# opt/zimbra/lib/jars/icu4j-4.8.1.1.jar
# opt/zimbra/lib/jars/jackson-all-1.9.2.jar
# opt/zimbra/lib/jars/jamm-0.2.5.jar
# opt/zimbra/lib/jars/javamail-1.4.5.jar
# opt/zimbra/lib/jars/javax.ws.rs-api-2.0-m10.jar
# opt/zimbra/lib/jars/jaxb-api-2.2.6.jar
# opt/zimbra/lib/jars/jaxb-impl-2.2.6.jar
# opt/zimbra/lib/jars/jaxen-1.1.3.jar
# opt/zimbra/lib/jars/jaxws-api-2.2.6.jar
# opt/zimbra/lib/jars/jaxws-rt-2.2.6.jar
# opt/zimbra/lib/jars/jcharset.jar
# opt/zimbra/lib/jars/jcommon-1.0.20.jar
# opt/zimbra/lib/jars/jcs-1.3.jar
# opt/zimbra/lib/jars/jdom.jar
# opt/zimbra/lib/jars/jersey-client-1.11.jar
# opt/zimbra/lib/jars/jersey-core-1.11.jar
# opt/zimbra/lib/jars/jersey-json-1.11.jar
# opt/zimbra/lib/jars/jersey-multipart-1.12.jar
# opt/zimbra/lib/jars/jersey-server-1.11.jar
# opt/zimbra/lib/jars/jersey-servlet-1.11.jar
# opt/zimbra/lib/jars/jetty-continuation-9.3.5.v20151012.jar
# opt/zimbra/lib/jars/jetty-http-9.3.5.v20151012.jar
# opt/zimbra/lib/jars/jetty-io-9.3.5.v20151012.jar
# opt/zimbra/lib/jars/jetty-rewrite-9.3.5.v20151012.jar
# opt/zimbra/lib/jars/jetty-security-9.3.5.v20151012.jar
# opt/zimbra/lib/jars/jetty-server-9.3.5.v20151012.jar
# opt/zimbra/lib/jars/jetty-servlet-9.3.5.v20151012.jar
# opt/zimbra/lib/jars/jetty-servlets-9.3.5.v20151012.jar
# opt/zimbra/lib/jars/jetty-util-9.3.5.v20151012.jar
# opt/zimbra/lib/jars/jfreechart-1.0.16.jar
# opt/zimbra/lib/jars/jna-3.4.0.jar
# opt/zimbra/lib/jars/json.jar
# opt/zimbra/lib/jars/jsr181-api-2.2.6.jar
# opt/zimbra/lib/jars/jsr311-api-1.1.1.jar
# opt/zimbra/lib/jars/junixsocket-1.3.jar
# opt/zimbra/lib/jars/junixsocket-demo-1.3.jar
# opt/zimbra/lib/jars/junixsocket-mysql-1.3.jar
# opt/zimbra/lib/jars/junixsocket-rmi-1.3.jar
# opt/zimbra/lib/jars/jython-2.5.2.jar
# opt/zimbra/lib/jars/jzlib-1.0.7.jar
# opt/zimbra/lib/jars/libidn-1.24.jar
# opt/zimbra/lib/jars/log4j-1.2.16.jar
# opt/zimbra/lib/jars/lucene-analyzers-3.5.0.jar
# opt/zimbra/lib/jars/lucene-core-3.5.0.jar
# opt/zimbra/lib/jars/lucene-smartcn-3.5.0.jar
# opt/zimbra/lib/jars/mariadb-java-client-1.1.8.jar
# opt/zimbra/lib/jars/memcached-2.6.jar
# opt/zimbra/lib/jars/mina-core-2.0.4.jar
# opt/zimbra/lib/jars/neethi-3.0.2.jar
# opt/zimbra/lib/jars/nekohtml-1.9.13.1z.jar
# opt/zimbra/lib/jars/oauth-1.4.jar
# opt/zimbra/lib/jars/owasp-java-html-sanitizer-r239.jar
# opt/zimbra/lib/jars/policy-2.2.6.jar
# opt/zimbra/lib/jars/servlet-api-3.1.jar
# opt/zimbra/lib/jars/slf4j-api-1.6.4.jar
# opt/zimbra/lib/jars/slf4j-log4j12-1.6.4.jar
# opt/zimbra/lib/jars/smack.jar
# opt/zimbra/lib/jars/smackx-debug.jar
# opt/zimbra/lib/jars/smackx-jingle.jar
# opt/zimbra/lib/jars/smackx.jar
# opt/zimbra/lib/jars/spring-aop-3.0.7.RELEASE.jar
# opt/zimbra/lib/jars/spring-asm-3.0.7.RELEASE.jar
# opt/zimbra/lib/jars/spring-beans-3.0.7.RELEASE.jar
# opt/zimbra/lib/jars/spring-context-3.0.7.RELEASE.jar
# opt/zimbra/lib/jars/spring-core-3.0.7.RELEASE.jar
# opt/zimbra/lib/jars/spring-expression-3.0.7.RELEASE.jar
# opt/zimbra/lib/jars/sqlite-jdbc-3.7.5-1.jar
# opt/zimbra/lib/jars/stax-ex-2.2.6.jar
# opt/zimbra/lib/jars/stax2-api-3.1.1.jar
# opt/zimbra/lib/jars/streambuffer-2.2.6.jar
# opt/zimbra/lib/jars/syslog4j-0.9.46-bin.jar
# opt/zimbra/lib/jars/tnef-1.8.0.jar
# opt/zimbra/lib/jars/unboundid-ldapsdk-2.3.5-se.jar
# opt/zimbra/lib/jars/woodstox-core-asl-4.2.0.jar
# opt/zimbra/lib/jars/wsdl4j-1.6.3.jar
# opt/zimbra/lib/jars/xercesImpl-2.9.1.jar
# opt/zimbra/lib/jars/xmlschema-core-2.0.3.jar
# opt/zimbra/lib/jars/yuicompressor-2.4.2-zimbra.jar
# opt/zimbra/lib/jars/zimbra-charset.jar
# opt/zimbra/lib/jars/zimbra-native.jar
# opt/zimbra/lib/jars/zimbraclient.jar
# opt/zimbra/lib/jars/zimbracommon.jar
# opt/zimbra/lib/jars/zimbrasoap.jar
# opt/zimbra/lib/jars/zimbrastore.jar
# opt/zimbra/lib/jars/zkclient-0.1.jar
# opt/zimbra/lib/jars/zookeeper-3.4.5.jar

# opt/zimbra/lib/ext/com_zimbra_bulkprovision/com_zimbra_bulkprovision.jar
# opt/zimbra/lib/ext/com_zimbra_bulkprovision/commons-csv-1.2.jar
# opt/zimbra/lib/ext/com_zimbra_cert_manager/com_zimbra_cert_manager.jar
# opt/zimbra/lib/ext/com_zimbra_clientuploader/com_zimbra_clientuploader.jar

# opt/zimbra/lib/ext-common/zimbra-license-tools.jar

# opt/zimbra/lib/jars-ant/ant-1.6.5.jar

   CreateDebianPackage
}

############################################################################
main "$@"
