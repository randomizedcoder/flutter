<details open><summary>Code sample</summary>

This is a C/C++ engine bug in the Fuchsia zircon FFI layer. The affected code:

**`engine/src/flutter/shell/platform/fuchsia/dart_pkg/zircon_ffi/basic_types.cc`** (user-controlled size):
```cpp
ZIRCON_FFI_EXPORT
zircon_dart_byte_array_t* zircon_dart_byte_array_create(uint32_t size) {
  zircon_dart_byte_array_t* arr = static_cast<zircon_dart_byte_array_t*>(
      malloc(sizeof(zircon_dart_byte_array_t)));
  arr->length = size;     // BUG: NULL deref if malloc fails
  arr->data = static_cast<uint8_t*>(malloc(size * sizeof(uint8_t)));
  // BUG: arr->data could be NULL — no check
  return arr;
}
```

**`engine/src/flutter/shell/platform/fuchsia/dart_pkg/zircon_ffi/channel.cc`** (two functions):
```cpp
static zircon_dart_handle_t* MakeHandle(zx_handle_t handle) {
  zircon_dart_handle_t* result = static_cast<zircon_dart_handle_t*>(
      malloc(sizeof(zircon_dart_handle_t)));
  result->handle = handle;  // BUG: NULL deref if malloc fails
  return result;
}

ZIRCON_FFI_EXPORT
zircon_dart_handle_pair_t* zircon_dart_channel_create(uint32_t options) {
  // ...
  zircon_dart_handle_pair_t* result = static_cast<zircon_dart_handle_pair_t*>(
      malloc(sizeof(zircon_dart_handle_pair_t)));
  result->left = MakeHandle(out0);   // BUG: NULL deref if malloc fails
  result->right = MakeHandle(out1);
  return result;
}
```

**`engine/src/flutter/shell/platform/fuchsia/dart_pkg/zircon_ffi/handle.cc`**:
```cpp
ZIRCON_FFI_EXPORT
zircon_dart_handle_list_t* zircon_dart_handle_list_create() {
  zircon_dart_handle_list_t* result = static_cast<zircon_dart_handle_list_t*>(
      malloc(sizeof(zircon_dart_handle_list_t)));
  result->size = 0;     // BUG: NULL deref if malloc fails
  result->data = nullptr;
  return result;
}
```

**Fix pattern** — add NULL check after every malloc:
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

</details>
