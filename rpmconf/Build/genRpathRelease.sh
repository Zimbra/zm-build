#!/bin/bash 


LOCAL=0
LABEL=zimbra.liquidsys.com@zimbra:devel

if [ "$1" = "--local" ]; then
    LOCAL=1
    shift
elif [ "$1" = "--label" ]; then
  LABEL=$2
  shift; shift;
fi

BUILDROOT=$1
RELEASETAG=$4

cd $BUILDROOT
cvc checkout group-dist=$LABEL
cd group-dist
cvc cook group-dist=$LABEL --debug
if [ $? -ne 0 ]; then
  echo "cvc cook group-dist failed"
  exit 1
fi

cd $BUILDROOT

TROVE=`conary rq --full-versions --flavors group-dist=/zimbra.rpath.org@rpl:1//$LABEL`
echo "Building ISO Image $BUILDROOT/zcs-${RELEASETAG}.iso..."
BUILD=`rbuilder build-create zimbra "$TROVE" installable_iso --wait | awk -F= '{print $NF}'`
if [ $? -eq 0 ]; then
  echo "Getting URL for Build $BUILD"
  ISO=`rbuilder build-url $BUILD | head -1`
  echo "Retrieving image from $ISO"
  wget -qO $BUILDROOT/zcs-${RELEASETAG}.iso $ISO
  ln -s $BUILDROOT/zcs-${RELEASETAG}.iso $BUILDROOT/zcs.iso
fi

echo "Building VMWare Image $BUILDROOT/zcs-${RELEASETAG}-vmware.zip..."
BUILD=`rbuilder build-create zimbra "$TROVE" vmware_image --wait --option 'vmMemory 512' --option 'freespace 500'  | awk -F= '{print $NF}'`
if [ $? -eq 0 ]; then
  echo "Getting URL for Build $BUILD"
  ISO=`rbuilder build-url $BUILD | head -1`
  echo "Retrieving image from $ISO"
  wget -qO $BUILDROOT/zcs-${RELEASETAG}-vmware.zip $ISO
  ln -s $BUILDROOT/zcs-${RELEASETAG}-vmware.zip $BUILDROOT/zcs-vmware.zip
fi
