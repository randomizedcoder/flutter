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
