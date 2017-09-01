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
yum install -y java-1.8.0-openjdk ant ant-junit maven
yum install -y rpm-build createrepo
