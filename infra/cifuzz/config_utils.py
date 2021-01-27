# Copyright 2021 Google LLC
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
"""Module for getting the configuration CIFuzz needs to run."""

import logging
import enum
import os
import json


def _get_project_repo_name():
  return os.path.basename(os.getenv('GITHUB_REPOSITORY'))


def _get_pr_ref(event):
  if event == 'pull_request':
    return os.getenv('GITHUB_REF')
  return None


def _get_sanitizer():
  return os.getenv('SANITIZER', 'address').lower()


def _get_project_name():
  # TODO(metzman): Remove OSS-Fuzz reference.
  return os.getenv('OSS_FUZZ_PROJECT_NAME')


class Config:  # pylint: disable=too-few-public-methods,too-many-instance-attributes
  """Object containing constant configuration for CIFuzz."""

  class Platform(enum.Enum):
    """Enum representing the different platforms CIFuzz runs on."""
    EXTERNAL_GITHUB = 0  # Non-OSS-Fuzz on GitHub actions.
    INTERNAL_GITHUB = 1  # OSS-Fuzz on GitHub actions.
    INTERNAL_GENERIC_CI = 2  # OSS-Fuzz on any CI.

  def _get_config_from_event_path(self, event):
    event_path = os.getenv('GITHUB_EVENT_PATH')
    if not event_path:
      return
    with open(event_path, encoding='utf-8') as file_handle:
      event_data = json.load(file_handle)
    if event == 'push':
      self.base_commit = event_data['before']

    self.git_url = event_data['repository']['git_url']

  def __init__(self):
    """Get the configuration from CIFuzz from the environment. These variables
    are set by GitHub or the user."""
    self.project_name = _get_project_name()
    self.project_repo_name = _get_project_repo_name()
    self.commit_sha = os.getenv('GITHUB_SHA')

    event = os.getenv('GITHUB_EVENT')
    self.is_github = bool(event)
    self.pr_ref = _get_pr_ref(event)

    self.git_url = None
    self.base_commit = None
    self._get_config_from_event_path(event)

    self.base_commit = None
    self.base_ref = os.getenv('GITHUB_BASE_REF')

    self.workspace = os.getenv('GITHUB_WORKSPACE')
    self.project_src_path = get_project_src_path(self.workspace)

    self.sanitizer = _get_sanitizer()
    self.build_integration_path = os.getenv('BUILD_INTEGRATION_PATH')
    self.allowed_broken_targets_percentage = os.getenv(
        'ALLOWED_BROKEN_TARGETS_PERCENTAGE')
    # Check if failures should not be reported.
    self.dry_run = _is_dry_run()

  @property
  def platform(self):
    """Returns the platform CIFuzz is runnning on."""
    if self.build_integration_path:
      return self.Platform.EXTERNAL_GITHUB
    if self.is_github:
      return self.Platform.INTERNAL_GITHUB
    return self.Platform.INTERNAL_GENERIC_CI


def _is_dry_run():
  """Returns True if configured to do a dry run."""
  return os.getenv('DRY_RUN').lower() == 'true'


def get_project_src_path(workspace):
  """Returns the manually checked out path of the project's source if specified
  or None."""
  # TODO(metzman): Get rid of MANUAL_SRC_PATH when Skia switches to
  # PROJECT_SRC_PATH.
  path = os.getenv('PROJECT_SRC_PATH', os.getenv('MANUAL_SRC_PATH'))
  if not path:
    logging.debug('No PROJECT_SRC_PATH.')
    return path

  logging.debug('PROJECT_SRC_PATH set.')
  if os.path.isabs(path):
    return path

  # If |src| is not absolute, assume we are running in GitHub actions.
  # TODO(metzman): Don't make this assumption.
  return os.path.join(workspace, path)
