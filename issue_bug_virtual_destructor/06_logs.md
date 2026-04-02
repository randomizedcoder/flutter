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
