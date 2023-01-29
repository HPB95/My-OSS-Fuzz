#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include "ucl.h"


extern int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) {
    if (Size < 2) return 0;

    ucl_object_t *obj = ucl_object_fromlstring((const char *)Data, Size);
    if (obj == NULL) return 0;

    size_t tlen = 0;
    ucl_object_tolstring(obj, &tlen);

    ucl_object_unref(obj);
    return 0;
}
