#!/bin/bash

set -x
set -e
set -o pipefail

export DEBIAN_FRONTEND=noninteractive

# SYSTEM
apt-get -qq update
apt-get -qq install -y apt-utils
apt-get -qq install -y ca-certificates tzdata
apt-get -qq install -y curl wget
apt-get -qq install -y software-properties-common

# JOB
apt-get -qq install -y awscli
