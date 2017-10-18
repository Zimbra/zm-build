#!/bin/bash

set -euo pipefail
OP="$1"
[ -d .circleci ] || exit 1
[ "$APP1_SSH_USER" ] || exit 1;
[ "$APP1_SSH_HOST" ] || exit 1;
[ "$APP1_ADMIN_PASS" ] || exit 1;

source .circleci/get-env.sh;

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

DIR=$(echo ../BUILDS/UBUNTU16_64* | head -1); [ -d "$DIR" ] || exit 1;

#Rsync --delete -avz ~/zm-build "$APP1_SSH_USER@$APP1_SSH_HOST:"
Rsync --delete -avz "$DIR/" "$APP1_SSH_USER@$APP1_SSH_HOST:BUILD/"
Rsync .circleci/jobs/deploy_ec2/install.conf.in "$APP1_SSH_USER@$APP1_SSH_HOST:BUILD/install.conf.in"
Rsync .circleci/jobs/deploy_ec2/upgrade.conf.in "$APP1_SSH_USER@$APP1_SSH_HOST:BUILD/upgrade.conf.in"

Ssh "$APP1_SSH_USER@$APP1_SSH_HOST" -- "DOMAIN_NAME=$APP1_SSH_HOST" "ADMIN_PASS=$APP1_ADMIN_PASS" "OP=$OP" bash -s <<"SCRIPT_EOM"
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
   sudo apt-get remove --purge -y zimbra-*
   sudo rm -rf /opt/zimbra
   echo
}

buildCleanUp()
{
   echo -----------------------------------
   echo Build Cleanup
   echo -----------------------------------

   sudo rm -rf ~/WDIR
   mkdir ~/WDIR
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

   for archives in $HOME/BUILD/archives/*
   do
      echo "deb [trusted=yes] file://$archives ./"
   done | sudo tee /etc/apt/sources.list.d/zimbra-local.list
   sudo apt-get update -qq
}

deploy()
{
   echo -----------------------------------
   echo Uncompress tarball
   echo -----------------------------------

   tar -C ~/WDIR -xzf BUILD/zcs-*.tgz

   echo -----------------------------------
   echo Upgrade/Install
   echo -----------------------------------

   cd ~/WDIR/zcs-*/;
   sudo ./install.sh $@
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
   sudo su - zimbra -c "zmmailboxdctl restart"
}

Main() {
   echo $OP
   if [ "$OP" == "upgrade" ]; then
      buildCleanUp
      prepareConfig
      updatePackages
      deploy "~/WDIR/upgrade.conf"
   else
      setUp
      buildCleanUp
      prepareConfig
      updatePackages
      deploy "~/WDIR/install.conf"
      postInstallConfiguration
   fi
}

Main
echo -----------------------------------
echo INSTALL FINISHED
echo -----------------------------------
SCRIPT_EOM

echo DEPLOY FINISHED - https://$APP1_SSH_HOST/
