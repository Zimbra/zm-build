#!/bin/bash

set -e -o pipefail

curl -Ls "https://circleci.com/api/v1.1/project/github/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/$CIRCLE_BUILD_NUM?circle-token=$CIRCLE_API_TOKEN"
