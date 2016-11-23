#!/bin/bash -xe

export ZUUL_URL="https://git.openstack.org"
export ZUUL_PROJECT="openstack/oslo.messaging"
export ZUUL_BRANCH="master"
export ZUUL_REF="HEAD"
export OVERRIDE_ZUUL_BRANCH="master"
   
curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py"
python get-pip.py
pip install tox

ssh-keygen -N "" -t rsa -f /root/.ssh/id_rsa
KEY_CONTENTS=$(cat /root/.ssh/id_rsa.pub | awk '{print $2}' )
git clone https://git.openstack.org/openstack-infra/system-config /opt/system-config
/opt/system-config/install_puppet.sh
/opt/system-config/install_modules.sh
puppet apply --modulepath=/opt/system-config/modules:/etc/puppet/modules -e 'class { openstack_project::single_use_slave: install_users => false,   enable_unbound => true, ssh_key => \"$KEY_CONTENTS\" }'
echo "jenkins ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/jenkins
export WORKSPACE=/home/jenkins/workspace/testing
mkdir -p "$WORKSPACE"
cd $WORKSPACE
git clone --depth 1 https://git.openstack.org/openstack-infra/devstack-gate

# for lt environment, need lots more time (4 hrs should be enough, in ms)
export BUILD_TIMEOUT=14400000

export PYTHONUNBUFFERED=true

export DEVSTACK_GATE_HEAT=1
export DEVSTACK_GATE_NEUTRON=1
export DEVSTACK_GATE_TEMPEST=0
export DEVSTACK_GATE_EXERCISES=0
export DEVSTACK_GATE_INSTALL_TESTONLY=1

export PROJECTS="openstack/ceilometer openstack/aodh openstack/gnocchi openstack/oslo.messaging openstack/devstack-plugin-{plugin}"
export DEVSTACK_LOCAL_CONFIG="enable_plugin gnocchi git://git.openstack.org/openstack/gnocchi"
export DEVSTACK_LOCAL_CONFIG+=$'\n'"enable_plugin ceilometer git://git.openstack.org/openstack/ceilometer"
export DEVSTACK_LOCAL_CONFIG+=$'\n'"enable_plugin aodh git://git.openstack.org/openstack/aodh"

#case "$ZUUL_BRANCH" in
#    stable/liberty|stable/mitaka) break;;
#    stable/1.3|stable/2.0|stable/2.1|stable/2.2) break;;
#    *)
#    export DEVSTACK_LOCAL_CONFIG+=$'\n'"enable_plugin panko git://git.openstack.org/openstack/panko"
#    export PROJECTS="openstack/panko $PROJECTS"
#esac

export DEVSTACK_LOCAL_CONFIG+=$'\n'"GNOCCHI_ARCHIVE_POLICY=high"
export DEVSTACK_LOCAL_CONFIG+=$'\n'"CEILOMETER_PIPELINE_INTERVAL=5"
export DEVSTACK_LOCAL_CONFIG+=$'\n'"CEILOMETER_BACKEND=gnocchi"
export DEVSTACK_LOCAL_CONFIG+=$'\n'"GNOCCHI_STORAGE_BACKEND=file"

export DEVSTACK_LOCAL_CONFIG+=$'\n'"enable_plugin devstack-plugin-{plugin} git://git.openstack.org/openstack/devstack-plugin-{plugin}"

#export DEVSTACK_LOCAL_CONFIG+=$'\n'"AMQP1_USERNAME=queueuser"
#export DEVSTACK_LOCAL_CONFIG+=$'\n'"AMQP1_USERNAME=queuepassword"
#export DEVSTACK_LOCAL_CONFIG+=$'\n'"AMQP1_SERVICE=qdr"

#export DEVSTACK_PROJECT_FROM_GIT="oslo.messaging"

function post_test_hook {{
    cd /opt/stack/new/ceilometer/ceilometer/tests/integration/hooks/
    ./post_test_hook.sh
}}
export -f post_test_hook

cp devstack-gate/devstack-vm-gate-wrap.sh ./safe-devstack-vm-gate-wrap.sh
./safe-devstack-vm-gate-wrap.sh

