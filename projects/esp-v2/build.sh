#!/bin/bash -eu
# Copyright 2020 Google Inc.
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

## Copied from envoy

export CFLAGS="$CFLAGS"
export CXXFLAGS="$CXXFLAGS"

FUZZER_DICTIONARIES="\
"

# Copy $CFLAGS and $CXXFLAGS into Bazel command-line flags, for both
# compilation and linking.
#
# Some flags, such as `-stdlib=libc++`, generate warnings if used on a C source
# file. Since the build runs with `-Werror` this will cause it to break, so we
# use `--conlyopt` and `--cxxopt` instead of `--copt`.
#
declare -r EXTRA_BAZEL_FLAGS="$(
for f in ${CFLAGS}; do
  echo "--conlyopt=${f}" "--linkopt=${f}"
done
for f in ${CXXFLAGS}; do
  echo "--cxxopt=${f}" "--linkopt=${f}"
done

if [ "$SANITIZER" = "undefined" ]
then
  # Bazel uses clang to link binary, which does not link clang_rt ubsan library for C++ automatically.
  # See issue: https://github.com/bazelbuild/bazel/issues/8777
  echo "--linkopt=\"$(find $(llvm-config --libdir) -name libclang_rt.ubsan_standalone_cxx-x86_64.a | head -1)\""
elif [ "$SANITIZER" = "address" ]
then
  echo "--copt -D__SANITIZE_ADDRESS__" "--copt -DADDRESS_SANITIZER=1"
fi
)"

declare BAZEL_BUILD_TARGETS=""
declare BAZEL_CORPUS_TARGETS=""
declare FILTERED_FUZZER_TARGETS=""
for t in $(bazel query 'src/...' --output label | grep '_fuzz_test$')
do
  declare TAGGED=$(bazel query "attr('tags', 'no_fuzz', ${t})")
  if [ -z "${TAGGED}" ]
  then
    BASE_PATH=${t//://}
    BASE_PATH=${BASE_PATH#"//"}
    FILTERED_FUZZER_TARGETS+="${BASE_PATH} "
    BAZEL_BUILD_TARGETS+="${t}_driverless "
    BAZEL_CORPUS_TARGETS+="${t}_corpus_tar "
  fi
done

# Build driverless libraries.
# Benchmark about 3 GB per CPU (10 threads for 28.8 GB RAM)
# TODO(nareddyt): Remove deprecation warnings when Envoy and deps moves to C++17
bazel build --verbose_failures --dynamic_mode=off --spawn_strategy=sandboxed \
  --local_cpu_resources=HOST_CPUS*0.32 \
  --genrule_strategy=standalone --strip=never \
  --copt=-fno-sanitize=vptr --linkopt=-fno-sanitize=vptr \
  --define tcmalloc=disabled --define signal_trace=disabled \
  --define ENVOY_CONFIG_ASAN=1 \
  --define force_libcpp=enabled --build_tag_filters=-no_asan \
  --linkopt=-lc++ --linkopt=-pthread ${EXTRA_BAZEL_FLAGS} \
  ${BAZEL_BUILD_TARGETS[*]} ${BAZEL_CORPUS_TARGETS[*]}

# Profiling with coverage requires that we resolve+copy all Bazel symlinks and
# also remap everything under proc/self/cwd to correspond to Bazel build paths.
if [ "$SANITIZER" = "coverage" ]
then
  # The build invoker looks for sources in $SRC, but it turns out that we need
  # to not be buried under src/, paths are expected at out/proc/self/cwd by
  # the profiler.
  declare -r REMAP_PATH="${OUT}/proc/self/cwd"
  mkdir -p "${REMAP_PATH}"

  rsync -av "${SRC}"/esp-v2/src "${REMAP_PATH}"
  # Remove filesystem loop manually.
  rm -rf "${SRC}"/esp-v2/bazel-esp-v2/external/esp-v2
  # Clean up symlinks with a missing referrant.
  find "${SRC}"/esp-v2/bazel-esp-v2/external -follow -type l -ls -delete || echo "Symlink cleanup soft fail"
  rsync -avLk "${SRC}"/esp-v2/bazel-esp-v2/external "${REMAP_PATH}"
  # For .h, and some generated artifacts, we need bazel-out/. Need to heavily
  # filter out the build objects from bazel-out/. Also need to resolve symlinks,
  # since they don't make sense outside the build container.
  declare -r RSYNC_FILTER_ARGS=("--include" "*.h" "--include" "*.cc" "--include" \
    "*.hpp" "--include" "*.cpp" "--include" "*.c" "--include" "*/" "--exclude" "*")
  rsync -avLk "${RSYNC_FILTER_ARGS[@]}" "${SRC}"/esp-v2/bazel-out "${REMAP_PATH}"
  rsync -avLkR "${RSYNC_FILTER_ARGS[@]}" "${HOME}" "${OUT}"
  rsync -avLkR "${RSYNC_FILTER_ARGS[@]}" /tmp "${OUT}"
fi

# Copy out test driverless binaries from bazel-bin/.
for t in ${FILTERED_FUZZER_TARGETS}
do
  TARGET_BASE="$(expr "$t" : '.*/\(.*\)_fuzz_test')"
  TARGET_DRIVERLESS=bazel-bin/"${t}"_driverless
  echo "Copying fuzzer $t"
  cp "${TARGET_DRIVERLESS}" "${OUT}"/"${TARGET_BASE}"_fuzz_test
done

# Zip up related test corpuses.
# TODO(nareddyt): just use the .tar directly when
# https://github.com/google/oss-fuzz/issues/1918 is fixed.
CORPUS_UNTAR_PATH="${PWD}"/_tmp_corpus
for t in ${FILTERED_FUZZER_TARGETS}
do
  echo "Extracting and zipping fuzzer $t corpus"
  rm -rf "${CORPUS_UNTAR_PATH}"
  mkdir -p "${CORPUS_UNTAR_PATH}"
  tar -C "${CORPUS_UNTAR_PATH}" -xvf bazel-bin/"${t}"_corpus_tar.tar
  TARGET_BASE="$(expr "$t" : '.*/\(.*\)_fuzz_test')"
  # There may be *.dict files in this folder that need to be moved into the OUT dir.
  find "${CORPUS_UNTAR_PATH}" -type f -name *.dict -exec mv -n {} "${OUT}"/ \;
  zip "${OUT}/${TARGET_BASE}"_fuzz_test_seed_corpus.zip \
    "${CORPUS_UNTAR_PATH}"/*
done
rm -rf "${CORPUS_UNTAR_PATH}"

# Copy dictionaries and options files to $OUT/
for d in $FUZZER_DICTIONARIES; do
  cp "$d" "${OUT}"/
done

# Cleanup bazel- symlinks to avoid oss-fuzz trying to copy out of the build
# cache.
rm -f bazel-*
