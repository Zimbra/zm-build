#!/bin/bash

if [ x`whoami` != xroot ]; then
  echo Error: must be run as root user
  exit 1
fi

VERSION=`su - zimbra -c 'zmcontrol -v'`
VERSION=$(echo ${VERSION} | cut -d' ' -f2)
VERSION=$(echo ${VERSION} | sed "s/_.*//")
MAJOR=$(echo ${VERSION} | cut -d'.' -f1)
MINOR=$(echo ${VERSION} | cut -d'.' -f2)
PATCH=$(echo ${VERSION} | cut -d'.' -f3)

if [ $MAJOR -ne 8 ]; then
  echo "Unsupported MAJOR version $MAJOR"
  exit 1
fi

if [ $MINOR -ne 0 ]; then
  echo "Unsupported MINOR version $MINOR"
  exit 1
fi

if [ $PATCH -lt 7 ]; then
   echo "Must be running 8.0.7"
   exit 1
fi

if [ $PATCH -gt 7 ]; then
  echo "Must be running 8.0.7"
  exit 1
fi

CURL_VERSION=7.35.0

if [ ! -d "/opt/zimbra/curl-${CURL_VERSION}" ]; then
  echo "Error: Unable to patch this release"
  exit 1
fi

EGREP=`which egrep`
if [ x$EGREP = "x" ]; then
  echo "Error: egrep not in path"
  exit 1
fi

$EGREP 7.36.0 /opt/zimbra/curl-${CURL_VERSION}/bin/curl >/dev/null
RC=$?

if [ $RC -eq 0 ]; then
  echo "Error: Already patched"
  exit 1
fi

ONLINE=1
if [ x"$1" = "x-o" -o x"$1" = "x--offline" ]; then
  ONLINE=0
fi

cd /tmp
PLAT=`/bin/sh /opt/zimbra/libexec/get_plat_tag.sh`

if [ $ONLINE -eq 1 ]; then
  if [ -d curl/$PLAT ]; then
    rm -rf curl/$PLAT
  fi
fi

mkdir -p curl/$PLAT
cd curl/$PLAT

if [ $ONLINE -eq 1 ]; then
  WGET=`which wget`
  if [ x"$WGET" = "x" ]; then
    echo "Error: wget not in path"
    exit 1
  fi
fi

MD5SUM=`which md5sum`
if [ x"$MD5SUM" = "x" ]; then
  echo "Error: md5sum not in path"
  exit 1
fi

if [ $ONLINE -eq 1 ]; then
  echo "Downloading patched curl"
  wget http://files.zimbra.com/downloads/8.0.${PATCH}_GA/curl/$PLAT/curl-${CURL_VERSION}.tgz >/dev/null 2>&1
  RC=$?
  
  if [ $RC -ne 0 ]; then
    echo "Error: Unable to download curl"
    exit 1
  fi
  
  wget http://files.zimbra.com/downloads/8.0.${PATCH}_GA/curl/$PLAT/curl-${CURL_VERSION}.tgz.md5sum >/dev/null 2>&1
  RC=$?
  
  if [ $RC -ne 0 ]; then
    echo "Error: Unable to download md5sum"
    exit 1
  fi
fi

echo -n "Validating patched curl: "
DOWNLOAD_SUM=`$MD5SUM curl-${CURL_VERSION}.tgz`
GOOD_SUM=`cat curl-${CURL_VERSION}.tgz.md5sum`

if [ "$GOOD_SUM" = "$DOWNLOAD_SUM" ]; then
  echo "success"
else
  echo "ERROR: MD5SUM mismatch"
  echo "Expected $GOOD_SUM"
  echo "Got $DOWNLOAD_SUM"
  exit 1
fi

echo -n "Backing up old curl: "
cd /opt/zimbra
mv curl-${CURL_VERSION} curl-${CURL_VERSION}.sslprotocol.$$
echo "complete"

echo -n "Installing patched curl: "
tar xfz /tmp/curl/$PLAT/curl-${CURL_VERSION}.tgz
echo "complete"

echo "Curl patch process complete."
echo "Please restart Zimbra Collaboration Suite as the Zimbra user via zmcontrol restart"
