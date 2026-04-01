`GetExecutablePath()` should use a `PATH_MAX`-sized buffer and return `{false, ""}` on any `readlink` error.

`GetExecutableDirectory()` should return an empty path on any `readlink` error, without triggering undefined behavior.

Both should match Chromium's [`ReadSymbolicLink()`](https://chromium.googlesource.com/chromium/src/+/main/base/files/file_util_posix.cc#695) pattern in `base/files/file_util_posix.cc`:

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
