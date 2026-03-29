{ pkgs, flutter, projectName }:
pkgs.writeShellApplication {
  name = "dart-format-check";
  runtimeInputs = [ flutter pkgs.coreutils ];
  # Does not use the shared copy-to-work-dir fragment because formatting
  # only needs lib/ and test/ — no pubspec, analysis_options, or sed step.
  text = ''
    SRC_DIR="$PWD"
    WORK_DIR=$(mktemp -d "/tmp/${projectName}-fmt-check-XXXXXX")
    trap 'rm -rf "$WORK_DIR"' EXIT INT TERM

    if [ ! -f "$SRC_DIR/pubspec.yaml" ] || [ ! -d "$SRC_DIR/lib" ]; then
      echo "ERROR: Run this from the examples/${projectName}/ directory." >&2
      exit 1
    fi

    cp -r "$SRC_DIR/lib" "$WORK_DIR/"
    if [ -d "$SRC_DIR/test" ]; then
      cp -r "$SRC_DIR/test" "$WORK_DIR/"
    fi

    DIRS=("$WORK_DIR/lib/")
    if [ -d "$WORK_DIR/test" ]; then
      DIRS+=("$WORK_DIR/test/")
    fi

    dart format --output=none --set-exit-if-changed --page-width=100 "''${DIRS[@]}"
  '';
}
