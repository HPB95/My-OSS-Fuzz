#!/bin/bash -eu
# Copyright 2021 Google Inc.
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
# Run the OSS-Fuzz script in the project
#$SRC/utf8proc/test/ossfuzz.sh #broken, for now

mkdir build
cd build
cmake .. -DUTF8PROC_ENABLE_TESTING=ON
make -j$(nproc)


$CC $CFLAGS -I$SRC/utf8proc \
    $SRC/utf8proc/test/fuzzer.c \
    -o $OUT/utf8proc_fuzzer \
    $LIB_FUZZING_ENGINE $SRC/utf8proc/build/libutf8proc.a
	
This conversation was marked as resolved by randy408

find $SRC/utf8proc/test -name "*.txt" | \
     xargs zip $OUT/utf8proc_fuzzer_seed_corpus.zip
