#!/bin/bash

set -x
set -e
set -o pipefail

source .circleci/get-env.sh;

for i in ../BUILDS/*
do
   if [ -d "$i" ]
   then
      aws s3 sync "$i" "s3://$ZIMBRA_CI_DEPLOY_HOSTNAME/$ZIMBRA_CI_DEPLOY_PATH/$(basename "$i")" --acl public-read --region us-east-1
   fi
done
