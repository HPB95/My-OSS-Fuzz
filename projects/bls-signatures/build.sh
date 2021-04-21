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

export CXXFLAGS="$CXXFLAGS -DCRYPTOFUZZ_NO_OPENSSL -D_LIBCPP_DEBUG=1"
export LIBFUZZER_LINK="$LIB_FUZZING_ENGINE"
export LINK_FLAGS=""

# Install Boost headers
cd $SRC/
tar jxf boost_1_74_0.tar.bz2
cd boost_1_74_0/
CFLAGS="" CXXFLAGS="" ./bootstrap.sh
CFLAGS="" CXXFLAGS="" ./b2 headers
cp -R boost/ /usr/include/

# Prevent Boost compilation error with -std=c++17
export CXXFLAGS="$CXXFLAGS -D_LIBCPP_ENABLE_CXX17_REMOVED_AUTO_PTR"

# Configure Cryptofuzz
cd $SRC/cryptofuzz/
git checkout bls
python gen_repository.py

if [[ $CFLAGS = *-m32* ]]
then
    # Build and install libgmp
    cd $SRC/
    mkdir $SRC/libgmp-install
    tar xf gmp-6.2.1.tar.lz
    cd $SRC/gmp-6.2.1/
    autoreconf -ivf
    if [[ $CFLAGS != *-m32* ]]
    then
        ./configure --prefix="$SRC/libgmp-install/" --enable-cxx
    else
        setarch i386 ./configure --prefix="$SRC/libgmp-install/" --enable-cxx
    fi
    make -j$(nproc)
    make install
    export CXXFLAGS="$CXXFLAGS -I $SRC/libgmp-install/include/"
fi

# Build blst
cd $SRC/blst/
./build.sh
export BLST_LIBBLST_A_PATH=$(realpath libblst.a)
export BLST_INCLUDE_PATH=$(realpath bindings/)
export CXXFLAGS="$CXXFLAGS -DCRYPTOFUZZ_BLST"

# Build Chia
cd $SRC/bls-signatures/
mkdir build/
cd build/
if [[ $CFLAGS = *-m32* ]]
then
    export CHIA_ARCH="X86"
else
    export CHIA_ARCH="X64"
fi
cmake .. -DBUILD_BLS_PYTHON_BINDINGS=0 -DBUILD_BLS_TESTS=0 -DBUILD_BLS_BENCHMARKS=0 -DARCH=$CHIA_ARCH
make -j$(nproc)
export CHIA_BLS_LIBBLS_A_PATH=$(realpath libbls.a)
export CHIA_BLS_INCLUDE_PATH=$(realpath ../src/)
export CHIA_BLS_RELIC_INCLUDE_PATH_1=$(realpath _deps/relic-build/include/)
export CHIA_BLS_RELIC_INCLUDE_PATH_2=$(realpath _deps/relic-src/include/)
export CXXFLAGS="$CXXFLAGS -DCRYPTOFUZZ_CHIA_BLS"

# Build mcl
cd $SRC/mcl/
mkdir build/
cd build/
if [[ $CFLAGS != *-m32* ]]
then
    cmake .. -DMCL_STATIC_LIB=on
    export LINK_FLAGS="$LINK_FLAGS -lgmp"
else
    cmake .. -DMCL_STATIC_LIB=on \
    -DGMP_INCLUDE_DIR="$SRC/libgmp-install/include/"
    -DGMP_LIBRARY="$SRC/libgmp-install/lib/libgmp.a"
    -DGMP_GMPXX_INCLUDE_DIR="$SRC/libgmp-install/include/"
    -DGMP_GMPXX_LIBRARY="$SRC/libgmp-install/lib/libgmpxx.a"
    -DMCL_USE_ASM=off
    export LINK_FLAGS="$LINK_FLAGS $SRC/libgmp-install/lib/libgmp.a"
fi
make
export MCL_INCLUDE_PATH=$(realpath ../include/)
export MCL_LIBMCL_A_PATH=$(realpath lib/libmcl.a)
export MCL_LIBMCLBN384_A_PATH=$(realpath lib/libmclbn384.a)
export CXXFLAGS="$CXXFLAGS -DCRYPTOFUZZ_MCL"

# Build Botan
cd $SRC/botan/
if [[ $CFLAGS != *-m32* ]]
then
    ./configure.py --cc-bin=$CXX \
    --cc-abi-flags="$CXXFLAGS" \
    --disable-shared \
    --disable-modules=locking_allocator,x509,tls \
    --build-targets=static \
    --without-documentation
else
    ./configure.py --cpu=x86_32 \
    --cc-bin=$CXX \
    --cc-abi-flags="$CXXFLAGS" \
    --disable-shared \
    --disable-modules=locking_allocator,x509,tls \
    --build-targets=static \
    --without-documentation
fi
make -j$(nproc)

export CXXFLAGS="$CXXFLAGS -DCRYPTOFUZZ_BOTAN -DCRYPTOFUZZ_BOTAN_IS_ORACLE"
export LIBBOTAN_A_PATH="$SRC/botan/libbotan-3.a"
export BOTAN_INCLUDE_PATH="$SRC/botan/build/include"

# Build modules
cd $SRC/cryptofuzz/modules/botan/
make -B

cd $SRC/cryptofuzz/modules/blst/
make -B

cd $SRC/cryptofuzz/modules/chia_bls/
make -B

cd $SRC/cryptofuzz/modules/mcl/
make -B

# Build Cryptofuzz
cd $SRC/cryptofuzz/
make -B -j

cp cryptofuzz $OUT/cryptofuzz-bls-signatures
