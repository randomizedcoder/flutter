## Missing virtual destructors in polymorphic base classes cause undefined behavior on deletion

### Steps to reproduce

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

### Expected results

Every polymorphic base class (class with virtual methods) should have a virtual destructor, per C++ Core Guidelines [C.35: "A base class destructor should be either public and virtual, or protected and non-virtual"](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines#Rc-dtor-virtual).

The fix for each class is a one-line addition:

```cpp
virtual ~ClassName() = default;
```

**Highest priority fixes** (currently UB):

```cpp
// shell/platform/windows/accessibility_plugin.h
class AccessibilityPlugin {
 public:
  virtual ~AccessibilityPlugin() = default;  // ADD THIS
  virtual void Announce(const FlutterViewId view_id, std::u16string text) = 0;
};

// shell/common/variable_refresh_rate_reporter.h
class VariableRefreshRateReporter {
 public:
  virtual ~VariableRefreshRateReporter() = default;  // ADD THIS
  virtual double GetRefreshRate() const = 0;
};
```

**Cascade fix** — adding a virtual destructor to `DlOpReceiver` would resolve ~10 additional warnings in its derived class hierarchy:

```cpp
// display_list/dl_op_receiver.h
class DlOpReceiver {
 public:
  virtual ~DlOpReceiver() = default;  // ADD THIS — fixes 10+ derived class warnings
  // ... ~100 pure virtual methods
};
```

**Note**: PR #180288 previously attempted a similar fix for the `Codec` base class but was closed. The fix pattern is identical and trivial — `virtual ~Base() = default;`.

### Actual results

When a derived object is deleted through a base pointer that lacks a virtual destructor, the behavior is undefined per [expr.delete/3]:

> *"if the static type of the object to be deleted is different from its dynamic type and the selected deallocation function is not a destroying operator delete, the static type shall have a virtual destructor or the behavior is undefined."*

**`AccessibilityPlugin`** — this is the most critical case. `FlutterWindowsEngine` stores it as `std::unique_ptr<AccessibilityPlugin>`. When the engine is destroyed, `unique_ptr` calls `delete` on the `AccessibilityPlugin*` base pointer. Without a virtual destructor:
- The derived class destructor is **not called**
- Any resources held by the derived class are **leaked**
- The compiler is allowed to assume UB doesn't happen and may **optimize away** seemingly-unrelated code

**`VariableRefreshRateReporter`** — stored as `shared_ptr<VariableRefreshRateReporter>`. Currently safe by accident (`shared_ptr` type-erases the deleter at construction time, so if constructed with the concrete type, the correct destructor is called). However, this is fragile — any `static_pointer_cast` or `make_shared<VariableRefreshRateReporter>()` would break it.

**The remaining ~11 classes** are currently safe (never deleted through base pointer), but represent a maintenance hazard. Any future code that stores them via `unique_ptr<Base>` or `shared_ptr<Base>` would silently introduce UB.

### Recommended fix strategy

The fix for each class is `virtual ~ClassName() = default;` in the header file.

**This is not a breaking change.** These classes already have virtual methods, so the vtable and vptr already exist. Adding a virtual destructor does not add a vtable where one didn't exist before — the memory overhead is zero.

We recommend splitting the fix into two waves to make review easier:

**Wave 1 — Critical defect fixes:**
- `AccessibilityPlugin` — active UB via `unique_ptr<Base>` deletion
- `VariableRefreshRateReporter` — fragile, works by accident via `shared_ptr` type-erased deleter

**Wave 2 — Hygiene / cleanup:**
- `DlOpReceiver` — cascade fix that resolves ~10 additional warnings in derived classes. High value because it reduces static analysis noise, making it easier for maintainers to spot new bugs in the future.
- The remaining ~10 interface classes (`SnapshotDelegate`, `ServiceProtocol::Handler`, `WindowBindingHandlerDelegate`, `GPUSurfaceGLDelegate`, `GPUSurfaceSoftwareDelegate`, `AtlasGeometry`, `Comparable<T>`, `PathTessellator::VertexWriter`/`SegmentReceiver`, `TaskRunnerWindow::Delegate`)

**Header vs. implementation:** Since these are mostly pure virtual interface classes, `= default;` should stay in the header file. (In rare cases where a stable ABI requires anchoring the vtable, maintainers might prefer an empty destructor in the `.cc` file — but for the Flutter engine's internal classes, header-only `= default` is standard practice.)

### Code sample

<details open><summary>Code sample</summary>

**Bug 1 — `AccessibilityPlugin`** (active UB — deleted through base pointer):

```cpp
// shell/platform/windows/accessibility_plugin.h
class AccessibilityPlugin {
 public:
  virtual void Announce(const FlutterViewId view_id, std::u16string text) = 0;
  // BUG: no virtual destructor
};

// shell/platform/windows/flutter_windows_engine.h — stores as unique_ptr<Base>:
class FlutterWindowsEngine {
  std::unique_ptr<AccessibilityPlugin> accessibility_plugin_;
  // When FlutterWindowsEngine is destroyed, unique_ptr calls
  // delete on AccessibilityPlugin* — UB without virtual destructor
};
```

**Bug 2 — `VariableRefreshRateReporter`** (fragile — works by accident):

```cpp
// shell/common/variable_refresh_rate_reporter.h
class VariableRefreshRateReporter {
 public:
  virtual double GetRefreshRate() const = 0;
  // BUG: no virtual destructor
};

// shell/common/variable_refresh_rate_display.h — stores as shared_ptr<Base>:
class VariableRefreshRateDisplay : public Display {
  std::shared_ptr<VariableRefreshRateReporter> refresh_rate_reporter_;
  // Currently safe only because shared_ptr type-erases the deleter.
  // Any static_pointer_cast would break this.
};
```

**Cascade fix — `DlOpReceiver`** (resolves 10+ warnings):

```cpp
// display_list/dl_op_receiver.h — ~100 pure virtuals, wide hierarchy
class DlOpReceiver {
 public:
  // BUG: no virtual destructor — derived classes include:
  // DlDispatcherBase, DlSkCanvasDispatcher, DlSkPaintDispatchHelper,
  // IgnoreAttributeDispatchHelper, IgnoreClipDispatchHelper,
  // IgnoreTransformDispatchHelper, IgnoreDrawDispatchHelper,
  // DisplayListBuilder, DlOpSpy, ...

  virtual void setAntiAlias(bool aa) = 0;
  // ... ~100 more pure virtuals
};
```

**Fix** — one line per class:
```cpp
virtual ~AccessibilityPlugin() = default;
virtual ~VariableRefreshRateReporter() = default;
virtual ~DlOpReceiver() = default;
// ... same for each affected class
```

</details>

### Screenshots or Video demonstration

<details open>
<summary>Screenshots / Video demonstration</summary>

Not applicable — this is a C++ engine code bug found by static analysis, not a visual issue.

</details>

### Logs

<details open><summary>Logs</summary>

Static analysis output that identified the bugs (representative sample — 64 total findings):

```console
$ clang-tidy --checks='cppcoreguidelines-virtual-class-destructor' \
    engine/src/flutter/shell/platform/windows/accessibility_plugin.h

warning: destructor of 'AccessibilityPlugin' is non-virtual but has virtual functions [cppcoreguidelines-virtual-class-destructor]

$ clang-tidy --checks='cppcoreguidelines-virtual-class-destructor' \
    engine/src/flutter/shell/common/variable_refresh_rate_reporter.h

warning: destructor of 'VariableRefreshRateReporter' is non-virtual but has virtual functions [cppcoreguidelines-virtual-class-destructor]

$ clang-tidy --checks='cppcoreguidelines-virtual-class-destructor' \
    engine/src/flutter/display_list/dl_op_receiver.h

warning: destructor of 'DlOpReceiver' is non-virtual but has virtual functions [cppcoreguidelines-virtual-class-destructor]
```

Breakdown of all 64 findings:
- **~40 false positives** — class inherits virtual destructor from parent/grandparent, or class is `final`
- **2 active UB** — `AccessibilityPlugin` (deleted via `unique_ptr<Base>`), `VariableRefreshRateReporter` (stored as `shared_ptr<Base>`)
- **~11 preventive fixes** — classes not currently deleted through base pointer, but should have virtual destructors for safety

Classification:
- C++ Core Guidelines [C.35](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines#Rc-dtor-virtual): "A base class destructor should be either public and virtual, or protected and non-virtual"
- C++ Standard [expr.delete/3]: Deleting through base pointer without virtual destructor is UB

Related prior work:
- PR #180288 — attempted to fix missing virtual destructor in `Codec` base class (closed without merging, 2026-02-05)
- PR #178682 — correctly removed unnecessary virtual destructor from `final` class `VertexDescriptor` (merged, 2025-12-19)

</details>

### Flutter Doctor output

<details open><summary>Doctor output</summary>

```console
[!] Flutter (Channel [user-branch], 3.43.0-1.0.pre-391, on NixOS 26.05 (Yarara) 6.19.9, locale en_US.UTF-8) [51ms]
    ! Flutter version 3.43.0-1.0.pre-391 on channel [user-branch] at /home/das/Downloads/flutter
      Currently on an unknown channel. Run `flutter channel` to switch to an official channel.
      If that doesn't fix the issue, reinstall Flutter by following instructions at https://flutter.dev/setup.
    • Framework revision c589dfffda (16 hours ago), 2026-03-31 22:16:58 -0400
    • Engine revision be1e70f0a8
    • Dart version 3.12.0 (build 3.12.0-304.0.dev)
    • DevTools version 2.57.0-dev.0

[!] Android toolchain - develop for Android devices (Android SDK version 31.0.0)
    • Android SDK at /home/das/Android/Sdk

[✓] Chrome - develop for the web
    • CHROME_EXECUTABLE = /nix/store/5fyi5df2lfhmvjgvlkdm5b46rbwxibsy-google-chrome-146.0.7680.153/bin/google-chrome-stable

[✗] Linux toolchain - develop for Linux desktop
    ✗ clang++ is required for Linux development.
    ✗ CMake is required for Linux development.
    ✗ ninja is required for Linux development.

[✓] Connected device (2 available)
    • Linux (desktop) • linux  • linux-x64      • NixOS 26.05 (Yarara) 6.19.9
    • Chrome (web)    • chrome • web-javascript • Google Chrome 146.0.7680.153

[✓] Network resources
    • All expected network resources are available.

! Doctor found issues in 3 categories.
```

</details>
