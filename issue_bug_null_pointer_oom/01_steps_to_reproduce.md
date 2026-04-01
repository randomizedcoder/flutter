This is a code-level bug found via static analysis (cppcheck `nullPointerOutOfMemory`, CWE-476/CWE-252). Seven `malloc` call sites in the Fuchsia `zircon_ffi` package dereference the return value without checking for NULL. If `malloc` fails (returns NULL), the code triggers undefined behavior via NULL pointer dereference.

**Why this matters on Fuchsia specifically**: Unlike Linux, **Fuchsia does not overcommit memory**. On Linux, the OOM killer typically terminates processes before `malloc` returns NULL (due to overcommit), making these bugs hard to trigger in practice. On Fuchsia, `malloc` **actually returns NULL** when memory is exhausted. These bugs are more likely to trigger on the platform they were written for.

**Security impact**: This is a **denial-of-service / crash** bug (CWE-476 — NULL Pointer Dereference), not a code execution vulnerability. On modern systems with ASLR and unmapped page 0, dereferencing NULL causes SIGSEGV — a crash, not exploitable memory corruption. However:

1. **User-controlled allocation size** — `zircon_dart_byte_array_create(uint32_t size)` takes a size parameter directly from Dart FFI callers. A caller can request a very large allocation, cause `malloc` to fail, and crash the process.
2. **All 7 functions are `ZIRCON_FFI_EXPORT`** — public C APIs callable from Dart code, meaning untrusted Dart code can trigger these crashes.
3. **Cascading NULL** — In `zircon_dart_byte_array_create`, the struct allocation may succeed but the data buffer allocation may fail, returning a struct with a NULL `data` pointer. Subsequent calls to `zircon_dart_byte_array_set_value()` will crash when dereferencing `arr->data[index]`.

**Google style guidance**: The Google C++ Style Guide recommends `std::unique_ptr` / `std::make_unique` over raw `new` or `malloc` ([Abseil Tip #126: `make_unique` is the new `new`](https://abseil.io/tips/126)). Using C++ `new` would throw `std::bad_alloc` on failure (catchable), while `std::make_unique` makes ownership explicit. The use of C-style `malloc` in these FFI functions is necessary for the C ABI, but the missing NULL checks violate [CERT MEM32-C: "Detect and handle memory allocation errors"](https://wiki.sei.cmu.edu/confluence/display/c/MEM32-C). Chromium addresses this with `base::UncheckedMalloc()` / `base::UncheckedCalloc()` wrappers in `base/process/memory.h`, which include the explicit warning: *"Please only use this if you really handle the case when the allocation fails. Doing otherwise would risk security."*

**Steps to reproduce**:

1. Run cppcheck on the Fuchsia zircon_ffi source files:
   ```
   cppcheck --enable=all --std=c++20 \
     engine/src/flutter/shell/platform/fuchsia/dart_pkg/zircon_ffi/basic_types.cc \
     engine/src/flutter/shell/platform/fuchsia/dart_pkg/zircon_ffi/channel.cc \
     engine/src/flutter/shell/platform/fuchsia/dart_pkg/zircon_ffi/handle.cc
   ```
2. Observe 7 `nullPointerOutOfMemory` errors — each is a `malloc` return value dereferenced without a NULL check.
3. Alternatively, run a Flutter app on Fuchsia under memory pressure and call `zircon_dart_byte_array_create()` with a large size — the process will crash with SIGSEGV.

**Affected call sites** (all in `engine/src/flutter/shell/platform/fuchsia/dart_pkg/zircon_ffi/`):

| File | Line | Function | malloc size | User-controlled? |
|------|------|----------|-------------|-----------------|
| `basic_types.cc` | 14 | `zircon_dart_byte_array_create` | `sizeof(zircon_dart_byte_array_t)` (fixed) | No |
| `basic_types.cc` | 16 | `zircon_dart_byte_array_create` | `size * sizeof(uint8_t)` | **Yes** — `size` param from Dart |
| `channel.cc` | 17 | `MakeHandle` (static) | `sizeof(zircon_dart_handle_t)` (fixed) | No |
| `channel.cc` | 29 | `zircon_dart_channel_create` | `sizeof(zircon_dart_handle_pair_t)` (fixed) | No |
| `channel.cc` | 30–31 | `zircon_dart_channel_create` | (via `MakeHandle`) | No |
| `handle.cc` | 89 | `zircon_dart_handle_list_create` | `sizeof(zircon_dart_handle_list_t)` (fixed) | No |
| `handle.cc` | 90–91 | `zircon_dart_handle_list_create` | (deref of result) | No |

**Existing issue search**: We searched for related issues and PRs before filing. The following are related but do not identify these specific bugs:
- #182574 — "Rename 'dart-pkg' to 'dart_pkg' in the Fuchsia Flutter Engine" — merged (2026-02-25). Renamed the directory containing these files but did not modify the code. Note: file paths in this issue use the new `dart_pkg` name.
- #133569 — "[engine] A wish for better Dart testing in the engine" — closed (2024-09-27). Discusses zircon_ffi testing gaps but does not identify the unchecked malloc calls.

No existing issues or PRs address the missing NULL checks in `zircon_ffi/basic_types.cc`, `channel.cc`, or `handle.cc`.
