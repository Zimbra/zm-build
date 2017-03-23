# zm-build

## Introduction

This repository contains the build script and supporting files required to create a [FOSS](https://en.wikipedia.org/wiki/Free_and_open-source_software) build of the [Zimbra Collaboration Suite](https://www.zimbra.com/). 

## Overview

* `build.pl` - Invoke this script to produce a build.  See the *Building* section 
  below for an example.
* `instructions/`
    * `FOSS_remote_list.pl` - Maps between remote label and URL
    * `FOSS_repo_list.pl` - Specifies which branches (or tags) are checked out to
      build each component repository.
    * `FOSS_staging_list.pl` - defines the staging order and details.

## Setup

### Ubuntu 16.04

The following steps assume that your are starting with a clean VM and are
logged in as a non-root user with `sudo` privileges.

    sudo apt-get update
    sudo apt-get install software-properties-common openjdk-8-jdk ant ruby git maven build-essential

### Ubuntu 14.04

The following steps assume that your are starting with a clean VM and are
logged in as a non-root user with `sudo` privileges.

    sudo apt-get install software-properties-common 
    sudo add-apt-repository ppa:openjdk-r/ppa
    sudo apt-get update
    sudo update-ca-certificates -f
    sudo apt-get install openjdk-8-jdk ant ruby git maven build-essential

### Ubuntu 12.04

    sudo apt-get install python-software-properties software-properties-common
    sudo add-apt-repository ppa:openjdk-r/ppa
    sudo apt-get update
    sudo update-ca-certificates -f
    sudo apt-get install openjdk-8-jdk ant ruby git maven build-essential zlib1g-dev

### CentOS 7

    sudo yum groupinstall 'Development Tools'
    sudo yum install java-1.8.0-openjdk ant ruby git maven cpan wget perl-IPC-Cmd

### CentOS 6

    sudo yum groupinstall 'Development Tools'
    sudo yum remove java-1.7.0-openjdk java-1.6.0-openjdk ant
    sudo yum install java-1.8.0-openjdk java-1.8.0-openjdk-devel ruby git cpan wget
    # install specific perl modules
    sudo cpan IPC::Cmd
    cd /tmp
    # install maven
    wget http://mirror.metrocast.net/apache/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz
    sudo tar -xf apache-maven-3.3.9-bin.tar.gz
    sudo mv apache-maven-3.3.9 /opt
    echo 'export PATH="/opt/apache-maven-3.3.9/bin:$PATH"' | sudo tee -a /etc/profile.d/maven.sh
    # install current version of ant
    wget https://www.apache.org/dist/ant/binaries/apache-ant-1.9.9-bin.zip
    sudo unzip apache-ant-1.9.9-bin.zip
    sudo mv apache-ant-1.9.9 /opt
    echo 'export PATH="/opt/apache-ant-1.9.9/bin:$PATH"' | sudo tee -a /etc/profile.d/ant.sh

## Building

Create a directory for your build and check-out the `zm-build` repository:

    mkdir installer-build
    cd installer-build
    git clone https://github.com/Zimbra/zm-build.git
    cd zm-build
    git checkout origin/develop

The `build.pl` command is used to build the product. Run it with the `-h` option for help:

    Usage: ./build.pl <options>
    Supported options:
       --build-no=i
       --build-ts=i
       --build-artifacts-base-dir=s
       --build-sources-base-dir=s
       --build-release=s
       --build-release-no=s
       --build-release-candidate=s
       --build-type=s
       --build-thirdparty-server=s
       --build-prod-flag!
       --build-debug-flag!
       --build-dev-tool-base-dir=s
       --interactive!
       --git-overrides=s%
       --git-default-tag=s
       --git-default-remote=s
       --git-default-branch=s
       --stop-after-checkout!

You _can_ specify all the options on the command-line, as follows:

    ./build.pl --build-no=1713 --build-ts=`date +'%Y%m%d%H%M%S'` \
      --build-release=JUDASPRIEST --build-release-no=8.7.6 \
      --build-release-candidate=GA --build-type=FOSS 
      --build-thirdparty-server=files.zimbra.com --no-interactive

The completed build will be archived into a `*.tgz` file that is stored in the appropriate platform and release-specific
subdirectory of the `BUILDS` directory.  The above command, run on an Ubuntu 16.04 machine, created the following:

    $HOME/installer_build/BUILDS/UBUNTU16_64/JUDASPRIEST-877/20170322153033_FOSS/zm-build/zcs-8.7.7_8.7.7_1713.UBUNTU16_64.20170322153033.tgz

You can also specify any or all of the required options by placing them in a file
called `config.build`.  This file should be at the top level of the `zm-build`
directory.  For example:

    BUILD_NO                    = 1713
    BUILD_RELEASE               = JUDASPRIEST
    BUILD_RELEASE_NO            = 8.7.6
    BUILD_RELEASE_CANDIDATE     = GA
    BUILD_TYPE                  = FOSS
    BUILD_THIRDPARTY_SERVER     = files.zimbra.com
    INTERACTIVE                 = 0

Then just run `./build.pl`.

The above command, run on a CentOS 7 machine with the options as shown in `config.build`, created the following:

    $HOME/installer-build/BUILDS/RHEL7_64/JUDASPRIEST-876/20170323061131_FOSS/zm-build/zcs-8.7.6_GA_1713.RHEL7_64.20170323061131.tgz
