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

# This script configures a VM to run the devstack-gate. It is run once
# under root at initial VM boot via the virt-install command

set -x

export DEBIAN_FRONTEND=noninteractive

#
# Install the latest for qpidd, dispatch, and proton
#
set +e
apt-get -y purge  '.*qpid-proton.*' '^libqpid.*' '^qpidd.*' '^qdrouter.*'
set -e

## KAG: Disabled until we fix the amqp1 devstack plugin to allow external message bus

apt-get -y install git gcc cmake libssl-dev libsasl2-dev swig python-dev python-pip \
        g++  pkg-config ruby libboost-dev libboost-program-options-dev \
        libboost-filesystem-dev libboost-all-dev libboost-system-dev \
        uuid-dev libnss3-dev sasl2-bin python3-yaml ntp ntpdate

pip install -U pip
pip install tox

if false; then


# Install proton:
cd /root
git clone https://git-wip-us.apache.org/repos/asf/qpid-proton.git
cd qpid-proton
mkdir BUILD
cd BUILD
cmake -DCMAKE_INSTALL_PREFIX=/usr ..
make -j4 install
cd proton-c/bindings/python/dist
python setup.py build sdist
cd dist
pip install ./python-qpid-proton-*.tar.gz

# install qpidd, listening on ports 5672/5671:
cd /root
git clone https://git-wip-us.apache.org/repos/asf/qpid-cpp.git
cd qpid-cpp
mkdir BUILD
cd BUILD
cmake -DCMAKE_INSTALL_PREFIX=/usr ..
make -j4 install
cat <<EOF | tee /usr/etc/qpid/qpidd.conf
auth=no
queue-patterns=exclusive
queue-patterns=unicast
topic-patterns=broadcast
log-enable=info+
log-to-syslog=yes
max-connections=0
EOF
##qpidd -d


# install qdrouterd, listening on port 15672:
cd /root
git clone https://git-wip-us.apache.org/repos/asf/qpid-dispatch.git
cd qpid-dispatch
mkdir BUILD
cd BUILD
cmake -DCMAKE_INSTALL_PREFIX=/usr ..
make -j4 install

cat <<EOF | tee /etc/qpid-dispatch/qdrouterd.conf
router {
    mode: standalone
    id: Router.A
}

listener {
    addr: 0.0.0.0
    port: 15672
    authenticatePeer: no
}

address {
    prefix: openstack.org/om/rpc/multicast
    distribution: multicast
}

address {
    prefix: openstack.org/om/rpc/unicast
    distribution: closest
}

address {
    prefix: openstack.org/om/rpc/anycast
    distribution: balanced
}

address {
    prefix: openstack.org/om/notify/multicast
    distribution: multicast
}

address {
    prefix: openstack.org/om/notify/unicast
    distribution: closest
}

address {
    prefix: openstack.org/om/notify/anycast
    distribution: balanced
}

log {
    module: DEFAULT
    enable: info+
}
EOF
#PYTHONPATH="/usr/lib/python2.7/site-packages:$PYTHONPATH" qdrouterd -d
#cd


### KAG FIXME:
fi

# configure system as a openstack single-use slave,
# see http://git.openstack.org/cgit/openstack-infra/devstack-gate/tree/README.rst
#

cd /root
git clone https://git.openstack.org/openstack-infra/system-config
system-config/install_puppet.sh && system-config/install_modules.sh
ssh-keygen -N "" -t rsa -f /root/.ssh/id_rsa
KEY_CONTENTS=$(cat /root/.ssh/id_rsa.pub | awk '{print $2}' )
puppet apply --verbose --modulepath=/root/system-config/modules:/etc/puppet/modules \
       -e 'class { openstack_project::single_use_slave: ssh_key => "${KEY_CONTENTS}" }'

# # break the resolv.conf link
# cp /etc/resolv.conf ~/resolv.conf
# rm -f /etc/resolv.conf
# cp ~/resolv.conf /etc
# DNS1="10.11.5.19"
# DNS2="10.5.30.160"
# echo "nameserver $(DNS1)" >> /etc/resolv.conf
# echo "nameserver $(DNS2)" >> /etc/resolv.conf

#
# create an auto login console for root access
#

mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d
cat > /etc/systemd/system/serial-getty@ttyS0.service.d/override.conf <<-EOF
    [Service]
    ExecStart=
    ExecStart=-/sbin/agetty -a root --keep-baud 115200,38400,9600 %I $TERM
EOF


# create the jenkins user
#useradd -m jenkins
#echo -e "password\npassword" | passwd jenkins
echo "jenkins ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/jenkins

# BUG:
#  devstack-gate setup_workspace fails with:
# devstack-gate/functions.sh:setup_workspace:L521:   find /opt/stack/cache/files/ -mindepth 1 -maxdepth 1 -exec cp -l '{}' /opt/stack/new/devstack/files/ ';'
# find: '/opt/stack/cache/files/': No such file or directory
# so create /opt/stack/cache/files to avoid this error

mkdir -p /opt/stack/cache/files
chown -R jenkins:jenkins /opt/stack/cache/files

echo "Setup completed!  Shutting down..."
shutdown -t now




