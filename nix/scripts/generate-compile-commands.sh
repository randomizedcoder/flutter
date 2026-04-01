#!/usr/bin/env bash
# Generate compile_commands.json for the Flutter repo.
# Tiered: uses GN+ninja if available, otherwise synthesizes a minimal database.
set -euo pipefail

cd "$FLUTTER_REPO_ROOT"

OUTPUT="${1:-compile_commands.json}"

# Tier 1: GN-based generation
if command -v gn &>/dev/null && command -v ninja &>/dev/null; then
  OUT_DIR="out/static_analysis"
  echo "Using GN to generate compile commands..."
  gn gen "$OUT_DIR" --export-compile-commands
  if [[ -f "$OUT_DIR/compile_commands.json" ]]; then
    cp "$OUT_DIR/compile_commands.json" "$OUTPUT"
    echo "Generated $OUTPUT via GN ($(wc -l < "$OUTPUT") lines)"
    exit 0
  fi
fi

# Tier 2: Synthesize minimal compile_commands.json
echo "GN/ninja not available; synthesizing minimal compile_commands.json..."

COMPILER="${CXX:-clang++}"
STD="${CXXSTD:-c++20}"
DIR="$(pwd)"

echo "[" > "$OUTPUT"

first=true
while IFS= read -r file; do
  abs_file="$DIR/$file"
  if [[ "$first" == true ]]; then
    first=false
  else
    echo "," >> "$OUTPUT"
  fi
  # Escape for JSON
  cat >> "$OUTPUT" <<ENTRY
  {
    "directory": "$DIR",
    "command": "$COMPILER -std=$STD -c -x c++ $abs_file",
    "file": "$abs_file"
  }
ENTRY
done < <(flutter-find-cpp-files)

echo "]" >> "$OUTPUT"

echo "Synthesized $OUTPUT with $(grep -c '"file"' "$OUTPUT") entries"
