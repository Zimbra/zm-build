#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd);
CIRCLE_DIR=$(dirname "$(dirname "$SCRIPT_DIR")")

usage()
{
   echo "Usage: $0 -o <upgrade|install> -t <u16|u14|u12|r7|r6> -h <ssh-ec2-host> -u <ssh-ec2-user> -a <admin-pass-to-set>" 1>&2;
   echo 1>&2;
   echo "Example:" 1>&2;
   echo "   $0 -o upgrade -t u16 -h ec2-xx-xx-xx-xx.us-east-2.compute.amazonaws.com -u ubuntu -a admin123" 1>&2;
   exit 1
}

#######################################################################
##### PARSE ARGS, SANITIZE #####
#######################################################################

set +u
while getopts "o:t:h:u:a:" cur_opt; do
    case "${cur_opt}" in
        o)
            OPERATION="${OPTARG}"
            if [ "$OPERATION" != "upgrade" ] && [ "$OPERATION" != "install" ]
            then
	       usage
            fi
            ;;
        t)
            PKG_OS_TAG=${OPTARG}
            case "$PKG_OS_TAG" in
               u16) DIR=$(echo $CIRCLE_DIR/../../BUILDS/UBUNTU16_64* | head -1); ;;
               u14) DIR=$(echo $CIRCLE_DIR/../../BUILDS/UBUNTU14_64* | head -1); ;;
               u12) DIR=$(echo $CIRCLE_DIR/../../BUILDS/UBUNTU12_64* | head -1); ;;
                r7) DIR=$(echo $CIRCLE_DIR/../../BUILDS/RHEL7_64* | head -1); ;;
                r6) DIR=$(echo $CIRCLE_DIR/../../BUILDS/RHEL6_64* | head -1); ;;
                *) usage; ;;
            esac
            ;;
        h)
            MY_SSH_HOST=${OPTARG}
            ;;
        u)
            MY_SSH_USER=${OPTARG}
            ;;
        a)
            MY_ADMIN_PASS=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "$MY_SSH_USER" ] || [ -z "$MY_SSH_HOST" ] || [ -z "$MY_ADMIN_PASS" ] || [ -z "$PKG_OS_TAG" ]
then
   usage;
fi

if [ ! -f "$CIRCLE_DIR/config.yml" ]
then
   echo "Rerun from within .circleci directory";
   exit 1
fi

if [ ! -d "$DIR" ]
then
   echo "Could not find the BUILD";
   exit 1;
fi
set -u

##### END GETOPT #####
#######################################################################


#######################################################################
##### RSYNC #####
#######################################################################

SSH_OPTS=(
   "-o" "UserKnownHostsFile=/dev/null"
   "-o" "StrictHostKeyChecking=no"
   "-o" "CheckHostIP=no"
   "-o" "ServerAliveInterval=100"
)

Rsync()
{
   rsync -e "ssh ${SSH_OPTS[*]}" "$@"
}

Ssh()
{
   ssh "${SSH_OPTS[@]}" "$@"
}

#Rsync --delete -avz $CIRCLE_DIR/../zm-build "$MY_SSH_USER@$MY_SSH_HOST:"
Rsync --delete -avz "$DIR/" "$MY_SSH_USER@$MY_SSH_HOST:BUILD/"
Rsync $CIRCLE_DIR/jobs/deploy_ec2/install.conf.in "$MY_SSH_USER@$MY_SSH_HOST:BUILD/install.conf.in"
Rsync $CIRCLE_DIR/jobs/deploy_ec2/upgrade.conf.in "$MY_SSH_USER@$MY_SSH_HOST:BUILD/upgrade.conf.in"

##### END RSYNC #####
#######################################################################


#######################################################################
##### FORWARD SCRIPT TO EXECUTE #####
#######################################################################

Ssh "$MY_SSH_USER@$MY_SSH_HOST" -- tee /tmp/injected_bash_script.sh <<"SCRIPT_EOM"
#!/bin/bash

[ -z "$DOMAIN_NAME" ] && echo "DOMAIN_NAME is not defined" && exit 1;
[ -z "$ADMIN_PASS"  ] && echo "ADMIN_PASS is not defined"  && exit 1;
[ -z "$OPERATION"   ] && echo "OPERATION is not defined"   && exit 1;
[ -z "$PKG_OS_TAG"  ] && echo "PKG_OS_TAG is not defined"  && exit 1;

set -euxo pipefail

setUp()
{
   echo -----------------------------------
   echo System Setup specific to EC2
   echo -----------------------------------

   [ -f /etc/hosts.orig ] || sudo cp /etc/hosts /etc/hosts.orig
   [ -f /etc/resolv.conf.orig ] || sudo cp /etc/resolv.conf /etc/resolv.conf.orig
   EC2_IP=$(hostname      | sed -e 's/[.\s].*$//' -e 's/^ip-//' -e 's/[-]/./g')
   EC2_RESOLVE=$(hostname | sed -e 's/[.\s].*$//' -e 's/^ip-//' -e 's/[-]/./g' -e 's/[.][0-9]*[.][0-9]*$/.0.2/')
   sudo sed -i -e "\$a$EC2_IP $(hostname -f) $(hostname)" -e "/ip-/ { /$(hostname)/d; }" /etc/hosts
   sudo sed -i -e "/^search/i\\nameserver $EC2_RESOLVE\nnameserver 8.8.8.8" -e "/nameserver 8.8.8.8/d" -e "/nameserver $EC2_RESOLVE/d" /etc/resolv.conf

   echo -----------------------------------
   echo System Cleanup
   echo -----------------------------------

   set +e;
   sudo killall master zmstat-fd
   sudo killall -u zimbra
   sudo killall -u postfix
   sudo pkill -f 'amavi[s]'
   sleep 10
   sudo killall -9 master zmstat-fd
   sudo killall -9 -u zimbra
   sudo killall -9 -u postfix
   sudo pkill -9 -f 'amavi[s]'
   sleep 10
   [[ "$PKG_OS_TAG" =~ u* ]] && sudo apt-get remove --purge -y zimbra-*
   [[ "$PKG_OS_TAG" =~ r* ]] && sudo yum erase -y zimbra-*
   sudo rm -rf /opt/zimbra

   [[ "$PKG_OS_TAG" =~ u* ]] && sudo apt-get install -y perl
   [[ "$PKG_OS_TAG" =~ r* ]] && sudo yum install -y perl
   if [[ "$PKG_OS_TAG" =~ r6 ]]
   then
      if [ ! -f /usr/lib/python2.6/site-packages/yum/__init__.py.patched ]
      then
         #We are running into a curious yum bug - See https://bugzilla.redhat.com/show_bug.cgi?id=993567

         sudo yum -y install wget patch
         sudo wget http://s3.amazonaws.com/files.zimbra.com/dev-releases/hold/r6-yum-patch/yum.patch -O ~/yum.patch
         sudo cp /usr/lib/python2.6/site-packages/yum/__init__.py{,.orig}
         sudo patch -p0 < ~/yum.patch
         sudo cp /usr/lib/python2.6/site-packages/yum/__init__.py{,.patched}
      fi
   fi
   echo
}

buildCleanUp()
{
   echo -----------------------------------
   echo Build Cleanup, Uncompress new tarball
   echo -----------------------------------

   sudo rm -rf ~/WDIR
   mkdir ~/WDIR
   tar -C ~/WDIR -xzf BUILD/zcs-*.tgz
}

prepareConfig()
{
   echo -----------------------------------
   echo Create install configuration
   echo -----------------------------------

   HOSTNAME="$(hostname --fqdn)"
   RESOLVE="$(cat /etc/resolv.conf | awk '/^\s*nameserver/ { print $2; }' | grep -v ^127 | head -1)"
   sed -e "s/template_resolv/$RESOLVE/" \
       -e "s/template_hostname/$HOSTNAME/" \
       -e "s/template_domainname/$DOMAIN_NAME/" \
       -e "s/template_admin_pass/$ADMIN_PASS/g" \
   ~/BUILD/install.conf.in > ~/WDIR/install.conf
   cat ~/BUILD/upgrade.conf.in > ~/WDIR/upgrade.conf
}

updatePackages()
{
   echo -----------------------------------
   echo Setup local archives
   echo -----------------------------------

   if [[ "$PKG_OS_TAG" =~ u ]]
   then
      sudo rm -f /etc/apt/sources.list.d/zimbra-*.list

      echo "deb [trusted=yes] file://$(echo $HOME/BUILD/archives/*/$PKG_OS_TAG) ./"                                                           | sudo tee -a /etc/apt/sources.list.d/zimbra-local.list
      echo "deb [trusted=yes] https://files.zimbra.com/dev-releases/hold/Zimbra/zm-zextras/develop-52/archives/zimbra-zextras/$PKG_OS_TAG ./" | sudo tee -a /etc/apt/sources.list.d/zimbra-zextras.list
      echo "deb [trusted=yes] https://files.zimbra.com/dev-releases/hold/Zimbra/zm-timezones/develop-35/archives/zimbra-foss/$PKG_OS_TAG  ./" | sudo tee -a /etc/apt/sources.list.d/zimbra-foss.list

      #echo "deb [arch=amd64] https://repo.zimbra.com/apt/zimbra-zextras xenial zimbra" | sudo tee -a /etc/apt/sources.list.d/zimbra-zextras.list
      #echo "deb [arch=amd64] https://repo.zimbra.com/apt/zimbra-foss xenial zimbra"    | sudo tee -a /etc/apt/sources.list.d/zimbra-foss.list

      sudo apt-get update -qq
   fi

   if [[ "$PKG_OS_TAG" =~ r ]]
   then
      sudo rm -f /etc/yum.repos.d/zimbra-*.repo

      sudo tee -a /etc/yum.repos.d/zimbra-local.repo <<EOM
[zimbra-local-zm-build]
name=zimbra-local
baseurl=file://$(echo $HOME/BUILD/archives/*/$PKG_OS_TAG)
enabled=1
gpgcheck=0
protect=0
EOM

      sudo tee -a /etc/yum.repos.d/zimbra-zextras.repo <<EOM
[zimbra-zextras-zm-zextras]
name=zimbra-zextras
baseurl=https://files.zimbra.com/dev-releases/hold/Zimbra/zm-zextras/develop-52/archives/zimbra-zextras/$PKG_OS_TAG
enabled=1
gpgcheck=0
protect=0
EOM

      sudo tee -a /etc/yum.repos.d/zimbra-foss.repo <<EOM
[zimbra-foss-zm-timezones]
name=zimbra-foss
baseurl=https://files.zimbra.com/dev-releases/hold/Zimbra/zm-timezones/develop-35/archives/zimbra-foss/$PKG_OS_TAG
enabled=1
gpgcheck=0
protect=0
EOM

      sudo yum clean all
   fi
}

deploy()
{
   echo -----------------------------------
   echo Upgrade/Install
   echo -----------------------------------

   cd ~/WDIR/zcs-*/;
   sudo ./install.sh $1
}

postInstallConfiguration()
{
   echo -----------------------------------
   echo Additional Settings
   echo -----------------------------------

   sudo su - zimbra -c "zmprov -l md $DOMAIN_NAME zimbraVirtualHostname $DOMAIN_NAME"
   sudo su - zimbra -c "zmprov -l mcf zimbraReverseProxyAdminEnabled TRUE"
   sudo su - zimbra -c "zmproxyctl restart"

   sudo su - zimbra -c "zmprov -l mcf zimbraPublicServiceHostname $DOMAIN_NAME"
   sudo su - zimbra -c "zmprov -l mcf zimbraPublicServicePort 443"
   sudo su - zimbra -c "zmprov -l mcf zimbraPublicServiceProtocol https"
   sudo su - zimbra -c "zmprov mc default zimbraFeatureNotebookEnabled TRUE"
   sudo su - zimbra -c "zmmailboxdctl restart"
}

Main() {
   echo $OPERATION
   if [ "$OPERATION" == "upgrade" ]; then
      buildCleanUp
      prepareConfig
      updatePackages
      deploy ~/WDIR/upgrade.conf
   else
      setUp
      buildCleanUp
      prepareConfig
      updatePackages
      deploy ~/WDIR/install.conf
      postInstallConfiguration
   fi
}

Main
echo -----------------------------------
echo INSTALL FINISHED
echo -----------------------------------
SCRIPT_EOM

#######################################################################
##### EXECUTE SCRIPT IN EC2 #####
#######################################################################

# XXX:  All variables have to be explicitly forwarded to the script below, and it runs inside the remote machines's context

Ssh "$MY_SSH_USER@$MY_SSH_HOST" -- "DOMAIN_NAME=$MY_SSH_HOST" "ADMIN_PASS=$MY_ADMIN_PASS" "OPERATION=$OPERATION" "PKG_OS_TAG=$PKG_OS_TAG" bash /tmp/injected_bash_script.sh

echo DEPLOY FINISHED - https://$MY_SSH_HOST/
