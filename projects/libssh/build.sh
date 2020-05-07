#!/bin/bash -eu
# Copyright 2016 Google Inc.
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

BUILD=$WORK/build
mkdir -p $BUILD
pushd $BUILD
cmake -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
    -DBUILD_SHARED_LIBS=OFF -DWITH_INSECURE_NONE=ON $SRC/libssh
make "-j$(nproc)"

fuzzers=$(find $SRC/libssh/tests/fuzz/ -name "*_fuzzer.cpp")
for f in $fuzzers; do
    fuzzerName=$(basename $f .cpp)
    echo "Building fuzzer $fuzzerName"
    $CXX $CXXFLAGS -std=c++11 -I$SRC/libssh/include/ \
        "$f" -o "$OUT/$fuzzerName" \
        $LIB_FUZZING_ENGINE ./src/libssh.a -Wl,-Bstatic -lcrypto -lz -Wl,-Bdynamic

    if [ -d "$SRC/libssh/tests/fuzz/${fuzzerName}_corpus" ]; then
        zip -j $OUT/${fuzzerName}_seed_corpus.zip $SRC/libssh/tests/fuzz/${fuzzerName}_corpus/*
    fi
done
popd
