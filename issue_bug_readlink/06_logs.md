<details open><summary>Logs</summary>

Static analysis output that identified the bugs:

```console
$ flawfinder engine/src/flutter/fml/platform/linux/paths_linux.cc
engine/src/flutter/fml/platform/linux/paths_linux.cc:15:22:  [5] (race) readlink:
  This accepts filename arguments; if an attacker can move those files or
  change the link content, a race condition results. Also, it does not
  terminate with ASCII NUL. (CWE-362, CWE-20). Reconsider approach.

$ flawfinder engine/src/flutter/shell/platform/common/path_utils.cc
engine/src/flutter/shell/platform/common/path_utils.cc:26:20:  [5] (race) readlink:
  This accepts filename arguments; if an attacker can move those files or
  change the link content, a race condition results. Also, it does not
  terminate with ASCII NUL. (CWE-362, CWE-20). Reconsider approach.
```

Manual review against CERT POS30-C ("Use the readlink() function properly") confirmed:
- `paths_linux.cc`: 255-byte buffer violates the standard (should be `PATH_MAX`)
- `path_utils.cc`: Missing `-1` return check leads to undefined behavior

Note: The CWE-362 (TOCTOU race) flagged by flawfinder is a **false positive** for `/proc/self/exe` specifically — it is a kernel-managed symlink that cannot be redirected by userspace. The real bugs are the undersized buffer and the missing error check.

</details>
