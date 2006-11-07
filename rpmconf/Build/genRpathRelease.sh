#!/bin/bash 



LABEL=zimbra.liquidsys.com@zimbra:devel
if [ "$1" = "--label" ]; then
  LABEL=$2
  shift; shift;
fi

BUILDROOT=$1
RELEASETAG=$2

cd $BUILDROOT
cvc checkout group-dist
cd group-dist
cvc cook group-dist --debug
if [ $? -ne 0 ]; then
  echo "cvc cook group-dist failed"
  exit 1
fi

cd $BUILDROOT

TROVE=`conary rq --full-versions --flavors group-dist=/zimbra.rpath.org@rpl:1//$LABEL`
echo "Building ISO Image $BUILDROOT/i386/zcs-${RELEASETAG}.iso..."
BUILD=`rbuilder build-create zimbra "$TROVE" installable_iso --wait | awk -F= '{print $NF}'`
if [ $? -eq 0 ]; then
  ISO=`rbuilder build-url $BUILD | head -1`
  wget -qO $BUILDROOT/i386/zcs-${RELEASETAG}.iso $ISO
  ln -s $BUILDROOT/i386/zcs-${RELEASETAG}.iso $BUILDROOT/i386/zcs.iso
fi
echo "Building VMWare Image $BUILDROOT/i386/zcs-${RELEASETAG}-vmware.zip...""
BUILD=`rbuilder build-create zimbra "$TROVE" vmware_image --wait | awk -F= '{print $NF}'`
if [ $? -eq 0 ]; then
  ISO=`rbuilder build-url $BUILD | head -1`
  wget -qO $BUILDROOT/i386/zcs-${RELEASETAG}-vmware.zip $ISO
  ln -s $BUILDROOT/i386/zcs-${RELEASETAG}-vmware.zip $BUILDROOT/i386/zcs-vmware.zip
fi
