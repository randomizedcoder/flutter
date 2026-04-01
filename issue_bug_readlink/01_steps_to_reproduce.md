**Existing issue search**: We searched for related issues before filing. The following are related but do not identify these specific bugs:
- #162063 — "[BUG] Error: PathNotFoundException during symbolic link resolution on Linux (/proc/self/exe not found)" — closed without resolution (2025-02-27). Describes `readlink` failures on Linux, but does not identify the missing error check in `path_utils.cc` that would cause undefined behavior in exactly that scenario.
- #3648 — "Platform.executable and Platform.resolvedExecutable crash" — closed (2016, filed by @Hixie). Reports crashes from executable path resolution, but predates the current code and does not identify the root cause.
- #125286 / #124079 — `readlink -f` issues in CocoaPods scripts on Xcode 14.3. Unrelated (shell script, not C++ engine code).

This is a code-level bug found via static analysis (flawfinder CWE-362/CWE-20, CERT POS30-C). Two `readlink("/proc/self/exe")` call sites have correctness issues.

**Bug 1 — Undersized buffer** in `engine/src/flutter/fml/platform/linux/paths_linux.cc:12-19`:

1. Deploy a Flutter application to a Linux system where the executable path exceeds 255 bytes (e.g. a deeply nested directory or long directory names).
2. The application calls `fml::paths::GetExecutablePath()`.
3. The returned path is silently truncated to 255 bytes because the buffer is hardcoded to 255 instead of `PATH_MAX` (4096).

**Bug 2 — Missing error check** in `engine/src/flutter/shell/platform/common/path_utils.cc:24-31`:

1. Run a Flutter desktop application on a Linux system where `/proc` is not mounted or `/proc/self/exe` is otherwise unavailable (e.g. certain container configurations, restricted sandboxes).
2. `readlink("/proc/self/exe")` returns `-1`.
3. The code checks `length > PATH_MAX` which does not catch `-1`.
4. `std::string(buffer, (size_t)-1)` is called — this is undefined behavior (`(size_t)-1` = 18446744073709551615 on 64-bit), causing a crash or massive allocation attempt.

Both bugs have been present since the engine monorepo merge (`7e0bed752f3`, 2023-04-25). `path_utils.cc` dates to 2015 (`ad9b1352171`).
