All fundamental-type members (raw pointers, integers, arrays of integers) should be initialized at the point of declaration using default member initializers, per [Abseil Tip #61](https://abseil.io/tips/61) and [Abseil Tip #182](https://abseil.io/tips/182).

The fix for each member:

**1. `UnevenQuadrantsRearranger::lengths_`** — zero-initialize the array:
```cpp
size_t lengths_[4] = {};  // zero-initializes all elements
```

**2. `FlutterPlatformNodeDelegate::ax_node_`** — initialize to nullptr:
```cpp
ui::AXNode* ax_node_ = nullptr;
```

**3. `FlutterDesktopMessenger::engine_`** (GLFW) — initialize to nullptr, matching the Windows version:
```cpp
FlutterDesktopEngineState* engine_ = nullptr;
```

**Note**: The Windows version of `FlutterDesktopMessenger` (in `flutter_desktop_messenger.h:74`) already correctly initializes `engine = nullptr`. The GLFW version should match this pattern.
