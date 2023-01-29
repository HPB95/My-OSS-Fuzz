#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include "ichi.h"
#include "inchi_api.h"
#include "inchi_gui.h"
#include "inchicmp.h"
#include "ichi_bns.h"
#include "ichi_io.h"
#include "ichicano.h"
#include "ichicant.h"
#include "ichicomn.h"
#include "ichicomp.h"
#include "ichidrp.h"
#include "ichierr.h"
#include "ichimain.h"
#include "ichimake.h"
#include "ichinorm.h"
#include "ichiring.h"
#include "ichirvrs.h"
#include "ichisize.h"
#include "ichister.h"
#include "ichitaut.h"
#include "ichitime.h"
#include "ikey_base26.h"
#include "extr_ct.h"
#include "incomdef.h"
#include "inpdef.h"
#include "ixa.h"
#include "mode.h"
#include "mol_fmt.h"
#include "readinch.h"
#include "sha2.h"
#include "strutil.h"
#include "util.h"
#include "ixa_mol.h"
#include "ixa_status.h"
#include "inchi_dll.h"
#include "inchi_dll_a.h"
#include "inchi_dll_b.h"
#include "inchi_dll_main.h"
#include "inchi_dll.h"


extern int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) {
    char *buf = (char *)malloc(Size + 1);
    if (!buf) return 0;
    memcpy(buf, Data, Size);
    buf[Size] = 0;
    const char *argv[256];
    parse_options_string(buf, argv, 256);
    free(buf);
    return 0;
}
