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

# This script sets up the message bus using the current master branch from upstream.
# This script should be run by root.

set -x

# Install proton:
_CDIR=$(pwd)
git clone https://git-wip-us.apache.org/repos/asf/qpid-proton.git
cd qpid-proton
mkdir BUILD
cd BUILD
cmake -DCMAKE_INSTALL_PREFIX=/usr ..
make -j2 install
cd proton-c/bindings/python/dist
python setup.py build sdist
cd dist
pip install ./python-qpid-proton-*.tar.gz
cd $_CDIR

# install qpidd, listening on ports 5672/5671:
git clone https://git-wip-us.apache.org/repos/asf/qpid-cpp.git
cd qpid-cpp
mkdir BUILD
cd BUILD
cmake -DCMAKE_INSTALL_PREFIX=/usr ..
make -j2 install
cat <<EOF | tee /usr/etc/qpid/qpidd.conf
auth=no
queue-patterns=exclusive
queue-patterns=unicast
topic-patterns=broadcast
log-enable=info+
log-to-syslog=yes
max-connections=0
EOF
qpidd -d
cd $_CDIR

# install qdrouterd, listening on port 15672:
git clone https://git-wip-us.apache.org/repos/asf/qpid-dispatch.git
cd qpid-dispatch
mkdir BUILD
cd BUILD
cmake -DCMAKE_INSTALL_PREFIX=/usr ..
make -j2 install

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
PYTHONPATH="/usr/lib/python2.7/site-packages:$PYTHONPATH" qdrouterd -d
cd $_CDIR
