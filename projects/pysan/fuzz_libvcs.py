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
"""Targets https://github.com/advisories/GHSA-mv2w-4jqc-6fg4"""
import os
import sys
import atheris
import pysan

import libvcs
from libvcs.shortcuts import create_repo, create_repo_from_pip_url
from libvcs.util import run, which


def TestOneInput(data):
    fdp = atheris.FuzzedDataProvider(data)
    mercurial_repo = create_repo(
        url=fdp.ConsumeUnicodeNoSurrogates(128), vcs="hg", repo_dir="./"
    )
    try:
    	mercurial_repo.update_repo()
    except (
        ValueError,
        FileNotFoundError
    ) as e:
        pass


def main():
    pysan.pysan_add_hooks()
    atheris.instrument_all()
    atheris.Setup(sys.argv, TestOneInput, enable_python_coverage=True)
    atheris.Fuzz()


if __name__ == "__main__":
    main()
