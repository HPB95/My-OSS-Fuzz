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
"""Module for dealing with docker."""
import os
import sys

# pylint: disable=wrong-import-position,import-error
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import utils

BASE_BUILDER_TAG = 'gcr.io/oss-fuzz-base/base-builder'
BASE_RUNNER_TAG = 'gcr.io/oss-fuzz-base/base-runner'
MSAN_LIBS_BUILDER_TAG = 'gcr.io/oss-fuzz-base/msan-libs-builder'
PROJECT_TAG_PREFIX = 'gcr.io/oss-fuzz/'

# Default fuzz configuration.
DEFAULT_ENGINE = 'libfuzzer'
DEFAULT_ARCHITECTURE = 'x86_64'
_DEFAULT_DOCKER_RUN_ARGS = [
    '--cap-add', 'SYS_PTRACE', '-e', 'FUZZING_ENGINE=' + DEFAULT_ENGINE, '-e',
    'ARCHITECTURE=' + DEFAULT_ARCHITECTURE, '-e', 'CIFUZZ=True'
]

_DEFAULT_DOCKER_RUN_COMMAND = [
    'docker',
    'run',
    '--rm',
    '--privileged',
]


def get_project_image_name(project):
  """Returns the name of the project builder image for |project_name|."""
  return PROJECT_TAG_PREFIX + project


def delete_images(images):
  """Deletes |images|."""
  command = ['docker', 'rmi', '-f'] + images
  utils.execute(command)
  utils.execute(['docker', 'builder', 'prune', '-f'])


def get_base_docker_run_args(out_dir, sanitizer='address', language='c++'):
  """Returns arguments that should be passed to every invocation of 'docker
  run'."""
  docker_args = _DEFAULT_DOCKER_RUN_ARGS.copy()
  docker_args += [
      '-e',
      f'SANITIZER={sanitizer}',
      '-e',
      f'FUZZING_LANGUAGE={language}',
  ]
  docker_container = utils.get_container_name()
  if docker_container:
    docker_args += ['--volumes-from', docker_container, '-e', 'OUT=' + out_dir]
  else:
    docker_args += get_args_mapping_host_path_to_container(out_dir, '/out')
  return docker_args, docker_container


def get_base_docker_run_command(out_dir, sanitizer='address', language='c++'):
  """Returns part of the command that should be used everytime 'docker run' is
  invoked."""
  docker_args, docker_container = get_base_docker_run_args(
      out_dir, sanitizer, language)
  command = _DEFAULT_DOCKER_RUN_COMMAND.copy() + docker_args
  return command, docker_container


def get_args_mapping_host_path_to_container(host_path, container_path=None):
  """Get arguments to docker run that will map |host_path| a path on the host to
  a path in the container. If |container_path| is specified, that path is mapped
  to. If not, then |host_path| is mapped to itself in the container."""
  container_path = host_path if container_path is None else container_path
  return ['-v', f'{host_path}:{container_path}']
