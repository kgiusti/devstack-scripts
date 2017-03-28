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

# This script configures a VM to run the devstack-gate
# Run this as root on a bare Ubuntu server VM, then reboot
# Then log back in as jenkins and run the vm-tempest.sh script

set -x

function die {
    local exitcode=$?
    local msg="[ERROR] $1"
    echo $msg 1>&2
    exit $exitcode
}

[ "$(whoami)" == "root" ] || die "must be run as root"
cd
DEBIAN_FRONTEND=noninteractive apt-get --assume-yes install -y git python-pip python-tox python3-yaml
ssh-keygen -N "" -t rsa -f /root/.ssh/id_rsa

# configure system as a openstack single-use slave,
# see http://git.openstack.org/cgit/openstack-infra/devstack-gate/tree/README.rst
git clone https://git.openstack.org/openstack-infra/system-config
system-config/install_puppet.sh && system-config/install_modules.sh
KEY_CONTENTS=$(cat /root/.ssh/id_rsa.pub | awk '{print $2}' )
puppet apply --verbose --modulepath=/root/system-config/modules:/etc/puppet/modules -e 'class { openstack_project::single_use_slave: install_users => false, enable_unbound => true, ssh_key => "${KEY_CONTENTS}" }'

# create the jenkins user
useradd -m jenkins
echo -e "password\npassword" | passwd jenkins
echo "jenkins ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/jenkins

# signal that the VM is ready to reboot
touch /VM-SETUP

echo "Setup complete!  Reboot in order for changes to take effect"



