// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/fml/native_library.h"

#include <windows.h>

#include "flutter/fml/platform/win/wstring_conversion.h"

namespace fml {

NativeLibrary::NativeLibrary(const char* path)
    : handle_(nullptr), close_handle_(true) {
  if (path == nullptr) {
    return;
  }

  // Use LoadLibraryExW with safe search flags to prevent DLL hijacking via
  // the current working directory (CWE-114). Try System32 first (covers
  // system DLLs like user32.dll, opengl32.dll, Shcore.dll), then fall back
  // to default safe directories for app-bundled or user-added DLLs.
  // LOAD_LIBRARY_SEARCH_DEFAULT_DIRS includes the app directory, System32,
  // and user-added directories, but NOT the CWD.
  // See: https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-security
  handle_ = ::LoadLibraryExW(Utf8ToWideString(path).c_str(), nullptr,
                              LOAD_LIBRARY_SEARCH_SYSTEM32);
  if (handle_ == nullptr) {
    handle_ = ::LoadLibraryExW(Utf8ToWideString(path).c_str(), nullptr,
                                LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
  }
}

NativeLibrary::NativeLibrary(Handle handle, bool close_handle)
    : handle_(handle), close_handle_(close_handle) {}

NativeLibrary::~NativeLibrary() {
  if (handle_ != nullptr && close_handle_) {
    ::FreeLibrary(handle_);
  }
}

NativeLibrary::Handle NativeLibrary::GetHandle() const {
  return handle_;
}

fml::RefPtr<NativeLibrary> NativeLibrary::Create(const char* path) {
  auto library = fml::AdoptRef(new NativeLibrary(path));
  return library->GetHandle() != nullptr ? library : nullptr;
}

fml::RefPtr<NativeLibrary> NativeLibrary::CreateWithHandle(
    Handle handle,
    bool close_handle_when_done) {
  auto library =
      fml::AdoptRef(new NativeLibrary(handle, close_handle_when_done));
  return library->GetHandle() != nullptr ? library : nullptr;
}

fml::RefPtr<NativeLibrary> NativeLibrary::CreateForCurrentProcess() {
  return fml::AdoptRef(new NativeLibrary(::GetModuleHandle(nullptr), false));
}

NativeLibrary::SymbolHandle NativeLibrary::Resolve(const char* symbol) const {
  if (symbol == nullptr || handle_ == nullptr) {
    return nullptr;
  }
  return ::GetProcAddress(handle_, symbol);
}

}  // namespace fml
