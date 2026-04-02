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

**This is not a breaking change.** These classes already have virtual methods, so the vtable and vptr already exist. Adding a virtual destructor does not add a vtable where one didn't exist before — the memory overhead is zero.

**Note**: PR #180288 previously attempted a similar fix for the `Codec` base class but was closed. The fix pattern is identical and trivial — `virtual ~Base() = default;`.
