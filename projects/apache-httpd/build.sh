#!/bin/bash -eu
# Copyright 2021 Google LLC
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

unset CPP
unset CXX

# Download apr and apr-utils and place them in httpd folder
cd $SRC/
mkdir deps
cd deps
wget https://downloads.apache.org//apr/apr-1.7.0.tar.gz
tar -xf apr-1.7.0.tar.gz
mv apr-1.7.0 $SRC/httpd/srclib/apr

wget https://downloads.apache.org//apr/apr-util-1.6.1.tar.gz
tar -xf apr-util-1.6.1.tar.gz
mv apr-util-1.6.1 $SRC/httpd/srclib/apr-util

# Build httpd
cd $SRC/httpd
./configure --with-included-apr
make

# Build the fuzzers
for fuzzname in utils parse tokenize addr_parse; do
  $CC $CFLAGS $LIB_FUZZING_ENGINE -I./include -I./os/unix -I./srclib/apr/include -I./srclib/apr-util/include/ \
    $SRC/fuzz_${fuzzname}.c -o $OUT/fuzz_${fuzzname} \
    ./modules.o buildmark.o \
    -Wl,--start-group ./server/.libs/libmain.a \
                      ./modules/core/.libs/libmod_so.a \
                      ./modules/http/.libs/libmod_http.a \
                      ./server/mpm/event/.libs/libevent.a \
                      ./os/unix/.libs/libos.a \
                      ./srclib/apr-util/.libs/libaprutil-1.a \
                      ./srclib/apr/.libs/libapr-1.a \
    -Wl,--end-group -luuid -lpcre
done
