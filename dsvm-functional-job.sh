#!/bin/bash

if [ - x "$(command -v yum)" ]; then
    yum -y group install "Development Tools"
    yum -y install libffi_devel
    yum -y install openssl_devel
    yum -y install python_devel
    yum -y install curl
    yum -y install cyrus-sasl-lib
    yum -y install cyrus-sasl-plain
    yum -y install qpid-cpp-server
    yum -y update
else
    apt-get install -y libffi-dev
    apt-get install -y libssl-dev
    apt-get install -y python-dev
    apt-get install -y curl
    apt-get install -y sasl2-bin
    add-apt-repository -y ppa:qpid/testing
    apt-get update -y
    apt-get install -y qpidd
fi

curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py"
python get-pip.py
pip install tox
pip install pyngus

cd ../
git clone https://git.openstack.org/openstack/oslo.messaging
cd oslo.messaging
tox -epy27 --notest
source .tox/py27/bin/activate
export TRANSPORT_URL=amqp://stackqpid:secretqpid@127.0.0.1:65123//
export AMQP1_BACKEND=qpidd
./setup-test-env-amqp1.sh python setup.py testr --slowest --testr-args='oslo_messaging.tests.functional'


#synaptic package manager
