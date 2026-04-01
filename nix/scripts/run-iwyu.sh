#!/usr/bin/env bash
# Run include-what-you-use on Flutter C++ files.
# Requires compile_commands.json.
set -euo pipefail

cd "$FLUTTER_REPO_ROOT"

COMPILE_DB="${FLUTTER_REPO_ROOT}/compile_commands.json"

if [[ ! -f "$COMPILE_DB" ]]; then
  echo "Error: compile_commands.json not found at $COMPILE_DB"
  echo "Run flutter-gen-compile-commands first."
  exit 1
fi

echo "Running include-what-you-use..."

# Use iwyu_tool.py for parallel execution if available
if command -v iwyu_tool.py &>/dev/null; then
  iwyu_tool.py -p "$FLUTTER_REPO_ROOT" -j "$(nproc)" "$@"
elif command -v iwyu_tool &>/dev/null; then
  iwyu_tool -p "$FLUTTER_REPO_ROOT" -j "$(nproc)" "$@"
else
  echo "Warning: iwyu_tool.py not found, running include-what-you-use directly..."
  mapfile -t FILES < <(flutter-find-cpp-files)
  for file in "${FILES[@]}"; do
    include-what-you-use "$file" 2>&1 || true
  done
fi
