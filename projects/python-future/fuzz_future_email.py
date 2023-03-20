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
#
##########################################################################
import sys
import json
import atheris

from future.backports.email.mime.multipart import MIMEMultipart
from future.backports.email.mime.text import MIMEText
from future.backports.email.utils import formatdate


def TestOneInput(data):
  fdp = atheris.FuzzedDataProvider(data)
  MIMEMultipart(fdp.ConsumeUnicodeNoSurrogates(fdp.ConsumeIntInRange(1, 1024)))
  MIMEText(fdp.ConsumeUnicodeNoSurrogates(fdp.ConsumeIntInRange(1, 1024)))

  try:
    formatdate(fdp.ConsumeUnicodeNoSurrogates(fdp.ConsumeIntInRange(1, 1024)))
  except TypeError:
    pass


def main():
  atheris.instrument_all()
  atheris.Setup(sys.argv, TestOneInput)
  atheris.Fuzz()


if __name__ == "__main__":
  main()
