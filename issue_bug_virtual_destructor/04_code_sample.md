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
