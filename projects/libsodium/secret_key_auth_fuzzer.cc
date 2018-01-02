extern "C" {
  #include <sodium.h>
}

class SodiumState {
public:
  unsigned char key[crypto_auth_KEYBYTES];
  unsigned char mac[crypto_auth_BYTES];

  SodiumState() {
    sodium_init(); // this can fail with a non-zero return code
    crypto_auth_keygen(key);
  }
};

SodiumState state;

extern "C" int LLVMFuzzerTestOneInput(const unsigned char *data, size_t size) {
  crypto_auth(state.mac, data, size, state.key);
  crypto_auth_verify(state.mac, data, size, state.key);
  return 0;
}
