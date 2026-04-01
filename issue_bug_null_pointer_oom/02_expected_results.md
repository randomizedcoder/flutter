Every `malloc` call should check for NULL before dereferencing the returned pointer. On failure, the function should return NULL (or an error sentinel) so the Dart FFI caller can handle the failure gracefully instead of crashing.

The fix for each function follows this pattern:

```cpp
zircon_dart_byte_array_t* zircon_dart_byte_array_create(uint32_t size) {
  zircon_dart_byte_array_t* arr = static_cast<zircon_dart_byte_array_t*>(
      malloc(sizeof(zircon_dart_byte_array_t)));
  if (arr == nullptr) {
    return nullptr;
  }
  arr->length = size;
  arr->data = static_cast<uint8_t*>(malloc(size * sizeof(uint8_t)));
  if (arr->data == nullptr) {
    free(arr);
    return nullptr;
  }
  return arr;
}
```

This is consistent with:
- [CERT MEM32-C](https://wiki.sei.cmu.edu/confluence/display/c/MEM32-C): "Detect and handle memory allocation errors"
- [Abseil Tip #126](https://abseil.io/tips/126): Prefer `make_unique` over raw `new`/`malloc` — but since these are C FFI functions requiring a C ABI, `malloc` + NULL checks is the appropriate pattern
- Chromium's `base/process/memory.h`: *"Please only use this if you really handle the case when the allocation fails. Doing otherwise would risk security."*
