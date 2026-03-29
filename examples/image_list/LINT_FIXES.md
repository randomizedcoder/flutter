# Lint issues found in `image_list`

See [`../hello_world/LINT_FIXES.md`](../hello_world/LINT_FIXES.md) for full methodology, analysis tool setup, and discussion of the repo's lint configuration.

## Priority summary

| Priority | Lint rule | File | Issue | Fix |
|----------|-----------|------|-------|-----|
| **P0 — Bug** | `unawaited_futures` | `lib/main.dart:115` | `request.response.close()` without `await` — HTTP response never reliably closed | Added `await` |
| **Intentional** | `discarded_futures` | `lib/main.dart:173` | `AnimationController..repeat()` in cascade | No fix — standard Flutter pattern |
| **Intentional** | `discarded_futures` | `lib/main.dart:180` | `Future.wait().then()` chain | No fix — intentional fire-and-forget timing |

## Issue 1 — `unawaited_futures`: missing `await` on `request.response.close()`

**Rule:** [`unawaited_futures`](https://dart.dev/lints/unawaited_futures) — "Future results in async function bodies should be awaited or marked unawaited using `dart:async`."

**Repo status:** Disabled in `/analysis_options.yaml` (line 216): "too many false positives, especially with AnimationController".

### The problem

```dart
httpServer.listen((HttpRequest request) async {
  // ... chunked response writing ...
  request.response.close();  // Future<void> silently dropped
});
```

`HttpResponse.close()` returns a `Future` that completes when the response has been fully sent to the client. Without `await`, the listener callback returns before the response is flushed, which could cause incomplete responses under load. This is a local HTTPS server serving image data to the app — dropping the close future means the server may not fully transmit image bytes before moving to the next request.

### The fix

```dart
  await request.response.close();
```

## Issue 2 — `discarded_futures`: `AnimationController..repeat()` in cascade

### The code

```dart
final controllers = <AnimationController>[
  for (int i = 0; i < images; i++)
    AnimationController(duration: const Duration(milliseconds: 3600), vsync: this)..repeat(),
];
```

### Assessment

**No fix needed.** `AnimationController.repeat()` returns a `TickerFuture` that never completes (by design — the animation repeats indefinitely). Awaiting it would block forever. The cascade operator `..` is the standard Flutter idiom for initializing and starting an animation in one expression. This is the exact pattern the repo cites as the reason for disabling `unawaited_futures` globally.

## Issue 3 — `discarded_futures`: `Future.wait().then()` chain

### The code

```dart
Future.wait(futures).then((_) {
  debugPrint(
    '===image_list=== all loaded in ${DateTime.now().difference(started).inMilliseconds}ms.',
  );
});
```

### Assessment

**No fix needed.** This is an intentional fire-and-forget timing measurement. The `build()` method starts the image loading, records the start time, and attaches a `.then()` callback that prints when all images have loaded. The build method doesn't need to wait for this — it sets up the timing measurement and returns immediately. The `.then()` chain is a valid async pattern here because the result (a debug print) has no impact on the widget tree.
