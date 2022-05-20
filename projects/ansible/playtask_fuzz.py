#!/usr/bin/python3

# Copyright 2022 Google LLC
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
import atheris
with atheris.instrument_imports():
   from ansible.errors import AnsibleError, AnsibleParserError
   from ansible.playbook.play import Play
   from ansible.playbook.task import Task

def TestInput(input_bytes):
   fdp = atheris.FuzzedDataProvider(input_bytes)

   try:
      task1 = Task.load({'name': fdp.ConsumeString(10), 'shell': fdp.ConsumeString(10), 'action': fdp.ConsumeString(10)})
      task2 = Task.load({'name': fdp.ConsumeString(10), 'shell': fdp.ConsumeString(10), 'action': fdp.ConsumeString(10)})
      task3 = Task.load({'action': fdp.ConsumeString(10)})

      Play.load(dict(name=fdp.ConsumeString(10),hosts=[fdp.ConsumeString(5)],gather_facts=fdp.ConsumeBool(),tasks=[task1,task2,task3]))
   except Exception:
      pass
def main():
   atheris.Setup(sys.argv, TestInput, enable_python_coverage=True)
   atheris.Fuzz()

if __name__ == "__main__":
   main()
