# Copyright 2022 Google LLC
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

from typing import Optional
import functools
import re
import sys
import time

sanitizer_log_level = 0
def sanitizer_log(msg, log_level):
    global sanitizer_log_level
    if log_level >= sanitizer_log_level:
        print(f"[PYSAN] {msg}")

def hookObject(**methods):
  """function for hooking an object.

  This is needed for hooking built-in types and object attributes.

  Example use case is if we want to find ReDOS vulnerabilities, that
  have a pattern of

  ```
  import re
  r = re.compile(REGEX)
  for _ in r.findall(...)
  ```

  In the above case r.findall is a reference to
  re.Pattern.findall, which is a built-in type that is non-writeable.

  In order to hook such calls we need to wrap the object, and also hook the
  re.compile function to return the wrapped/hooked object.
  """

  class Wrapper(object):
    def __init__(self, instance):
      object.__setattr__(self, 'instance',instance)

    def __setattr__(self, name, value):
      object.__setattr__(object.__getattribute__(self,'instance'), name, value)

    def __getattribute__(self, name):
      instance = object.__getattribute__(self, 'instance')

      def _hook_func(self, pre_hook, post_hook, orig, *args, **kargs):
          if pre_hook is not None:
              pre_hook(self, *args, **kargs)
          # No need to pass instance here because when we extracted
          # the funcion we used instance.__getattribute__(name) which
          # seems to include it. I think.
          r = orig(*args, **kargs)

          if post_hook is not None:
              post_hook(self, *args, **kargs)
          return r

      # If this is a wrapped method, return a bound method
      if name in methods:
          pre_hook = methods[name][0]
          post_hook = methods[name][1]
          orig = instance.__getattribute__(name)
          return (
            lambda *args, **kargs: _hook_func(
                self, pre_hook, post_hook, orig, *args, **kargs
            )
          )

      # Otherwise, just return attribute of instance
      return instance.__getattribute__(name)

  return Wrapper

p = re.compile("a")

def hooked_re_findall_post(self, s):
    global starttime
    #print("In post hook")
    try:
        endtime = time.time() - starttime
        if endtime > 4:
            raise Exception("Potential ReDOS attack")
    except NameError:
        #print("For some reason starttime is not set, which it should have")
        sys.exit(1)
        pass

def hooked_re_findall(self, s):
    #print("In hooked")
    global starttime
    starttime = time.time()
    #time.sleep(5)
    #print(self.pattern)

    # Check if pattern + argument equals ReDOS
    #print(s)


def sanitize_hook(function, hook = None, post_hook = None, extra=None):
    """Hook a function.

    Hooks can be placed pre and post function call. At least one hook is
    needed.
    """
    if hook is None and post_hook is None:
        raise Exception("Some hooks must be included")

    @functools.wraps(function)
    def run(*args, **kwargs):
        sanitizer_log(f"Hook start {str(function)}", 0)
        # Call hook
        hook(*args, **kwargs)

        # Call the original function in the even the hook did not indicate
        # failure.
        ret = function(*args, **kwargs)

        # Ensure we hook object
        if extra == "hookrecompile":
            print("Hooking object's function")
            H = hookObject(findall = (hooked_re_findall, hooked_re_findall_post))
            ret = H(ret)
            #ret.findall = sanitize_hook(ret.findall, pysan_hook_re_compile)

        # Enable post hooking. This can be used to e.g. check
        # state of file system.
        if post_hook is not None:
            post_hook(*args, **kwargs)
        sanitizer_log(f"Hook end {str(function)}", 0)
        return ret
    return run


def check_code_injection_match(elem) -> Optional[str]:
    # Check exact match
    if elem == "exec-sanitizer":
        return "Explicit command injection found."

    # Check potential for injecting into a string
    if "FROMFUZZ" in elem:
        return "Fuzzer controlled content in data. Code injection potential."
    return None


def pysan_hook_subprocess_Popen(cmd, **kwargs):
    """Hook for subprocess.Popen"""
    # Check first argument
    if type(cmd) is str:
        res = check_code_injection_match(cmd)
        if res != None:
            raise Exception(
                    f"Potental code injection in subprocess.Popen\n{res}")
    if type(cmd) is list:
        for elem in cmd:
            res = check_code_injection_match(elem)
            if res != None:
                print(res)
                raise Exception(
                    f"Potential code injection in subprocess.Popen\n{res}")


def pysan_hook_os_system(cmd):
    """Hook for os.system"""
    res = check_code_injection_match(cmd)
    if res != None:
        raise Exception(f"Potential code injection by way of os.system\n{res}")


def pysan_hook_eval(cmd):
    """Hook for eval"""
    res = check_code_injection_match(cmd)
    if res != None:
        raise Exception(f"Potential code injection by way of eval\n{res}")

def pysan_hook_re_compile(pattern, flags=None):
    sanitizer_log("Inside re compile hook", 0)

    # Should we dosomething here in terms of setting return value?

def pysan_hook_re_pattern_findall(s):
    sanitizer_log("Inside re compile hook", 0)

def pysan_hook_re_findall(pattern, string, flags=0):
    sanitizer_log("Insider re findall hook")

def pysan_add_hook(target, pre_hook = None, post_hook = None, extra = None):
    return sanitize_hook(target, hook = pre_hook, post_hook = post_hook, extra = extra)


# Do the actual hooks
def pysan_add_hooks():
    #import re
    import os
    import subprocess
    #eval = pysan_add_hook(eval, pre_hook = pysan_hook_eval)
    #re.Pattern.findall = pysan_add_hook(re.Pattern.findall,
    #                            pre_hook = pysan_hook_re_pattern_findall)
    re.findall = pysan_add_hook(re.findall,
                                pre_hook = pysan_hook_re_findall)

    re.compile = pysan_add_hook(re.compile,
                                pre_hook = pysan_hook_re_compile,
                                extra = "hookrecompile")
    os.system = pysan_add_hook(os.system,
                               pre_hook = pysan_hook_os_system)
    subprocess.Popen = pysan_add_hook(subprocess.Popen,
                                      pre_hook = pysan_hook_subprocess_Popen)


pysan_add_hooks()
