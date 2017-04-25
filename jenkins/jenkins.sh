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

#@todo(kgiusti): TempestVM hardcoded in vm-run-command.py
VM_NAME=${VM_NAME:-TempestVM}
DISTRO=${DISTRO:-ubuntu-16.04}
DISK_SIZE=${DISK_SIZE:-24G}
ROOT_PW=${ROOT_PW:-password}
MEMSIZE_MB=${MEMSIZE_MB:-8000}   # 8GB
V_CPUS=${V_CPUS:-4}    # virtual CPUs for the VM


function cleanup {
    set +e
    virsh destroy $VM_NAME
    virsh undefine --remove-all-storage $VM_NAME
    set -e
}

# ensure that no stale VM has been left over...
cleanup
##trap cleanup ERR
set -e

mkdir -p ${PWD}/_build

#
# build a disk for the VM
#

# Commands to configure the filesystem
# Run after the disk is built (before booting)
cat > ${PWD}/_build/build-image <<-EOF
update
copy-in ${PWD}/vm-run-tempest.sh:/usr/bin
chmod 0755:/usr/bin/vm-run-tempest.sh
# bugfix: overwrite insane /etc/hosts file
edit /etc/hosts:s/unassigned-hostname/localhost/
edit /etc/hosts:s/unassigned-domain/localdomain/
edit /etc/hosts:s/^::1[ \t]*localhost /::1 localhost6 /
# Allow login without passwords
edit /etc/pam.d/common-auth:s/nullok_secure/nullok/
# Add console to kernel
edit /etc/default/grub:s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="console=tty0 console=ttyS0,115200n8"/
run-command update-grub
EOF

virt-builder ${DISTRO} \
             -o ${PWD}/_build/$VM_NAME.img \
             --hostname $VM_NAME \
             --root-password password:${ROOT_PW} \
             --size ${DISK_SIZE} \
             --firstboot  ${PWD}/vm-firstboot.sh \
             --commands-from-file ${PWD}/_build/build-image

# create the VM
# the vm-firstboot.sh script is invoked on first boot
virt-install --name $VM_NAME \
             --import \
             --memory ${MEMSIZE_MB} \
             --disk path=${PWD}/_build/$VM_NAME.img,format=raw \
             --virt-type kvm \
             --cpu host \
             --vcpus ${V_CPUS} \
             --graphics none \
             --os-variant ubuntu15.10

virsh start $VM_NAME
sleep 5
${PWD}/vm-run-command.py --name $VM_NAME --shutdown "su --login --command \"/usr/bin/vm-run-tempest.sh\" jenkins"
##cleanup


