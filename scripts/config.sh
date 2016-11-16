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

# Common configuration parameters for build script


#-------------------- Global Configuration ---------------------------

	gitRepoDir=/home/zimbra/git
	gitRepoURL=stash.corp.synacor.com:7999

	buildsDir=/home/build/builds
	packagesDir=`pwd`/packages

	releaseArray=(JUDASPRIEST-880)
	osArray=(UBUNTU16_64 UBUNTU14_64 UBUNTU12_64 RHEL7_64 RHEL6_64)
	buildTypeArray=(NETWORK FOSS)

	currentYear=`date +%Y`
	currentMonth=`date +%m`
	currentDate=`date +%d`
	currentTime=`date +%T`
	buildTimeStamp=`echo ${currentYear}${currentMonth}${currentDate}${currentTime} | sed "s/\://g"`


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #