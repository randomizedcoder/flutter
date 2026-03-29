{ pkgs, flutter, shellFragments }:
pkgs.writeShellApplication {
  name = "dart-code-linter";
  runtimeInputs = [ flutter pkgs.coreutils pkgs.gnused ];
  text = shellFragments.copyToWorkDir + ''
    # dart_code_linter is not in pubspec.yaml because its analyzer dependency
    # conflicts with the monorepo workspace's pinned analyzer version. We add
    # it here in the isolated copy where workspace resolution has been stripped.
    sed -i '/^dev_dependencies:$/a\  dart_code_linter: ^3.2.1' "$WORK_DIR/pubspec.yaml"
    flutter pub get

    FAILURES=0

    echo "── dart_code_linter: analyze ──────────────────────────"
    if ! flutter pub run dart_code_linter:metrics analyze lib/ --fatal-warnings --fatal-style; then
      FAILURES=$((FAILURES + 1))
    fi

    echo "── dart_code_linter: check-unused-code ────────────────"
    if ! flutter pub run dart_code_linter:metrics check-unused-code lib/; then
      FAILURES=$((FAILURES + 1))
    fi

    echo "── dart_code_linter: check-unused-files ───────────────"
    if ! flutter pub run dart_code_linter:metrics check-unused-files lib/; then
      FAILURES=$((FAILURES + 1))
    fi

    echo "── dart_code_linter: check-unnecessary-nullable ───────"
    if ! flutter pub run dart_code_linter:metrics check-unnecessary-nullable lib/; then
      FAILURES=$((FAILURES + 1))
    fi

    if [ "$FAILURES" -ne 0 ]; then
      echo "FAILED: $FAILURES dart_code_linter check(s) reported issues" >&2
      exit 1
    fi
  '';
}
