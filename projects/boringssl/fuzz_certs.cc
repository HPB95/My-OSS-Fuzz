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
#include <openssl/err.h>
#include <openssl/mem.h>
#include <openssl/x509.h>

int FUZZ_CERT(const uint8_t *buf, size_t len) {
  X509 *x509 = d2i_X509(NULL, &buf, len);
  if (x509 != NULL) {
    // Extract the public key.
    EVP_PKEY_free(X509_get_pubkey(x509));

    // Reserialize the structure.
    uint8_t *der = NULL;
    i2d_X509(x509, &der);
    OPENSSL_free(der);
  }
  X509_free(x509);
  ERR_clear_error();
  return 0;
}

DEFINE_PROTO_FUZZER(const asn1_pdu::PDU &asn1) {
  asn1_pdu::ASN1ProtoToDER converter = asn1_pdu::ASN1ProtoToDER();
  std::vector<uint8_t> der = converter.ProtoToDER(asn1);
  const uint8_t* ptr = &der[0];
  size_t size = der.size();
  FUZZ_CERT(ptr, size);
}