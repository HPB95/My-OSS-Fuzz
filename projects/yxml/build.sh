#!/bin/bash -eu
#
# Copyright 2024 Google LLC
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

# Build yxml project
$CC $CFLAGS -I$SRC/yxml -c yxml.c -o yxml.a

# Build fuzzing harness
$CC $CFLAGS -I$SRC/yxml -c $SRC/yxml_fuzzer.c -o yxml_fuzzer.o
$CXX $CXXFLAGS $LIB_FUZZING_ENGINE yxml_fuzzer.o \
     -o $OUT/yxml_fuzzer yxml.a

# Create seed corpus
zip -rj $OUT/yxml_fuzzer_seed_corpus.zip $SRC/yxml/test/*.xml
