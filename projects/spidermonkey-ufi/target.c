#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define STRINGLIT(S) #S
#define STRINGIFY(S) STRINGLIT(S)

// Required for oss-fuzz to consider the binary a target.
static const char* magic __attribute__((used)) = "LLVMFuzzerTestOneInput";

int main(int argc, char* argv[]) {
  setenv("HOME", "/tmp", 0);
  setenv("LIBFUZZER", "1", 1);
  setenv("FUZZER", STRINGIFY(FUZZ_TARGET), 1);

  char* options = getenv("ASAN_OPTIONS");
  if (options) {
    char* ptr;
    char* new_options = strdup(options);

    // https://bugzilla.mozilla.org/1477846
    ptr = strstr(new_options, "detect_stack_use_after_return=1");
    if (ptr) ptr[30] = '0';

    // https://bugzilla.mozilla.org/1477844
    ptr = strstr(new_options, "detect_leaks=1");
    if (ptr) ptr[13] = '0';

    setenv("ASAN_OPTIONS", new_options, 1);
    free(new_options);
  }

  int ret = execv("./fuzz-tests", argv);
  if (ret)
    perror("execv");
  return ret;
}

