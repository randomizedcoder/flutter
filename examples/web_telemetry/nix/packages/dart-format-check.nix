{ pkgs, flutter }:
pkgs.writeShellApplication {
  name = "dart-format-check";
  runtimeInputs = [ flutter pkgs.coreutils ];
  # Does not use the shared copy-to-work-dir fragment because formatting
  # only needs lib/ and test/ — no pubspec, analysis_options, or sed step.
  text = ''
    # Must be run from the examples/web_telemetry/ directory.
    SRC_DIR="$PWD"
    WORK_DIR=$(mktemp -d /tmp/dart-format-check-XXXXXX)
    trap 'rm -rf "$WORK_DIR"' EXIT INT TERM

    if [ ! -f "$SRC_DIR/pubspec.yaml" ] || [ ! -d "$SRC_DIR/lib" ]; then
      echo "ERROR: Run this from the examples/web_telemetry/ directory." >&2
      exit 1
    fi

    cp -r "$SRC_DIR/lib" "$WORK_DIR/"
    cp -r "$SRC_DIR/test" "$WORK_DIR/"

    dart format --output=none --set-exit-if-changed --page-width=100 \
      "$WORK_DIR/lib/" "$WORK_DIR/test/"
  '';
}
