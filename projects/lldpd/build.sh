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
./autogen.sh
./configure --disable-shared --enable-pie --enable-fuzzer=$LIB_FUZZING_ENGINE
make

cp tests/fuzz_cdp $OUT/
cp tests/fuzz_edp $OUT/
cp tests/fuzz_lldp $OUT/
cp tests/fuzz_sonmp $OUT/

zip -r $OUT/fuzz_cdp_seed_corpus.zip    tests/fuzzing_seed_corpus/fuzz_cdp_seed_corpus
zip -r $OUT/fuzz_edp_seed_corpus.zip    tests/fuzzing_seed_corpus/fuzz_edp_seed_corpus
zip -r $OUT/fuzz_lldp_seed_corpus.zip   tests/fuzzing_seed_corpus/fuzz_lldp_seed_corpus
zip -r $OUT/fuzz_sonmp_seed_corpus.zip  tests/fuzzing_seed_corpus/fuzz_sonmp_seed_corpus
