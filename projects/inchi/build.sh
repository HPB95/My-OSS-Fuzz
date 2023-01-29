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

$CC $CFLAGS -Wno-everything -DTARGET_API_LIB -DCOMPILE_ANSI_ONLY -ansi -c \
    INCHI_BASE/src/*.c INCHI_API/libinchi/src/*.c INCHI_API/libinchi/src/ixa/*.c
ar rcs $WORK/libinchi.a *.o

for fuzzer in $SRC/*_fuzzer.c; do
  fuzzer_basename=$(basename -s .c $fuzzer)

  $CC $CFLAGS \
      -I INCHI_BASE/src/ \
      -I INCHI_API/libinchi/src/ \
      -I INCHI_API/libinchi/src/ixa/ \
      $fuzzer -c -o ${fuzzer_basename}.o

  $CXX $CXXFLAGS \
      ${fuzzer_basename}.o -o $OUT/$fuzzer_basename \
      $LIB_FUZZING_ENGINE $WORK/libinchi.a
done

set +e
for outfile in $(find /src/*/fuzzdrivers -name "*.c"); do
outexe=${outfile%.*}
echo $outexe
/usr/local/bin/clang-15 -isystem /usr/local/lib/clang/15.0.0/include -isystem /usr/local/include -isystem /usr/include/x86_64-linux-gnu -isystem /usr/include -fsanitize=address -fsanitize=fuzzer -fsanitize-address-use-after-scope -I/src/INCHI-1-SRC/INCHI_BASE/src/ -I/src/INCHI-1-SRC/INCHI_API/libinchi/src/ -I/src/INCHI-1-SRC/INCHI_API/libinchi/src/ixa/ -Wno-everything -DTARGET_API_LIB -DCOMPILE_ANSI_ONLY -ansi $outfile /work/libinchi.a -o $outexe
cp $outexe /out/
done

