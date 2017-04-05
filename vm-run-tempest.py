#!/usr/bin/env python
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.


# [sudo] password for kgiusti:
# '^\[sudo\] password for [^:]+:'
# Connected to domain TempestCI-clone
# Escape character is ^]
# '^Escape character is \^]'
#

import sys
import re
import logging
import os

try:
    import pexpect
except ImportError:
    sys.stderr.write("ERROR: the required pexpect python package is not"
                     " installed\n")
    sys.stderr.write(" try: pip install pexpect or install your distro's\n"
                     " pexpect package (usually python#-pexpect)\n")
    exit(-1)

SUDO_PROMPT = re.compile('^\[sudo\] password for [^:]+:')
VM_CONNECT = re.compile('Connected to domain \S+')
VM_READY = re.compile('Escape character is \^]')
VM_PROMPT = re.compile('[^@]+@TempestCI:[^#]+#')

def sudo_login(vm, passwd):
    rc = vm.expect([SUDO_PROMPT, pexpect.EOF, pexpect.TIMEOUT], timeout=5)
    if rc == 0:
        # SUDO_PROMPT
        logging.debug("SUDO_PROMPT")
        vm.sendline(passwd)
        return True
    if rc == 1:
        logging.warn("Child unexpectedly returned EOF!")
        return False
    if rc == 2:
        logging.warn("No prompt for sudo - ignoring...")
        return True

def wait_for_prompt(vm, regex, timeout=10):
    try:
        return vm.expect(regex, timeout=timeout)
    except pexpect.EOF:
        logging.debug("EOF during prompt wait")
        return -1
    except pexpect.TIMEOUT:
        logging.debug("TIMEOUT during prompt wait")
        return -1

def wait_for_exit(vm, timeout=60, size=2048):
    while True:
        try:
            vm.read_nonblocking(size=size, timeout=timeout)
        except pexpect.TIMEOUT:
            logging.debug("read timed out - ignoring")
        except pexpect.EOF:
            logging.debug("child closed stdin")
            return vm.wait()


def main(argv):

    try:
        # oh yes, this is a terribly bad idea:
        pw = os.environ['SUDO_PW']
    except KeyError:
        logging.error("Need password for SUDO! set SUDO_PW env var")
        return -1

    # first start the VM
    vm = pexpect.spawn('sudo', ['virsh', 'start', 'TempestCI-clone'],
                        logfile=sys.stdout, encoding='utf8',
                        timeout=60)
    if not vm.isalive():
        logging.error("Failed to spawn command")
        return -1
    if not sudo_login(vm, pw):
        return -1
    rc = wait_for_exit(vm, timeout=60 * 3)  # wait for boot to finish
    if rc != 0:
        # something failed
        logging.error("The VM failed to start: return code=%d", rc)
        return -1

    # login to the VM and run the tempest test script:
    vm = pexpect.spawn('sudo', ['virsh', 'console', 'TempestCI-clone'],
                       logfile=sys.stdout, encoding='utf8',
                       timeout=60)
    if not vm.isalive():
        logging.error("Failed to spawn command")
        return -1
    if not sudo_login(vm, pw):
        return -1

    # wait for the console prompt
    while True:
        index = vm.expect_list([VM_CONNECT, VM_READY, VM_PROMPT,
                                pexpect.EOF, pexpect.TIMEOUT],
                               timeout=30)
        if index == 0:
            # VM_CONNECT message - ignore it
            logging.debug("VM_CONNECT")
        elif index == 1:
            # VM_READY
            logging.debug("VM_READY")
            vm.sendline("")  # <enter>
        elif index == 2:
            # VM_PROMPT
            logging.debug("VM_PROMPT")
            break
        elif index > 2:
            logging.error("VM console failed to connect: %s!",
                          "EOF received" if index == 3 else "TIMEOUT")
            return -1

    #
    # Console is up - fire off the tempest script
    #
    #vm.sendline("shutdown -t now")
    vm.sendline("echo HI")
    wait_for_prompt(vm, VM_PROMPT)
    vm.sendline("shutdown -t now")
    wait_for_exit(vm)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
