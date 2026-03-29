# Lint issues found in `platform_channel_swift`

See [`../hello_world/LINT_FIXES.md`](../hello_world/LINT_FIXES.md) for full methodology, analysis tool setup, and discussion of the repo's lint configuration.

## Priority summary

| Priority | Lint rule | File | Issue | Fix |
|----------|-----------|------|-------|-----|
| **P0 — Bug** | `unawaited_futures` | `test_driver/button_tap_test.dart:17` | `driver.close()` without `await` — WebDriver connection never reliably closed | Added `await` |

## Issue 1 — `unawaited_futures`: missing `await` on `driver.close()`

**Rule:** [`unawaited_futures`](https://dart.dev/lints/unawaited_futures) — "Future results in async function bodies should be awaited or marked unawaited using `dart:async`."

**Repo status:** Disabled in `/analysis_options.yaml` (line 216): "too many false positives, especially with AnimationController".

### The problem

```dart
tearDownAll(() async {
  driver.close();  // Future<void> silently dropped
});
```

Identical to the `platform_channel` and `hello_world` bugs — `FlutterDriver.close()` returns `Future<void>` that is silently dropped. See the [hello_world deep dive](../hello_world/LINT_FIXES.md#git-history-deep-dive-how-did-this-bug-survive-6-years) for full history and analysis.

### The fix

```dart
tearDownAll(() async {
  await driver.close();
});
```
