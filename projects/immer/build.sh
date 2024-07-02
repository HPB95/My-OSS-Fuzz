#!/bin/bash -eu
# Copyright 2020 Google Inc.
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

# Temporarily disable -fsanitize=object-size, until https://github.com/arximboldi/immer/issues/274 is fixed
if [ "$SANITIZER" = undefined ]; then
    export CFLAGS="$CFLAGS     -fno-sanitize=object-size"
    export CXXFLAGS="$CXXFLAGS -fno-sanitize=object-size"
fi

mkdir build
cd build
cmake .. \
      -DBOEHM_GC_INCLUDE_DIR=/usr/include \
      -DBOEHM_GC_LIBRARIES=/usr/lib/x86_64-linux-gnu/libgc.a \
      -Dimmer_BUILD_TESTS=OFF
make -j$(nproc) fuzzers

for fuzzer in extra/fuzzer/*; do
    if [[ -f $fuzzer && -x $fuzzer ]]; then
        cp $fuzzer $OUT
    fi
done
