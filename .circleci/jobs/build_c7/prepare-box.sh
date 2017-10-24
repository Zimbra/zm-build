#!/bin/bash

set -euxo pipefail

sudo yum clean all
sudo yum -y upgrade
