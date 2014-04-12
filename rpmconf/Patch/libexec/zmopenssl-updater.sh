#!/bin/bash

if [ x`whoami` != xroot ]; then
  echo Error: must be run as root user
  exit 1
fi

SSL[0]='1.0.1d'
SSL[1]='1.0.1e'
SSL[2]='1.0.1e'
SSL[3]='1.0.1e'
SSL[4]='1.0.1f'
VERSION=`su - zimbra -c 'zmcontrol -v'`
if [[ $VERSION == *ZCA* ]]; then
  VERSION=$(echo $VERSION|tr -d '\n')
  VERSION=$(expr "$VERSION" : '.*\(ZCS Build.*\)')
  VERSION=$(echo ${VERSION} | cut -d' ' -f3)
else
  VERSION=$(echo ${VERSION} | cut -d' ' -f2)
  VERSION=$(echo ${VERSION} | sed "s/_.*//")
fi
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

if [ $PATCH -lt 3 ]; then
   echo "Must be running 8.0.3 or later"
   exit 1
fi

if [ $PATCH -gt 7 ]; then
  echo "Must be running 8.0.7 or earlier"
  exit 1
fi

ARPATCH=$(expr $PATCH - 3)
SSL_VERSION=${SSL[$ARPATCH]}

if [ ! -d "/opt/zimbra/openssl-${SSL_VERSION}" ]; then
  echo "Error: Unable to patch this release"
  exit 1
fi

EGREP=`which egrep`
if [ x$EGREP = "x" ]; then
  echo "Error: egrep not in path"
  exit 1
fi

$EGREP dtls1_process_heartbeat /opt/zimbra/openssl-${SSL_VERSION}/lib/libssl.so.1.0.0 >/dev/null
RC=$?

if [ $RC -eq 1 ]; then
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
  if [ -d openssl/$PLAT ]; then
    rm -rf openssl/$PLAT
  fi
fi

mkdir -p openssl/$PLAT
cd openssl/$PLAT

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
  echo "Downloading patched openssl"
  wget http://files.zimbra.com/downloads/8.0.${PATCH}_GA/openssl/$PLAT/openssl-${SSL_VERSION}.tgz >/dev/null 2>&1
  RC=$?
  
  if [ $RC -ne 0 ]; then
    echo "Error: Unable to download openssl"
    exit 1
  fi
  
  wget http://files.zimbra.com/downloads/8.0.${PATCH}_GA/openssl/$PLAT/openssl-${SSL_VERSION}.tgz.md5sum >/dev/null 2>&1
  RC=$?
  
  if [ $RC -ne 0 ]; then
    echo "Error: Unable to download md5sum"
    exit 1
  fi
fi

echo -n "Validating patched openssl: "
DOWNLOAD_SUM=`$MD5SUM openssl-${SSL_VERSION}.tgz`
GOOD_SUM=`cat openssl-${SSL_VERSION}.tgz.md5sum`

if [ "$GOOD_SUM" = "$DOWNLOAD_SUM" ]; then
  echo "success"
else
  echo "ERROR: MD5SUM mismatch"
  echo "Expected $GOOD_SUM"
  echo "Got $DOWNLOAD_SUM"
  exit 1
fi

echo -n "Backing up old openssl: "
cd /opt/zimbra
mv openssl-${SSL_VERSION} openssl-${SSL_VERSION}.brokenheart.$$
echo "complete"

echo -n "Installing patched openssl: "
tar xfz /tmp/openssl/$PLAT/openssl-${SSL_VERSION}.tgz
echo "complete"

echo "OpenSSL patch process complete."
echo "Please restart Zimbra Collaboration Suite as the Zimbra user via zmcontrol restart"
