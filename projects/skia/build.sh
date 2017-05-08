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

export CXXFLAGS_ARR=`echo $CXXFLAGS | sed -e "s/\s/\",\"/g"`
$SRC/depot_tools/gn gen out/Fuzz --args='cc="'$CC'" cxx="'$CXX'" is_debug=false extra_cflags=["'"$CXXFLAGS_ARR"'","-DIS_FUZZING"] skia_use_system_freetype2=false skia_use_fontconfig=false skia_enable_gpu=false extra_ldflags=["-lFuzzingEngine", "'"$CXXFLAGS_ARR"'"]'



$SRC/depot_tools/ninja -C out/Fuzz fuzz_region_deserialize

cp out/Fuzz/fuzz_region_deserialize $OUT/fuzz_region_deserialize
