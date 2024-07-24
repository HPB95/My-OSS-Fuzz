#!/bin/bash -eu
# Copyright 2024 Google LLC
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

export GGML_NO_OPENMP=1
sed -i 's/:= c++/:= ${CXX}/g' ./Makefile
sed -i 's/:= cc/:= ${CC}/g' ./Makefile

UNAME_M=amd642 UNAME_p=amd642 LLAMA_NO_METAL=1 make -j$(nproc)


# Convert models into header files so we can use them for fuzzing.
xxd -i models/ggml-vocab-bert-bge.gguf > model_header_bge.h
xxd -i models/ggml-vocab-llama-bpe.gguf > model_header_bpe.h
xxd -i models/ggml-vocab-llama-spm.gguf > model_header_spm.h
xxd -i models/ggml-vocab-qwen2.gguf > model_header_qwen2.h
xxd -i models/ggml-vocab-command-r.gguf > model_header_command_r.h
xxd -i models/ggml-vocab-aquila.gguf > model_header_aquila.h
xxd -i models/ggml-vocab-gpt-2.gguf > model_header_gpt_2.h
xxd -i models/ggml-vocab-baichuan.gguf > model_header_baichuan.h
xxd -i models/ggml-vocab-deepseek-coder.gguf > model_header_deepseek_coder.h
xxd -i models/ggml-vocab-falcon.gguf > model_header_falcon.h

OBJ_FILES="ggml/src/llamafile/sgemm.o ggml/src/ggml.o ggml/src/ggml-alloc.o ggml/src/ggml-backend.o ggml/src/ggml-quants.o ggml/src/ggml-aarch64.o src/llama.o src/llama-vocab.o src/llama-grammar.o src/llama-sampling.o src/unicode.o src/unicode-data.o common/common.o common/console.o common/ngram-cache.o common/sampling.o common/train.o common/grammar-parser.o common/build-info.o common/json-schema-to-grammar.o"
FLAGS="-std=c++11 -Iggml/include -Iggml/src -Iinclude -Isrc -Icommon -I./ -DNDEBUG -DGGML_USE_LLAMAFILE"

cp fuzzers/*.dict $OUT/

$CXX $LIB_FUZZING_ENGINE $CXXFLAGS ${FLAGS} ${OBJ_FILES} fuzzers/fuzz_json_to_grammar.cpp -o $OUT/fuzz_json_to_grammar
$CXX $LIB_FUZZING_ENGINE $CXXFLAGS ${FLAGS} ${OBJ_FILES} fuzzers/fuzz_grammar.cpp -o $OUT/fuzz_grammar

$CXX $LIB_FUZZING_ENGINE $CXXFLAGS ${FLAGS} ${OBJ_FILES} -DFUZZ_BGE fuzzers/fuzz_tokenizer.cpp -o $OUT/fuzz_tokenizer_bge
$CXX $LIB_FUZZING_ENGINE $CXXFLAGS ${FLAGS} ${OBJ_FILES} -DFUZZ_BPE  fuzzers/fuzz_tokenizer.cpp -o $OUT/fuzz_tokenizer_bpe
$CXX $LIB_FUZZING_ENGINE $CXXFLAGS ${FLAGS} ${OBJ_FILES} -DFUZZ_SPM  fuzzers/fuzz_tokenizer.cpp -o $OUT/fuzz_tokenizer_spm
$CXX $LIB_FUZZING_ENGINE $CXXFLAGS ${FLAGS} ${OBJ_FILES} -DFUZZ_COMMAND_R  fuzzers/fuzz_tokenizer.cpp -o $OUT/fuzz_tokenizer_command_r
$CXX $LIB_FUZZING_ENGINE $CXXFLAGS ${FLAGS} ${OBJ_FILES} -DFUZZ_AQUILA  fuzzers/fuzz_tokenizer.cpp -o $OUT/fuzz_tokenizer_aquila
$CXX $LIB_FUZZING_ENGINE $CXXFLAGS ${FLAGS} ${OBJ_FILES} -DFUZZ_QWEN2  fuzzers/fuzz_tokenizer.cpp -o $OUT/fuzz_tokenizer_qwen2
$CXX $LIB_FUZZING_ENGINE $CXXFLAGS ${FLAGS} ${OBJ_FILES} -DFUZZ_GPT_2  fuzzers/fuzz_tokenizer.cpp -o $OUT/fuzz_tokenizer_gpt_2
$CXX $LIB_FUZZING_ENGINE $CXXFLAGS ${FLAGS} ${OBJ_FILES} -DFUZZ_BAICHUAN  fuzzers/fuzz_tokenizer.cpp -o $OUT/fuzz_tokenizer_baichuan
$CXX $LIB_FUZZING_ENGINE $CXXFLAGS ${FLAGS} ${OBJ_FILES} -DFUZZ_DEEPSEEK_CODER  fuzzers/fuzz_tokenizer.cpp -o $OUT/fuzz_tokenizer_deepseek_coder
$CXX $LIB_FUZZING_ENGINE $CXXFLAGS ${FLAGS} ${OBJ_FILES} -DFUZZ_FALCON  fuzzers/fuzz_tokenizer.cpp -o $OUT/fuzz_tokenizer_falcon
