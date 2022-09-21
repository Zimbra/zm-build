#!/bin/bash
#
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016 Synacor, Inc.
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


if [ -f /etc/redhat-release ]; then
   i=`uname -i`
   if [[ "x$i" == "xx86_64" ]] || [[ "x$i" == "xppc64"* ]]; then
        i="_64"
  else
    i=""
  fi

  grep "Red Hat Enterprise Linux.*release 8" /etc/redhat-release > /dev/null 2>&1
  if [ $? = 0 ]; then
    echo "RHEL8${i}"
    exit 0
  fi
  grep "Red Hat Enterprise Linux.*release 7" /etc/redhat-release > /dev/null 2>&1
  if [ $? = 0 ]; then
    echo "RHEL7${i}"
    exit 0
  fi
  grep "Red Hat Enterprise Linux.*release 6" /etc/redhat-release > /dev/null 2>&1
  if [ $? = 0 ]; then
    echo "RHEL6${i}"
    exit 0
  fi

  grep "CentOS Linux release 8" /etc/redhat-release > /dev/null 2>&1
  if [ $? = 0 ]; then
    echo "RHEL8${i}"
    exit 0
  fi
  grep "CentOS Linux release 7" /etc/redhat-release > /dev/null 2>&1
  if [ $? = 0 ]; then
    echo "RHEL7${i}"
    exit 0
  fi
  grep "CentOS release 6" /etc/redhat-release > /dev/null 2>&1
  if [ $? = 0 ]; then
    echo "RHEL6${i}"
    exit 0
  fi

  grep "Rocky Linux release 8" /etc/redhat-release > /dev/null 2>&1
  if [ $? = 0 ]; then
    echo "RHEL8${i}"
    exit 0
  fi

  grep "Scientific Linux release 8" /etc/redhat-release > /dev/null 2>&1
  if [ $? = 0 ]; then
    echo "RHEL8${i}"
    exit 0
  fi
  grep "Scientific Linux release 7" /etc/redhat-release > /dev/null 2>&1
  if [ $? = 0 ]; then
    echo "RHEL7${i}"
    exit 0
  fi
  grep "Scientific Linux release 6" /etc/redhat-release > /dev/null 2>&1
  if [ $? = 0 ]; then
    echo "RHEL6${i}"
    exit 0
  fi

  grep "Fedora release 23" /etc/redhat-release >/dev/null 2>&1
  if [ $? = 0 ]; then
    echo "F23${i}"
    exit 0
  fi
  grep "Fedora release 22" /etc/redhat-release >/dev/null 2>&1
  if [ $? = 0 ]; then
    echo "F22${i}"
    exit 0
  fi

  grep "Red Hat Enterprise Linux.*release" /etc/redhat-release > /dev/null 2>&1
  if [ $? = 0 ]; then
    echo "RHELUNKNOWN${i}"
    exit 0
  fi
  grep "CentOS release" /etc/redhat-release > /dev/null 2>&1
  if [ $? = 0 ]; then
    echo "CentOSUNKNOWN${i}"
    exit 0
  fi
  grep "Rocky Linux release" /etc/redhat-release > /dev/null 2>&1
  if [ $? = 0 ]; then
    echo "RockyUNKNOWN${i}"
    exit 0
  fi
  grep "Fedora Core release" /etc/redhat-release > /dev/null 2>&1
  if [ $? = 0 ]; then
    echo "FCUNKNOWN${i}"
    exit 0
  fi
fi

if [ -f /etc/SuSE-release ]; then
  i=`uname -i`
   if [[ "x$i" == "xx86_64" ]] || [[ "x$i" == "xppc64"* ]]; then
    i="_64"
  else
    i=""
  fi

  grep "SUSE Linux Enterprise Server 11" /etc/SuSE-release >/dev/null 2>&1
  if [ $? = 0 ]; then
    echo "SLES11${i}"
    exit 0
  fi
  grep "SUSE Linux Enterprise Server 10" /etc/SuSE-release >/dev/null 2>&1
  if [ $? = 0 ]; then
    echo "SLES10${i}"
    exit 0
  fi
  grep "SUSE Linux Enterprise Server" /etc/SuSE-release >/dev/null 2>&1
  if [ $? = 0 ]; then
    echo "SLESUNKNOWN${i}"
    exit 0
  fi
  grep "openSUSE" /etc/SuSE-release > /dev/null 2>&1
  if [ $? = 0 ]; then
    echo "openSUSEUNKNOWN${i}"
    exit 0
  fi
fi

if [ -f /etc/lsb-release ]; then
  LSB="lsb_release"
  i=`dpkg --print-architecture`
  if [ "x$i" = "xamd64" ]; then
    i="_64"
  else
    i=""
  fi
  RELEASE=$($LSB -s -c)
  DISTRIBUTOR=$($LSB -s -i)
  if [ "$DISTRIBUTOR" = "Ubuntu" ]; then
    echo -n "UBUNTU"
    if [ "$RELEASE" = "precise" ]; then
      echo "12${i}"
      exit 0
    fi
    if [ "$RELEASE" = "trusty" ]; then
      echo "14${i}"
      exit 0
    fi
    if [ "$RELEASE" = "xenial" ]; then
      echo "16${i}"
      exit 0
    fi
    if [ "$RELEASE" = "bionic" ]; then
      echo "18${i}"
      exit 0
    fi
    if [ "$RELEASE" = "focal" ]; then
      echo "20${i}"
      exit 0
    fi
    echo "UNKNOWN${i}"
    exit 0
  fi
  if [ "$DISTRIBUTOR" = "Debian" ]; then
    echo -n "DEBIAN"
    if [ "$RELEASE" = "wheezy" ]; then
      echo "7${i}"
      exit 0
    fi
    if [ "$RELEASE" = "jessie" ]; then
      echo "8${i}"
      exit 0
    fi
    if [ "$RELEASE" = "stretch" ]; then
      echo "9${i}"
      exit 0
    fi
    echo "UNKNOWN${i}"
    exit 0
  fi
  if [ "$DISTRIBUTOR" = "Univention" ]; then
    echo -n "UCS"
    if [ "$RELEASE" = "Vahr" ]; then
      echo "4${i}"
      exit 0
    fi
    echo "UNKNOWN${i}"
    exit 0
  fi
fi

if [ -f /etc/debian_version ]; then
  echo "DEBIANUNKNOWN${i}"
  exit 0
fi

if [ -f /etc/mandriva-release ]; then
  echo "MANDRIVAUNKNOWN"
  exit 0
fi

if [ -f /etc/release ]; then
  egrep 'Solaris 10.*X86' /etc/release > /dev/null 2>&1
  if [ $? = 0 ]; then
    echo "SOLARISX86"
    exit 0
  fi
  echo "SOLARISUNKNOWN"
fi

a=`uname -a | awk '{print $1}'`
p=`uname -p`
if [ "x$a" = "xDarwin" ]; then
  v=`sw_vers | grep ^ProductVersion | awk '{print $NF}' | awk -F. '{print $1"."$2}'`
  if [ "x$v" = "x10.4" ]; then
    if [ "x$p" = "xi386" ]; then
      echo "MACOSXx86"
      exit 0
    fi

    if [ "x$p" = "xpowerpc" ]; then
      echo "MACOSX"
      exit 0
    fi
  else
    if [ "x$p" = "xi386" ]; then
      p=x86
    fi
    echo "MACOSX${p}_${v}"
    exit 0
  fi
fi

echo "UNKNOWN${i}"
exit 1
