The three members are left uninitialized by their constructors. Reading them before explicit assignment is undefined behavior:

**1. `lengths_[4]`** — `UnevenQuadrantsRearranger` constructor initializes `cache_` and `segment_capacity_` but not `lengths_`. The member is accessed in `QuadSize(i)` (returns `lengths_[i]`) and `ContourLength()` (sums all 4 elements). If called before the array is populated, the arithmetic operates on garbage values, producing incorrect geometry.

**2. `ax_node_`** — `FlutterPlatformNodeDelegate()` is `= default`, leaving the raw pointer uninitialized. It's set later in `Init()`. If any method (e.g., `GetAXNode()`, `AccessibilityPerformAction()`) is called before `Init()`, it dereferences an uninitialized pointer — crash or memory corruption.

**3. `engine_`** — `FlutterDesktopMessenger()` is `= default`, leaving the raw pointer uninitialized. `GetEngine()` returns the uninitialized pointer. If called before `SetEngine()`, the caller gets a garbage pointer.

In practice:
- **Debug builds** may appear to work because debug allocators often zero-fill memory
- **Release/optimized builds** will contain whatever was previously on the stack or heap
- **The compiler may optimize assuming these values are valid** (since accessing uninitialized memory is UB, the compiler can assume it doesn't happen)
