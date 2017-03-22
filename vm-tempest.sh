#!/bin/bash
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.
#

# This script runs the tempest devstack-gate CI test on oslo.messaging.
# Be sure to run vm-setup.sh script before running this script

# run as user 'jenkins' - see vm-setup.sh

set -x

function die {
    local exitcode=$?
    local msg="[ERROR] $1"
    echo $msg 1>&2
    exit $exitcode
}

[ "$(whoami)" == "jenkins" ] || die "must be run as user 'jenkins'"
[ -e "/VM-SETUP" ] || die "you must run vm-setup.sh as root first"

export REPO_URL=https://git.openstack.org
export ZUUL_URL=/home/jenkins/workspace-cache
export ZUUL_REF=HEAD

# set the two vars below to the project and branch to test:
export ZUUL_PROJECT=openstack/oslo.messaging
export ZUUL_BRANCH=master

export WORKSPACE=/home/jenkins/workspace/testing
mkdir -p $WORKSPACE
git clone $REPO_URL/$ZUUL_PROJECT $ZUUL_URL/$ZUUL_PROJECT
cd $ZUUL_URL/$ZUUL_PROJECT
git checkout remotes/origin/$ZUUL_BRANCH
cd $WORKSPACE
git clone --depth 1 $REPO_URL/openstack-infra/devstack-gate

# 4 hours:
export BUILD_TIMEOUT=14400000

export PYTHONUNBUFFERED=true
export DEVSTACK_GATE_TEMPEST=1
export DEVSTACK_GATE_TEMPEST_FULL=1
export PROJECTS="openstack/oslo.messaging $PROJECTS"
# export PROJECTS="openstack/devstack-plugin-amqp1 openstack/oslo.messaging $PROJECTS"
export DEVSTACK_LOCAL_CONFIG="LIBS_FROM_GIT=oslo.messaging"
#export DEVSTACK_LOCAL_CONFIG="enable_plugin devstack-plugin-amqp1 git://git.openstack.org/openstack/devstack-plugin-amqp1"
cp devstack-gate/devstack-vm-gate-wrap.sh ./safe-devstack-vm-gate-wrap.sh
./safe-devstack-vm-gate-wrap.sh

