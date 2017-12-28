#!/bin/bash -eu
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


# Compile and install dependencies for static linking
# Cribbed from projects/wget2, thanks rockdaboot@gmail.com

export DEPS_PATH=$SRC/knot_deps
export PKG_CONFIG_PATH=$DEPS_PATH/lib/pkgconfig
export CPPFLAGS="-I$DEPS_PATH/include"
export CXXFLAGS=$CPPFLAGS
export CFLAGS=$CPPFLAGS
export LDFLAGS="-L$DEPS_PATH/lib"

cd $SRC/libunistring
./autogen.sh
./configure --enable-static --disable-shared --prefix=$DEPS_PATH
make -j$(nproc)
make install

GNUTLS_CONFIGURE_FLAGS=""
NETTLE_CONFIGURE_FLAGS=""
if [[ $CFLAGS = *sanitize=memory* ]]; then
  GNUTLS_CONFIGURE_FLAGS="--disable-hardware-acceleration"
  NETTLE_CONFIGURE_FLAGS="--disable-assembler --disable-fat"
fi

cd $SRC/nettle
bash .bootstrap
./configure --enable-mini-gmp --enable-static --disable-shared --disable-documentation --prefix=$DEPS_PATH $NETTLE_CONFIGURE_FLAGS
( make -j$(nproc) || make -j$(nproc) ) && make install
if test $? != 0;then
        echo "Failed to compile nettle"
        exit 1
fi

cd $SRC/gnutls
touch .submodule.stamp
make bootstrap
GNUTLS_CFLAGS=`echo $CFLAGS|sed s/-DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION//`
LIBS="-lunistring" \
CFLAGS="$GNUTLS_CFLAGS" \
./configure --with-nettle-mini --enable-gcc-warnings --enable-static --disable-shared --with-included-libtasn1 \
    --with-included-unistring --without-p11-kit --disable-doc --disable-tests --disable-tools --disable-cxx \
    --disable-maintainer-mode --disable-libdane --disable-gcc-warnings --prefix=$DEPS_PATH $GNUTLS_CONFIGURE_FLAGS
make -j$(nproc)
make install


# Compile knot, install fuzzers to /out

cd $SRC/knot-dns
autoreconf -if

./configure --with-sanitize-fuzzer --with-oss-fuzz=yes --disable-shared --enable-static --with-sanitize-fuzzer  --disable-daemon --disable-utilities --disable-documentation --disable-fastparser --with-module-dnsproxy=no --with-module-noudp=no --with-module-onlinesign=no --with-module-rrl=no --with-module-stats=no --with-module-synthrecord=no --with-module-whoami=no
make -j$(nproc)
cd $SRC/knot-dns/tests-fuzz
make check
/bin/bash ../libtool   --mode=install /usr/bin/install -c packet_libfuzzer zscanner_libfuzzer '/out'


# Set up fuzzing seeds

git submodule update --init -- ./packet_libfuzzer.in
find ./packet_libfuzzer.in/ -type f -exec zip -u $OUT/packet_libfuzzer_seed_corpus.zip {} \;
git submodule update --init -- ./zscanner_libfuzzer.in
find ./zscanner_libfuzzer.in/ -type f -exec zip -u $OUT/packet_libfuzzer_seed_corpus.zip {} \;
