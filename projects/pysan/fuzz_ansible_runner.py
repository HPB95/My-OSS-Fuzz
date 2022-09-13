#!/usr/bin/python3
# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Targets: https://github.com/advisories/GHSA-6j58-grhv-2769"""

import os
import sys
import atheris
import sanlib

import pexpect
import ansible_runner
from ansible_runner.config.runner import RunnerConfig


def TestOneInput(data):
    fdp = atheris.FuzzedDataProvider(data)

    rc = RunnerConfig("/tmp/")
    rc.suppress_ansible_output = True
    rc.expect_passwords = {
        pexpect.TIMEOUT: None,
        pexpect.EOF: None
    }
    rc.cwd = str("/tmp/")
    rc.env = {}
    rc.job_timeout = 10
    rc.idle_timeout = 0
    rc.pexpect_timeout = 2.
    rc.pexpect_use_poll = True
    rc.command = "from_fuzzer"

    runner = ansible_runner.Runner(rc)
    runner.resource_profiling = True
    #rc.resource_profiling_base_cgroup = "; exec-san"
    assistance = True
    if assistance and fdp.ConsumeIntInRange(1, 100) > 80:
        rc.resource_profiling_base_cgroup = "FROMFUZZ"
    else:
        rc.resource_profiling_base_cgroup = fdp.ConsumeUnicodeNoSurrogates(24)
    try:
        runner.run()
    except (
        RuntimeError,
        ValueError,
        TypeError
    ) as e:
        pass


def main():
    atheris.instrument_all()
    atheris.Setup(sys.argv, TestOneInput, enable_python_coverage=True)
    atheris.Fuzz()


if __name__ == "__main__":
    main()
