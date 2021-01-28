/* Copyright 2021 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

#include <stdint.h>
#include <config.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef HAVE_STRINGS_H
# include <strings.h>
#endif /* HAVE_STRINGS_H */
#include <ctype.h>
#include <errno.h>
#include <pwd.h>
#include <unistd.h>
#ifdef HAVE_GETOPT_LONG
# include <getopt.h>
# else
# include "compat/getopt.h"
#endif /* HAVE_GETOPT_LONG */

#include "sudoers.h"
#include "sudoers_version.h"
#include "sudo_lbuf.h"
#include "redblack.h"
#include "cvtsudoers.h"
#include <gram.h>

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    if (size < 5) {
        return 0;
    }

    char filename[256];
    sprintf(filename, "/tmp/fuzz-sudoers.XXXXXX");

    int fp = mkstemp(filename);
    if (fp < 0) {
        return 0;
    }
    write(fp, data, size);
    close(fp);

    // main entry point for the fuzzer
    FILE *fd = fopen(filename, "rb");
    if (fd != NULL) {
        init_parser(filename, false, true);
        sudoers_parse_ldif(&parsed_policy, fd, NULL, true);
    }
    remove(filename);
    return 0;
}
