#!/bin/bash
#
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2013, 2014, 2015, 2016 Synacor, Inc.
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
#

installPackages() {
   echo
   echo "Beginning Installation - see $LOGFILE for details..."
   echo

   local repo_pkg_names_delayed=()
   local repo_pkg_names=()
   local local_pkg_files=()
   local local_pkg_names=()

   pretty_display() {
      local banner=$1; shift;
      local pk=("$@");
      echo
      echo "$banner (${#pk[*]}):" | tee -a $LOGFILE
      local p;
      for p in "${pk[@]}"
      do
         echo "   $(basename $p)" | tee -a $LOGFILE
      done
      echo -n "      ...";
      echo >> $LOGFILE
   }

   gather_package_info() {
      local PKG;
      for PKG in "$@"
      do
         findLatestPackage $PKG
         if [ "$file_location" == "local" ]
         then
            if ! grep -q -w -e $PKG <(echo "${local_pkg_names[*]}")
            then
               printf "%28s %s\n" "$PKG" "will be installed."
               local_pkg_files=( "${local_pkg_files[@]}" "$file" )
               local_pkg_names=( "${local_pkg_names[@]}" "$PKG" )
            fi
         elif [ "$file_location" == "repo" ]
         then
            if [ "$file_delayed_install" == "1" ]
            then
               if ! grep -q -w -e $PKG <(echo "${repo_pkg_names_delayed[*]}")
               then
                  printf "%28s %s\n" "$PKG" "will be downloaded and installed."
                  repo_pkg_names_delayed=( "${repo_pkg_names_delayed[@]}" "$PKG" )
               fi
            else
               if ! grep -q -w -e $PKG <(echo "${repo_pkg_names[*]}")
               then
                  printf "%28s %s\n" "$PKG" "will be downloaded and installed."
                  repo_pkg_names=( "${repo_pkg_names[@]}" "$PKG" )
               fi
            fi
         fi
      done
   }

   local PKG;
   for PKG in $INSTALL_PACKAGES
   do
      gather_package_info $PKG;

      [ x$PKG = "xzimbra-drive"    ] && gather_package_info "zimbra-core"
      [ x$PKG = "xzimbra-chat"     ] && gather_package_info "zimbra-core"
      [ x$PKG = "xzimbra-core"     ] && gather_package_info "zimbra-core-components"
      [ x$PKG = "xzimbra-apache"   ] && gather_package_info "zimbra-apache-components"
      [ x$PKG = "xzimbra-dnscache" ] && gather_package_info "zimbra-dnscache-components"
      [ x$PKG = "xzimbra-ldap"     ] && gather_package_info "zimbra-ldap-components"
      [ x$PKG = "xzimbra-mta"      ] && gather_package_info "zimbra-mta-components"
      [ x$PKG = "xzimbra-proxy"    ] && gather_package_info "zimbra-proxy-components" "zimbra-memcached"
      [ x$PKG = "xzimbra-snmp"     ] && gather_package_info "zimbra-snmp-components"
      [ x$PKG = "xzimbra-spell"    ] && gather_package_info "zimbra-spell-components"
      [ x$PKG = "xzimbra-store"    ] && gather_package_info "zimbra-store-components"
   done

   if [ "${#repo_pkg_names[@]}" -gt 0 ]
   then
      # Download packages.
      pretty_display "Downloading packages" "${repo_pkg_names[@]}";
      $PACKAGEDOWNLOAD "${repo_pkg_names[@]}" >> $LOGFILE 2>&1
      if [ $? -ne 0 ]; then
         echo "Unable to download packages from repository. System is not modified."
         exit 1
      fi
      echo "done"
   fi

   if [ $UPGRADE = "yes" ]; then
      if [ ${ZM_CUR_MAJOR} -lt 8 ] || [ ${ZM_CUR_MAJOR} -eq 8 -a ${ZM_CUR_MINOR} -lt 7 ]; then
         POST87UPGRADE="false"
      else
         POST87UPGRADE="true"
      fi
      # Special case for zimbra-memcached as pre-8.7.0 it is local package moved to remote.
      if [ $POST87UPGRADE = "false" ]; then
         if [ $ISUBUNTU = "true" ]; then
            MEMCACHEDVER=`apt-cache show zimbra-memcached | grep -i version | \
               grep "zimbra$ZM_INST_MAJOR.$ZM_INST_MINOR" | head -n1 | \
               cut -d ':' -f 2 |  tr -d " "`
            echo "Downloading Remote package zimbra-memcached version $MEMCACHEDVER";
            $PACKAGEDOWNLOAD zimbra-memcached=$MEMCACHEDVER >> $LOGFILE 2>&1
         else
            MEMCACHEDVER=`yum --showduplicates list zimbra-memcached | \
               grep "zimbra$ZM_INST_MAJOR.$ZM_INST_MINOR" | head -n1 | \
               awk '{print $2}'`
            echo "Downloading Remote package zimbra-memcached version $MEMCACHEDVER";
            yum downgrade --downloadonly --assumeyes zimbra-memcached-$MEMCACHEDVER >> $LOGFILE 2>&1
         fi
         if [ $? -ne 0 ]; then
            echo "Unable to download packages zimbra-memcached from repository. System is not modified."
            exit 1
         fi
      fi
      if [ "$FORCE_UPGRADE" = "yes" -o "$POST87UPGRADE" = "false" ]; then
         findUbuntuExternalPackageDependencies
      fi
      saveExistingConfig
   fi

   removeExistingInstall

   if [ "${#repo_pkg_names[@]}" -gt 0 ]
   then
      pretty_display "Installing repo packages" "${repo_pkg_names[@]}";
      $REPOINST "${repo_pkg_names[@]}" >>$LOGFILE 2>&1
      if [ $? != 0 ]; then
         pkgError
      fi
      echo "done"
   fi

   if [ "${#local_pkg_files[@]}" -gt 0 ]
   then
      pretty_display "Installing local packages" "${local_pkg_names[@]}";
      $PACKAGEINST "${local_pkg_files[@]}" >> $LOGFILE 2>&1
      if [ $? != 0 ]; then
         pkgError
      fi
      echo "done"
   fi

   if [ "${#repo_pkg_names_delayed[@]}" -gt 0 ]
   then
      pretty_display "Installing extra packages" "${repo_pkg_names_delayed[@]}";
      $REPOINST "${repo_pkg_names_delayed[@]}" >>$LOGFILE 2>&1
      if [ $? != 0 ]; then
         echo "Unable to download extra packages from repository. Proceeding without this..."
         # not exiting on error
      else
         echo "done"
      fi
   fi

   if [ $UPGRADE = "yes" ]; then
      ST="UPGRADED"
   else
      ST="INSTALLED"
   fi

   D=`date +%s`
   if [ "$ISUBUNTU" = "true" ] && [ ! -z "$EXTPACKAGES" ]; then
      echo -n "Re-installing $EXTPACKAGES ..."
      $REPOINST $EXTPACKAGES >> $LOGFILE 2>&1
      if [ $? -ne 0 ]; then
         echo "Failed to install package[s] $EXTPACKAGES."
         # not exiting on error
      fi
      echo "done"
   fi

   for f in "${local_pkg_files[@]}"; do
      f=`basename $f`
      echo "${D}: $ST $f" >> /opt/zimbra/.install_history
   done

   echo
   echo "Running Post Installation Configuration:"
}

pkgError() {
   echo ""
   echo "ERROR: Unable to install required packages"
   if [ $UPGRADE = "yes" ]; then
      echo "WARNING: REMOTE PACKAGE INSTALLATION FAILED."
      echo "To proceed, review the instructions at:"
      echo "https://wiki.zimbra.com/wiki/Recovering_from_upgrade_failure"
      echo "Failure to follow the instructions on the wiki will result in complete data loss."
   else
      echo "Fix the issues with remote package installation and rerun the installer"
   fi
   exit 1
}

findLatestPackage() {
   package=$1

   latest=""
   himajor=0
   himinor=0
   histamp=0

   files=`ls $PACKAGE_DIR/$package*.$PACKAGEEXT 2> /dev/null`
   for q in $files; do
      f=`basename $q`
      if [ x"$PACKAGEEXT" = "xrpm" ]; then
         id=`echo $f | awk -F- '{print $3}'`
         version=`echo $id | awk -F_ '{print $1}'`
         major=`echo $version | awk -F. '{print $1}'`
         minor=`echo $version | awk -F. '{print $2}'`
         micro=`echo $version | awk -F. '{print $3}'`
         stamp=`echo $f | awk -F_ '{print $3}' | awk -F. '{print $1}'`
         elif [ x"$PACKAGEEXT" = "xdeb" ]; then
         id=`basename $f .deb | awk -F_ '{print $2"_"$3}'`
         id=`echo $id | sed -e 's/_i386$//'`
         id=`echo $id | sed -e 's/_amd64$//'`
         version=`echo $id | awk -F. '{print $1"."$2"."$3"_"$4}'`
         major=`echo $version | awk -F. '{print $1}'`
         minor=`echo $version | awk -F. '{print $2}'`
         micro=`echo $version | awk -F. '{print $3}'`
         stamp=`echo $id | awk -F. '{print $4}'`
      else
         id=`echo $f | awk -F_ '{print $2}'`
         version=`echo $id | awk -F_ '{print $1}'`
         major=`echo $version | awk -F. '{print $1}'`
         minor=`echo $version | awk -F. '{print $2}'`
         micro=`echo $version | awk -F. '{print $3}'`
         stamp=`echo $f | awk -F_ '{print $3}' | awk -F. '{print $1}'`
      fi
      if [ x"$PACKAGEEXT" = "xdeb" ]; then
         debos=`echo $id | awk -F. '{print $6}'`
         hwbits=`echo $id | awk -F. '{print $7}'`
         if [ x"$hwbits" = "x64" ]; then
            installable_platform=${debos}_${hwbits}
         else
            installable_platform=${debos}
         fi
      else
         installable_platform=`echo $id | awk -F. '{print $4}'`
      fi

      if [ $major -gt $himajor ]; then
         himajor=$major
         himinor=$minor
         histamp=$stamp
         latest=$q
         continue
      fi
      if [ $minor -gt $himinor ]; then
         himajor=$major
         himinor=$minor
         histamp=$stamp
         latest=$q
         continue
      fi
      if [ $stamp -gt $histamp ]; then
         himajor=$major
         himinor=$minor
         histamp=$stamp
         latest=$q
         continue
      fi
   done

   unset file
   unset file_location
   unset file_delayed_install

   if [ -f "$latest" ]
   then
      file=$latest
      file_location="local"
      file_delayed_install=1
   else
      if [ $ISUBUNTU = "true" ]
      then
         if grep -q -w -e "^$package" <(apt-cache search --names-only "^$package" 2>/dev/null)
         then
            file_location="repo"
         fi
      else
         if grep -q -w -e "^$package" <(yum --showduplicates list available -q -e 0 "$package" 2>/dev/null)
         then
            file_location="repo"
         fi
      fi

      if [ "$file_location" == "repo" ]
      then
         if [ "$package" == "zimbra-chat" ] || [ "$package" == "zimbra-drive" ]
         then
            file_delayed_install=1
         fi
      fi
   fi
}

checkPackages() {
   echo ""
   echo "Checking for installable packages"
   echo ""

   AVAILABLE_PACKAGES=""

   for i in $CORE_PACKAGES $PACKAGES $OPTIONAL_PACKAGES;
   do
      findLatestPackage $i
      if [ "$file_location" == "local" ]
      then
         if grep -q i386 <(echo $file)
         then
            PROC="i386"
         else
            PROC="x86_64"
         fi

         if [[ $PLATFORM == "DEBIAN"* || $PLATFORM == "UBUNTU"* ]]; then
            LOCALPROC=`dpkg --print-architecture`
            if [ x"$LOCALPROC" == "xamd64" ]; then
               LOCALPROC="x86_64"
            fi
         else
            LOCALPROC=`uname -i`
         fi

         if [ x$LOCALPROC != x$PROC ]; then
            echo "Error: attempting to install $PROC packages on a $LOCALPROC OS."
            echo "Exiting..."
            echo ""
            exit 1
         fi

         file_check="unverified"
         if [ x"$PACKAGEVERIFY" != "x" ]; then
            if $PACKAGEVERIFY $file > /dev/null 2>&1
            then
               file_check="verified";
            else
               echo "Found $i locally, but package is not installable. (possibly corrupt)"
               echo "Unable to continue. Please correct package corruption and rerun the installation."
               exit 1
            fi
         fi

         if ! grep -q -w -e "$package" <(echo "$CORE_PACKAGES")
         then
            AVAILABLE_PACKAGES="$AVAILABLE_PACKAGES $i"
         fi

         printf "%s\n" "Found $i ($file_location)"

      elif [ "$file_location" == "repo" ]
      then
         if ! grep -q -w -e "$package" <(echo "$CORE_PACKAGES")
         then
            AVAILABLE_PACKAGES="$AVAILABLE_PACKAGES $i"
         fi

         printf "%s\n" "Found $i ($file_location)"
      else
         if grep -q -w -e "$package" <(echo "$CORE_PACKAGES")
         then
            echo "ERROR: Required Core package $i not found in $PACKAGE_DIR"
            echo "Exiting"
            exit 1
         fi
      fi
   done
   echo ""
}
