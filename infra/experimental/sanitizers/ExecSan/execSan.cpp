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
/* A detector that uses ptrace to identify shell injection vulnerabilities. */

/* C standard library */
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <signal.h>

/* POSIX */
#include <unistd.h>
#include <sys/stat.h>
#include <sys/user.h>
#include <sys/wait.h>

/* Linux */
#include <syscall.h>
#include <sys/ptrace.h>

#include <fstream>
#include <string>
#include <map>
#include <vector>
#include <set>
#include <sstream>
#include <iostream>

#define DEBUG_LOGS 0

#if DEBUG_LOGS
#define debug_log(...) \
  do { \
    fprintf(stderr, __VA_ARGS__); fflush(stdout); \
    fputc('\n', stderr); \
  } while (0)
#else
#define debug_log(...)
#endif

#define fatal_log(...) \
  do { \
    fprintf(stderr, __VA_ARGS__); \
    fputc('\n', stderr); \
    exit(EXIT_FAILURE); \
  } while (0)

// The magic string that we'll use to detect full control over the command
// executed.
const std::string kTripWire = "/tmp/tripwire";
// Shell injection bug confirmed with /tmp/tripwire.
const std::string kInjectionError = "Shell injection";
// Shell corruption bug detected based on syntax error.
const std::string kCorruptionError = "Shell corruption";

// The PID of the root process we're fuzzing.
pid_t g_root_pid;
// Assuming the longest pathname is "/bin/bash".
constexpr int kShellPathnameLength = 10;
// Assuming the syntax error pattern is
// within the first 100 chars of the write buffer.
constexpr int kErrorMessageLength = 100;

// Syntax error messages of each shell.
const std::map<std::string, std::set<std::string>> kShellSyntaxErrors = {
  {
    "sh",
    {
      ": command not found",  // General
      ": syntax error",       // Unfinished " or ' or ` or if, leading | or ;
      ": missing"             // Unfinished [
      ": event not found",    // ! leads large numbers
      ": No such file",       // Leading < or /
    }
  },
  {
    "bash",
    {
      ": command not found",  // General
      ": syntax error",       // Unfinished " or ' or ` or if, leading | or ;
      ": missing"             // Unfinished [
      ": event not found",    // ! leads large numbers
      ": No such file",       // Leading < or /
    }
  },
  {
    "csh",
    {
      ": Command not found",        // General
      "Unmatched",                  // Unfinished " or ' or `, leading ;
      ": Missing",                  // Unfinished {
      "Too many",                   // Unfinished (
      "No match",                   // Leading [
      "Invalid null command",       // Leading | or < or >
      "Missing name for redirect"   // Single < or >
      ": No match",                 // Leading ? or [ or *
      "Modifier failed",            // Leading ^
      ": No such job",              // Leading %
      ": Undefined variable",       // Containing $
      ": Event not found",          // ! leads large numbers
    }
  },
  {
    "dash",
    {
      ": not found",     // General
      ": Syntax error",  // Unfinished " or ' or ` or if, leading | or ; or &
      ": missing"        // Unfinished [
      ": No such file",  // Leading <
    }
  },
  {
    "zsh",
    {
      ": command not found",               // General
      ": syntax error",                    // Unfinished " or ' or `
      " expected"                          // Unfinished [
      ": no such file or directory",       // Leading < or /
      ": parse error",                     // Leading |, or &
      ": no such user or named directory", // Leading ~
    }
  },
};

// Shells used by Processes.
std::map<pid_t, std::string> g_shell_pids;

struct Tracee {
  pid_t pid;
  bool syscall_enter = true;

  Tracee(pid_t pid) : pid(pid) {}
};

pid_t run_child(char **argv) {
  // Run the program under test with its args as a child process
  pid_t pid = fork();
  switch (pid) {
    case -1:
      fatal_log("Fork failed: %s", strerror(errno));
    case 0:
      raise(SIGSTOP);
      execv(argv[0], argv);
      fatal_log("execv: %s", strerror(errno));
  }
  return pid;
}

std::vector<std::byte> read_memory(pid_t pid, unsigned long long address, size_t size) {
  std::vector<std::byte> memory;

  for (size_t i = 0; i < size; i += sizeof(long)) {
    long word = ptrace(PTRACE_PEEKTEXT, pid, address + i, 0);
    if (word == -1) {
      return memory;
    }

    std::byte *word_bytes = reinterpret_cast<std::byte*>(&word);
    memory.insert(memory.end(), word_bytes, word_bytes+sizeof(long));
  }

  return memory;
}

// Construct a string with the memory specified in a register.
std::string read_string(pid_t pid, unsigned long reg, unsigned long length) {
  auto memory = read_memory(pid, reg, length);
  if (!memory.size()) {
    return "";
  }

  std::string content(reinterpret_cast<char*>(
        memory.data()), std::min(memory.size(), length));
  return content;
}

void report_bug(std::string bug_type) {
  // Report the bug found based on the bug code.
  std::cerr << "===BUG DETECTED: " << bug_type.c_str() << "===\n";
  // Rely on sanitizers/libFuzzer to produce a stacktrace by sending SIGABRT
  // to the root process.
  // Note: this may not be reliable or consistent if shell injection happens
  // in an async way.
  kill(g_root_pid, SIGABRT);
  _exit(0);
}

void inspect_for_injection(pid_t pid, const user_regs_struct &regs) {
  // Inspect a PID's registers for the sign of shell injection.
  std::string path = read_string(pid, regs.rdi, kTripWire.length());
  if (!path.length()) {
    return;
  }
  debug_log("inspecting");
  if (path == kTripWire) {
    report_bug(kInjectionError);
  }
}

std::string get_pathname(pid_t pid, const user_regs_struct &regs) {
  // Parse the pathname from the memory specified in the RDI register.
  std::string raw_content = read_string(pid, regs.rdi, kShellPathnameLength);

  std::string pathname = raw_content.substr(0, raw_content.find(" "));
  debug_log("Pathname is %s (len %lu)\n", pathname.c_str(), pathname.length());
  return pathname;
}

std::string match_shell(std::string binary_pathname) {
  // Identify the name of the shell used in the pathname.
  for (auto it = kShellSyntaxErrors.begin(); it != kShellSyntaxErrors.end(); ++it) {
    std::string known_shell = it->first;
    std::string binary_name = binary_pathname.substr(binary_pathname.find_last_of("/") + 1, known_shell.length());
    if (binary_name == known_shell) {
      debug_log("Matched %s\n", binary_name.c_str());
      return known_shell;
    }
  }
  return "";
}

std::string get_shell(pid_t pid, const user_regs_struct &regs) {
  // Get shell name used in a process.
  std::string binary_pathname = get_pathname(pid, regs);
  if (binary_pathname.length()) {
    return match_shell(binary_pathname);
  }
  return "";
}

void match_error_pattern(std::string buffer, std::string shell) {
  auto error_patterns = kShellSyntaxErrors.at(shell);
  for(auto it = error_patterns.begin(); it != error_patterns.end(); ++it) {
    debug_log("Pattern : %s\n", it->c_str());
    debug_log("Found at: %lu\n", buffer.find(*it));
    if(buffer.find(*it) != std::string::npos) {
      buffer = buffer.substr(0, buffer.find("\n"));
      printf("--- Found a sign of shell corruption ---\n"
             "%s\n"
             "----------------------------------------\n", buffer.c_str());
      report_bug(kCorruptionError);
    }
  }
}

void inspect_for_corruption(pid_t pid, const user_regs_struct &regs) {
  // Inspect a PID's registers for shell corruption.
  std::string buffer = read_string(pid, regs.rsi, kErrorMessageLength);
  debug_log("Write buffer: %s\n", buffer.c_str());
  match_error_pattern(buffer, g_shell_pids[pid]);
}

void trace(std::map<pid_t, Tracee> pids) {
  while (!pids.empty()) {
    std::vector<pid_t> new_pids;

    auto it = pids.begin();

    while (it != pids.end()) {
      auto pid = it->first;
      auto &tracee = it->second;
      int status = 0;

      int result = waitpid(pid, &status, __WALL | WNOHANG);
      if (result == -1) {
        it = pids.erase(it);
        continue;
      }

      if (result == 0) {
        // Nothing to report yet.
        ++it;
        continue;
      }

      debug_log("finished waiting %d", pid);

      if (WIFEXITED(status) || WIFSIGNALED(status)) {
        debug_log("%d exited", pid); 
        it = pids.erase(it);
        // Remove pid from the watchlist when it exits
        g_shell_pids.erase(pid);
        continue;
      }

      // ptrace sets 0x80 for syscalls (with PTRACE_O_TRACESYSGOOD set).
      bool is_syscall = WIFSTOPPED(status) && WSTOPSIG(status) == (SIGTRAP | 0x80);
      int sig = 0;
      if (!is_syscall) {
        // Handle generic signal.
        siginfo_t siginfo;
        if (ptrace(PTRACE_GETSIGINFO, pid, nullptr, &siginfo) == -1) {
          debug_log("ptrace(PTRACE_GETSIGINFO, %d): %s", pid, strerror(errno));
          continue;
        }
        sig = siginfo.si_signo;
        debug_log("forwarding signal %d to %d", sig, pid);
      }

      if (WIFSTOPPED(status) && 
          (status>>8 == (SIGTRAP | (PTRACE_EVENT_CLONE<<8)) ||
           status>>8 == (SIGTRAP | (PTRACE_EVENT_FORK<<8)) ||
           status>>8 == (SIGTRAP | (PTRACE_EVENT_VFORK<<8)))) {
        long new_pid;
        if (ptrace(PTRACE_GETEVENTMSG, pid, 0, &new_pid) == -1) {
          debug_log("ptrace(PTRACE_GETEVENTMSG, %d): %s", pid, strerror(errno));
          continue;
        }
        debug_log("forked %ld", new_pid);
        new_pids.push_back(new_pid);
      }

      if (is_syscall) {
        user_regs_struct regs;
        if (ptrace(PTRACE_GETREGS, pid, 0, &regs) == -1) {
          debug_log("ptrace(PTRACE_GETREGS, %d): %s", pid, strerror(errno));
          continue;
        }

        if (tracee.syscall_enter) {
          if (regs.orig_rax == __NR_execve) {
            inspect_for_injection(pid, regs);
            std::string shell = get_shell(pid, regs);
            if (shell != "") {
              debug_log("Shell parsed: %s", shell.c_str());
              g_shell_pids.insert(std::make_pair(pid, shell));
            }
          }

          if (regs.orig_rax == __NR_write && g_shell_pids.find(pid) != g_shell_pids.end()) {
            debug_log("Inspecting the `write` buffer of shell process %d.", pid);
            inspect_for_corruption(pid, regs);
          }
        }

        // TODO: Check for commands with invalid syntax passed to /bin/sh and
        // other shells.
        // TODO: It's possible the process we're fuzzing can communicate with
        // another process to execute code. Our check wouldn't catch this
        // currently.
        tracee.syscall_enter = !tracee.syscall_enter;
      }

      debug_log("tracing %d %d", pid, sig);
      if (ptrace(PTRACE_SYSCALL, pid, nullptr, sig) == -1) {
        debug_log("ptrace(PTRACE_SYSCALL, %d): %s", pid, strerror(errno));
        continue;
      }

      ++it;
    }

    for (const auto &pid : new_pids) {
      pids.emplace(pid, Tracee(pid));
    }
  }
}

int main(int argc, char **argv) {
  if (argc <= 1) {
    fatal_log("Expecting at least one arguments, received %d", argc - 1);
  }

  // Create an executable tripwire file, as programs may check for existence
  // before actually calling exec.
  std::ofstream tripwire(kTripWire);
  tripwire.close();
  chmod(kTripWire.c_str(), 0755);

  pid_t pid = run_child(argv + 1);

  long options = 
    PTRACE_O_TRACESYSGOOD
    | PTRACE_O_TRACEFORK
    | PTRACE_O_TRACEVFORK
    | PTRACE_O_TRACECLONE;

  if (ptrace(PTRACE_SEIZE, pid, nullptr, options) == -1) {
    fatal_log("ptrace(PTRACE_SEIZE): %s", strerror(errno));
  }

  if (waitpid(pid, nullptr, __WALL) == -1) {
    fatal_log("waitpid: %s", strerror(errno));
  }

  if (ptrace(PTRACE_SYSCALL, pid, 0, 0) == -1) {
    fatal_log("ptrace(PTRACE_SYSCALL): %s", strerror(errno));
  }

  g_root_pid = pid;
  std::map<pid_t, Tracee> pids;
  pids.emplace(pid, Tracee(pid));
  trace(pids);
}
