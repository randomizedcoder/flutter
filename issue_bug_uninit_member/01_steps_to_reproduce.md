This is a code-level bug found via static analysis (cppcheck `uninitMemberVar`). Three classes in production engine code have member variables of fundamental types (raw pointers, `size_t` arrays) that are not initialized by their constructors. Any read of these members before explicit assignment is undefined behavior per the C++ standard.

**Why this matters**: Uninitialized fundamental-type members are a well-known class of C++ bug. As [Abseil Tip #182: "Initialize Your Ints!"](https://abseil.io/tips/182) states: *"C++ makes it too easy to leave variables uninitialized. This is scary, because almost any access to an uninitialized object results in Undefined Behavior."* [Abseil Tip #61: Default Member Initializers](https://abseil.io/tips/61) further notes that fundamental types like `bool`, `int`, `double`, and raw pointers *"often slip through the cracks and end up uninitialized"* and recommends default member initializers to prevent this.

These bugs are particularly insidious because:

1. **They often "work" in debug builds** — debug allocators may zero-fill memory, masking the bug. Optimized/release builds use whatever garbage is on the stack or heap, producing intermittent, non-reproducible crashes or corrupted state.
2. **Compilers can exploit UB for optimization** — the compiler is allowed to assume UB cannot happen and optimize accordingly, potentially eliminating "defensive" code paths that check for zero/null.
3. **Sanitizers may not catch them** — MemorySanitizer (MSan) can detect uninitialized reads, but it is not enabled in all CI configurations. Valgrind can also detect them but is rarely used in CI due to performance overhead.

**Steps to reproduce**:

1. Run cppcheck on the affected files:
   ```
   cppcheck --enable=all --std=c++20 \
     engine/src/flutter/impeller/entity/geometry/round_superellipse_geometry.cc \
     engine/src/flutter/shell/platform/common/flutter_platform_node_delegate.h \
     engine/src/flutter/shell/platform/glfw/flutter_glfw.cc
   ```
2. Observe 3 `uninitMemberVar` errors in production code (plus additional findings in stub/padding code which are lower priority).

**Affected members**:

| File | Class | Member | Type | Constructor | Risk |
|------|-------|--------|------|-------------|------|
| `impeller/entity/geometry/round_superellipse_geometry.cc:105` | `UnevenQuadrantsRearranger` | `lengths_[4]` | `size_t[4]` | Not in initializer list | High — used in arithmetic (`QuadSize()`, `ContourLength()`) without guaranteed prior initialization |
| `shell/platform/common/flutter_platform_node_delegate.h:174` | `FlutterPlatformNodeDelegate` | `ax_node_` | `ui::AXNode*` | `= default` constructor, set in `Init()` | Medium — relies on `Init()` being called before any access; comment says "called only once, immediately after construction" but no enforcement |
| `shell/platform/glfw/flutter_glfw.cc:200` | `FlutterDesktopMessenger` | `engine_` | `FlutterDesktopEngineState*` | `= default` constructor, set via `SetEngine()` | Medium — raw pointer read via `GetEngine()` before `SetEngine()` returns garbage |

**Note**: The Windows version of `FlutterDesktopMessenger` (in `flutter_desktop_messenger.h`) correctly initializes `engine = nullptr`. The GLFW version does not — this inconsistency suggests the initialization was simply overlooked.

**Existing issue search**: We searched for related issues and PRs before filing. The following are related but do not identify these specific bugs:
- #127789 — "In flutter 3.10 our app crash when user start typing in text field in some windows devices" — closed (2024-06-06). Crash in accessibility code, but root cause was different.
- #182876 — "[Windows] External voice dictation tools cannot detect Flutter TextFields" — open. Accessibility-related but about missing automation support, not uninitialized members.

No existing issues or PRs address the uninitialized `lengths_`, `ax_node_`, or `engine_` members.
