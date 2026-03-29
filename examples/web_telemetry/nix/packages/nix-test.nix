{ pkgs, flutter }:
pkgs.writeShellApplication {
  name = "nix-test";
  runtimeInputs = [
    flutter pkgs.curl pkgs.coreutils pkgs.lsof pkgs.gnugrep pkgs.gnused pkgs.nix
  ];
  text = ''
    FAILURES=0
    PASSES=0

    pass() {
      PASSES=$((PASSES + 1))
      echo "  PASS: $1"
    }

    fail() {
      FAILURES=$((FAILURES + 1))
      echo "  FAIL: $1" >&2
    }

    run_test() {
      local name="$1"
      shift
      echo ""
      echo "── $name ──────────────────────────────────────────"
      if "$@"; then
        pass "$name"
      else
        fail "$name (exit code: $?)"
      fi
    }

    FLAKE_DIR="$PWD"
    if [ ! -f "$FLAKE_DIR/flake.nix" ]; then
      echo "ERROR: Run this from the examples/web_telemetry/ directory." >&2
      exit 1
    fi

    echo "=================================================="
    echo "  Nix Integration Tests"
    echo "  (flake: $FLAKE_DIR)"
    echo "=================================================="

    # ── 1. nix flake show ─────────────────────────────────
    # Verifies the flake evaluates without errors (catches missing
    # arguments, import failures, etc.)
    run_test "nix flake show" nix flake show --no-write-lock-file

    # ── 2. nix develop (shell enters and exits) ──────────
    echo ""
    echo "── nix develop ──────────────────────────────────────"
    # shellcheck disable=SC2016
    if nix develop --no-write-lock-file --command bash -c 'echo "shell OK; flutter=$(flutter --version 2>&1 | head -1)"'; then
      pass "nix develop"
    else
      fail "nix develop"
    fi

    # ── 3. nix fmt (dry-run) ─────────────────────────────
    echo ""
    echo "── nix fmt (dry-run) ───────────────────────────────"
    if nix fmt --no-write-lock-file -- --output=none --set-exit-if-changed --page-width=100 lib/ test/; then
      pass "nix fmt (dry-run)"
    else
      fail "nix fmt (dry-run)"
    fi

    # ── 4. nix run .#dart-format-check ────────────────────
    run_test "nix run .#dart-format-check" nix run --no-write-lock-file .#dart-format-check

    # ── 5. nix run .#dart-analyze ─────────────────────────
    run_test "nix run .#dart-analyze" nix run --no-write-lock-file .#dart-analyze

    # ── 6. nix run .#flutter-analyze ──────────────────────
    run_test "nix run .#flutter-analyze" nix run --no-write-lock-file .#flutter-analyze

    # ── 7. nix run .#dart-code-linter ─────────────────────
    run_test "nix run .#dart-code-linter" nix run --no-write-lock-file .#dart-code-linter

    # ── 8. flutter pub get (in-tree, workspace resolution) ─
    echo ""
    echo "── flutter pub get (in-tree) ────────────────────────"
    if nix develop --no-write-lock-file --command flutter pub get; then
      pass "flutter pub get (in-tree)"
    else
      fail "flutter pub get (in-tree)"
    fi

    # ── 9. dart analyze (in-tree via nix develop) ────────
    echo ""
    echo "── dart analyze (in-tree) ───────────────────────────"
    if nix develop --no-write-lock-file --command dart analyze lib/ test/; then
      pass "dart analyze (in-tree)"
    else
      fail "dart analyze (in-tree)"
    fi

    # ── 10. flutter test (isolated temp dir) ──────────────
    echo ""
    echo "── flutter test (isolated) ──────────────────────────"
    WORK_DIR=$(mktemp -d /tmp/nix-test-flutter-XXXXXX)
    trap 'rm -rf "$WORK_DIR"' EXIT INT TERM
    cp -r lib test pubspec.yaml analysis_options.yaml "$WORK_DIR/"
    sed -i '/^resolution: workspace$/d' "$WORK_DIR/pubspec.yaml"
    if nix develop --no-write-lock-file --command bash -c "cd $WORK_DIR && flutter pub get && flutter test"; then
      pass "flutter test (isolated)"
    else
      fail "flutter test (isolated)"
    fi
    rm -rf "$WORK_DIR"
    trap - EXIT INT TERM

    # ── 11. nix run .#smoke-test ──────────────────────────
    run_test "nix run .#smoke-test" nix run --no-write-lock-file .#smoke-test

    # ── Summary ───────────────────────────────────────────
    echo ""
    echo "=================================================="
    TOTAL=$((PASSES + FAILURES))
    echo "  $PASSES/$TOTAL passed, $FAILURES failed"
    if [ "$FAILURES" -eq 0 ]; then
      echo "  ALL NIX TARGETS PASSED"
    else
      echo "  SOME TARGETS FAILED"
    fi
    echo "=================================================="

    exit "$FAILURES"
  '';
}
