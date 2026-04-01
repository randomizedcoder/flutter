#!/usr/bin/env bash
# Finds C++ source and header files in the Flutter repo, excluding generated/vendored code.
set -euo pipefail

cd "$FLUTTER_REPO_ROOT"

find . \
  -type f \
  \( -name '*.cc' -o -name '*.cpp' -o -name '*.h' -o -name '*.hpp' -o -name '*.mm' \) \
  ! -path '*/third_party/*' \
  ! -path '*/gen/*' \
  ! -path '*/.dart_tool/*' \
  ! -path '*/build/*' \
  ! -path '*/generated_plugin_registrant.*' \
  ! -path '*/.pub-cache/*' \
  | sort
