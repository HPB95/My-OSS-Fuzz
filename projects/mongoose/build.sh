#!/bin/bash -eu
# Copyright 2020 Google LLC
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

cd $SRC/mongoose
$CXX $CXXFLAGS $LIB_FUZZING_ENGINE -DMG_ENABLE_LINES -DMG_ENABLE_LOG=0 mongoose.c -I. test/fuzz.c -o $OUT/fuzz

# Fuzzer using honggfuzz netdriver.
if [[ "$FUZZING_ENGINE" == "honggfuzz" ]]
then
  export HONGGFUZZ_HOME=$SRC/honggfuzz
  $HONGGFUZZ_HOME/hfuzz_cc/hfuzz-clang $CFLAGS -DMG_ENABLE_LINES=1 \
    -DMG_DISABLE_DAV_AUTH -DMG_ENABLE_FAKE_DAVLOCK \
    fuzz_netdriver_http.c mongoose.c -I. -o $OUT/fuzz_netdriver_http  \
    $HONGGFUZZ_HOME/libhfnetdriver/libhfnetdriver.a -pthread
fi
