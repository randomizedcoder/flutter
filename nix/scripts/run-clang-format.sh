#!/usr/bin/env bash
# Check (or fix) formatting of Flutter C++ files using clang-format.
# Pass --fix to auto-format in place.
set -euo pipefail

cd "$FLUTTER_REPO_ROOT"

FIX=false
EXTRA_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --fix)
      FIX=true
      ;;
    *)
      EXTRA_ARGS+=("$arg")
      ;;
  esac
done

# If specific files passed, use those; otherwise discover all
if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  FILES=("${EXTRA_ARGS[@]}")
else
  mapfile -t FILES < <(flutter-find-cpp-files)
fi

echo "Checking formatting of ${#FILES[@]} files..."

if [[ "$FIX" == true ]]; then
  printf '%s\n' "${FILES[@]}" | xargs -P "$(nproc)" clang-format -i --style=file
  echo "Formatting applied."
else
  FAILED=0
  for file in "${FILES[@]}"; do
    if ! clang-format --dry-run --Werror --style=file "$file" 2>/dev/null; then
      FAILED=$((FAILED + 1))
    fi
  done

  if [[ "$FAILED" -gt 0 ]]; then
    echo "$FAILED file(s) have formatting issues. Run with --fix to auto-format."
    exit 1
  else
    echo "All files formatted correctly."
  fi
fi
