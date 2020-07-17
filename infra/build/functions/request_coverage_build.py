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
"""Cloud function that requests coverage builds."""

import google.auth
from google.cloud import ndb

import build_and_run_coverage
import build_lib
from datastore_entities import Project
import request_build

BASE_PROJECT = 'oss-fuzz-base'


def get_coverage_build_steps(project_name, project_yaml_contents,
                             dockerfile_lines, image_project,
                             base_images_project):
  """Retrieve coverage build steps."""
  build_steps = build_and_run_coverage.get_build_steps(project_name,
                                                       project_yaml_contents,
                                                       dockerfile_lines,
                                                       image_project,
                                                       base_images_project)
  return build_steps


def request_coverage_build(event, context):
  """Entry point for coverage build cloud function."""
  del event, context  #unused

  with ndb.Client().context():

    credentials, image_project = google.auth.default()
    for project in Project.query():
      project_name = project.name
      project_yaml_contents = project.project_yaml_contents
      dockerfile_content = project.dockerfile_content
      dockerfile_lines = dockerfile_content.split('\n')

      build_steps = get_coverage_build_steps(project_name,
                                             project_yaml_contents,
                                             dockerfile_lines, image_project,
                                             BASE_PROJECT)
      request_build.run_build(project_name, image_project, build_steps,
                              build_lib.BUILD_TIMEOUT, credentials, '-coverage')
