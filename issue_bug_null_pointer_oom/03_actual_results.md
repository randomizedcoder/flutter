When `malloc` returns NULL (out of memory), the code immediately dereferences the NULL pointer:

```cpp
// basic_types.cc — two unchecked mallocs
zircon_dart_byte_array_t* arr = static_cast<zircon_dart_byte_array_t*>(
    malloc(sizeof(zircon_dart_byte_array_t)));
arr->length = size;     // <-- NULL deref if malloc failed
arr->data = static_cast<uint8_t*>(malloc(size * sizeof(uint8_t)));
// arr->data could be NULL — later deref in set_value() will crash
```

This is **undefined behavior** per the C++ standard. In practice:
- **SIGSEGV crash** on all modern systems (page 0 is unmapped)
- Not exploitable for code execution (ASLR, NX, unmapped page 0)
- **More likely to occur on Fuchsia** than Linux because Fuchsia does not overcommit memory — `malloc` actually returns NULL when memory is exhausted, rather than relying on an OOM killer

The `zircon_dart_byte_array_create` function is particularly concerning because:
1. The `size` parameter is user-controlled (passed from Dart FFI)
2. If the struct alloc succeeds but `malloc(size * sizeof(uint8_t))` fails, the returned struct has `data == NULL`
3. The caller has no way to detect this — `zircon_dart_byte_array_set_value()` will crash on `arr->data[index]`
