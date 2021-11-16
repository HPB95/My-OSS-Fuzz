#!/bin/bash -eux
# Copyright 2021 Google LLC
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
#
################################################################################

# This script will install the perf tool
# Try a simple way first, check if it succeeded, otherwise try harder...

# Try the easiest way first and check if installation succeeded.
apt-get update && apt-get install -y linux-tools-common linux-tools-generic
perf --version ||
(
    # Try to get kernel specific package if generic was not good enough.
    apt-get install -y linux-tools-`uname -r`
    perf --version
) ||
(
    # Last way is to recompile from right kernel tag.
    export tagname=v`uname -r | cut -d- -f1 | sed 's/\.0$//'`
    git clone --depth 1 --branch $tagname git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
    pushd linux-stable/tools/perf/
    apt-get install -y flex bison make elfutils libelf-dev
    # clang finds errors such as tautological-bitwise-compare
    WERROR=0 CC=gcc DESTDIR=/usr/ make install
    apt-get remove -y --purge flex bison elfutils libelf-dev
    popd
    rm -rf linux-stable
)
