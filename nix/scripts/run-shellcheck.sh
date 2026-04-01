#!/usr/bin/env bash
# Run shellcheck on all shell scripts in the Flutter repo.
set -euo pipefail

cd "$FLUTTER_REPO_ROOT"

mapfile -t FILES < <(find . -type f -name '*.sh' \
  ! -path '*/third_party/*' \
  ! -path '*/.dart_tool/*' \
  ! -path '*/build/*' \
  ! -path '*/.pub-cache/*' \
  | sort)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No shell scripts found."
  exit 0
fi

echo "Running shellcheck on ${#FILES[@]} shell scripts..."

shellcheck --severity=warning "${@}" "${FILES[@]}"
