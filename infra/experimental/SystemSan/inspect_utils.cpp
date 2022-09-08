/*
 * Copyright 2022 Google LLC

 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at

 *      http://www.apache.org/licenses/LICENSE-2.0

 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
/* A detector that uses ptrace to identify DNS arbitrary resolutions. */

/* C standard library */
#include <signal.h>

/* POSIX */
#include <unistd.h>

/* Linux */
#include <sys/ptrace.h>

#include <iostream>
#include <string>
#include <vector>

extern pid_t g_root_pid;

std::vector<std::byte> read_memory(pid_t pid, unsigned long long address,
                                   size_t size) {
  std::vector<std::byte> memory;

  for (size_t i = 0; i < size; i += sizeof(long)) {
    long word = ptrace(PTRACE_PEEKTEXT, pid, address + i, 0);
    if (word == -1) {
      return memory;
    }

    std::byte *word_bytes = reinterpret_cast<std::byte *>(&word);
    memory.insert(memory.end(), word_bytes, word_bytes + sizeof(long));
  }

  return memory;
}

void report_bug(std::string bug_type) {
  // Report the bug found based on the bug code.
  std::cerr << "===BUG DETECTED: " << bug_type.c_str() << "===\n";
  // Rely on sanitizers/libFuzzer to produce a stacktrace by sending SIGABRT
  // to the root process.
  // Note: this may not be reliable or consistent if shell injection happens
  // in an async way.
  tgkill(g_root_pid, g_root_pid, SIGABRT);
}
