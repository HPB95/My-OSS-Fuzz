# Copyright 2019 Google LLC
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
"""Test the functionality of the DockerRepoManager class
The will consist of the following functional tests
  1. Test the construction and paring of a Docker image and a git repo
  2. Test that the class can create a docker image with a specific commit
"""

from DockerRepoManager import DockerRepoManager 
import unittest


class TestDockerRepoManager(unittest.TestCase):
  """Class to test the functionality of the DockerRepoManager class."""

  project_name = 'curl'

  def test_constructor(self):
    """Tests docker repo manager initilization."""
    curl_drm = DockerRepoManager(self.project_name)
    self.assertEqual(curl_drm.docker_image, 'gcr.io/oss-fuzz/curl')
    self.assertEqual(curl_drm.repo_url, 'https://github.com/curl/curl.git')
    self.assertEqual(curl_drm.src_on_image, '/src/curl')

  def test_get_image_commit(self):
    """Test that a specific commit can be transfered into a docker image."""
    curl_drm = DockerRepoManager(self.project_name)
    commit_to_test = 'bc5d22c3dede2f04870c37aec9a50474c4b888ad'
    curl_drm.checkout_commit(commit_to_test)
    self.assertEqual(curl_drm.get_image_commit(), commit_to_test)

  def test_infer_main_repo(self):
    """Test that infer_main_repo works for different docker files."""
    yara_drm = DockerRepoManager('yara')
    self.assertEqual(yara_drm.repo_url, 'https://github.com/VirusTotal/yara.git')
    libs_drm = DockerRepoManager('libspectre')
    self.assertEqual(libs_drm.repo_url, 'https://gitlab.freedesktop.org/libspectre/libspectre.git')
    liba_drm = DockerRepoManager('libass')
    self.assertEqual(liba_drm.repo_url, 'https://github.com/libass/libass.git')


if __name__ == '__main__':
  unittest.main()
