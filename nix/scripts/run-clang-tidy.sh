#!/usr/bin/env bash
# Run clang-tidy with expanded checks on Flutter C++ files.
set -euo pipefail

cd "$FLUTTER_REPO_ROOT"

COMPILE_DB="${FLUTTER_REPO_ROOT}/compile_commands.json"

if [[ ! -f "$COMPILE_DB" ]]; then
  echo "Error: compile_commands.json not found at $COMPILE_DB"
  echo "Run flutter-gen-compile-commands first."
  exit 1
fi

EXTRA_ARGS=()
if [[ -f "$CLANG_TIDY_CONFIG" ]]; then
  EXTRA_ARGS+=("--config-file=$CLANG_TIDY_CONFIG")
fi

# If specific files are passed as arguments, use those; otherwise discover all
if [[ $# -gt 0 ]]; then
  FILES=("$@")
else
  mapfile -t FILES < <(flutter-find-cpp-files)
fi

echo "Running clang-tidy on ${#FILES[@]} files..."

# Use run-clang-tidy for parallel execution if available
if command -v run-clang-tidy &>/dev/null; then
  run-clang-tidy \
    -p "$FLUTTER_REPO_ROOT" \
    -quiet \
    "${EXTRA_ARGS[@]}" \
    "${FILES[@]}"
else
  # Fallback: run clang-tidy directly with xargs for parallelism
  printf '%s\n' "${FILES[@]}" | xargs -P "$(nproc)" -I{} \
    clang-tidy \
      -p "$FLUTTER_REPO_ROOT" \
      --quiet \
      "${EXTRA_ARGS[@]}" \
      {}
fi
