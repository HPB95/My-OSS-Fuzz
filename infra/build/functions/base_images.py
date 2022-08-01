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
"""Cloud function to build base images on Google Cloud Builder."""
import logging

import google.auth

import build_lib

BASE_IMAGES = [
    'base-image',
    'base-clang',
    'base-builder',
    'base-builder-go',
    'base-builder-go-codeintelligencetesting',
    'base-builder-jvm',
    'base-builder-python',
    'base-builder-rust',
    'base-builder-swift',
    'base-runner',
    'base-runner-debug',
]
INTROSPECTOR_BASE_IMAGES = ['base-clang', 'base-builder']
BASE_PROJECT = 'oss-fuzz-base'
TAG_PREFIX = f'gcr.io/{BASE_PROJECT}/'
MAJOR_TAG = 'v1'
INTROSPECTOR_TAG = 'introspector'
TIMEOUT = str(6 * 60 * 60)
INTROSPECTOR_ARG = ['--build-arg', 'introspector=1']


def get_base_image_steps(images, tag_prefix=TAG_PREFIX):
  """Returns build steps for given images."""
  steps = [build_lib.get_git_clone_step()]

  for base_image in images:
    image = tag_prefix + base_image
    tagged_image = image + ':' + MAJOR_TAG
    steps.append(
        build_lib.get_docker_build_step([image, tagged_image],
                                        'infra/base-images/' + base_image))
  return steps

def get_image_tags(name, test_image_suffix=None, introspector=False):
  tags = [TAG_PREFIX + image]
  if test_image_suffix:
    tag = tags[0]
    tags.append(tag + '-' + test_image_suffix)
  if introspector:

  return tags


def get_introspector_base_images_steps(
    clone=True, test_image_suffix=None, tag_prefix=TAG_PREFIX):
  """Returns build steps for given images version of introspector."""
  steps = []
  if clone:
    steps.append(build_lib.get_clone_step())

  for base_image in images:
    image = tag_prefix + base_image
    args_list = ['build']

  steps += [
    ['build', '--build-arg', 'introspector=1'],
  ]

    if base_image == 'base-clang':
      args_list.extend(INTROSPECTOR_ARG)
    elif base_image == 'base-builder':
      steps.append({
          'name':
              'gcr.io/cloud-builders/docker',
          'args': [
              'tag', 'gcr.io/oss-fuzz-base/base-clang:introspector',
              'gcr.io/oss-fuzz-base/base-clang:latest'
          ]
      })

    args_list.extend([
        '-t',
        f'{image}:{INTROSPECTOR_TAG}',
        '.',
    ])
    steps.append({
        'args': args_list,
        'dir': 'oss-fuzz/infra/base-images/' + base_image,
        'name': 'gcr.io/cloud-builders/docker',
    })

  return steps


# pylint: disable=no-member
def run_build(steps, images, tags=None, build_version=MAJOR_TAG):
  """Execute the retrieved build steps in gcb."""
  credentials, _ = google.auth.default()
  body_overrides = {
      'images': images + [f'{image}:{build_version}' for image in images],
      'options': {
          'machineType': 'E2_HIGHCPU_32'
      },
  }
  return build_lib.run_build(steps,
                             credentials,
                             BASE_PROJECT,
                             TIMEOUT,
                             body_overrides,
                             tags,
                             use_build_pool=False)


def base_builder(event, context):
  """Cloud function to build base images."""
  del event, context
  logging.basicConfig(level=logging.INFO)

  steps = get_base_image_steps(BASE_IMAGES)
  images = [TAG_PREFIX + base_image for base_image in BASE_IMAGES]
  run_build(steps, images)

  introspector_steps = get_introspector_base_images_steps()
  introspector_images = [
      TAG_PREFIX + base_image for base_image in INTROSPECTOR_BASE_IMAGES
  ]

  run_build(introspector_steps,
            introspector_images,
            tags=INTROSPECTOR_TAG,
            build_version=INTROSPECTOR_TAG)
