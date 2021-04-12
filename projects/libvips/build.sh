#!/bin/bash -eu
# Copyright 2019 Google Inc.
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

export PKG_CONFIG_PATH=/work/lib/pkgconfig
export LDFLAGS="$CXXFLAGS"

# libz
pushd $SRC/zlib
./configure --static --prefix=$WORK
make -j$(nproc) all
make install
popd

# libexif
pushd $SRC/libexif
autoreconf -fi
./configure \
  --enable-shared=no \
  --disable-docs \
  --disable-dependency-tracking \
  --prefix=$WORK
make -j$(nproc)
make install
popd

# aom
pushd $SRC/aom
mkdir -p build/linux
cd build/linux
cmake -G "Unix Makefiles" \
  -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX \
  -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
  -DCMAKE_INSTALL_PREFIX=$WORK -DCMAKE_INSTALL_LIBDIR=lib \
  -DENABLE_SHARED:bool=off -DCONFIG_PIC=1 \
  -DENABLE_EXAMPLES=0 -DENABLE_DOCS=0 -DENABLE_TESTS=0 \
  -DCONFIG_SIZE_LIMIT=1 \
  -DDECODE_HEIGHT_LIMIT=12288 -DDECODE_WIDTH_LIMIT=12288 \
  -DDO_RANGE_CHECK_CLAMP=1 \
  -DAOM_MAX_ALLOCABLE_MEMORY=536870912 \
  -DAOM_TARGET_CPU=generic \
  ../../
make clean
make -j$(nproc)
make install
popd

# libheif
pushd $SRC/libheif
autoreconf -fi
./configure \
  --disable-shared \
  --enable-static \
  --disable-examples \
  --disable-go \
  --prefix=$WORK
make clean
make -j$(nproc)
make install
popd

# libjpeg-turbo
pushd $SRC/libjpeg-turbo
cmake . -DCMAKE_INSTALL_PREFIX=$WORK -DENABLE_STATIC:bool=on
make -j$(nproc)
make install
popd

# libpng
pushd $SRC/libpng
sed -ie "s/option WARNING /option WARNING disabled/" scripts/pnglibconf.dfa
autoreconf -fi
./configure \
  --prefix=$WORK \
  --disable-shared \
  --disable-dependency-tracking
make -j$(nproc)
make install
popd

# libwebp
pushd $SRC/libwebp
autoreconf -fi
./configure \
  --enable-libwebpdemux \
  --enable-libwebpmux \
  --disable-shared \
  --disable-jpeg \
  --disable-tiff \
  --disable-gif \
  --disable-wic \
  --disable-threading \
  --disable-dependency-tracking \
  --prefix=$WORK
make -j$(nproc)
make install
popd

# libtiff ... a bug in libtiff master as of 20 Nov 2019 means we have to 
# explicitly disable lzma
pushd $SRC/libtiff
autoreconf -fi
./configure \
  --disable-lzma \
  --disable-shared \
  --disable-dependency-tracking \
  --prefix=$WORK
make -j$(nproc)
make install
popd

# libvips
./autogen.sh \
  --disable-shared \
  --disable-gtk-doc \
  --disable-gtk-doc-html \
  --disable-dependency-tracking \
  --prefix=$WORK
make -j$(nproc) CCLD=$CXX
make install

# Merge the seed corpus in a single directory, exclude files larger than 2k
mkdir -p fuzz/corpus
find \
  $SRC/afl-testcases/{gif*,jpeg*,png,tiff,webp}/full/images \
  fuzz/*_fuzzer_corpus \
  test/test-suite/images \
  -type f -size -2k \
  -exec bash -c 'hash=($(sha1sum {})); mv {} fuzz/corpus/$hash' ';'
zip -jrq $OUT/seed_corpus.zip fuzz/corpus

# Build fuzzers and link corpus
for fuzzer in fuzz/*_fuzzer.cc; do
  target=$(basename "$fuzzer" .cc)
  $CXX $CXXFLAGS -std=c++11 "$fuzzer" -o "$OUT/$target" \
    -I$WORK/include \
    -I/usr/include/glib-2.0 \
    -I/usr/lib/x86_64-linux-gnu/glib-2.0/include \
    $WORK/lib/libvips.a \
    $WORK/lib/libexif.a \
    $WORK/lib/libturbojpeg.a \
    $WORK/lib/libpng.a \
    $WORK/lib/libz.a \
    $WORK/lib/libwebpmux.a \
    $WORK/lib/libwebpdemux.a \
    $WORK/lib/libwebp.a \
    $WORK/lib/libtiff.a \
    $WORK/lib/libheif.a \
    $WORK/lib/libaom.a \
    $LIB_FUZZING_ENGINE \
    -Wl,-Bstatic \
    -lfftw3 -lgmodule-2.0 -lgio-2.0 -lgobject-2.0 -lffi -lglib-2.0 -lpcre -lexpat \
    -lresolv -lsepol -lselinux \
    -Wl,-Bdynamic -pthread
  ln -sf "seed_corpus.zip" "$OUT/${target}_seed_corpus.zip"
done

# Copy options and dictionary files to $OUT
find fuzz -name '*_fuzzer.dict' -exec cp -v '{}' $OUT ';'
find fuzz -name '*_fuzzer.options' -exec cp -v '{}' $OUT ';'
