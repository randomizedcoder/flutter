#!/usr/bin/env bash
# Run all Flutter C++ static analysis tools and report a summary.
set -euo pipefail

cd "$FLUTTER_REPO_ROOT"

COMPILE_DB="${FLUTTER_REPO_ROOT}/compile_commands.json"
PASS=0
FAIL=0
SKIP=0

run_tool() {
  local name="$1"
  shift
  echo ""
  echo "===== $name ====="
  if "$@"; then
    echo "$name: PASSED"
    PASS=$((PASS + 1))
  else
    echo "$name: FAILED (exit code $?)"
    FAIL=$((FAIL + 1))
  fi
}

skip_tool() {
  local name="$1"
  local reason="$2"
  echo ""
  echo "===== $name ====="
  echo "SKIPPED: $reason"
  SKIP=$((SKIP + 1))
}

# Tools that don't need compile_commands.json
run_tool "flawfinder" flutter-flawfinder
run_tool "cppcheck" flutter-cppcheck
run_tool "clang-format" flutter-clang-format
run_tool "shellcheck" flutter-shellcheck

# Tools that require compile_commands.json
if [[ -f "$COMPILE_DB" ]]; then
  run_tool "clang-tidy" flutter-clang-tidy
  run_tool "iwyu" flutter-iwyu
else
  skip_tool "clang-tidy" "compile_commands.json not found (run flutter-gen-compile-commands)"
  skip_tool "iwyu" "compile_commands.json not found (run flutter-gen-compile-commands)"
fi

echo ""
echo "===== Summary ====="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Skipped: $SKIP"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
