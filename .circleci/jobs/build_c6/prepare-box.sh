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
yum install -y java-1.8.0-openjdk ant ant-junit
yum install -y rpm-build createrepo


(
   set -x
   set -e
   set -o pipefail

   cd /tmp
   wget http://mirror.metrocast.net/apache/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz
   tar -xf apache-maven-3.3.9-bin.tar.gz
   mv apache-maven-3.3.9 /opt
   echo 'export PATH="/opt/apache-maven-3.3.9/bin:$PATH"' | tee /etc/profile.d/maven.sh
)
