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

# This script is run by the jenkins user to
# 1) Build a disk image for the tempest VM
# 2) Create the tempest VM
# 3) Run the devstack gate in the tempest VM

set -x

${VM_NAME:=tempest_vm}
${DISTRO:=ubuntu-16.04}
${DISK_SIZE:=8G}
${ROOT_PW:=password}
${MEMSIZE_MB:=4000}   # 4GB
${V_CPUS:=4}    # virtual CPUs for the VM


function cleanup {
    virsh destroy $VM_NAME
    virsh undefine --remove-all-storage $VM_NAME
}

mkdir -p ${PWD}/_build

#
# build a disk for the VM
#

# configure pam to allow logins without passwords
# Hack the interfaces file since it uses the wrong device name (bug?)
# Boot to console device
cat > ${PWD}/_build/build-image <<-EOF
    edit '/etc/pam.d/common-auth:s/nullok_secure/nullok/'
    edit '/etc/network/interfaces:s/ens2/ens3/'
    edit '/etc/default/grub:s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="console=tty0 console=ttyS0,115200n8"/' \
    run-command update-grub
EOF

virt-builder ${DISTRO} \
             -o ${PWD}/_build/$VM_NAME.img \
             --hostname $VM_NAME \
             --root-password password:${ROOT_PW} \
             --size ${DISK_SIZE} \
             --verbose \
             --firstboot  ${PWD}/vm-firstboot.sh \
             --command-from-file ${PWD}/_build/build-image

# create the VM
#  the vm-firstboot.sh script is invoked on first boot
virt-install --name $VM_NAME \
             --import \
             --memory ${MEMSIZE_MB} \
             --disk path=${PWD}/_build/$VM_NAME.img,format=raw \
             --virt-type kvm \
             --cpu host \
             --vcpus ${V_CPUS} \
             --graphics none \
             --noautoconsole











