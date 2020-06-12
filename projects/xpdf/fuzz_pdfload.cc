/*  Copyright 2020 Google Inc.

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

#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "PDFDoc.h"
#include "Zoox.h"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
	char filename[256];
	sprintf(filename, "/tmp/libfuzzer.%d", getpid());
	FILE *fp = fopen(filename, "wb");
	if (!fp)
		return 0;
	fwrite(data, size, 1, fp);
	fclose(fp);

	PDFDoc *doc;
	doc = new PDFDoc(filename, NULL, NULL);
	if (doc->isOk())
	{
		doc->getNumPages();
	}
	delete doc;

	unlink(filename);
    return 0;
}
