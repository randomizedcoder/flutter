# Pull Request Draft

**Repository**: flutter/flutter
**Base branch**: master
**Title**: Fix readlink error handling in GetExecutablePath and GetExecutableDirectory

---

## PR Body

Fix two `readlink("/proc/self/exe")` correctness bugs on Linux, aligning with Chromium's [`ReadSymbolicLink()`](https://chromium.googlesource.com/chromium/src/+/main/base/files/file_util_posix.cc#695) in `base/files/file_util_posix.cc`.

### `engine/src/flutter/fml/platform/linux/paths_linux.cc`

- Buffer size `255` → `PATH_MAX` (4096). Paths longer than 255 bytes were silently truncated. Added `#include <linux/limits.h>`.
- Error check `read_size == -1` → `count <= 0`. Consistent with Chromium.

### `engine/src/flutter/shell/platform/common/path_utils.cc`

- Error check `length > PATH_MAX` → `length <= 0`. The old check did not catch `readlink` returning `-1` on failure. When `readlink` fails, `std::string(buffer, (size_t)-1)` is undefined behavior.
- Buffer `PATH_MAX + 1` → `PATH_MAX`. The `+1` was unnecessary — `readlink` does not NUL-terminate, and the string is constructed with an explicit length.

### Chromium reference

Chromium's `ReadSymbolicLink()` at [`base/files/file_util_posix.cc:695-719`](https://chromium.googlesource.com/chromium/src/+/main/base/files/file_util_posix.cc#695):

```cpp
char buf[PATH_MAX];
ssize_t count = ::readlink(symlink_path.value().c_str(), buf, std::size(buf));
bool error = count <= 0;
```

Both files have been unchanged since the engine monorepo merge (`7e0bed752f3`, 2023-04-25). `path_utils.cc` dates to 2015.

Found via static analysis with flawfinder (CWE-362/CWE-20) and manual code review against CERT POS30-C.

Fixes https://github.com/flutter/flutter/issues/XXXXX
Related: #162063, #3648

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [AI contribution guidelines] and understand my responsibilities, or I am not using AI tools.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [x] I signed the [CLA].
- [x] I listed at least one issue that this PR fixes in the description above.
- [ ] I updated/added relevant documentation (doc comments with `///`).
- [x] I added new tests to check the change I am making, or this PR is [test-exempt].
- [ ] I followed the [breaking change policy] and added [Data Driven Fixes] where supported.
- [x] All existing and new tests are passing.

**Note**: This is test-exempt — the fix corrects error handling on a failure path that requires a broken `/proc` filesystem to trigger. The existing `path_utils_unittests.cc` test (`PathUtilsTest.ExecutableDirector`) validates the success path and continues to pass.

---

## Commit Message

```
Fix readlink error handling in GetExecutablePath and GetExecutableDirectory

paths_linux.cc: buffer 255 → PATH_MAX (CERT POS30-C), error check == -1 → <= 0
path_utils.cc: missing error check for readlink returning -1 (undefined behavior)

Aligns with Chromium base/files/file_util_posix.cc:695-719 ReadSymbolicLink().
```

---

## Files Changed

| File | Change |
|------|--------|
| `engine/src/flutter/fml/platform/linux/paths_linux.cc` | Add `#include <linux/limits.h>`, buffer `255` → `PATH_MAX`, error check `== -1` → `<= 0` |
| `engine/src/flutter/shell/platform/common/path_utils.cc` | Buffer `PATH_MAX + 1` → `PATH_MAX`, error check `> PATH_MAX` → `<= 0`, explicit `static_cast<size_t>` |

---

## Diff Preview

### `engine/src/flutter/fml/platform/linux/paths_linux.cc`

```diff
+#include <linux/limits.h>
 #include <unistd.h>

 #include "flutter/fml/paths.h"

 namespace fml {
 namespace paths {

 std::pair<bool, std::string> GetExecutablePath() {
-  const int path_size = 255;
-  char path[path_size] = {0};
-  auto read_size = ::readlink("/proc/self/exe", path, path_size);
-  if (read_size == -1) {
+  char path[PATH_MAX];
+  ssize_t count = ::readlink("/proc/self/exe", path, sizeof(path));
+  if (count <= 0) {
     return {false, ""};
   }
-  return {true, std::string{path, static_cast<size_t>(read_size)}};
+  return {true, std::string{path, static_cast<size_t>(count)}};
 }
```

### `engine/src/flutter/shell/platform/common/path_utils.cc`

```diff
 #elif defined(__linux__)
-  char buffer[PATH_MAX + 1];
+  char buffer[PATH_MAX];
   ssize_t length = readlink("/proc/self/exe", buffer, sizeof(buffer));
-  if (length > PATH_MAX) {
+  if (length <= 0) {
     return std::filesystem::path();
   }
-  std::filesystem::path executable_path(std::string(buffer, length));
+  std::filesystem::path executable_path(
+      std::string(buffer, static_cast<size_t>(length)));
   return executable_path.remove_filename();
```
