#!/usr/bin/env bash
# Run cppcheck on Flutter C++ files.
set -euo pipefail

cd "$FLUTTER_REPO_ROOT"

COMPILE_DB="${FLUTTER_REPO_ROOT}/compile_commands.json"
NPROC="$(nproc)"

COMMON_ARGS=(
  --enable=all
  --std=c++20
  -j "$NPROC"
  --suppress=missingInclude
  --suppress=unmatchedSuppression
  --inline-suppr
  --error-exitcode=1
)

if [[ $# -gt 0 ]]; then
  echo "Running cppcheck on $# specified files..."
  cppcheck "${COMMON_ARGS[@]}" "$@"
elif [[ -f "$COMPILE_DB" ]]; then
  echo "Running cppcheck with compile database..."
  cppcheck "${COMMON_ARGS[@]}" --project="$COMPILE_DB"
else
  echo "Running cppcheck on discovered files (no compile database)..."
  mapfile -t FILES < <(flutter-find-cpp-files)
  echo "Checking ${#FILES[@]} files..."
  cppcheck "${COMMON_ARGS[@]}" "${FILES[@]}"
fi
