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

# Force Python3, run configure.py to pick the right build config
PYTHON=python3
yes "" | ${PYTHON} configure.py

# Since Bazel passes flags to compilers via `--copt`, `--conlyopt` and
# `--cxxopt`, we need to move all flags from `$CFLAGS` and `$CXXFLAGS` to these.
# We don't use `--copt` as warnings issued by C compilers when encountering a
# C++-only option results in errors during build.
#
# Note: Make sure that by this line `$CFLAGS` and `$CXXFLAGS` are properly set
# up as further changes to them won't be visible to Bazel.
#
# Note: We remove the `-stdlib=libc++` flag as Bazel produces linker errors if
# it is present.
declare -r EXTRA_FLAGS="\
$(
for f in ${CFLAGS}; do
  echo "--conlyopt=${f}" "--linkopt=${f}"
done
for f in ${CXXFLAGS}; do
  if [[ "$f" != "-stdlib=libc++" ]]; then
    echo "--cxxopt=${f}" "--linkopt=${f}"
  fi
done
)"

# Determine all fuzz targets. To control what gets fuzzed with OSSFuzz, all
# supported fuzzers are in `//tensorflow/security/fuzzing`.
declare -r FUZZERS=$(bazel query 'tests(//tensorflow/security/fuzzing/...)' | grep -v identity)

# Build the fuzzer targets.
# Pass in `--verbose_failures` so it is easy to debug compile crashes.
# Pass in `--strip=never` to ensure coverage support.
# Pass in `$LIB_FUZZING_ENGINE` to `--copt` and `--linkopt` to ensure we have a
# `main` symbol defined (all these fuzzers build without a `main` and by default
# `$CFLAGS` and `CXXFLAGS` compile with `-fsanitize=fuzzer-no-link`).
bazel build \
  ${EXTRA_FLAGS} \
  --verbose_failures \
  --strip=never \
  --copt=${LIB_FUZZING_ENGINE} \
  --linkopt=${LIB_FUZZING_ENGINE} \
  -- ${FUZZERS}

# The fuzzers built above are in the `bazel-bin/` symlink. But they need to be
# in `$OUT`, so move them accordingly.
for bazel_target in ${FUZZERS}; do
  colon_index=$(expr index "${bazel_target}" ":")
  fuzz_name="${bazel_target:$colon_index}"
  bazel_location="bazel-bin/${bazel_target/:/\/}"
  mv ${bazel_location} ${OUT}/$fuzz_name
done

# Finally, make sure we don't accidentally run with stuff from the bazel cache.
rm -f bazel-*
