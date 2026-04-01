<details open><summary>Code sample</summary>

This is a C++ engine bug, not reproducible from Dart. The affected code:

**`engine/src/flutter/fml/platform/linux/paths_linux.cc`** (buffer too small):
```cpp
std::pair<bool, std::string> GetExecutablePath() {
  const int path_size = 255;          // BUG: should be PATH_MAX (4096)
  char path[path_size] = {0};
  auto read_size = ::readlink("/proc/self/exe", path, path_size);
  if (read_size == -1) {
    return {false, ""};
  }
  return {true, std::string{path, static_cast<size_t>(read_size)}};
}
```

**`engine/src/flutter/shell/platform/common/path_utils.cc`** (missing error check):
```cpp
std::filesystem::path GetExecutableDirectory() {
  char buffer[PATH_MAX + 1];
  ssize_t length = readlink("/proc/self/exe", buffer, sizeof(buffer));
  if (length > PATH_MAX) {            // BUG: does not catch length == -1
    return std::filesystem::path();
  }
  std::filesystem::path executable_path(std::string(buffer, length));  // UB when length is -1
  return executable_path.remove_filename();
}
```

**Chromium's correct implementation** ([`base/files/file_util_posix.cc:695-719`](https://chromium.googlesource.com/chromium/src/+/main/base/files/file_util_posix.cc#695)):
```cpp
bool ReadSymbolicLink(const FilePath& symlink_path, FilePath* target_path) {
  DCHECK(!symlink_path.empty());
  DCHECK(target_path);
  char buf[PATH_MAX];
  ssize_t count = ::readlink(symlink_path.value().c_str(), buf, std::size(buf));
  bool error = count <= 0;
  if (error) {
    target_path->clear();
    return false;
  }
  *target_path = FilePath(FilePath::StringType(buf, static_cast<size_t>(count)));
  return true;
}
```

</details>
