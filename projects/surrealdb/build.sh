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
cd crates

# Copy dictionaries, but don't fail if there aren't any.
cp fuzz/fuzz_targets/*.dict $OUT/ || true

# Add additional compiler flags required for a successful build.
export RUSTFLAGS="$RUSTFLAGS --cfg surrealdb_unstable"

cargo fuzz build -O --debug-assertions --target-dir sdk --fuzz-dir fuzz

FUZZ_TARGET_OUTPUT_DIR=fuzz/target/x86_64-unknown-linux-gnu/release
for f in fuzz/fuzz_targets/*.rs
do
    FUZZ_TARGET_NAME=$(basename ${f%.*})
    cp $FUZZ_TARGET_OUTPUT_DIR/$FUZZ_TARGET_NAME $OUT/
    # Create fuzz corpus, but don't fail if there aren't any.
    zip $OUT/${FUZZ_TARGET_NAME}_seed_corpus.zip fuzz/fuzz_targets/${FUZZ_TARGET_NAME}_seed_corpus/* || true
done

find $SRC/surrealdb_website -name '*.surql' -exec zip -r $OUT/fuzz_executor_seed_corpus.zip {} \;
