#!/bin/bash -eu
# Copyright 2023 Google LLC
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

set -eox pipefail

pushd $SRC/askama/fuzz
cargo update -p serde --precise 1.0.200
popd

target_out_dir=fuzz/target/x86_64-unknown-linux-gnu/release
cargo fuzz build -O
cargo fuzz list | while read i; do
    cp $target_out_dir/$i $OUT/
done
