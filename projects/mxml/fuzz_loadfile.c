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
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#include <mxml.h>

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
	char filename[256];
	sprintf(filename, "/tmp/libfuzzer.%d", getpid());

	FILE *fp2 = fopen(filename, "wb");
	if (!fp2) {
        return 0;
    }
	fwrite(data, size, 1, fp2);
	fclose(fp2);

	FILE *fp;
	mxml_node_t *tree = NULL;

	fp = fopen(filename, "r");
	tree = mxmlLoadFile(NULL, fp, MXML_OPAQUE_CALLBACK);
    if (tree != NULL) {
        free(tree);
    }

	fclose(fp);

	unlink(filename);

	return 0;
}
