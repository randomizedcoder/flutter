# Lint issues found in `layers`

See [`../hello_world/LINT_FIXES.md`](../hello_world/LINT_FIXES.md) for full methodology, analysis tool setup, and discussion of the repo's lint configuration.

## Priority summary

| Priority | Lint rule | File | Issue | Fix |
|----------|-----------|------|-------|-----|
| **Intentional** | `discarded_futures` | `rendering/spinning_square.dart:52` | `AnimationController..repeat()` in cascade | No fix — standard Flutter pattern |
| **Intentional** | `discarded_futures` | `widgets/spinning_square.dart:21` | `AnimationController..repeat()` in cascade | No fix — standard Flutter pattern |
| **Intentional** | `discarded_futures` | `services/isolate.dart:128-142` | `rootBundle.loadString().then()` / `Isolate.spawn().then()` chain | No fix — intentional async chain with lifecycle management |

## Issue 1 & 2 — `discarded_futures`: `AnimationController..repeat()` in cascade

### The code

`rendering/spinning_square.dart:49-52`:
```dart
final animation = AnimationController(
  duration: const Duration(milliseconds: 1800),
  vsync: const NonStopVSync(),
)..repeat();
```

`widgets/spinning_square.dart:18-21`:
```dart
late final AnimationController _animation = AnimationController(
  duration: const Duration(milliseconds: 3600),
  vsync: this,
)..repeat();
```

### Assessment

**No fix needed.** `AnimationController.repeat()` returns a `TickerFuture` that never completes — the animation repeats indefinitely by design. Awaiting it would block forever. The cascade `..` is the standard Flutter idiom for initializing and starting an animation. This is the exact pattern the repo cites as the reason for disabling `unawaited_futures` globally.

## Issue 3 — `discarded_futures`: Isolate spawning chain

### The code

`services/isolate.dart:123-142`:
```dart
void _runCalculation() {
  rootBundle.loadString('services/data.json').then<void>((String data) {
    if (isRunning) {
      final message = CalculationMessage(data, _receivePort.sendPort);
      Isolate.spawn<CalculationMessage>(_calculate, message).then<void>((Isolate isolate) {
        if (!isRunning) {
          isolate.kill(priority: Isolate.immediate);
        } else {
          _state = CalculationState.calculating;
          _isolate = isolate;
        }
      });
    }
  });
}
```

### Assessment

**No fix needed.** This uses `.then()` chaining rather than `async`/`await`, which is a valid async pattern. The method is intentionally `void` — it kicks off the calculation pipeline and returns immediately, allowing the UI to remain responsive. The isolate lifecycle is properly managed: spawned isolates are stored in `_isolate` for later cleanup, and the `isRunning` guard prevents work after disposal. The comment in the source explains why: "spawned isolates do not have access to the root bundle" so the JSON must be loaded in the main isolate first.
