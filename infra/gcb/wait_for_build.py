#!/usr/bin/python2

"""Waits for project build on Google Cloud Builder.

Usage: wait_for_build.py <build_id>
"""

import json
import sys
import time
import threading

from google.cloud import logging
from google.cloud import pubsub
from googleapiclient.discovery import build
from oauth2client.client import GoogleCredentials

POLL_INTERVAL = 30


def usage():
  sys.stderr.write(
    "Usage: " + sys.argv[0] + " <build_id>\n")
  exit(1)


def create_log_subscription(log_topic, build_id):
  log_sub = log_topic.subscription('build-sub-' + build_id)
  if log_sub.exists():
    log_sub.delete()

  log_sub.create()
  return log_sub


def poll_build_status_thread(build_id):
  credentials = GoogleCredentials.get_application_default()
  cloudbuild = build('cloudbuild', 'v1', credentials=credentials)

  while True:
    build_info = cloudbuild.projects().builds().get(
        projectId='clusterfuzz-external', id=build_id).execute()
    status = build_info['status']
    if status == 'SUCCESS':
      print status
      exit(0)

    if status == 'FAILURE':
      print status
      exit(1)

    time.sleep(POLL_INTERVAL)


def main():
  if len(sys.argv) != 2:
    usage()

  build_id = sys.argv[1]

  pubsub_client = pubsub.Client()
  log_topic = pubsub_client.topic('build-logs-' + build_id)
  assert log_topic.exists()

  status_thread = threading.Thread(target=poll_build_status_thread, args=(build_id,))
  status_thread.start()

  log_sub = create_log_subscription(log_topic, build_id)
  while True:
    pulled = log_sub.pull(max_messages=32)
    for ack_id, message in pulled:
      print json.loads(message.data)['textPayload']
      log_sub.acknowledge([ack_id])


if __name__ == "__main__":
  main()
