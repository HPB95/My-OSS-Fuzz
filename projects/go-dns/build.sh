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

function compile_fuzzer {
  path=$1
  function=$2
  fuzzer=$3

  if [[ $SANITIZER = *coverage* ]]; then
    cd $GOPATH/src/$path
    fuzzed_package=`pwd | rev | cut -d'/' -f 1 | rev`
    cp $GOPATH/ossfuzz_coverage_runner.go ./"${function,,}"_test.go
    sed -i -e 's/FuzzFunction/'$function'/' ./"${function,,}"_test.go
    sed -i -e 's/mypackagebeingfuzzed/'$fuzzed_package'/' ./"${function,,}"_test.go
    sed -i -e 's/TestFuzzCorpus/Test'$function'Corpus/' ./"${function,,}"_test.go

    echo "#/bin/sh" > $OUT/$fuzzer
    echo "cd $path" >> $OUT/$fuzzer
    echo "go test -run Test${function}Corpus -v -tags fuzz -coverprofile \$1 " >> $OUT/$fuzzer
    chmod +x $OUT/$fuzzer

    cd -
    return 0
  fi
  # Compile and instrument all Go files relevant to this fuzz target.
  go-fuzz -tags fuzz -func $function -o $fuzzer.a $path

  # Link Go code ($fuzzer.a) with fuzzing engine to produce fuzz target binary.
  $CXX $CXXFLAGS $LIB_FUZZING_ENGINE $fuzzer.a -o $OUT/$fuzzer
}

# Same as usual except for added -tags fuzz.
compile_fuzzer github.com/miekg/dns FuzzNewRR fuzz_newrr
compile_fuzzer github.com/miekg/dns Fuzz fuzz_msg_unpack
