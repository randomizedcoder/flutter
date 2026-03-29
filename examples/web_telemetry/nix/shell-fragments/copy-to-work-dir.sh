# Copy project sources to an isolated temp directory for analysis/testing.
#
# Why a temp directory instead of a proper Nix derivation?
#
# These check scripts (dart analyze, flutter analyze, dart_code_linter, etc.)
# need `flutter pub get` to resolve dependencies, which requires network
# access. Nix's build sandbox blocks network by default. To do this purely
# in Nix you'd need a fixed-output derivation (FOD) to pre-fetch pub
# dependencies — similar to how buildGoModule or buildNpmPackage work — and
# then a second derivation that uses those deps offline. That's significant
# infrastructure for an example project.
#
# Using `writeShellApplication` + `nix run` sidesteps this because the
# script runs outside the build sandbox, with full network access.
#
# We still need a temp directory (rather than running in-place) because:
#   1. The pubspec.yaml declares `resolution: workspace` for the Flutter
#      monorepo. The Nix-provided Flutter SDK is standalone, not the
#      monorepo, so `flutter pub get` fails unless that line is stripped.
#      We can't modify the source tree in place.
#   2. `flutter pub get` creates .dart_tool/, pubspec.lock, .packages, etc.
#      Running in a temp dir keeps the source checkout clean.
#
# Must be run from the examples/web_telemetry/ directory.
# Sets $WORK_DIR and cd's into it. Sets a default EXIT/INT/TERM trap that
# removes $WORK_DIR — callers that need custom cleanup can override the trap
# after sourcing.
#
# Optional: set EXTRA_DIRS before sourcing to copy additional directories.
# Example: EXTRA_DIRS="web"
SRC_DIR="$PWD"
WORK_DIR=$(mktemp -d /tmp/web-telemetry-work-XXXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT INT TERM

if [ ! -f "$SRC_DIR/pubspec.yaml" ] || [ ! -d "$SRC_DIR/lib" ]; then
  echo "ERROR: Run this from the examples/web_telemetry/ directory." >&2
  exit 1
fi

cp -r "$SRC_DIR/lib" "$WORK_DIR/"
cp -r "$SRC_DIR/test" "$WORK_DIR/"
cp "$SRC_DIR/pubspec.yaml" "$WORK_DIR/"
cp "$SRC_DIR/analysis_options.yaml" "$WORK_DIR/"

for dir in ''${EXTRA_DIRS:-}; do
  cp -r "$SRC_DIR/$dir" "$WORK_DIR/"
done

# Strip "resolution: workspace" so pub resolves against the nix SDK
sed -i '/^resolution: workspace$/d' "$WORK_DIR/pubspec.yaml"

cd "$WORK_DIR"
