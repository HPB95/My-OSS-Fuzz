#!/bin/bash -eux
#
# Copyright 2017 Google Inc.
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

# This is not a typical OSS-Fuzz set up, don't use it as an example.

# This builds LLVM fuzzers using $CC/$CXX and LLVM's own copy of libFuzzer.
# TODO(kcc): honor CFLAGS/CXXFLAGS to allow building with msan/ubsan

mkdir build
cd build

cmake -GNinja -DCMAKE_BUILD_TYPE=Release ../llvm \
    -DLLVM_ENABLE_ASSERTIONS=ON \
    -DCMAKE_C_COMPILER=$CC \
    -DCMAKE_CXX_COMPILER=$CXX \
    -DLLVM_USE_SANITIZE_COVERAGE=YES \
    -DLLVM_USE_SANITIZER=Address

ninja clang-fuzzer

cp bin/clang-fuzzer $OUT
