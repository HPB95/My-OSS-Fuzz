# Copyright 2022 Google LLC
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
cd $SRC/pest/meta
cargo bootstrap && RUSTFLAGS="-Znew-llvm-pass-manager=no" cargo +nightly fuzz build
cd $SRC/pest/grammars
cargo bootstrap && RUSTFLAGS="-Znew-llvm-pass-manager=no" cargo +nightly fuzz build
cp $SRC/pest/meta/fuzz/target/x86_64-unknown-linux-gnu/release/parser $OUT/
cp $SRC/pest/grammars/fuzz/target/x86_64-unknown-linux-gnu/release/toml $OUT/
cp $SRC/cloud-hypervisor/fuzz/target/x86_64-unknown-linux-gnu/release/json $OUT/