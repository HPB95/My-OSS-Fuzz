// Copyright 2018 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


#include "skcms.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    skcms_ICCProfile p;
    if (!skcms_ICCProfile_parse(&p, data, size)) {
        return 0;
    }
    skcms_Matrix3x3 m;
    skcms_ICCProfile_toXYZD50(&p, &m);
    skcms_TransferFunction tf;
    skcms_ICCProfile_getTransferFunction(&p, &tf);

    if (p.tag_count > 0) {
        skcms_ICCTag tag;
        skcms_ICCProfile_getTagByIndex(&p, 0, &tag);
        skcms_ICCProfile_getTagByIndex(&p, p.tag_count - 1, &tag);
    }
    return 0;
}
