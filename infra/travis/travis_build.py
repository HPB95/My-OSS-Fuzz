#!/usr/bin/env python
# Copyright 2019 Google Inc.
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
"""Build modified projects."""

from __future__ import print_function

import os
import re
import subprocess
import yaml

DEFAULT_ARCHITECTURES = ['x86_64']
DEFAULT_ENGINES = ['afl', 'libfuzzer']
DEFAULT_SANITIZERS = ['address', 'undefined']


def get_modified_projects():
  """Get a list of all the projects modified in this commit."""
  master_head_sha = subprocess.check_output(
      ['git', 'merge-base', 'HEAD', 'FETCH_HEAD']).decode().strip()
  output = subprocess.check_output(
      ['git', 'diff', '--name-only', 'HEAD', master_head_sha]).decode()
  projects_regex = '.*projects/(?P<name>.*)/.*\n'
  return set(re.findall(projects_regex, output))


def get_oss_fuzz_root():
  """Get the absolute path of the root of the oss-fuzz checkout."""
  script_path = os.path.realpath(__file__)
  return os.path.abspath(
      os.path.dirname(os.path.dirname(os.path.dirname(script_path))))


def execute_helper_command(helper_command):
  """Execute |helper_command| using helper.py."""
  root = get_oss_fuzz_root()
  script_path = os.path.join(root, 'infra', 'helper.py')
  command = ['python', script_path] + helper_command
  print('Running command: %s' % ' '.join(command))
  subprocess.check_call(command)


def build_fuzzers(project, engine, sanitizer, architecture):
  """Execute helper.py's build_fuzzers command on |project|. Build the fuzzers
  with |engine| and |sanitizer| for |architecture|."""
  execute_helper_command([
      'build_fuzzers', project, '--engine', engine, '--sanitizer', sanitizer,
      '--architecture', architecture
  ])


def check_build(project, engine, sanitizer, architecture):
  """Execute helper.py's check_build command on |project|, assuming it was most
  recently built with |engine| and |sanitizer| for |architecture|."""
  execute_helper_command([
      'check_build', project, '--engine', engine, '--sanitizer', sanitizer,
      '--architecture', architecture
  ])


def is_build(engine, sanitizer, architecture):
  """Is travis specifiying a build with fuzzing |engine|, |sanitizer|, and
  |architecture|?"""
  return (engine == os.getenv('TRAVIS_ENGINE') and
          sanitizer == os.getenv('TRAVIS_SANITIZER') and
          architecture == os.getenv('TRAVIS_ARCHITECTURE'))


def build_project(project):
  """Do the build of |project| that is specified by the TRAVIS_* environment
  variables (TRAVIS_SANITIZER, TRAVIS_ENGINE, and TRAVIS_ARCHITECTURE)."""
  root = get_oss_fuzz_root()
  project_yaml_path = os.path.join(root, 'projects', project, 'project.yaml')
  with open(project_yaml_path) as fp:
    project_yaml = yaml.safe_load(fp)

  if project_yaml.get('disabled', False):
    print('Project {0} is disabled, not building.'.format(project))
    return

  print('Building project', project)
  for architecture in project_yaml.get('architecture', DEFAULT_ARCHITECTURES):
    for engine in project_yaml.get('fuzzing_engines', DEFAULT_ENGINES):
      for sanitizer in project_yaml.get('sanitizers', DEFAULT_SANITIZERS):

        if not is_build(engine, sanitizer, architecture):
          continue

        build_fuzzers(project, engine, sanitizer, architecture)
        check_build(project, engine, sanitizer, architecture)


def main():
  projects = get_modified_projects()
  failed_projects = []
  for project in projects:
    try:
      build_project(project)
    except subprocess.CalledProcessError:
      failed_projects.append(project)

  if failed_projects:
    print('Failed projects:', ' '.join(failed_projects))
    exit(1)


if __name__ == '__main__':
  main()
