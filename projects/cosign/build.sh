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

go get github.com/AdamKorcz/go-118-fuzz-build/testing

mv ./pkg/cosign/keys_test.go ./pkg/cosign/keys_test_keep_in_fuzz_scope.go
compile_native_go_fuzzer github.com/sigstore/cosign/v2/pkg/cosign/attestation FuzzGenerateStatement FuzzGenerateStatement
compile_native_go_fuzzer github.com/sigstore/cosign/v2/pkg/cosign/cue FuzzValidateJSON FuzzValidateJSON_cue
compile_native_go_fuzzer github.com/sigstore/cosign/v2/pkg/cosign/rego FuzzValidateJSON FuzzValidateJSON_rego
compile_native_go_fuzzer github.com/sigstore/cosign/v2/pkg/cosign FuzzImportKeyPairLoadPrivateKey FuzzImportKeyPairLoadPrivateKey
compile_native_go_fuzzer github.com/sigstore/cosign/v2/pkg/cosign FuzzSigVerify FuzzSigVerify
compile_native_go_fuzzer github.com/sigstore/cosign/v2/pkg/policy FuzzEvaluatePolicyAgainstJSON FuzzEvaluatePolicyAgainstJSON
