**Bug 1** (`paths_linux.cc`): Executable paths longer than 255 bytes are silently truncated. The application proceeds with an incorrect path, potentially leading to failures resolving assets, ICU data, or the Dart VM snapshot.

**Bug 2** (`path_utils.cc`): When `readlink` fails (returns `-1`), the code constructs `std::string(buffer, (size_t)-1)` which is undefined behavior. In practice this causes either:
- An `std::bad_alloc` exception (attempting to allocate ~18 exabytes)
- A segfault
- Memory corruption

The current code:

```cpp
// paths_linux.cc — buffer too small
const int path_size = 255;          // should be PATH_MAX (4096)
char path[path_size] = {0};
auto read_size = ::readlink("/proc/self/exe", path, path_size);

// path_utils.cc — missing error check
ssize_t length = readlink("/proc/self/exe", buffer, sizeof(buffer));
if (length > PATH_MAX) {            // does not catch length == -1
  return std::filesystem::path();
}
std::filesystem::path executable_path(std::string(buffer, length)); // UB when length == -1
```
