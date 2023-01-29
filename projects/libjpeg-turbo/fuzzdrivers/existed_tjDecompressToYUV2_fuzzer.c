#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include "jpeglib.h"
#include "turbojpeg.h"
#include "turbojpeg.h"


extern int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) {
    tjhandle handle = tjInitDecompress();
    if (!handle)
        return 0;
    int width = 0;
    int height = 0;
    int jpegSubsamp = 0;
    int jpegColorspace = 0;
    tjDecompressHeader3(handle, Data, Size, &width, &height, &jpegSubsamp, &jpegColorspace);
    unsigned char *dstBuf = (unsigned char *)malloc(width*height*2);
    tjDecompressToYUV2(handle,Data,Size,dstBuf,width,0,height,0);
    free(dstBuf);
    tjDestroy(handle);
    return 0;
}
