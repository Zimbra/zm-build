#!/bin/bash

set -x
set -e
set -o pipefail

yum clean all

# SYSTEM
yum install -y curl wget which

# JOB
yum install -y git perl ruby
yum install -y perl-Data-Dumper perl-IPC-Cmd
yum install -y gcc gcc-c++ make
yum install -y java-1.8.0-openjdk-devel
yum install -y rpm-build createrepo

for url in "http://mirror.metrocast.net/apache/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz" \
           "https://www.apache.org/dist/ant/binaries/apache-ant-1.9.9-bin.tar.gz"
do
   file="/tmp/$(basename "$url")"
   wget "$url" -O "$file"
   mkdir -p ~/.zm-dev-tools/
   tar -C ~/.zm-dev-tools/ -xf "$file"
done
