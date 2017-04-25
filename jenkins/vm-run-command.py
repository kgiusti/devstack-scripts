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

import argparse
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
                     " pexpect package (usually pythonX-pexpect)\n")
    exit(-1)

SUDO_PROMPT = re.compile('^\[sudo\] password for [^:]+:')
VM_CONNECT = re.compile('Connected to domain \S+')
VM_READY = re.compile('Escape character is \^]')


def sudo_login(vm, passwd, timeout=5):
    rc = vm.expect([SUDO_PROMPT, pexpect.EOF, pexpect.TIMEOUT], timeout)
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


def wait_for_prompt(vm, regex, timeout=60):
    try:
        return vm.expect(regex, timeout=timeout)
    except pexpect.EOF:
        logging.debug("EOF during prompt wait")
        return -1
    except pexpect.TIMEOUT:
        logging.debug("Timed out during prompt wait")
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

    parser = argparse.ArgumentParser(
        description='Execute a command on a VM console')
    parser.add_argument("--name",
                        default='TempestVM',
                        help="The name of the VM")
    parser.add_argument("--shutdown",
                        action='store_true',
                        help="force shutdown of VM after command completes")
    parser.add_argument("--timeout",
                        type=int,
                        default=30 * 60,
                        help="inactivity timeout in seconds")
    parser.add_argument("command",
                        type=str,
                        help="The command to execute on the VM")

    args = parser.parse_args()

    # login to the VM and run the tempest test script:
    vm = pexpect.spawn('virsh', ['console', args.name],
                       logfile=sys.stdout, encoding='utf8',
                       timeout=args.timeout)
    if not vm.isalive():
        logging.error("Failed to spawn command")
        return -1

    # wait for the console prompt

    VM_PROMPT = re.compile('[^@]+@%s:[^#]+#' % args.name)

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
    logging.error("The setting for shutdown is: %s", args.shutdown)
    vm.sendline(args.command)
    logging.error("WAITING")
    wait_for_prompt(vm, VM_PROMPT, timeout=None)
    logging.error("PROMPT")
    logging.info("Command '%s' completed", args.command)
    if args.shutdown:
        logging.error("SHUTTINGDOWN")
        vm.sendline("shutdown -t now")
        wait_for_exit(vm)
    else:
        logging.error("EXITING")
        vm.close()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

