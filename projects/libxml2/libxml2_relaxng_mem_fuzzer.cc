/*
# Copyright 2020 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################
*/
#include <stdint.h>

#include "libxml.h"
#include "libxml/xmlmemory.h"
#include "libxml/relaxng.h"


void ignore (void* ctx, const char* msg, ...) {
  // Error handler to avoid spam of error messages from libxml parser.
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    // Set ignore as error function
    xmlSetGenericErrorFunc(NULL, &ignore);

    xmlRelaxNGPtr schema = NULL;
    xmlRelaxNGParserCtxtPtr ctxt;

    // Main fuzzer logic
    ctxt = xmlRelaxNGNewMemParserCtxt((char*)data, size);
    schema = xmlRelaxNGParse(ctxt);
    xmlRelaxNGFreeParserCtxt(ctxt);
    if (schema != NULL)
        xmlRelaxNGFree(schema);

    // Cleanup
    xmlRelaxNGCleanupTypes();
    xmlCleanupParser();
    xmlMemoryDump();

    return EXIT_SUCCESS;
}

