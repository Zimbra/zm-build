#!/bin/bash
#
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2009, 2010, 2011, 2013, 2014, 2015, 2016, 2017, 2018 Synacor, Inc.
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

BUILD_DIR=${repoDir}/zm-build
PATCH_VERSION=${releaseNo}_${releaseCandidate}_${buildNo}
PATCH_NAME=zcs-patch-${PATCH_VERSION}

cd ${BUILD_DIR}

# Download perl libraries required for patch script.
wget -O perllib.tgz "https://files.zimbra.com/repository/perl-libs/${os}/perllib.tgz"
tar -xzf perllib.tgz -C lib

perl ${BUILD_DIR}/rpmconf/Patch/bin/zmpatch.pl -c ${BUILD_DIR}/rpmconf/Patch/conf/zmpatch.xml \
 -build -target ${BUILD_DIR}/${PATCH_NAME} -version ${PATCH_VERSION} -source ${BUILD_DIR}/.. -v -v


##########################################

tar czf ${PATCH_NAME}.tgz  ${PATCH_NAME}

echo "ZCS patch completed: ${repoDir}/zm-build/${PATCH_NAME}.tgz"
