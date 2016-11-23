#!/bin/bash


#yum -y group install "Development Tools"
#yum -y install libffi_devel
#yum -y install openssl_devel
#yum -y install python_devel
#yum -y update

apt-get install -y libffi-dev
apt-get install -y libssl-dev
apt-get install -y python-dev
apt-get install -y curl

curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py"

curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py"
python get-pip.py
pip install tox
pip install pyngus

#./safe-devstack-vm-gate-wrap.sh
