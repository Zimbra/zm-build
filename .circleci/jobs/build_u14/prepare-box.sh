#!/bin/bash

set -euxo pipefail

sudo apt-get -qq update
sudo apt-get -qq dist-upgrade -y
