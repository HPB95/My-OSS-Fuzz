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
"""Module for determining coverage of fuzz targets."""
import logging
import os
import sys

import http_utils

# pylint: disable=wrong-import-position,import-error
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import utils

# pylint: disable=too-few-public-methods


class CoverageError(Exception):
  """Exceptions for project coverage."""


class BaseCoverage:
  """Gets coverage data for a project."""

  def __init__(self, repo_path):
    self.repo_path = _normalize_repo_path(repo_path)

  def get_files_covered_by_target(self, target):
    """Returns a list of source files covered by the specific fuzz target.

    Args:
      target: The name of the fuzz target whose coverage is requested.

    Returns:
      A list of files that the fuzz targets covers or None.
    """
    raise NotImplementedError('Child class must implement method.')


class OSSFuzzCoverage(BaseCoverage):
  """Gets coverage data for a project from OSS-Fuzz."""

  # The path to get OSS-Fuzz project's latest report json file.
  LATEST_COVERAGE_INFO_PATH = 'oss-fuzz-coverage/latest_report_info/'

  def __init__(self, repo_path, oss_fuzz_roject_name):
    """Constructor for OssFuzzCoverage. Callers should check that
    fuzzer_stats_url is initialized."""
    super().__init__(repo_path)
    self.oss_fuzz_project_name = oss_fuzz_project_name
    self.fuzzer_stats_url = self._get_fuzzer_stats_dir_url()
    if self.fuzzer_stats_url is None:
      raise CoverageError('Could not get latest coverage.')

  def get_target_coverage_report(self, target):
    """Get the coverage report for a specific fuzz target.

    Args:
      target: The name of the fuzz target whose coverage is requested.

    Returns:
      The target's coverage json dict or None on failure.
    """
    if not self.fuzzer_stats_url:
      return None

    target_url = utils.url_join(self.fuzzer_stats_url, target + '.json')
    return http_utils.get_json_from_url(target_url)

  def get_files_covered_by_target(self, target):
    """Gets a list of source files covered by the specific fuzz target.

    Args:
      target: The name of the fuzz target whose coverage is requested.

    Returns:
      A list of files that the fuzz targets covers or None.
    """
    target_cov = self.get_target_coverage_report(target)
    if not target_cov:
      return None

    coverage_per_file = get_coverage_per_file(target_cov)
    if not coverage_per_file:
      logging.info('No files found in coverage report.')
      return None

    affected_file_list = []
    for file_cov in coverage_per_file:
      norm_file_path = os.path.normpath(file_cov['filename'])
      if not norm_file_path.startswith(self.repo_path):
        # Exclude files outside of the main repo.
        continue

      if not is_file_covered(file_cov):
        # Don't consider a file affected if code in it is never executed.
        continue

      # TODO(metzman): It's weird to me that we access file_cov['filename']
      # again and not norm_file_path, figure out if this makes sense.
      relative_path = utils.remove_prefix(file_cov['filename'], self.repo_path)
      affected_file_list.append(relative_path)

    return affected_file_list

  def _get_fuzzer_stats_dir_url(self):
    """Gets latest coverage report info for a specific OSS-Fuzz project from
    GCS.

    Returns:
      The projects coverage report info in json dict or None on failure.
    """
    latest_cov_info = self._get_latest_cov_report_info()

    if not latest_cov_info:
      return None

    if 'fuzzer_stats_dir' not in latest_cov_info:
      logging.error('fuzzer_stats_dir not in latest coverage info.')
      return None

    fuzzer_stats_dir_gs_url = latest_cov_info['fuzzer_stats_dir']
    fuzzer_stats_dir_url = utils.gs_url_to_https(fuzzer_stats_dir_gs_url)
    return fuzzer_stats_dir_url

  def _get_latest_cov_report_info(self):
    """Gets and returns a dictionary containing the latest coverage report info
    for |project|."""
    latest_report_info_url = utils.url_join(utils.GCS_BASE_URL,
                                            self.LATEST_COVERAGE_INFO_PATH,
                                            self.oss_fuzz_project_name + '.json')
    latest_cov_info = http_utils.get_json_from_url(latest_report_info_url)
    if latest_cov_info is None:
      logging.error('Could not get the coverage report json from url: %s.',
                    latest_report_info_url)
      return None
    return latest_cov_info


class FilesystemCoverage(BaseCoverage):
  """Class that gets a project's coverage from the filesystem."""

  def __init__(self, repo_path, project_coverage_dir):
    super().__init__(repo_path)
    self.project_coverage_dir = project_coverage_dir

  def get_files_covered_by_target(self, target):
    """Returns a list of source files covered by the specific fuzz target.

    Args:
      target: The name of the fuzz target whose coverage is requested.

    Returns:
      A list of files that the fuzz targets covers or None.
    """
    # TODO(jonathanmetzman): Implement this.
    raise NotImplementedError('Implementation TODO.')


def is_file_covered(file_cov):
  """Returns whether the file is covered."""
  return file_cov['summary']['regions']['covered']


def get_coverage_per_file(target_cov):
  """Returns the coverage per file within |target_cov|."""
  return target_cov['data'][0]['files']


def _normalize_repo_path(repo_path):
  """Normalizes and returns |repo_path| to make sure cases like /src/curl and
  /src/curl/ are both handled."""
  repo_path = os.path.normpath(repo_path)
  if not repo_path.endswith('/'):
    repo_path += '/'
  return repo_path
