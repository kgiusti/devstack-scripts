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
# Run once at initial VM boot via the virt-install command

set -x

# create an auto login console for root access
#
mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d
cat > /etc/systemd/system/serial-getty@ttyS0.service.d/override.conf <<-EOF
    [Service]
    ExecStart=
    ExecStart=-/sbin/agetty -a root --keep-baud 115200,38400,9600 %I $TERM
EOF

#ExecStart=-/sbin/agetty -a root --keep-baud 115200,38400,9600 %I $TERM
# /etc/systemd/system/serial-getty@ttyS0.service.d/override.conf
#  [Service]
#  ExecStart=
#   ExecStart=-/sbin/agetty -a root --keep-baud 115200,38400,9600 %I $TERM

cd
DEBIAN_FRONTEND=noninteractive apt-get --assume-yes install -y git python-pip python-tox python3-yaml

# configure system as a openstack single-use slave,
# see http://git.openstack.org/cgit/openstack-infra/devstack-gate/tree/README.rst
#
git clone https://git.openstack.org/openstack-infra/system-config
system-config/install_puppet.sh && system-config/install_modules.sh
ssh-keygen -N "" -t rsa -f /root/.ssh/id_rsa
KEY_CONTENTS=$(cat /root/.ssh/id_rsa.pub | awk '{print $2}' )
puppet apply --verbose --modulepath=/root/system-config/modules:/etc/puppet/modules \
       -e 'class { openstack_project::single_use_slave: install_users => false, enable_unbound => true, ssh_key => "${KEY_CONTENTS}" }'

# # break the resolv.conf link
# cp /etc/resolv.conf ~/resolv.conf
# rm -f /etc/resolv.conf
# cp ~/resolv.conf /etc
# DNS1="10.11.5.19"
# DNS2="10.5.30.160"
# echo "nameserver $(DNS1)" >> /etc/resolv.conf
# echo "nameserver $(DNS2)" >> /etc/resolv.conf

# create the jenkins user
useradd -m jenkins
echo -e "password\npassword" | passwd jenkins
echo "jenkins ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/jenkins

echo "Setup completed!  Shutting down..."
shutdown -t now




