# GitHub Issue Draft

**Repository**: flutter/flutter
**Title**: Fix readlink error handling in GetExecutablePath and GetExecutableDirectory on Linux

---

## Description

Two `readlink("/proc/self/exe")` call sites in the engine have correctness bugs:

### Bug 1: Undersized buffer in `fml/platform/linux/paths_linux.cc:12-19`

```cpp
std::pair<bool, std::string> GetExecutablePath() {
  const int path_size = 255;          // <-- should be PATH_MAX (4096)
  char path[path_size] = {0};
  auto read_size = ::readlink("/proc/self/exe", path, path_size);
  if (read_size == -1) {
    return {false, ""};
  }
  return {true, std::string{path, static_cast<size_t>(read_size)}};
}
```

The buffer is 255 bytes. `PATH_MAX` on Linux is 4096. Any executable path longer than 255 bytes is silently truncated. This violates CERT POS30-C.

### Bug 2: Missing error check in `shell/platform/common/path_utils.cc:24-31`

```cpp
char buffer[PATH_MAX + 1];
ssize_t length = readlink("/proc/self/exe", buffer, sizeof(buffer));
if (length > PATH_MAX) {             // <-- does not catch length == -1
  return std::filesystem::path();
}
std::filesystem::path executable_path(std::string(buffer, length));
```

If `readlink` fails, it returns `-1`. The check `length > PATH_MAX` does not catch this. `std::string(buffer, (size_t)-1)` is undefined behavior — `(size_t)-1` is 18446744073709551615 on 64-bit, causing either a massive allocation attempt or a crash.

### Chromium reference

Chromium's `ReadSymbolicLink()` in [`base/files/file_util_posix.cc:695-719`](https://chromium.googlesource.com/chromium/src/+/main/base/files/file_util_posix.cc#695) handles this correctly:

```cpp
char buf[PATH_MAX];
ssize_t count = ::readlink(symlink_path.value().c_str(), buf, std::size(buf));
bool error = count <= 0;
if (error) {
  target_path->clear();
  return false;
}
*target_path = FilePath(FilePath::StringType(buf, static_cast<size_t>(count)));
```

- Uses `PATH_MAX` buffer
- Checks `count <= 0` (covers both `-1` error and `0` empty result)
- Explicit `static_cast<size_t>(count)` for the string construction

### History

Both files were imported from the engine repo during the monorepo merge (`7e0bed752f3`, 2023-04-25). `path_utils.cc` traces back to 2015 (`ad9b1352171`, Adam Barth). The bugs have been present since the original code was written.

### Related issues

- #162063 — `PathNotFoundException: Cannot resolve symbolic links, path = '/proc/self/exe'` (closed without resolution, 2025-02-27). That report describes `readlink` failures on Linux. Bug 2 in this issue would cause undefined behavior in exactly that scenario — if `readlink` returns `-1`, the current code does not handle it.
- #3648 — `Platform.executable and Platform.resolvedExecutable crash` (closed, 2016). Ian Hickson reported crashes from executable path resolution.

### Proposed fix

Align both call sites with Chromium's pattern:
- `paths_linux.cc`: buffer `255` → `PATH_MAX`, error check `== -1` → `<= 0`
- `path_utils.cc`: error check `> PATH_MAX` → `<= 0`

Six lines changed total. Existing test `path_utils_unittests.cc` continues to pass.

### Labels

`engine`, `P2`, `a: quality`
