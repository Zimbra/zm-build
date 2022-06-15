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

## Setup with Zimbra Development Images (used for building)

* Set up docker on your box
* You can then pull and run using development images (built from Zimbra/zm-base-os.git)
* In case you need to customize the images for your purposes, you could maintain your own Dockerfile such as this:

        $ cat Dockerfile
        FROM zimbra/zm-base-os:devcore-ubuntu-16.04
        RUN sudo apt-get install emacs my-special-tool etc..
        RUN ...

        $ docker build -t myuser/my-devcore-ubuntu-16 .
        $ docker run -it myuser/my-devcore-ubuntu-16 bash

### Ubuntu 16.04

    docker run -it zimbra/zm-base-os:devcore-ubuntu-16.04 bash

### Ubuntu 14.04

    docker run -it zimbra/zm-base-os:devcore-ubuntu-14.04 bash

### Ubuntu 12.04

    docker run -it zimbra/zm-base-os:devcore-ubuntu-12.04 bash

### CentOS 7

    docker run -it zimbra/zm-base-os:devcore-centos-7 bash

### CentOS 6

    docker run -it zimbra/zm-base-os:devcore-centos-6 bash

    # some tools are installed inside /home/build/.zm-dev-tools/, zm-build automatically sources this path.

## Setup (traditional)

### Ubuntu 16.04

The following steps assume that your are starting with a clean VM and are
logged in as a non-root user with `sudo` privileges.

    sudo apt-get update
    sudo apt-get install software-properties-common openjdk-8-jdk ant ant-optional ant-contrib ruby git maven build-essential debhelper

### Ubuntu 14.04

The following steps assume that your are starting with a clean VM and are
logged in as a non-root user with `sudo` privileges.

    sudo apt-get install software-properties-common 
    sudo add-apt-repository ppa:openjdk-r/ppa
    sudo apt-get update
    sudo update-ca-certificates -f
    sudo apt-get install openjdk-8-jdk ant ant-optional ant-contrib ruby git maven build-essential

### Ubuntu 12.04

    sudo apt-get install python-software-properties software-properties-common
    sudo add-apt-repository ppa:openjdk-r/ppa
    sudo apt-get update
    sudo update-ca-certificates -f
    sudo apt-get install openjdk-8-jdk ant ant-optional ant-contrib ruby git maven build-essential zlib1g-dev

### CentOS 7

    sudo yum groupinstall 'Development Tools'
    sudo yum install java-1.8.0-openjdk ant ant-junit ruby git maven cpan wget perl-IPC-Cmd

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

To build a specific patch example 9.0.0.p25 run the following: 

    mkdir installer-build
    cd installer-build
    git clone --depth 1 --branch 9.0.0.p25 git@github.com:Zimbra/zm-build.git
    cd zm-build
    ENV_CACHE_CLEAR_FLAG=true ./build.pl --ant-options -DskipTests=true --git-default-tag=9.0.0.p25,9.0.0.p24.1,9.0.0.p24,9.0.0.p23,9.0.0.p22,9.0.0.p21,9.0.0.p20,9.0.0.p19,9.0.0.p18,9.0.0.p17,9.0.0.p16,9.0.0.p15,9.0.0.p14,9.0.0.p13,9.0.0.p12,9.0.0.p11,9.0.0.p10,9.0.0.p9,9.0.0.p8,9.0.0.p7,9.0.0.p6.1,9.0.0.p6,9.0.0.p5,9.0.0.p4,9.0.0.p3,9.0.0.p2,9.0.0.p1,9.0.0 --build-release-no=9.0.0 --build-type=FOSS --build-release=NIKOLATESLA --build-release-candidate=GA --build-thirdparty-server=files.zimbra.com --build-no=3969 --no-interactive

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
      --build-release-candidate=GA --build-type=FOSS \
      --build-thirdparty-server=files.zimbra.com --no-interactive

The completed build will be archived into a `*.tgz` file that is stored in the appropriate platform and release-specific
subdirectory of the `BUILDS` directory.  The above command, run on an Ubuntu 16.04 machine, created the following:

    $HOME/installer_build/BUILDS/UBUNTU16_64/JUDASPRIEST-876/20170322153033_FOSS/zm-build/zcs-8.7.6_1713.UBUNTU16_64.20170322153033.tgz

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

# Development

## Setup

The following is a walk-through of the basic steps required to do ZCS development.  The first step is to simply install a current FOSS build on the machine that you wish to use.  The instructions that follow assume that this has been done.


1. Create `/home/zimbra` and make `zimbra` the owner.

		sudo mkdir /home/zimbra
		sudo chown zimbra:zimbra /home/zimbra

2. Install  `git`, `ant`, and `ant-contrib` by whichever method is appropriate for your distro:

		sudo apt-get install git ant ant-contrib

	or

		sudo yum install git ant ant-contrib

3. Configure `/opt/zimbra/.ssh/config` to use your ssh key for the git remotes that you need to access.
4. Perform the following edits on `/opt/zimbra/.bash_profile`
   * Comment-out `export LANG=C` and `export LC_ALL=C`.
   * Add export `LANG=en_US.UTF-8`
   * Add export `ANT_OPTS=-Ddev.home=/home/zimbra`
5. Change permissions on files and folders that you will be updating; e.g.,

		sudo chmod -R o+w /opt/zimbra/lib/
		sudo chmod -R o+w /opt/zimbra/jetty/
		sudo chown zimbra:zimbra /opt/zimbra
		
	**Note:** If you run `zmfixperms`, some of these permissions will be overwritten.

6. Add file `/opt/zimbra/.gitconfig` and update as needed.  At a minimum:

		[user]
			email = YOUR-EMAIL-ADDRESS
			name = YOUR-FIRST-AND-LAST-NAME

7. As the `zimbra` user, create a base directory under `/home/zimbra` from which to work.

		cd /home/zimbra
		mkdir zcs
		cd zcs

8. Now you can clone any repositories that you require and get to work.

## Email Delivery

If you want email delivery to work, set up a DNS server on your host
machine or another VM and configure `zimbraDNSMasterIP` to point to it.
To configure `zimbraDNSMasterIP`, do the following as the `zimbra` user:

	zmprov ms `zmhostname` zimbraDNSMasterIP DNS-SERVER-IP-ADDRESS

You may receive the following error when trying to send email:

	No SMTP hosts available for domain

If this occurs, you need to manually configure `zimbraSmtpHostname` for your domain(s).
To configure `zimbraSmtpHostname`, do the following as the `zimbra` user:

	zmprov md DOMAIN-NAME zimbraSmtpHostname `zmhostname`

## zm-mailbox example

As the `zimbra` user, `cd /home/zimbra/zcs`.  Then clone the `zm-mailbox` repository from github

	git clone git@github.com:Zimbra/zm-mailbox.git

The following sub-directories `zm-mailbox` build and deploy separately:

	client
	common
	milter-conf
	native
	soap
	store
	store-conf

The top-level `build.xml` is used by the `zm-build` scripts to create
an installer package.  You will not use that for normal development.  There are build-order
dependencies between the above-listed deployment targets.  These can be determined by 
inspection of the `ivy.xml` files within each subdirectory.

For example:

	grep 'org="zimbra"' store/ivy.xml

	<dependency org="zimbra" name="zm-common" rev="latest.integration"/>
	<dependency org="zimbra" name="zm-soap" rev="latest.integration"/>
	<dependency org="zimbra" name="zm-client" rev="latest.integration"/>
	<dependency org="zimbra" name="zm-native" rev="latest.integration"/>

Here you can see that the deployment target, `zm-store` (the `store` 
subdirectory), depends upon `common`, `soap`, `client`, and `native`.  Here is the current
ordering dependencies among all of the `zm-mailbox` deployment targets. The higher-numbered 
deployment targets depend upon the lower-numbered ones.  Note that `milter-conf` and 
`store-conf` have no cross-dependencies.

1. `native`
2. `common`
3. `soap`
4. `client`
5. `store`

So, from the `native` sub-directory:

	ant -Dzimbra.buildinfo.version=8.7.6_GA clean compile publish-local deploy
	
Comments:

- The requirement to include `-Dzimbra.buildinfo.version=8.7.6_GA` to ant is due to a change
  that was made when the FOSS code was moved to GitHub.  You can also just add that option
  to your `ANT_OPTS` enviroment variable that you defined in `$HOME/.bash_profile` as follows:
  
	  export ANT_OPTS="-Ddev.home=/home/zimbra -Dzimbra.buildinfo.version=8.7.6_GA"
	  
  If you do that, then you can omit that `-D...` argument to the `ant` command and future
  examples will reflect that.
- The `publish-local` target adds the artifact to `/home/zimbra/.zcs-deps`, which is 
  included in the Ivy resolution path.
- The `deploy` target installs the artifact to its run-time location and restarts the appropriate
  service(s). This will allow you to test your changes.

Then, from the `common`, `soap`, `client`, and `store` sub-directories (in that order):

	ant clean compile publish-local deploy

## Adding a new LDAP Attribute

**WARNING:It is absolutely imperative to avoid duplicate IDs for attributes.
Unfortunately, that currently isn't a trivial thing to do.  Need to check
Zimbra 8 and Zimbra X along with all development branches.
If customers get different setups using different IDs, this makes future upgrade
scenarios a complete nightmare**

Start by cloning _both_ the `zm-ldap-utilites` and the `zm-mailbox` repositories from GitHub.
Check out the appropriate branch of each. Then proceed as follows:

* Add your new attribute to `zm-mailbox/store/conf/attrs/zimbra-attrs.xml`
* From `zm-common/store` invoke the following command:

		ant generate-getters

* Do the following as `root`:

		chmod -R o+w /opt/zimbra/common/etc/openldap/schema
		chmod o+w /opt/zimbra/conf/zimbra.ldif
		chmod +w /opt/zimbra/conf/attrs/zimbra-attrs.xml
		chmod -R o+w /opt/zimbra/common/etc/openldap/zimbra

* Back as the `zimbra` user, invoke the following command from `zm-mailbox/common`:

		ant deploy publish-local

* Then from the `zm-mailbox/store` directory:

		ant deploy update-ldap-schema


Your ZCS development server should now be running with the new attribute(s).  You can test that
by querying them and modifying them with `zmprov`.  You can `git add ...` and `git commit`
your changes now.


