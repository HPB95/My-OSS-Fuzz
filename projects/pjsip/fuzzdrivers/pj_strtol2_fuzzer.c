#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include "pjlib-util.h"
#include "pjlib.h"
#include "pjmedia-codec.h"
#include "pjmedia.h"
#include "pjmedia_audiodev.h"
#include "pjmedia_videodev.h"
#include "pjnath.h"
#include "pjsip.h"
#include "pjsip_simple.h"
#include "pjsip_ua.h"
#include "pjsua.h"


extern int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) {
    pj_str_t str;
    str.ptr = (char *)Data;
    str.slen = Size;
    long value;
    pj_strtol2(&str, &value);
    return 0;
}
