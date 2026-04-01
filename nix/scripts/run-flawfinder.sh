#!/usr/bin/env bash
# Run flawfinder on Flutter C++ files.
set -euo pipefail

cd "$FLUTTER_REPO_ROOT"

mapfile -t FILES < <(flutter-find-cpp-files)

echo "Running flawfinder on ${#FILES[@]} files..."

flawfinder \
  --minlevel=2 \
  --columns \
  --context \
  "${@}" \
  "${FILES[@]}"
