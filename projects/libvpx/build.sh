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

# Build libvpx
build_dir=$WORK/build
mkdir -p ${build_dir}
pushd ${build_dir}

export CFLAGS="$CFLAGS -fno-sanitize=vptr"
export CXXFLAGS="$CXXFLAGS -fno-sanitize=vptr"

# Remove files generated by the previous build.
rm -rf ./*

LDFLAGS="$CXXFLAGS" $SRC/libvpx/configure \
    --disable-unit-tests \
    --size-limit=12288x12288 \
    --extra-cflags="-DVPX_MAX_ALLOCABLE_MEMORY=1073741824" \
    --target="generic-gnu"
make clean
make -j$(nproc) all
popd

# build fuzzers
fuzzer_src_name=vpx_dec_fuzzer
fuzzer_modes=( '' '_threaded' )
fuzzer_decoders=( 'vp9' 'vp8' )
for decoder in "${fuzzer_decoders[@]}"; do
    for mode in "${fuzzer_modes[@]}"; do
      fuzzer_name=${fuzzer_src_name}${mode}"_"${decoder}

      $CXX $CXXFLAGS -std=c++11 \
        -DDECODE_MODE${mode} \
        -DENABLE_${decoder} \
        -I$SRC/libvpx \
        -I$SRC/libvpx/third_party/libyuv/include \
        -I${build_dir} \
        -Wl,--start-group \
        -lFuzzingEngine \
        $SRC/${fuzzer_src_name}.cc -o $OUT/${fuzzer_name} \
        ${build_dir}/libvpx.a ${build_dir}/ivfdec.c.o ${build_dir}/tools_common.c.o \
        -Wl,--end-group

    cp $SRC/vpx_dec_fuzzer.dict $OUT/${fuzzer_name}.dict
    done
done
