#!/bin/bash -eu
# Copyright 2018 Google Inc.
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

./bootstrap.sh
sed -i'' -e 's/INT_MAX/100000/' "$SRC/libgd/src/gd_security.c"
./configure --prefix="$WORK" --disable-shared
make -j$(nproc) install

for target in bmp gif tga; do
    $CXX $CXXFLAGS -std=c++11 -I"$WORK/include" -L"$WORK/lib" \
      $SRC/${target}_target.cc -o $OUT/${target}_target \
      -lFuzzingEngine -lgd
done

mkdir afl_testcases
(cd afl_testcases; tar xvf "$SRC/afl_testcases.tgz")
for format in bmp gif; do
    mkdir $format
    find afl_testcases -type f -name '*.'$format -exec mv -n {} $format/ \;
    zip -rj $format.zip $format/
    cp $format.zip "$OUT/${format}_target_seed_corpus.zip"
done
