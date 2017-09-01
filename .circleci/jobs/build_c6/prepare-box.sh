#!/bin/bash

set -x
set -e
set -o pipefail

yum clean all

# SYSTEM TOOLS
yum install -y curl wget
