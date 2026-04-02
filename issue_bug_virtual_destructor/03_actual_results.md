When a derived object is deleted through a base pointer that lacks a virtual destructor, the behavior is undefined per [expr.delete/3]:

> *"if the static type of the object to be deleted is different from its dynamic type and the selected deallocation function is not a destroying operator delete, the static type shall have a virtual destructor or the behavior is undefined."*

**`AccessibilityPlugin`** — this is the most critical case. `FlutterWindowsEngine` stores it as `std::unique_ptr<AccessibilityPlugin>`. When the engine is destroyed, `unique_ptr` calls `delete` on the `AccessibilityPlugin*` base pointer. Without a virtual destructor:
- The derived class destructor is **not called**
- Any resources held by the derived class are **leaked**
- The compiler is allowed to assume UB doesn't happen and may **optimize away** seemingly-unrelated code

**`VariableRefreshRateReporter`** — stored as `shared_ptr<VariableRefreshRateReporter>`. Currently safe by accident (`shared_ptr` type-erases the deleter at construction time, so if constructed with the concrete type, the correct destructor is called). However, this is fragile — any `static_pointer_cast` or `make_shared<VariableRefreshRateReporter>()` would break it.

**The remaining ~11 classes** are currently safe (never deleted through base pointer), but represent a maintenance hazard. Any future code that stores them via `unique_ptr<Base>` or `shared_ptr<Base>` would silently introduce UB.
