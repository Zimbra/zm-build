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

# Script builds all required zimbra packages for the build.
# Usage: bash -x /home/zimbra/git/zm-build/scripts/packages.sh -r 8.7.1.GA -b JUDASPRIEST-871 -n 1670 -o UBUNTU16_64 -t NETWORK -s 20161129140015


#-------------------- Configuration ---------------------------


	. "$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)/config.sh"

	if ( [ -z ${1} ] && [ -z ${2} ] && [ -z ${3} ] && [ -z ${4} ] && [ -z ${5} ] && [ -z ${6} ] ) || ( [ -z ${1} ] || [ -z ${2} ] || [ -z ${3} ] || [ -z ${4} ] || [ -z ${5} ] || [ -z ${6} ] ); then

		echo -e "\tInvalid or insufficient arguments passed in script, it should in form of: bash <full-script-path> <release> <branch> <buildno> <os> <build-type> <build-timestamp>\n"

		exit

	else

		while getopts r:b:n:o:t:s: option
		do
			case "${option}"
			in
				r) release=${OPTARG};;
				b) branch=${OPTARG};;
				n) buildNo=${OPTARG};;
				o) os=${OPTARG};;
				t) buildType=${OPTARG};;
				s) buildTimeStamp=${OPTARG};;
			esac
		done
	fi

	repoDir=${buildsDir}/${os}/${branch}/${buildTimeStamp}_${buildType}
	buildTimeStamp=`echo ${repoDir} | cut -d "/" -f 7 | cut -d "_" -f 1`
	buildLogFile=${repoDir}/logs/build.log

	# Create logs directory
	mkdir -p ${repoDir}/logs
	cd ${repoDir}

	# Check architecture
	if [[ ${os} = *"UBUNTU"* ]]; then
		arch=amd64
	elif ( [[ ${os} = *"RHEL"* ]] || [[ ${os} = *"CENTOS"* ]] ); then
		arch=x86_64
	else
		echo -e "\tOS doesn't match with build argument OS: ${os} OR wrong arguments passed in build script\n\n\tEXIT\n" >> ${buildLogFile}
		exit
	fi
	mkdir -p ${repoDir}/zm-build/${arch}

	echo -e "Build script arguments: ${1} ${2} ${3} ${4} ${5} ${6}\n" >> ${buildLogFile}

	echo -e "Copying git repository manually (temporarily)" >> ${buildLogFile}
	cp -R ${gitRepoDir}/zm-build ${repoDir}
	cp -R ${gitRepoDir}/zm-core-utils ${repoDir}
	cp -R ${gitRepoDir}/zm-licenses ${repoDir}
	cp -R ${gitRepoDir}/zm-aspell ${repoDir}
	cp -R ${gitRepoDir}/zm-postfix ${repoDir}
	cp -R ${gitRepoDir}/zm-amavis ${repoDir}
	cp -R ${gitRepoDir}/zm-dnscache ${repoDir}
	cp -R ${gitRepoDir}/zm-network-build ${repoDir}
	cp -R ${gitRepoDir}/zm-convertd-native ${repoDir}
	cp -R ${gitRepoDir}/zm-convertd-store ${repoDir}
	cp -R ${gitRepoDir}/zm-nginx-conf ${repoDir}
	cp -R ${gitRepoDir}/zm-ldap-utilities ${repoDir}
	cp -R ${gitRepoDir}/zm-convertd-conf ${repoDir}
        cp -R ${gitRepoDir}/zm-hsm ${repoDir}
        cp -R ${gitRepoDir}/zm-archive-utils ${repoDir}
        cp -R ${gitRepoDir}/zm-sync-store ${repoDir}
        cp -R ${gitRepoDir}/zm-sync-tools ${repoDir}
        cp -R ${gitRepoDir}/zm-store-conf ${repoDir}
        cp -R ${gitRepoDir}/zm-web-client ${repoDir}
        cp -R ${gitRepoDir}/zm-windows-comp ${repoDir}

	echo -e "Exporting script argument values" >> ${buildLogFile}
	export release
	export branch
	export buildNo
	export os
	export buildType
	export repoDir
	export arch
	export buildTimeStamp
	export buildLogFile
	export zimbraThirdPartyServer


#-------------------- Build Packages ---------------------------

	declare -a packagesArray=(zimbra-snmp zimbra-spell zimbra-logger zimbra-dnscache zimbra-apache zimbra-mta zimbra-proxy zimbra-archiving zimbra-convertd zimbra-store)
	for i in "${packagesArray[@]}"
	do
		echo -e "\n\t-> Building ${i} package..." >> ${buildLogFile}
		bash "$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)/packages"/${i}.sh
	done
