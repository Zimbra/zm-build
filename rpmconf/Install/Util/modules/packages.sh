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

   gather_package_info()
   {
      local pkg=$1; shift;

      if [ -z "${gather_visit_flag[$pkg]}" ]
      then
         echo "gathering packgage info for: $pkg" >> $LOGFILE

         locatePackage $pkg

         gather_visit_flag[$pkg]=1

         if [ "${global_pkg_loc[$pkg]}" == "local" ]
         then
            local deps=( $(LocalPackageDepList "${global_pkg_file[$pkg]}") )
            local dep
            for dep in "${deps[@]}"
            do
               echo "descending into dependency: $pkg (local) --deps-> $dep" >> $LOGFILE
               gather_package_info "$dep"
            done

            printf "%48s %s\n" "$pkg" "will be installed."

            local_pkg_names+=( "$pkg" )
            local_pkg_files+=( "${global_pkg_file[$pkg]}" )

         elif [ "${global_pkg_loc[$pkg]}" == "repo" ]
         then
            local delay=0

            if ! [[ "$pkg" =~ ^zimbra-.*-components$ ]]
            then
               local dep
               for dep in $(RepoPackageDepList "$pkg")
               do
                  echo "locating dependency: $pkg (remote) --deps-> $dep" >> $LOGFILE
                  locatePackage "$dep"
                  if [ "${global_pkg_loc[$dep]}" == "local" ]
                  then
                     delay=1
                  fi
               done
            fi

            if [ "$delay" == "1" ]
            then
               printf "%48s %s\n" "$pkg" "will be downloaded and installed (later)."
               repo_pkg_names_delayed+=( "$pkg" )
            else
               printf "%48s %s\n" "$pkg" "will be downloaded and installed."
               repo_pkg_names+=( "$pkg" )
            fi
         else
            printf "%48s %s\n" "$pkg" "is missing.                                    ERROR";
            (( ++gather_dep_errors ))
         fi

         gather_visit_flag[$pkg]=2
      fi
   }

   local -A gather_visit_flag=()
   local gather_dep_errors=0
   local repo_pkg_names_delayed=()
   local repo_pkg_names=()
   local local_pkg_names=()
   local local_pkg_files=()

   local PKG;
   for PKG in $INSTALL_PACKAGES
   do
      gather_package_info $PKG;
   done

   if [ "$gather_dep_errors" -gt 0 ]
   then
      echo
      echo "Unable to find missing packages in repository. System is not modified."
      exit 1
   fi

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
      if [ "${ZM_CUR_MAJOR}" -lt 8 ] || [ "${ZM_CUR_MAJOR}" -eq 8 -a "${ZM_CUR_MINOR}" -lt 7 ]; then
         POST87UPGRADE="false"
      else
         POST87UPGRADE="true"
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

   local pkg_n
   for pkg_n in "${local_pkg_names[@]}" "${repo_pkg_names[@]}" "${repo_pkg_names_delayed[@]}"
   do
      echo "${D}: $ST $(DumpFileDetailsFromPackage "$pkg_n")" >> /opt/zimbra/.install_history
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

declare -A global_pkg_loc
declare -A global_pkg_file

locatePackage() {
   local package="$1"; shift;

   if [ -z "${global_pkg_loc[$package]}" ]
   then
      local check_file="$(echo "$PACKAGE_DIR/$package"[-_][0-9]*."$PACKAGEEXT")"
      if [ -f "$check_file" ]
      then
         global_pkg_loc[$package]="local"
         global_pkg_file[$package]=$check_file
      else
         if grep -q -w -e "^$package" <(LocatePackageInRepo "$package")
         then
            global_pkg_loc[$package]="repo"
            global_pkg_file[$package]=""
         else
            global_pkg_loc[$package]="unknown"
            global_pkg_file[$package]=""
         fi
      fi
   fi
}

checkPackages() {
   echo ""
   echo "Checking for installable packages"
   echo ""

   AVAILABLE_PACKAGES=""

   local package
   for package in $CORE_PACKAGES $PACKAGES $OPTIONAL_PACKAGES;
   do
      locatePackage $package
      if [ "${global_pkg_loc[$package]}" == "local" ]
      then
         local file=${global_pkg_file[$package]}
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
               echo "Found $package locally, but package is not installable. (possibly corrupt)"
               echo "Unable to continue. Please correct package corruption and rerun the installation."
               exit 1
            fi
         fi

         if ! grep -q -w -e "$package" <(echo "$CORE_PACKAGES")
         then
            AVAILABLE_PACKAGES="$AVAILABLE_PACKAGES $package"
         fi

         printf "%s\n" "Found $package (local)"

      elif [ "${global_pkg_loc[$package]}" == "repo" ]
      then
         if ! grep -q -w -e "$package" <(echo "$CORE_PACKAGES")
         then
            AVAILABLE_PACKAGES="$AVAILABLE_PACKAGES $package"
         fi

         printf "%s\n" "Found $package (repo)"
      else
         if grep -q -w -e "$package" <(echo "$CORE_PACKAGES")
         then
            echo "ERROR: Required Core package $package not found in $PACKAGE_DIR"
            echo "Exiting"
            exit 1
         fi
      fi
   done
   echo ""
}
