#!/bin/bash 


BUILDROOT=$1
RELEASETAG=$2

cd $BUILDROOT
cvc checkout group-dist
cd group-dist
cvc cook group-dist
cd $BUILDROOT

TROVE=`conary rq --full-versions --flavors group-dist=/zimbra.rpath.org@rpl:1//zimbra.liquidsys.com@zimbra:devel`
BUILD=`rbuilder build-create zimbra "$TROVE" installable_iso --wait | awk -F= '{print $NF}'`
if [ $? -eq 0 ]; then
  ISO=`rbuilder build-url $BUILD | head -1`
  wget -o $BUILDROOT/i386/zcs-${RELEASETAG}.iso $ISO
fi
BUILD=`rbuilder build-create zimbra "$TROVE" vmware_image --wait | awk -F= '{print $NF}'`
if [ $? -eq 0 ]; then
  ISO=`rbuilder build-url $BUILD | head -1`
  wget -o $BUILDROOT/i386/zcs-${RELEASETAG}-vmware.zip $ISO
fi
