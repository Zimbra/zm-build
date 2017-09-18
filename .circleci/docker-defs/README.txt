Building docker images requires:

1. Install docker

   See https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/

   # docker prerequisites
   sudo apt-get update -qq
   sudo apt-get remove docker docker-engine docker.io
   sudo apt-get install linux-image-extra-$(uname -r) linux-image-extra-virtual
   sudo apt-get install apt-transport-https ca-certificates curl software-properties-common

   # set up docker's apt repository
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

   sudo tee /etc/apt/sources.list.d/docker.list <<EOM
   deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable
   EOM

   sudo apt-get update -qq

   # install and test docker
   sudo apt-get install docker-ce
   sudo docker run hello-world

2. sudo docker login

   # Create appropriate login first at https://hub.docker.com/ (or your docker registry)

3. sudo make -j2
