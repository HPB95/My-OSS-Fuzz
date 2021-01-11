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

# ciso8601 does not build statically,
# so we remove it in the code:
sed -i '6d' $SRC/core/homeassistant/util/dt.py

# setup.py fails if these versions are not installed
pip3 install idna==2.9
pip3 install chardet==3.0.4

# install home-assistant/core
python3 setup.py install

# build fuzzers
for fuzzer in $(find $SRC -name '*_fuzzer.py'); do
  fuzzer_basename=$(basename -s .py $fuzzer)
  fuzzer_package=${fuzzer_basename}.pkg
  pyinstaller --distpath $OUT --onefile --name $fuzzer_package $fuzzer

  # Create execution wrapper.
  echo "#!/bin/sh
# LLVMFuzzerTestOneInput for fuzzer detection.
this_dir=\$(dirname \"\$0\")
LD_PRELOAD=\$this_dir/sanitizer_with_fuzzer.so \
ASAN_OPTIONS=\$ASAN_OPTIONS:symbolize=1:external_symbolizer_path=\$this_dir/llvm-symbolizer:detect_leaks=0 \
\$this_dir/$fuzzer_package \$@" > $OUT/$fuzzer_basename
  chmod u+x $OUT/$fuzzer_basename
done

# build seed and dict
cp $SRC/fuzzing/dictionaries/json.dict $OUT/json_fuzzer.dict
zip $OUT/json_fuzzer_seed_corpus.zip $SRC/fuzzing-corpus/json/sample.json
