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
# Usage: bash .../packages.sh 8.7.1.GA JUDASPRIEST-871 1670 UBUNTU16_64 NETWORK


#-------------------- Configuration ---------------------------


	. "$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)/config.sh"

	if ( [ -z ${1} ] && [ -z ${2} ] && [ -z ${3} ] && [ -z ${4} ] && [ -z ${5} ] ) || ( [ -z ${1} ] || [ -z ${2} ] || [ -z ${3} ] || [ -z ${4} ] || [ -z ${5} ] ); then

		echo -e "\tInvalid or insufficient arguments passed in script, it should in form of: bash <full-script-path> <release> <branch> <buildno> <os> <build-type>\n"

		exit

	else
		release=`echo ${1} | sed -e 's/^[ \t]*//'`
		branch=`echo ${2} | sed -e 's/^[ \t]*//'`
		buildNo=`echo ${3} | sed -e 's/^[ \t]*//'`
		os=`echo ${4} | sed -e 's/^[ \t]*//'`
		buildType=`echo ${5} | sed -e 's/^[ \t]*//'`
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
		echo -e "\tOS doesn't match with build argument OS: ${os}\n\n\tEXIT\n" >> ${buildLogFile}
		exit
	fi
	zmBuildDir=${repoDir}/zm-build
	mkdir -p ${zmBuildDir}/${arch}

	echo -e "Build script arguments: ${1} ${2} ${3} ${4} ${5}\n" >> ${buildLogFile}


	echo -e "Copying git repository manually (temporarily)" >> ${buildLogFile}
	cp -R ${gitRepoDir}/zm-build ${repoDir}
	cp -R ${gitRepoDir}/zm-aspell ${repoDir}


#-------------------- Build Packages ---------------------------

	declare -a packagesArray=(zimbra-spell)
	for i in "${packagesArray[@]}"
	do
		echo -e "\n\t-> Building ${i} package..." >> ${buildLogFile}
		bash "$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)/packages"/${i}.sh ${release} ${branch} ${buildNo} ${os} ${buildType} ${repoDir} ${arch}
	done