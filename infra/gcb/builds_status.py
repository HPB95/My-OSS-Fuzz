#!/usr/bin/env python2

import datetime
import os
import sys
import jinja2
import json
import tempfile
import time

import dateutil.parser
from oauth2client.client import GoogleCredentials
import googleapiclient
from googleapiclient.discovery import build as gcb_build
from google.cloud import logging
from google.cloud import storage
from jinja2 import Environment, FileSystemLoader

import build_project

STATUS_BUCKET = 'oss-fuzz-build-logs'
LOGS_BUCKET = 'oss-fuzz-gcb-logs'
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RETRY_COUNT = 3
RETRY_WAIT = 5


def usage():
  sys.stderr.write('Usage: ' + sys.argv[0] + ' <projects_dir>\n')
  exit(1)


def scan_project_names(projects_dir):
  projects = []
  for root, dirs, files in os.walk(projects_dir):
    for f in files:
      if f == 'Dockerfile':
        projects.append(os.path.basename(root))
  return sorted(projects)


def upload_status(successes, failures):
  """Upload main status page."""
  env = Environment(
      loader=FileSystemLoader(os.path.join(SCRIPT_DIR, 'templates')))
  data = {
      'projects': failures + successes,
      'failures': failures,
      'successes': successes,
      'last_updated': datetime.datetime.utcnow().ctime()
  }

  storage_client = storage.Client()
  bucket = storage_client.get_bucket(STATUS_BUCKET)

  blob = bucket.blob('status.html')
  blob.cache_control = 'no-cache'
  blob.upload_from_string(
      env.get_template('status_template.html').render(data),
      content_type='text/html')

  blob = bucket.blob('status.json')
  blob.cache_control = 'no-cache'
  blob.upload_from_string(json.dumps(data), content_type='application/json')


def is_build_successful(build):
  return build['status'] == 'SUCCESS'


def find_last_build(builds):
  DELAY_MINUTES = 40

  for build in builds:
    if build['status'] == 'WORKING':
      continue

    finish_time = dateutil.parser.parse(build['finishTime'], ignoretz=True)
    if (datetime.datetime.utcnow() - finish_time >=
        datetime.timedelta(minutes=DELAY_MINUTES)):
      storage_client = storage.Client()

      status_bucket = storage_client.get_bucket(STATUS_BUCKET)
      gcb_bucket = storage_client.get_bucket(build_project.GCB_LOGS_BUCKET)
      log_name = 'log-{0}.txt'.format(build['id'])
      log = gcb_bucket.blob(log_name)
      dest_log = status_bucket.blob(log_name)

      with tempfile.NamedTemporaryFile() as f:
        log.download_to_filename(f.name)
        dest_log.upload_from_filename(f.name, content_type='text/plain')

      return build

  return None


def execute_with_retries(request):
  for i in xrange(RETRY_COUNT + 1):
    try:
      return request.execute()
    except Exception as e:
      print('request failed with {0}, retrying...'.format(str(e)))
      if i < RETRY_COUNT:
        time.sleep(RETRY_WAIT)
        continue

      raise


def main():
  if len(sys.argv) != 2:
    usage()

  projects_dir = sys.argv[1]

  credentials = GoogleCredentials.get_application_default()
  cloudbuild = gcb_build('cloudbuild', 'v1', credentials=credentials)

  successes = []
  failures = []
  for project in scan_project_names(projects_dir):
    print project
    query_filter = ('images="gcr.io/oss-fuzz/{0}" AND tags="{1}"'.format(
        project, build_project.FUZZING_BUILD_TAG))
    try:
      response = execute_with_retries(cloudbuild.projects().builds().list(
          projectId='oss-fuzz', pageSize=2, filter=query_filter))
    except googleapiclient.errors.HttpError as e:
      print >> sys.stderr, 'Failed to list builds for', project, ':', str(e)
      continue

    if not 'builds' in response:
      continue

    builds = response['builds']

    last_build = find_last_build(builds)
    if not last_build:
      print >> sys.stderr, 'Failed to get build for', project
      continue

    print last_build['startTime'], last_build['status'], last_build['id']
    if is_build_successful(last_build):
      successes.append({
          'name': project,
          'build_id': last_build['id'],
          'finish_time': last_build['finishTime'],
          'success': True,
      })
    else:
      failures.append({
          'name': project,
          'build_id': last_build['id'],
          'finish_time': last_build['finishTime'],
          'success': False,
      })

  upload_status(successes, failures)


if __name__ == '__main__':
  main()
