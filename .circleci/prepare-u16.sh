#!/bin/bash

set -x
set -e
set -o pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get -qq update

# SYSTEM TOOLS
apt-get -qq install -y apt-utils
apt-get -qq install -y ca-certificates tzdata
apt-get -qq install -y curl wget jq
apt-get -qq install -y awscli vim

# DEVELOPMENT TOOLS
apt-get -qq install -y git perl ruby
apt-get -qq install -y build-essential debhelper software-properties-common
apt-get -qq install -y openjdk-8-jdk ant ant-optional maven
