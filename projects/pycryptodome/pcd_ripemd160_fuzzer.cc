// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "RIPEMD160.c"
#include <fuzzer/FuzzedDataProvider.h>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {

  if (!size)
    return 0;

  FuzzedDataProvider stream(data, size);
  hash_state *hs;
  if (ripemd160_init(&hs))
    return 0;

  while (stream.remaining_bytes()) {

    size_t num_bytes = stream.ConsumeIntegral<size_t>();
    std::vector<uint8_t> buffer = stream.ConsumeBytes<uint8_t>(num_bytes);

    if (ripemd160_update(hs, buffer.data(), buffer.size()))
      goto error;

  }

  uint8_t result[RIPEMD160_DIGEST_SIZE];
  ripemd160_digest(hs, result);

error:
  ripemd160_destroy(hs);
  return 0;
}
