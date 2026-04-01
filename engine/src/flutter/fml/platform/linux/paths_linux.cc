// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <linux/limits.h>
#include <unistd.h>

#include "flutter/fml/paths.h"

namespace fml {
namespace paths {

std::pair<bool, std::string> GetExecutablePath() {
  char path[PATH_MAX];
  // flawfinder: ignore — /proc/self/exe is kernel-managed, not a TOCTOU risk
  ssize_t count = ::readlink("/proc/self/exe", path, sizeof(path));
  if (count <= 0) {
    return {false, ""};
  }
  return {true, std::string{path, static_cast<size_t>(count)}};
}

fml::UniqueFD GetCachesDirectory() {
  // Unsupported on this platform.
  return {};
}

}  // namespace paths
}  // namespace fml
