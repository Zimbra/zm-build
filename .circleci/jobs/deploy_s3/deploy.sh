#!/bin/bash

set -euxo pipefail

for i in ../BUILDS/*
do
   if [ -d "$i" ]
   then
      aws s3 sync "$i" "s3://files.zimbra.com/dev-releases/$(basename "$i")" --acl public-read --region us-east-1
   fi
done
