{ pkgs, flutter, shellFragments }:
pkgs.writeShellApplication {
  name = "smoke-test";
  runtimeInputs = [
    flutter pkgs.curl pkgs.coreutils pkgs.lsof pkgs.gnugrep pkgs.gnused
  ];
  text = shellFragments.flutterServer + ''
    FLUTTER_PID=""
    FLUTTER_LOG=""
    PORT=8086
    FAILURES=0

    EXTRA_DIRS="web"
  '' + shellFragments.copyToWorkDir + ''
    # Override the default trap to also clean up the Flutter server.
    cleanup() {
      flutter_cleanup
      rm -rf "$WORK_DIR"
    }
    trap cleanup EXIT INT TERM

    echo "=================================================="
    echo "  Web Telemetry — Smoke Test"
    echo "  (working copy: $WORK_DIR)"
    echo "=================================================="
    echo ""

    # ── Phase 1: Unit tests ──────────────────────────────────
    echo "── Phase 1: Unit tests ────────────────────────────────"
    echo ""

    if flutter test; then
      echo "PASS: Unit tests succeeded"
    else
      echo "FAIL: Unit tests failed"
      FAILURES=$((FAILURES + 1))
    fi
    echo ""

    # ── Phase 2: Analyze ─────────────────────────────────────
    echo "── Phase 2: Static analysis ───────────────────────────"
    echo ""

    if flutter analyze; then
      echo "PASS: No analysis issues"
    else
      echo "FAIL: Analysis issues found"
      FAILURES=$((FAILURES + 1))
    fi
    echo ""

    # ── Phase 3: Web build + serve ───────────────────────────
    echo "── Phase 3: Web build & HTTP check ────────────────────"
    echo ""

    check_port_free
    FLUTTER_EXTRA_ARGS=(--release)
    start_flutter_server
    echo "Flutter PID: $FLUTTER_PID" >&2

    echo "Waiting for Flutter web server ..." >&2
    wait_for_flutter
    echo "HTTP server is ready" >&2
    echo ""

    # Check index.html returns 200
    HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/")
    if [ "$HTTP_CODE" = "200" ]; then
      echo "PASS: index.html returned HTTP $HTTP_CODE"
    else
      echo "FAIL: index.html returned HTTP $HTTP_CODE (expected 200)"
      FAILURES=$((FAILURES + 1))
    fi

    # Check main.dart.js is served (release JS build)
    JS_CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/main.dart.js")
    if [ "$JS_CODE" = "200" ]; then
      echo "PASS: main.dart.js returned HTTP $JS_CODE"
    else
      echo "FAIL: main.dart.js returned HTTP $JS_CODE (expected 200)"
      FAILURES=$((FAILURES + 1))
    fi

    # Check flutter_bootstrap.js is served
    BOOT_CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/flutter_bootstrap.js")
    if [ "$BOOT_CODE" = "200" ]; then
      echo "PASS: flutter_bootstrap.js returned HTTP $BOOT_CODE"
    else
      echo "FAIL: flutter_bootstrap.js returned HTTP $BOOT_CODE (expected 200)"
      FAILURES=$((FAILURES + 1))
    fi

    echo ""

    # ── Summary ──────────────────────────────────────────────
    cleanup
    trap - EXIT INT TERM

    if [ "$FAILURES" -eq 0 ]; then
      echo "=================================================="
      echo "  ALL CHECKS PASSED"
      echo "=================================================="
      exit 0
    else
      echo "=================================================="
      echo "  $FAILURES CHECK(S) FAILED"
      echo "=================================================="
      exit 1
    fi
  '';
}
