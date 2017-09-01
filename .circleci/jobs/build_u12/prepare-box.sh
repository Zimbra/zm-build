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
apt-get -qq install -y python-software-properties

# JOB
add-apt-repository -y ppa:openjdk-r/ppa
apt-get -qq update

apt-get -qq install -y git perl ruby
apt-get -qq install -y build-essential
apt-get -qq install -y openjdk-8-jdk ant ant-optional maven
apt-get -qq install -y debhelper
