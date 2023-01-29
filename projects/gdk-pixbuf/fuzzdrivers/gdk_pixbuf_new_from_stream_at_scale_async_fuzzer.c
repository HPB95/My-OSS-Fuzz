#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include "gdk-pixbuf-2.0/gdk-pixbuf/gdk-pixbuf-core.h"


extern int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) {
    GInputStream *stream = g_memory_input_stream_new_from_data(Data, Size, NULL);
    gdk_pixbuf_new_from_stream_at_scale_async(stream, 0, 0, FALSE, NULL, NULL, NULL);
    return 0;
}
