// Copyright 2020 Google Inc.
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
//
////////////////////////////////////////////////////////////////////////////////

#include "asn1_pdu.pb.h"
#include "fuzzing/proto/asn1-pdu-proto/asn1_proto_to_der.h"
#include "libprotobuf-mutator/src/libfuzzer/libfuzzer_macro.h"
#include <openssl/bytestring.h>
#include <openssl/evp.h>
#include <openssl/pkcs8.h>
#include <openssl/x509.h>
#include <iostream>

int FUZZ_PKCS12(const uint8_t *buf, size_t len) {
  bssl::UniquePtr<STACK_OF(X509)> certs(sk_X509_new_null());
  EVP_PKEY *key = nullptr;
  CBS cbs;
  CBS_init(&cbs, buf, len);
  PKCS12_get_key_and_certs(&key, certs.get(), &cbs, "foo");
  EVP_PKEY_free(key);
  return 0;
}

DEFINE_PROTO_FUZZER(const asn1_pdu::PDU &asn1) {
  asn1_pdu::ASN1ProtoToDER converter = asn1_pdu::ASN1ProtoToDER();
  std::vector<uint8_t> der = converter.ProtoToDER(asn1);
  const uint8_t* ptr = &der[0];
  size_t size = der.size();
  FUZZ_PKCS12(ptr, size);
}