# Copyright 2020 Google LLC
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
"""Tests for build.py"""

import os
import unittest
from unittest import mock

from ci import build


def patch_environ(testcase_obj):
  """Patch environment."""
  env = {}
  patcher = mock.patch.dict(os.environ, env)
  testcase_obj.addCleanup(patcher.stop)
  patcher.start()


class TestShouldBuild(unittest.TestCase):
  def setUp(self):
    patch_environ(self)

  def _set_coverage_build(self):
    os.environ['SANITIZER'] = 'coverage'
    os.environ['ENGINE'] = 'libfuzzer'
    os.environ['ARCHITECTURE'] = 'x86_64'

  def test_none_engine_coverage_build(self):
    """Tests that should_build returns False for a coverage build of a
    project that specifies 'none' for fuzzing_engines."""
    self._set_coverage_build()
    project_yaml = {'language': 'c++', 'fuzzing_engines': ['none'], 'sanitizers': ['address']}
    self.assertFalse(build.should_build(project_yaml))

  def test_unspecified_engines_coverage_build(self):
    """Tests that should_build returns True for a coverage build of a
    project that doesn't specify fuzzing_engines."""
    self._set_coverage_build()
    project_yaml = {'language': 'c++'}
    self.assertTrue(build.should_build(project_yaml))

  def test_libfuzzer_coverage_build(self):
    """Tests that should_build returns True for coverage build of a project
    specifying 'libfuzzer' and for fuzzing_engines."""
    self._set_coverage_build()
    project_yaml = {'language': 'c++', 'fuzzing_engines': ['libfuzzer'], 'sanitizers': ['address']}
    self.assertTrue(build.should_build(project_yaml))

  def test_go_coverage_build(self):
    """Tests that should_build returns False for coverage build of a project
    specifying 'libfuzzer' and for fuzzing_engines."""
    self._set_coverage_build()
    project_yaml = {'language': 'go'}
    self.assertFalse(build.should_build(project_yaml))
