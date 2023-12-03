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

# Build js fuzzers
cd $SRC
mkdir fuzzing
cd fuzzing
cp $SRC/fuzz_crypto_verify.js ./
npm init --yes
npm install
npm install --save-dev @jazzer.js/core
# Build Fuzzers.
compile_javascript_fuzzer fuzzing fuzz_crypto_verify.js -i fuzzing 

# A broken fuzzer will cause the CI to fail.
if [ -n "${OSS_FUZZ_CI-}" ]
then
	exit 0
fi

# Build C++ fuzzers
cd $SRC/node
# Build node
export LDFLAGS="$CXXFLAGS"
export LD="$CXX"
./configure --with-ossfuzz
make -j$(nproc)
make install

# Copy all fuzzers to OUT folder 
cp out/Release/fuzz_* ${OUT}/
