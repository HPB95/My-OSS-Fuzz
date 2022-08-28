#!/bin/bash -eu
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
#
################################################################################

mkdir build
cd build

cmake -DCMAKE_BUILD_TYPE=Debug -DFUZZER=ON -DCMAKE_C_COMPILER=$CC \
-DCMAKE_C_FLAGS=$CFLAGS -DCMAKE_EXE_LINKER_FLAGS=$CFLAGS -DLIB_FUZZING_ENGINE=$LIB_FUZZING_ENGINE ../

cp fuzzer $OUT/fuzzer
zip -r $OUT/fuzzer_seed_corpus.zip ../fuzzer/input/*.raw
