#!/usr/bin/python3
# Copyright 2023 Google LLC
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
import sys
import json
import atheris

import jsonschema
import openapi_schema_validator


def TestOneInput(data):
  fdp = atheris.FuzzedDataProvider(data)
  try:
    fuzz_dict_schema = json.loads(fdp.ConsumeUnicodeNoSurrogates(fdp.ConsumeIntInRange(0, 2048)))
    fuzz_dict_instance = json.loads(fdp.ConsumeUnicodeNoSurrogates(fdp.ConsumeIntInRange(0, 2048)))
  except:
    return
  if not isinstance(fuzz_schema, dict) or not isinstance(
      fuzz_dict_instance, dict):
    return

  try:
    openapi_schema_validator.validate(fuzz_dict_instance, fuzz_dict_schema)
  except (jsonschema.exceptions._Error):
    pass


def main():
  atheris.instrument_all()
  atheris.Setup(sys.argv, TestOneInput)
  atheris.Fuzz()


if __name__ == "__main__":
  main()
