This is a code-level bug found via static analysis (clang-tidy `cppcoreguidelines-virtual-class-destructor`). Multiple polymorphic base classes in the engine have virtual methods but no virtual destructor. Deleting a derived object through a base pointer in this situation is undefined behavior per the C++ standard ([expr.delete/3](https://eel.is/c++draft/expr.delete#3)).

Out of 64 clang-tidy findings, approximately 40 are **false positives** (the class inherits a virtual destructor from a grandparent, or is `final`). The remaining ~13 are real issues that need `virtual ~ClassName() = default;` added. Of these, **2 are actively dangerous** because objects are currently deleted through base pointers:

**Bug 1 — `AccessibilityPlugin`** (`shell/platform/windows/accessibility_plugin.h`):
- Has pure virtual method `Announce()`
- No virtual destructor
- Stored as `std::unique_ptr<AccessibilityPlugin>` in `FlutterWindowsEngine`
- **When the `unique_ptr` is destroyed, it calls `delete` through the base pointer — the derived class destructor is not called. This is UB.**

**Bug 2 — `VariableRefreshRateReporter`** (`shell/common/variable_refresh_rate_reporter.h`):
- Has pure virtual method `GetRefreshRate()`
- No virtual destructor
- Stored as `std::shared_ptr<VariableRefreshRateReporter>` and `std::weak_ptr<VariableRefreshRateReporter>`
- Current implementor is `VsyncWaiterIOS final`, and `shared_ptr` is created with the concrete type (so the type-erased deleter happens to work). However, this is fragile — any code path that constructs a `shared_ptr<VariableRefreshRateReporter>` directly (e.g., via `static_pointer_cast`) would trigger UB.

**Additional high-value fixes** (not currently dangerous, but prevent future UB):

| Priority | Class | File | Why |
|----------|-------|------|-----|
| 3 | `DlOpReceiver` | `display_list/dl_op_receiver.h` | ~100 pure virtuals, wide hierarchy — fixing this cascades to fix 10+ derived class warnings |
| 4 | `SnapshotDelegate` | `lib/ui/snapshot_delegate.h` | 7+ pure virtuals, stored as `TaskRunnerAffineWeakPtr<SnapshotDelegate>` |
| 5 | `ServiceProtocol::Handler` | `runtime/service_protocol.h` | 3 pure virtuals, stored as `Handler*` in a map |
| 6 | `WindowBindingHandlerDelegate` | `shell/platform/windows/window_binding_handler_delegate.h` | ~20 pure virtuals |
| 7 | `GPUSurfaceGLDelegate` | `shell/gpu/gpu_surface_gl_delegate.h` | Has non-virtual destructor (should be virtual) |
| 8 | `GPUSurfaceSoftwareDelegate` | `shell/gpu/gpu_surface_software_delegate.h` | Same pattern |
| 9 | `AtlasGeometry` | `impeller/entity/contents/atlas_contents.h` | 8 pure virtuals, derived class has its own destructor |
| 10 | `Comparable<T>` | `impeller/base/comparable.h` | Template base, 2 pure virtuals |
| 11 | `PathTessellator::VertexWriter` / `SegmentReceiver` | `impeller/tessellator/path_tessellator.h` | Always used by reference (low risk) |
| 12 | `TaskRunnerWindow::Delegate` | `shell/platform/windows/task_runner_window.h` | Non-owning pointer storage |

**Style guide and industry references**:

1. **C++ Core Guidelines [C.35](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines#Rc-dtor-virtual)**: *"A base class destructor should be either public and virtual, or protected and non-virtual."* This is the canonical rule for this class of bug.

2. **Chromium enforces this at compile time** — Chromium's custom Clang plugin (`FindBadConstructs.cpp`) emits `[chromium-style]` errors for ref-counted classes with non-private, non-virtual destructors. Chromium also compiles with `-Wdelete-non-virtual-dtor` (enabled by `-Wall`), which warns when deleting through a base pointer without a virtual destructor.

3. **Chromium's own base classes follow this pattern** — [`base::CheckedObserver`](https://chromium.googlesource.com/chromium/src/+/main/base/observer_list_types.h) (the canonical observer base) declares `virtual ~CheckedObserver();`, and [`base::TaskRunner`](https://chromium.googlesource.com/chromium/src/+/main/base/task/task_runner.h) declares `virtual ~TaskRunner();`. Flutter's `AccessibilityPlugin` is analogous to these — a polymorphic interface stored via owning smart pointer — and should follow the same pattern.

4. **GCC/Clang `-Wdelete-non-virtual-dtor`** — this compiler warning (included in `-Wall`) directly detects this bug pattern. Enabling it for the Flutter engine build would catch these issues automatically.

**Steps to reproduce**:

1. Run clang-tidy with `cppcoreguidelines-virtual-class-destructor` enabled on the engine source.
2. Observe 64 findings. After filtering out false positives (~40 where virtual dtor is inherited or class is `final`), 13 real issues remain.
3. Confirm `AccessibilityPlugin` is stored as `unique_ptr<AccessibilityPlugin>` in `FlutterWindowsEngine` — deletion through this pointer is UB without a virtual destructor.

**Existing issue search**: We searched for related issues and PRs before filing:
- #180288 — "[engine] fix missing virtual destructor in Codec base class" — **closed without merging** (2026-02-05). Attempted to fix the same class of bug in the `Codec` base class. The PR author noted crashes affecting "thousands of users every month" potentially caused by missing virtual destructor. References #161031.
- #161031 — "[engine] potential crash on deref of canvas_image_ in single_frame_codec.cc" — closed.
- #178682 — "remove unnecessary virtual destructor from VertexDescriptor" — merged (2025-12-19). Went the opposite direction, removing a virtual destructor from a `final` class (correct — `final` classes don't need it).
- #82917 / #82951 — UWP build failures mentioning "non-virtual destructor" in error output. Unrelated (old UWP issues).

No existing issue tracks the systematic `cppcoreguidelines-virtual-class-destructor` findings across the engine.
