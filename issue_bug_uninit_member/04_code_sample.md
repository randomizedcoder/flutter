<details open><summary>Code sample</summary>

**Bug 1 — `round_superellipse_geometry.cc`** (uninitialized array):
```cpp
class UnevenQuadrantsRearranger {
 public:
  UnevenQuadrantsRearranger(Point* cache, size_t segment_capacity)
      : cache_(cache), segment_capacity_(segment_capacity) {}
      // BUG: lengths_ not initialized

  size_t QuadSize(size_t i) const { return lengths_[i]; }  // reads garbage

  size_t ContourLength() const {
    return lengths_[0] + lengths_[1] + lengths_[2] + lengths_[3];  // garbage arithmetic
  }

 private:
  Point* cache_;
  size_t segment_capacity_;
  size_t lengths_[4];  // BUG: not initialized
};
```

**Bug 2 — `flutter_platform_node_delegate.h`** (uninitialized pointer):
```cpp
class FlutterPlatformNodeDelegate : public ui::AXPlatformNodeDelegateBase {
 public:
  FlutterPlatformNodeDelegate();  // = default — does not initialize ax_node_

  void Init(std::weak_ptr<OwnerBridge> bridge, ui::AXNode* node);
  // ^ sets ax_node_, but nothing enforces it's called before access

  ui::AXNode* GetAXNode() const override { return ax_node_; }  // reads garbage if Init() not called

 private:
  ui::AXNode* ax_node_;  // BUG: not initialized
};
```

**Bug 3 — `flutter_glfw.cc`** (uninitialized pointer, inconsistent with Windows version):
```cpp
// GLFW version (BUG):
struct FlutterDesktopMessenger {
  FlutterDesktopMessenger() = default;  // does not initialize engine_
  FlutterDesktopEngineState* GetEngine() const { return engine_; }  // reads garbage
 private:
  FlutterDesktopEngineState* engine_;  // BUG: not initialized
};

// Windows version (CORRECT — flutter_desktop_messenger.h):
// FlutterDesktopEngineState* engine = nullptr;  // ← properly initialized
```

**Fix** — add default member initializers:
```cpp
// Bug 1:
size_t lengths_[4] = {};

// Bug 2:
ui::AXNode* ax_node_ = nullptr;

// Bug 3:
FlutterDesktopEngineState* engine_ = nullptr;
```

</details>
