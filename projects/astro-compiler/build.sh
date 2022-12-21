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

go install github.com/AdamKorcz/go-118-fuzz-build@latest

# Fuzz internal/transform
printf "package transform\nimport _ \"github.com/AdamKorcz/go-118-fuzz-build/testing\"\n" > $SRC/compiler/internal/transform/registerfuzzdep.go
go mod tidy
go get -u github.com/AdamKorcz/go-118-fuzz-build/testing

compile_native_go_fuzzer $SRC/compiler/internal/transform FuzzScopeHTML fuzz_scope_html
compile_native_go_fuzzer $SRC/compiler/internal/transform FuzzTransformScoping fuzz_transform_scoping