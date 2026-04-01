# Flutter C++ Static Analysis Report

**Date**: 2026-04-01
**Scope**: 3,430 C++ files (.cc, .cpp, .h, .hpp, .mm) across the Flutter repository
**Branch**: `rainy-days` (base: `c589dfffdab`)
**Toolchain**: Nix flake with clang-tools 18.1.8, cppcheck 2.18.3, flawfinder 2.0.19, include-what-you-use 0.26, shellcheck (latest)
**Compile database**: Synthesized (no GN build — some false positives expected from missing includes)

---

## Executive Summary

| Tool | Total Findings | Errors | Warnings | Info/Style |
|------|---------------|--------|----------|------------|
| **clang-tidy** | 41,920 | 3,395 | 38,525 | — |
| **cppcheck** | 7,790+ | 1,872 syntax | 757 unusedStructMember | 4,293 missingIncludeSystem |
| **clang-format** | 190 files | — | — | — |
| **flawfinder** | 191 hits | 2 level-5 | 34 level-4 | 12 level-3, 143 level-2 |
| **shellcheck** | 46 findings | 9 errors | 37 warnings | — |
| **iwyu** | 3,422 | 3,348 fatal | 12 add/remove | 62 correct |

---

## 1. clang-tidy — 41,920 Findings

Config: `nix/clang-tidy-expanded.yaml` (broad checks: bugprone, cert, cppcoreguidelines, misc, modernize, performance, readability, security, clang-analyzer)

### 1.1 Errors (3,395)

All 3,380 `[clang-diagnostic-error]` are missing-header errors from the synthetic compile database (no real include paths). These are expected without a full GN build.

**Files with errors**: ~300 files, predominantly:
- `bin/cache/pkg/flutter_gpu/*.{cc,h}` — missing engine-internal headers
- `dev/*/ios/Runner/*.h` — missing `Flutter/Flutter.h`, `UIKit/UIKit.h`, `Foundation/Foundation.h`
- `dev/*/linux/*.{cc,h}` — missing `gtk/gtk.h`, `flutter_linux/flutter_linux.h`
- `dev/*/windows/runner/*.{cpp,h}` — missing `windows.h`, `flutter/dart_project.h`
- `engine/src/flutter/shell/platform/**` — missing engine-internal headers
- `packages/flutter_tools/templates/**` — template files without build context

### 1.2 Warnings by Check (38,525 total)

#### Critical / High-Value (likely real bugs or important improvements)

| Count | Check | Description |
|-------|-------|-------------|
| 1,133 | `cppcoreguidelines-pro-type-member-init` | Uninitialized member variables in constructors |
| 688 | `misc-const-correctness` | Variables/parameters that could be const |
| 610 | `cppcoreguidelines-init-variables` | Uninitialized variables |
| 575 | `cppcoreguidelines-special-member-functions` | Missing copy/move/destructor (Rule of 5) |
| 375 | `readability-non-const-parameter` | Pointer parameters that should be const |
| 317 | `misc-unused-parameters` | Unused function parameters |
| 245 | `bugprone-macro-parentheses` | Macros with unparenthesized parameters |
| 223 | `bugprone-branch-clone` | Identical branches in if/else or switch |
| 183 | `readability-implicit-bool-conversion` | Implicit int/pointer to bool conversion |
| 160 | `performance-unnecessary-value-param` | Parameters passed by value that should be const ref |
| 82 | `readability-braces-around-statements` | Missing braces on if/else/for/while |
| 64 | `cppcoreguidelines-virtual-class-destructor` | Non-virtual destructors in base classes |
| 63 | `readability-simplify-boolean-expr` | Unnecessarily complex boolean expressions |
| 8 | `bugprone-infinite-loop` | Potential infinite loops |
| 7 | `bugprone-forwarding-reference-overload` | Constructors that shadow copy/move |
| 6 | `bugprone-sizeof-expression` | Suspicious sizeof usage |
| 4 | `bugprone-misplaced-widening-cast` | Cast applied after arithmetic (potential overflow) |
| 3 | `bugprone-integer-division` | Integer division with float result expected |
| 3 | `cert-oop54-cpp` | Self-assignment not handled in operator= |
| 1 | `bugprone-suspicious-include` | Suspicious #include of .cc file |

#### Modernization

| Count | Check | Description |
|-------|-------|-------------|
| 931 | `modernize-use-using` | C-style typedef → using declaration |
| 524 | `modernize-concat-nested-namespaces` | `namespace a { namespace b {` → `namespace a::b {` |
| 446 | `modernize-use-equals-delete` | Private undefined methods → `= delete` |
| 177 | `modernize-use-equals-default` | Trivial special members → `= default` |
| 144 | `modernize-use-auto` | Explicit types that can use auto |
| 82 | `modernize-deprecated-headers` | `<stdio.h>` → `<cstdio>` |
| 63 | `modernize-return-braced-init-list` | `return T(...)` → `return {...}` |
| 52 | `modernize-raw-string-literal` | Escaped strings → R"(...)" |
| 33 | `modernize-redundant-void-arg` | `f(void)` → `f()` |
| 28 | `modernize-pass-by-value` | const ref params → move semantics |
| 27 | `modernize-use-nullptr` | `NULL`/`0` → `nullptr` |
| 24 | `modernize-use-std-numbers` | Magic math constants → `std::numbers::pi` etc. |

#### Style / Naming

| Count | Check | Description |
|-------|-------|-------------|
| 10,884 | `readability-identifier-naming` | Naming convention violations |
| 3,231 | `misc-include-cleaner` | Unused or missing includes |
| 1,816 | `misc-use-anonymous-namespace` | `static` functions → anonymous namespace |
| 717 | `readability-avoid-const-params-in-decls` | Const qualifier on pass-by-value params in declarations |
| 699 | `readability-convert-member-functions-to-static` | Non-static methods not using `this` |
| 234 | `readability-static-definition-in-anonymous-namespace` | Redundant `static` in anonymous namespace |
| 167 | `readability-redundant-inline-specifier` | Redundant `inline` on class member functions |

#### Guidelines / Safety

| Count | Check | Description |
|-------|-------|-------------|
| 3,083 | `cppcoreguidelines-avoid-non-const-global-variables` | Mutable global variables |
| 2,371 | `bugprone-easily-swappable-parameters` | Adjacent params of same type (easy to mix up) |
| 1,155 | `cert-dcl58-cpp` | Modification of namespace `std` |
| 683 | `cppcoreguidelines-avoid-const-or-ref-data-members` | Const/ref class members complicate assignment |
| 629 | `cppcoreguidelines-macro-usage` | Macros that should be constexpr/inline |
| 551 | `performance-enum-size` | Enums that could use smaller underlying type |
| 72 | `cppcoreguidelines-owning-memory` | Raw owning pointers (should use smart pointers) |
| 71 | `cppcoreguidelines-pro-type-union-access` | Union member access (type-unsafe) |
| 62 | `cppcoreguidelines-pro-bounds-constant-array-index` | Array indexed with non-constant |
| 60 | `cppcoreguidelines-avoid-do-while` | do-while loops (error-prone) |
| 46 | `cppcoreguidelines-pro-type-cstyle-cast` | C-style casts |
| 11 | `cppcoreguidelines-pro-type-vararg` | Variadic function usage |
| 11 | `cppcoreguidelines-no-malloc` | malloc/free usage |

---

## 2. cppcheck — 7,790+ Findings

### 2.1 Errors by Type

| Count | ID | Severity | Description |
|-------|----|----------|-------------|
| 1,872 | `syntaxError` | error | C++ code parsed as C (namespace, class, etc.) — cppcheck limitation without `--language=c++` per-file |
| 106 | `unknownMacro` | error | GTK/ObjC/Win32 macros not recognized (`G_DECLARE_FINAL_TYPE`, `@interface`, etc.) |
| 8 | `missingReturn` | error | Functions missing return statements |
| 8 | `nullPointerOutOfMemory` | error | Potential null dereference after failed allocation |

### 2.2 Warnings / Style

| Count | ID | Severity | Description |
|-------|----|----------|-------------|
| 757 | `unusedStructMember` | style | Struct members never read |
| 197 | `constParameterPointer` | style | Pointer parameters that should be const |
| 88 | `normalCheckLevelMaxBranches` | — | Analysis depth limit reached |
| 76 | `duplInheritedMember` | warning | Duplicate member in derived class shadows base |
| 69 | `cstyleCast` | style | C-style casts |
| 45 | `useStlAlgorithm` | style | Manual loops replaceable with STL algorithms |
| 35 | `missingOverride` | style | Missing `override` on virtual function overrides |
| 34 | `knownConditionTrueFalse` | style | Condition always true or always false |
| 31 | `unreadVariable` | style | Variables written but never read |
| 29 | `constVariablePointer` | style | Pointer variables that should be const |
| 28 | `constVariableReference` | style | Reference variables that should be const |
| 25 | `shadowVariable` | style | Variable shadows outer scope variable |
| 15 | `constParameterReference` | style | Reference parameters that should be const |
| 14 | `virtualCallInConstructor` | warning | Virtual function called in constructor |
| 14 | `passedByValue` | performance | Large objects passed by value |
| 13 | `variableScope` | style | Variable scope could be reduced |
| 12 | `noExplicitConstructor` | style | Single-arg constructors missing `explicit` |
| 11 | `useInitializationList` | performance | Assignments in constructor body → initializer list |
| 9 | `uninitMemberVar` | warning | Uninitialized member variables |
| 9 | `returnStdMoveLocal` | performance | Redundant `std::move` on local return |
| 8 | `unusedVariable` | style | Unused variables |

### 2.3 Information

| Count | ID | Description |
|-------|-----|-------------|
| 4,293 | `missingIncludeSystem` | System headers not found (expected without build sysroot) |

---

## 3. clang-format — 190 Files with Formatting Issues

### 3.1 Breakdown by Directory

| Directory | Files | Notes |
|-----------|-------|-------|
| `bin/cache/dart-sdk/include/` | 5 | Dart SDK headers (vendored) |
| `bin/cache/pkg/flutter_gpu/` | 20 | GPU package cache (vendored) |
| `dev/a11y_assessments/` | 10 | Linux/Windows/iOS runner code |
| `dev/benchmarks/` | 18 | Various benchmark runner code |
| `dev/integration_tests/` | 54 | Integration test runner code |
| `dev/manual_tests/` | 10 | Manual test runner code |
| `engine/src/flutter/` | 14 | Engine source (display_list, fml, impeller, shell) |
| `examples/` | 32 | Example app runner code |
| `packages/flutter_tools/templates/` | 9 | Flutter tool templates |
| `packages/integration_test/` | 3 | Integration test plugin headers |

### 3.2 Full File List

<details>
<summary>All 190 files (click to expand)</summary>

```
bin/cache/dart-sdk/include/dart_api_dl.h
bin/cache/dart-sdk/include/dart_api.h
bin/cache/dart-sdk/include/dart_native_api.h
bin/cache/dart-sdk/include/dart_tools_api.h
bin/cache/dart-sdk/include/internal/dart_api_dl_impl.h
bin/cache/pkg/flutter_gpu/command_buffer.cc
bin/cache/pkg/flutter_gpu/command_buffer.h
bin/cache/pkg/flutter_gpu/context.cc
bin/cache/pkg/flutter_gpu/context.h
bin/cache/pkg/flutter_gpu/device_buffer.cc
bin/cache/pkg/flutter_gpu/device_buffer.h
bin/cache/pkg/flutter_gpu/export.cc
bin/cache/pkg/flutter_gpu/export.h
bin/cache/pkg/flutter_gpu/formats.cc
bin/cache/pkg/flutter_gpu/formats.h
bin/cache/pkg/flutter_gpu/render_pass.cc
bin/cache/pkg/flutter_gpu/render_pass.h
bin/cache/pkg/flutter_gpu/render_pipeline.cc
bin/cache/pkg/flutter_gpu/render_pipeline.h
bin/cache/pkg/flutter_gpu/shader.cc
bin/cache/pkg/flutter_gpu/shader.h
bin/cache/pkg/flutter_gpu/shader_library.cc
bin/cache/pkg/flutter_gpu/shader_library.h
bin/cache/pkg/flutter_gpu/texture.cc
bin/cache/pkg/flutter_gpu/texture.h
dev/a11y_assessments/linux/main.cc
dev/a11y_assessments/linux/my_application.cc
dev/a11y_assessments/linux/my_application.h
dev/a11y_assessments/windows/runner/flutter_window.cpp
dev/a11y_assessments/windows/runner/flutter_window.h
dev/a11y_assessments/windows/runner/main.cpp
dev/a11y_assessments/windows/runner/resource.h
dev/a11y_assessments/windows/runner/utils.cpp
dev/a11y_assessments/windows/runner/utils.h
dev/a11y_assessments/windows/runner/win32_window.cpp
dev/a11y_assessments/windows/runner/win32_window.h
dev/benchmarks/complex_layout/windows/runner/flutter_window.cpp
dev/benchmarks/complex_layout/windows/runner/flutter_window.h
dev/benchmarks/complex_layout/windows/runner/main.cpp
dev/benchmarks/complex_layout/windows/runner/resource.h
dev/benchmarks/complex_layout/windows/runner/utils.cpp
dev/benchmarks/complex_layout/windows/runner/utils.h
dev/benchmarks/complex_layout/windows/runner/win32_window.cpp
dev/benchmarks/complex_layout/windows/runner/win32_window.h
dev/benchmarks/platform_channels_benchmarks/ios/Runner/AppDelegate.h
dev/benchmarks/platform_views_layout_hybrid_composition/ios/Runner/DummyPlatformView.h
dev/benchmarks/platform_views_layout/ios/Runner/DummyPlatformView.h
dev/benchmarks/test_apps/stocks/ios/Runner/AppDelegate.h
dev/integration_tests/channels/ios/Runner/AppDelegate.h
dev/integration_tests/external_textures/ios/Runner/AppDelegate.h
dev/integration_tests/flavors/ios/Runner/AppDelegate.h
dev/integration_tests/flutter_gallery/ios/Runner/AppDelegate.h
dev/integration_tests/flutter_gallery/linux/main.cc
dev/integration_tests/flutter_gallery/linux/my_application.cc
dev/integration_tests/flutter_gallery/linux/my_application.h
dev/integration_tests/flutter_gallery/windows/runner/flutter_window.cpp
dev/integration_tests/flutter_gallery/windows/runner/flutter_window.h
dev/integration_tests/flutter_gallery/windows/runner/main.cpp
dev/integration_tests/flutter_gallery/windows/runner/resource.h
dev/integration_tests/flutter_gallery/windows/runner/utils.cpp
dev/integration_tests/flutter_gallery/windows/runner/utils.h
dev/integration_tests/flutter_gallery/windows/runner/win32_window.cpp
dev/integration_tests/flutter_gallery/windows/runner/win32_window.h
dev/integration_tests/ios_add2app_life_cycle/ios_add2app/AppDelegate.h
dev/integration_tests/ios_add2app_life_cycle/ios_add2app/MainViewController.h
dev/integration_tests/ios_host_app/Host/AppDelegate.h
dev/integration_tests/ios_host_app/Host/DualFlutterViewController.h
dev/integration_tests/ios_host_app/Host/DynamicResizingViewController.h
dev/integration_tests/ios_host_app/Host/HybridViewController.h
dev/integration_tests/ios_host_app/Host/MainViewController.h
dev/integration_tests/ios_host_app/Host/NativeViewController.h
dev/integration_tests/ios_platform_view_tests/ios/Runner/ButtonFactory.h
dev/integration_tests/ios_platform_view_tests/ios/Runner/FakeAdMobBannerFactory.h
dev/integration_tests/ios_platform_view_tests/ios/Runner/TextFieldFactory.h
dev/integration_tests/ios_platform_view_tests/ios/Runner/ViewFactory.h
dev/integration_tests/ios_platform_view_tests/ios/Runner/WebViewFactory.h
dev/integration_tests/platform_interaction/ios/Runner/AppDelegate.h
dev/integration_tests/platform_interaction/ios/Runner/TestNavigationController.h
dev/integration_tests/ui/ios/Runner/AppDelegate.h
dev/integration_tests/ui/linux/main.cc
dev/integration_tests/ui/linux/my_application.cc
dev/integration_tests/ui/linux/my_application.h
dev/integration_tests/ui/windows/runner/flutter_window.cpp
dev/integration_tests/ui/windows/runner/flutter_window.h
dev/integration_tests/ui/windows/runner/main.cpp
dev/integration_tests/ui/windows/runner/resource.h
dev/integration_tests/ui/windows/runner/utils.cpp
dev/integration_tests/ui/windows/runner/utils.h
dev/integration_tests/ui/windows/runner/win32_window.cpp
dev/integration_tests/ui/windows/runner/win32_window.h
dev/integration_tests/windowing_test/linux/runner/main.cc
dev/integration_tests/windowing_test/linux/runner/my_application.cc
dev/integration_tests/windowing_test/linux/runner/my_application.h
dev/integration_tests/windowing_test/windows/runner/flutter_window.cpp
dev/integration_tests/windowing_test/windows/runner/flutter_window.h
dev/integration_tests/windowing_test/windows/runner/main.cpp
dev/integration_tests/windowing_test/windows/runner/resource.h
dev/integration_tests/windowing_test/windows/runner/utils.cpp
dev/integration_tests/windowing_test/windows/runner/utils.h
dev/integration_tests/windowing_test/windows/runner/win32_window.cpp
dev/integration_tests/windowing_test/windows/runner/win32_window.h
dev/integration_tests/windows_startup_test/windows/runner/flutter_window.cpp
dev/integration_tests/windows_startup_test/windows/runner/flutter_window.h
dev/integration_tests/windows_startup_test/windows/runner/main.cpp
dev/integration_tests/windows_startup_test/windows/runner/resource.h
dev/integration_tests/windows_startup_test/windows/runner/utils.cpp
dev/integration_tests/windows_startup_test/windows/runner/utils.h
dev/integration_tests/windows_startup_test/windows/runner/win32_window.cpp
dev/integration_tests/windows_startup_test/windows/runner/win32_window.h
dev/manual_tests/linux/main.cc
dev/manual_tests/linux/my_application.cc
dev/manual_tests/linux/my_application.h
dev/manual_tests/windows/runner/flutter_window.cpp
dev/manual_tests/windows/runner/flutter_window.h
dev/manual_tests/windows/runner/main.cpp
dev/manual_tests/windows/runner/resource.h
dev/manual_tests/windows/runner/utils.cpp
dev/manual_tests/windows/runner/utils.h
dev/manual_tests/windows/runner/win32_window.cpp
dev/manual_tests/windows/runner/win32_window.h
engine/src/flutter/display_list/dl_op_records.h
engine/src/flutter/display_list/skia/dl_sk_conversions_unittests.cc
engine/src/flutter/fml/memory/weak_ptr_unittest.cc
engine/src/flutter/impeller/renderer/backend/vulkan/vk.h
engine/src/flutter/impeller/toolkit/android/toolkit_android_unittests.cc
engine/src/flutter/shell/platform/android/android_egl_surface.cc
engine/src/flutter/shell/platform/darwin/common/framework/Source/FlutterChannels.mm
engine/src/flutter/shell/platform/darwin/ios/framework/Source/FlutterPluginAppLifeCycleDelegate.mm
engine/src/flutter/shell/platform/embedder/tests/embedder_a11y_unittests.cc
engine/src/flutter/shell/platform/windows/client_wrapper/flutter_view_controller_unittests.cc
engine/src/flutter/shell/platform/windows/direct_manipulation.cc
engine/src/flutter/shell/platform/windows/direct_manipulation_unittests.cc
engine/src/flutter/shell/platform/windows/windowsx_shim.h
examples/api/windows/runner/main.cpp
examples/api/windows/runner/resource.h
examples/api/windows/runner/utils.cpp
examples/api/windows/runner/win32_window.cpp
examples/api/windows/runner/win32_window.h
examples/flutter_view/ios/Runner/AppDelegate.h
examples/flutter_view/ios/Runner/MainViewController.h
examples/flutter_view/ios/Runner/NativeViewController.h
examples/flutter_view/windows/runner/flutter_window.cpp
examples/flutter_view/windows/runner/main.cpp
examples/flutter_view/windows/runner/resource.h
examples/flutter_view/windows/runner/utils.cpp
examples/flutter_view/windows/runner/win32_window.cpp
examples/flutter_view/windows/runner/win32_window.h
examples/hello_world/ios/Runner/AppDelegate.h
examples/hello_world/windows/runner/flutter_window.cpp
examples/hello_world/windows/runner/main.cpp
examples/hello_world/windows/runner/resource.h
examples/hello_world/windows/runner/utils.cpp
examples/hello_world/windows/runner/win32_window.cpp
examples/hello_world/windows/runner/win32_window.h
examples/layers/ios/Runner/AppDelegate.h
examples/layers/windows/runner/flutter_window.cpp
examples/layers/windows/runner/main.cpp
examples/layers/windows/runner/resource.h
examples/layers/windows/runner/utils.cpp
examples/layers/windows/runner/win32_window.cpp
examples/layers/windows/runner/win32_window.h
examples/multiple_windows/windows/runner/resource.h
examples/multiple_windows/windows/runner/utils.cpp
examples/platform_channel/ios/Runner/AppDelegate.h
examples/platform_channel/linux/runner/my_application.cc
examples/platform_channel/windows/runner/flutter_window.cpp
examples/platform_channel/windows/runner/resource.h
examples/platform_channel/windows/runner/utils.cpp
examples/platform_channel/windows/runner/win32_window.cpp
examples/platform_channel/windows/runner/win32_window.h
examples/platform_view/ios/Runner/AppDelegate.h
examples/platform_view/windows/runner/main.cpp
examples/platform_view/windows/runner/resource.h
examples/platform_view/windows/runner/utils.cpp
examples/platform_view/windows/runner/win32_window.cpp
examples/platform_view/windows/runner/win32_window.h
examples/texture/linux/runner/my_application.cc
packages/flutter_tools/templates/app/linux.tmpl/runner/main.cc
packages/flutter_tools/templates/app/linux.tmpl/runner/my_application.h
packages/flutter_tools/templates/app/windows.tmpl/runner/flutter_window.cpp
packages/flutter_tools/templates/app/windows.tmpl/runner/flutter_window.h
packages/flutter_tools/templates/app/windows.tmpl/runner/resource.h
packages/flutter_tools/templates/app/windows.tmpl/runner/utils.cpp
packages/flutter_tools/templates/app/windows.tmpl/runner/utils.h
packages/flutter_tools/templates/app/windows.tmpl/runner/win32_window.cpp
packages/flutter_tools/templates/app/windows.tmpl/runner/win32_window.h
packages/integration_test/example/ios/Runner/SimplePlatformView.h
packages/integration_test/ios/integration_test/Sources/integration_test/include/FLTIntegrationTestRunner.h
packages/integration_test/ios/integration_test/Sources/integration_test/include/IntegrationTestIosTest.h
packages/integration_test/ios/integration_test/Sources/integration_test/include/IntegrationTestPlugin.h
```

</details>

---

## 4. flawfinder — 191 Security Hits

**622,901 lines analyzed in 5.41 seconds**

### 4.1 Level 5 — `readlink("/proc/self/exe")` Deep Dive (2 hits) — [flutter/flutter#184476](https://github.com/flutter/flutter/issues/184476)

| File | Line | Function | CWE |
|------|------|----------|-----|
| `engine/src/flutter/fml/platform/linux/paths_linux.cc` | 15 | `readlink` | CWE-362, CWE-20 |
| `engine/src/flutter/shell/platform/common/path_utils.cc` | 26 | `readlink` | CWE-362, CWE-20 |

#### What the code does

**`paths_linux.cc`** — resolves the current executable path:
```cpp
const int path_size = 255;
char path[path_size] = {0};
auto read_size = ::readlink("/proc/self/exe", path, path_size);
```

**`path_utils.cc`** — same purpose, different implementation:
```cpp
char buffer[PATH_MAX + 1];
ssize_t length = readlink("/proc/self/exe", buffer, sizeof(buffer));
if (length > PATH_MAX) {
    return std::filesystem::path();
}
```

#### Is this a security vulnerability requiring responsible disclosure? **No.**

`/proc/self/exe` is a **kernel-managed symlink**. Userspace cannot modify where it points — the kernel sets it at `execve()` time. The classic TOCTOU attack pattern (CWE-362) requires an attacker to change a symlink between the check and the use, but:

1. **No userspace process can redirect `/proc/self/exe`**. An attacker would need kernel-level access, at which point they already own the system.
2. **The code only reads the path** — it does not re-execute via `/proc/self/exe`. Historical CVEs (CVE-2009-1894 PulseAudio, CVE-2019-5736 runC) exploited *re-execution* or *writing* through `/proc/self/exe`, not reading it.
3. **Modern kernels mitigate** the historical attack vector: hard links to setuid binaries require matching ownership (`protected_hardlinks` sysctl, since ~2012).
4. **Google's own Abseil library** uses the identical pattern (`absl/base/internal/sysinfo.cc`) without any race-condition commentary or mitigation. Chromium also uses `readlink("/proc/self/exe")` in production.
5. **No CVE has ever been filed** for the act of calling `readlink` on `/proc/self/exe` to obtain an executable path.

**Flawfinder flags all `readlink` calls generically** — it cannot distinguish `/proc/self/exe` (kernel-managed) from user-writable symlinks in `/tmp` (genuinely dangerous).

#### Real code bugs in these files (not security, but correctness)

1. **`paths_linux.cc:13` — undersized buffer**: Uses a fixed 255-byte buffer. `PATH_MAX` on Linux is 4096. Paths longer than 255 bytes are silently truncated. This is a latent bug — unlikely to trigger on standard installations but violates CERT POS30-C.

2. **`path_utils.cc:26` — missing error check**: Does not check for `readlink` returning `-1` (error). If `readlink` fails, `length` is `-1` and `std::string(buffer, (size_t)-1)` is **undefined behavior** (massive allocation or crash). The `length > PATH_MAX` check on line 27 doesn't catch this because `-1` cast to `ssize_t` is less than `PATH_MAX`.

3. **Both files — `readlink` does not NUL-terminate**: Per POSIX, `readlink` does not append `\0`. `paths_linux.cc` zero-initializes the buffer (safe). `path_utils.cc` uses `std::string(buffer, length)` with explicit length (also safe, if length is valid — but see bug #2).

#### Why don't the sanitizers catch this?

Flutter's engine has full sanitizer support (ASAN, TSAN, MSAN, LSAN, UBSAN) configured via GN flags (`--asan`, `--tsan`, etc.) and run on Linux unopt CI builds. However:

- **ThreadSanitizer (TSAN)** detects **memory-level data races between threads** — concurrent reads/writes to the same memory address. It does **not** detect filesystem TOCTOU races. TSAN instruments memory accesses, not syscalls. A `readlink` call is a single atomic syscall from TSAN's perspective — there are no concurrent memory accesses to flag. Flutter's `tsan_suppressions.txt` confirms TSAN is used for threading bugs (`race:flutter::Shell::OnAnimatorBeginFrame`), not filesystem races.

- **AddressSanitizer (ASAN)** could catch a buffer overflow if `readlink` wrote past the buffer — but with a 255-byte or `PATH_MAX`-sized buffer reading a typical path, no overflow occurs at runtime. The undersized buffer in `paths_linux.cc` would only trigger if the actual exe path exceeded 255 bytes.

- **No sanitizer detects the missing `-1` check** in `path_utils.cc`. The UB from `std::string(buffer, -1)` would only manifest if `readlink` actually failed at runtime, which doesn't happen in normal test execution.

- **Filesystem TOCTOU detection** is a fundamentally different problem from memory races. No mainstream runtime sanitizer covers it. Static analysis tools (flawfinder, Coverity, CodeQL) flag the pattern heuristically, but `/proc/self/exe` is a known false-positive trigger.

#### What about the Google C++ Style Guide?

The [Google C++ Style Guide](https://google.github.io/styleguide/cppguide.html) does **not** discuss race conditions, TOCTOU, `readlink`, or `/proc/self/exe`. The word "race" appears once, in the context of `thread_local` storage. The guide covers code style, naming, formatting, and language feature selection — not secure coding patterns.

The relevant guidance lives elsewhere:
- **CERT C Coding Standard**: [POS30-C](https://wiki.sei.cmu.edu/confluence/display/c/POS30-C.+Use+the+readlink()+function+properly) — "Use the readlink() function properly" (covers NUL-termination and buffer sizing)
- **CERT C Coding Standard**: [POS35-C](https://wiki.sei.cmu.edu/confluence/display/c/POS35-C.+Avoid+race+conditions+while+checking+for+the+existence+of+a+symbolic+link) — "Avoid race conditions while checking for the existence of a symbolic link" (covers user-writable paths, not procfs)
- **CWE-367**: TOCTOU Race Condition (the general class)

#### Verdict

| Aspect | Assessment |
|--------|-----------|
| Responsible disclosure needed? | **No** — `/proc/self/exe` is kernel-managed, not exploitable via readlink |
| Real security vulnerability? | **No** — flawfinder false positive for this specific path |
| Real code bugs? | **Yes** — undersized buffer (paths_linux.cc), missing error check / potential UB (path_utils.cc) |
| Sanitizer gap? | **Expected** — no runtime sanitizer covers filesystem TOCTOU; the real bugs are only triggered on rare error paths |

### 4.2 Level 4 — High (34 hits)

| Category | Count | Files | CWE |
|----------|-------|-------|-----|
| `system` / `popen` (shell injection) | 9 | `native_assets.cc`, `license_checker.cc`, `license_checker_unittests.cc` | CWE-78 |
| `StrCat` (buffer overflow) | 18 | `catalog.cc`, `license_checker.cc`, `license_checker_unittests.cc`, `main.cc`, `mmap_file.cc` | CWE-120 |
| `vsnprintf` / `printf` (format string) | 2 | `flutter_vma.cc`, `config.h` | CWE-134 |
| `access` (TOCTOU race) | 2 | `android_context_dynamic_impeller.cc`, `path_utils.cc` | CWE-362 |
| `strcpy` (buffer overflow) | 2 | `test_keyboard.cc`, `mock_vulkan.cc` | CWE-120 |
| `LoadLibrary` (DLL hijack) | 1 | `native_library_win.cc` | CWE-114 |

#### 4.2.1 Deep dive: `system()`/`popen()` shell injection (9 hits)

Manual review reclassifies these as follows:

**1 false positive — `native_assets.cc:41`**

```cpp
#error Target operating system detection failed.
```

Flawfinder matched the word "system" inside an `#error` string literal. Not a function call.

**1 real hit (low risk) — `license_checker.cc:64` (production code)**

```cpp
std::string cmd = "git -C \"" + repo_path.string() + "\" ls-files";
std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd.c_str(), "r"), pclose);
```

This concatenates `repo_path` directly into a shell command. A path containing shell metacharacters (`$`, `` ` ``, `;`, etc.) would be interpreted by the shell. The double quotes around the path provide minimal protection but don't handle `"`, `$`, or backticks within the path.

However, the practical risk is **low**:
- `license_checker` is a **developer-only CLI tool**, not shipped to end users
- `repo_path` comes from the tool's own internal logic, not external input
- The proper fix would be `fork`/`execvp` (bypassing the shell entirely), but this is not a security-critical path

**8 test code hits — `license_checker_unittests.cc` (negligible)**

All are hardcoded string literals in test setup:
- `std::system("git init")` (line 152)
- `std::system("git add " + file)` (line 156) — theoretical injection via `file`, but `file` comes from test fixtures
- `std::system("git commit -m \"test\"")` (line 160)
- `std::system("echo \"Hello world!\" > main.cc")` (lines 252, 471)
- `std::system("mkdir -p third_party/foobar")` (lines 411, 496, 596)

Best practice would be to use `std::filesystem` APIs instead of shelling out, but these are not a security concern.

| Hit | Verdict | Action |
|-----|---------|--------|
| `native_assets.cc:41` | **False positive** — word "system" in `#error` string | None |
| `license_checker.cc:64` | **Low risk** — developer tool, internal path | Optional: replace `popen` with `fork`/`execvp` |
| `license_checker_unittests.cc` (8 hits) | **Negligible** — hardcoded test literals | Optional: use `std::filesystem` APIs |

### 4.3 Level 3 — Medium (12 hits)

| Category | Count | Files | CWE |
|----------|-------|-------|-----|
| `getenv` (environment tampering) | 9 | `engine_switches.cc`, `availability_version_check.cc`, `FlutterPluginAppLifeCycleDelegate.mm`, `runner.cc`, `system_utils.cc`, `system_utils_test.cc` | CWE-807 |
| `srand` (weak PRNG) | 1 | `gaussian_blur_filter_contents_unittests.cc` | CWE-327 |
| `LoadLibrary` (DLL search order) | 1 | `native_library_win.cc` | CWE-114 |

### 4.4 Level 2 — Low (143 hits)

| Category | Count | Description |
|----------|-------|-------------|
| `memcpy` | 67 | Buffer copy without bounds checking |
| `char` / `wchar_t` fixed buffers | 24 | Stack buffer declarations |
| `open` | 9 | File handle operations |
| `atoi` | 2 | No error checking on conversion |
| `strcpy` / `strlen` | 4 | Buffer operations |
| `sprintf` | 5 | Format string operations |
| Other | 32 | Various buffer/race/format concerns |

---

## 5. shellcheck — 46 Findings in 19 Files

### 5.1 Errors (9)

| Code | Count | Description | Files |
|------|-------|-------------|-------|
| SC2148 | 4 | Missing shebang line | `find-undocumented-ios.sh`, `sanitizer_suppressions.sh`, `merge.sh`, `refresh.sh` |
| SC2145 | 2 | Array/string mixing in arguments | `docs.sh`, `mock_git.sh` |
| SC2199 | 1 | Array concatenation in `[[ ]]` | `ban_generated_plugin_registrant_java.sh` |
| SC2298 | 1 | Invalid `${${x}}` syntax | `devshell/lib/vars.sh` |
| SC2296 | 1 | Invalid parameter expansion | `devshell/lib/vars.sh` |

### 5.2 Warnings (37)

| Code | Count | Description |
|------|-------|-------------|
| SC2034 | 6 | Unused variables (`ROOT_DIR`, `FLUTTER_DIR`, `compilation_mode`, etc.) |
| SC2027 | 6 | Quotes inside quotes cancel out |
| SC2046 | 5 | Unquoted command substitution (word splitting risk) |
| SC2155 | 3 | `local var=$(cmd)` masks return value |
| SC2164 | 2 | `cd` without `|| exit` fallback |
| SC2124 | 2 | Array assigned to string |
| SC2319 | 1 | `$?` refers to condition, not command |
| SC2309 | 1 | `-eq` with string comparison |
| SC2209 | 1 | `FIND=find` assigns string, not command output |
| SC2207 | 1 | `$(find ...)` should use `mapfile` or `read -a` |
| SC2206 | 1 | Unquoted expansion for array splitting |
| SC2174 | 1 | `-m` with `-p` only applies to deepest dir |
| SC2154 | 1 | Referenced but unassigned variable |
| SC2128 | 1 | Array expanded without index |
| SC2076 | 1 | Quoted regex in `=~` matches literally |
| SC2053 | 1 | Unquoted RHS of `!=` in `[[ ]]` |
| SC2044 | 1 | `for f in $(find ...)` is fragile |
| SC1090 | 1 | Non-constant source |

### 5.3 Files with Issues

```
bin/internal/shared.sh                                           — SC2155, SC2319, SC1090
bin/internal/update_dart_sdk.sh                                  — SC2209, SC2174
dev/bots/codelabs_build_test.sh                                  — SC2155, SC2034
dev/bots/docs.sh                                                 — SC2034, SC2145
dev/tools/repackage_gradle_wrapper.sh                            — SC2128, SC2044
dev/tools/test/mock_git.sh                                       — SC2145
engine/src/flutter/ci/ban_generated_plugin_registrant_java.sh    — SC2199, SC2076
engine/src/flutter/ci/binary_size_treemap.sh                     — SC2046 (x3)
engine/src/flutter/ci/check_build_configs.sh                     — SC2034
engine/src/flutter/ci/clang_tidy.sh                              — SC2034
engine/src/flutter/shell/platform/darwin/find-undocumented-ios.sh — SC2148
engine/src/flutter/testing/sanitizer_suppressions.sh             — SC2148, SC2164, SC2046
engine/src/flutter/tools/android_sdk/create_cipd_packages.sh     — SC2206
engine/src/flutter/tools/fuchsia/devshell/build_and_copy_to_fuchsia.sh — SC2124, SC2027
engine/src/flutter/tools/fuchsia/devshell/lib/vars.sh            — SC2298, SC2296
engine/src/flutter/tools/fuchsia/devshell/run_integration_test.sh — SC2034, SC2124, SC2027, SC2309, SC2154, SC2207
engine/src/flutter/tools/fuchsia/devshell/run_unit_tests.sh      — SC2034, SC2027, SC2046
engine/src/flutter/tools/vscode_workspace/merge.sh               — SC2148
engine/src/flutter/tools/vscode_workspace/refresh.sh             — SC2148
```

---

## 6. include-what-you-use (IWYU) — 3,422 Findings

### 6.1 Fatal Errors (3,348)

Overwhelmingly "file not found" errors due to the synthetic compile database lacking include paths for:
- Engine-internal headers (`flutter/shell/platform/...`, `flutter/fml/...`, `flutter/lib/gpu/...`)
- Platform SDK headers (`Flutter/Flutter.h`, `UIKit/UIKit.h`, `windows.h`, `gtk/gtk.h`)
- Standard library headers (`<string>`, `<memory>`, `<cstdint>`, etc.)

These are **expected** without a real GN build providing sysroot and include paths.

### 6.2 Actionable Recommendations (12 files)

IWYU successfully analyzed the Dart SDK headers and found:

| File | Action | Details |
|------|--------|---------|
| `dart_native_api.h` | add | `#include <stdint.h>` (for `intptr_t`, `int64_t`, `uint8_t`, `int32_t`) |
| `dart_tools_api.h` | add | `#include <stdint.h>` (for `int64_t`, `intptr_t`, `uint8_t`, `int32_t`) |
| `dart_api_dl.h` | add | `#include <stdint.h>` (for `intptr_t`, `int64_t`) |
| `dart_api.h` | remove | `#include <assert.h>`, `#include <stdbool.h>`, `struct Dart_CodeObserver` forward decl |

---

## 7. Combined Risk Assessment

### Highest Priority Issues

1. **2 race conditions** (`readlink` in `paths_linux.cc` and `path_utils.cc`) — flawfinder level 5
2. **9 shell injection vectors** (`system()`, `popen()`) — flawfinder level 4, mostly in `license_checker`
3. **8 potential null dereferences** after allocation failure — cppcheck `nullPointerOutOfMemory`
4. **8 missing return statements** — cppcheck `missingReturn`
5. **9 uninitialized member variables** — cppcheck `uninitMemberVar`
6. **8 bugprone infinite loops** — clang-tidy `bugprone-infinite-loop`
7. **64 non-virtual destructors** in polymorphic classes — clang-tidy `cppcoreguidelines-virtual-class-destructor`
8. **4 missing shebang lines** in shell scripts — shellcheck SC2148
9. **Invalid zsh syntax** used in bash script (`devshell/lib/vars.sh`) — shellcheck SC2298

---

### 7.1 Deep Dive: `missingReturn` — 8 findings (cppcheck) — [flutter/flutter#184486](https://github.com/flutter/flutter/issues/184486)

All 8 hits are in **`engine/src/flutter/testing/display_list_testing.cc`** — `operator<<` overloads for enum types that use `switch` statements covering every enum value but have no return after the switch.

```cpp
std::ostream& operator<<(std::ostream& os, const flutter::DlClipOp& op) {
  switch (op) {
    case flutter::DlClipOp::kDifference: return os << "DlClipOp::kDifference";
    case flutter::DlClipOp::kIntersect:  return os << "DlClipOp::kIntersect";
  }
  // <-- no return here: UB if enum has an unexpected value
}
```

Affected functions (lines 145, 188, 195, 204, 212, 220, 228, 237):
- `operator<<` for `DlPathFillType` (2 cases)
- `operator<<` for `DlClipOp` (2 cases)
- `operator<<` for `DlSrcRectConstraint` (2 cases)
- `operator<<` for `DlStrokeCap` (3 cases)
- `operator<<` for `DlStrokeJoin` (3 cases)
- `operator<<` for `DlDrawStyle` (3 cases)
- `operator<<` for `DlBlurStyle` (4 cases)
- `operator<<` for `DlPointMode` (3 cases)

**Verdict: Real bug (UB), low practical risk.** These are test-only ostream formatters. If a corrupt or out-of-range enum value is passed, control falls off the end of a non-void function, which is undefined behavior per C++ standard. GCC/Clang may produce a warning (`-Wreturn-type`) but the code compiles. The standard fix is to add a `return os << "Unknown";` after the switch, or use `__builtin_unreachable()` / `FML_UNREACHABLE()`.

---

### 7.2 Deep Dive: `uninitMemberVar` — 9 findings (cppcheck) — [flutter/flutter#184490](https://github.com/flutter/flutter/issues/184490)

| File | Member | Verdict |
|------|--------|---------|
| `round_superellipse_geometry.cc:62` | `UnevenQuadrantsRearranger::lengths_` | **Real bug.** `lengths_` is a `size_t[4]` array used in `ContourLength()` arithmetic but never initialized in the constructor. Callers fill it via `QuadSize(i)` before reading, but no guarantee enforces this. |
| `flutter_platform_node_delegate.h:96` | `FlutterPlatformNodeDelegate::ax_node_` | **Real bug.** Raw pointer member not initialized. If `Init()` is never called before `ax_node_` is read, it's UB. |
| `flutter_glfw.cc:160` | `FlutterDesktopMessenger::engine_` | **Real bug.** Raw pointer, not initialized. |
| `vulkan_application.cc:35` | `VulkanApplication::padding_` | **Likely benign.** Padding field — may be intentionally uninitialized. |
| `vulkan_swapchain_stub.cc:9` (5 hits) | `VulkanSwapchain::vk`, `device_`, `current_backbuffer_index_`, `current_image_index_`, `valid_` | **Real bug, but in a stub.** This is a stub implementation (`_stub.cc`) where the constructor is intentionally empty and `IsValid()` always returns false. The members are never read in the stub path, but they're technically uninitialized. |

**Verdict: 3 real bugs in production code** (`lengths_`, `ax_node_`, `engine_`). 5 are in stub/padding code where the practical risk is near zero. 1 is debatable (`padding_`).

---

### 7.3 Deep Dive: `bugprone-infinite-loop` — 8 findings (clang-tidy)

| File | Line | Loop | Verdict |
|------|------|------|---------|
| `dl_benchmarks.cc:775` | `for (size_t i = 0; i <= outer_vertex_count; i++)` | **False positive.** `i` is clearly incremented in the loop. clang-tidy was confused because `outer_vertex_count` is a `size_t` and the check involves `<=` with an unsigned type — but the loop terminates normally. |
| `stroke_path_geometry.cc:515` | `for (size_t i = trigs_.size() - 2u; i > 0u; --i)` | **False positive.** `i` is decremented. clang-tidy can't see that `--i` updates the condition variable when it's an unsigned wrapping pattern. |
| `description_gles.cc:75` | `for (std::string version_component; std::getline(istream, version_component, '.');)` | **False positive.** `std::getline` modifies `istream`'s state (the stream position and eof flag), which is the real loop condition. clang-tidy doesn't model `std::getline`'s effect on the stream. |
| `system_utils.cc:124` | `while (getline(locales_stream, s, ':'))` | **False positive.** Same pattern — `getline` advances the stream. clang-tidy doesn't track stream state. |
| `flutter_windows_engine_unittests.cc:81` | `while (!finished) { PumpMessage(); }` | **False positive.** `finished` is modified by a callback invoked via `PumpMessage()` (Windows message pump dispatches a task that sets `finished = true`). clang-tidy can't see through the callback indirection. |
| `flutter_windows_engine_unittests.cc:939` | `while (!finished) { engine->task_runner()->ProcessTasks(); }` | **False positive.** Same pattern — `finished` is set by a Dart engine callback during `ProcessTasks()`. The test comment confirms: "The test will only succeed when this while loop exits. Otherwise it will timeout." |
| `flutter_windows_engine_unittests.cc:1078` | `while (!finished) { ... ProcessTasks(); }` | **False positive.** Same pattern. |
| `flutter_windows_engine_unittests.cc:1411` | `while (!received_call) { ... ProcessTasks(); }` | **False positive.** Same pattern. |

**Verdict: All 8 are false positives.** clang-tidy's `bugprone-infinite-loop` cannot model: (a) `std::getline`'s effect on stream state, (b) callback-driven state changes through message pumps, or (c) unsigned decrement patterns. None are real infinite loops. These checks could be suppressed with `// NOLINT` or added to the expanded clang-tidy config's exclusion list.

---

### 7.4 Deep Dive: `nullPointerOutOfMemory` — 8 findings (cppcheck) — [flutter/flutter#184488](https://github.com/flutter/flutter/issues/184488)

All 8 hits are in Fuchsia FFI code and one Android test helper:

| File | Line | Code | Verdict |
|------|------|------|---------|
| `zircon_ffi/basic_types.cc:15` | `arr->length = size;` | `malloc` result not checked before dereference | **Real bug.** |
| `zircon_ffi/basic_types.cc:16` | `arr->data = ...` | Second `malloc` result not checked | **Real bug.** |
| `zircon_ffi/channel.cc:18` | `result->status = ...` | `malloc` result not checked | **Real bug.** |
| `zircon_ffi/channel.cc:30` | `result->bytes = ...` | `malloc` result not checked | **Real bug.** |
| `zircon_ffi/channel.cc:31` | `result->handles = ...` | `malloc` result not checked | **Real bug.** |
| `zircon_ffi/handle.cc:90` | `result->status = ...` | `malloc` result not checked | **Real bug.** |
| `zircon_ffi/handle.cc:91` | `result->info = ...` | `malloc` result not checked | **Real bug.** |
| `native_activity.cc:45` | `copied` | `malloc` result not checked | **Real bug (test code).** |

Example from `basic_types.cc`:
```cpp
zircon_dart_byte_array_t* zircon_dart_byte_array_create(uint32_t size) {
  zircon_dart_byte_array_t* arr = static_cast<zircon_dart_byte_array_t*>(
      malloc(sizeof(zircon_dart_byte_array_t)));
  arr->length = size;     // <-- null deref if malloc fails
  arr->data = static_cast<uint8_t*>(malloc(size * sizeof(uint8_t)));
  return arr;             // <-- arr->data could be null
}
```

**Verdict: All 8 are real bugs.** Every one dereferences a `malloc` return without null checking. In practice, `malloc` failure on modern Linux/Fuchsia is rare (OOM killer fires first), but it's still undefined behavior per the standard and a crash on systems with strict memory limits. The Fuchsia FFI code (`zircon_ffi/`) uses a C-style `malloc`/`free` pattern — the fix is either null checks or switching to C++ `new` (which throws on failure).

---

### 7.5 Deep Dive: Missing shebangs — 4 findings (shellcheck SC2148)

| File | Notes |
|------|-------|
| `engine/src/flutter/shell/platform/darwin/find-undocumented-ios.sh` | Script intended to be run directly. Starts with copyright comment, no `#!/bin/bash`. |
| `engine/src/flutter/testing/sanitizer_suppressions.sh` | Sourced via `source ./flutter/testing/sanitizer_suppressions.sh`. As a sourced file, a shebang is technically optional but still best practice for editors and linters. |
| `engine/src/flutter/tools/vscode_workspace/merge.sh` | Developer tool script. No shebang. |
| `engine/src/flutter/tools/vscode_workspace/refresh.sh` | Developer tool script. No shebang. |

**Verdict: Real (trivial).** All 4 files are `.sh` files without `#!/bin/bash` or `#!/usr/bin/env bash`. Without a shebang, the behavior depends on the parent shell or `exec()` default — which may not be bash. `sanitizer_suppressions.sh` is a sourced file so the shebang is cosmetic, but the other 3 are intended to be executed directly. Fix is a one-line addition to each file.

### By Area

| Area | Total Findings | Most Common Issue |
|------|---------------|-------------------|
| `engine/src/flutter/` | ~35,000+ | identifier-naming, include-cleaner, member-init |
| `dev/` (tests, benchmarks) | ~3,500+ | formatting, missing headers, unused variables |
| `examples/` | ~1,200+ | formatting, const-correctness |
| `packages/` | ~800+ | formatting, template code issues |
| `bin/` (shell scripts, SDK cache) | ~300+ | shellcheck warnings, syntax errors |

---

## Reproduction

```bash
# Enter the analysis shell
nix develop

# Run individual tools
flutter-find-cpp-files | wc -l          # 3,430 files
flutter-flawfinder                       # 191 security hits
flutter-cppcheck                         # 7,790+ findings
flutter-clang-format                     # 190 files with issues
flutter-shellcheck                       # 46 findings in 19 files

# Generate compile database (needed for clang-tidy and iwyu)
flutter-gen-compile-commands             # Creates compile_commands.json

# Run tools requiring compile database
flutter-clang-tidy                       # 41,920 findings
flutter-iwyu                             # 3,422 findings

# Run everything
flutter-analyze-all                      # Full suite with summary
```

---

## Notes

- **Synthetic compile database**: Without a full GN build, clang-tidy and IWYU lack real include paths. This inflates error counts (~3,380 clang-tidy errors and ~3,348 IWYU fatal errors are all missing-header issues). The ~35,000 clang-tidy *warnings* are real findings on successfully parsed code.
- **cppcheck C vs C++**: cppcheck's 1,872 `syntaxError` findings are from C++ code parsed without `--language=c++` flag — an artifact of running without a compile database specifying language.
- **Vendored code**: `bin/cache/` contains vendored Dart SDK and GPU package code. 25 of 190 clang-format failures are in vendored files.
- **Template files**: `packages/flutter_tools/templates/` contains code templates with placeholders — some findings are expected.
