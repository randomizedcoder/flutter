# Lint issues found in `texture`

See [`../hello_world/LINT_FIXES.md`](../hello_world/LINT_FIXES.md) for full methodology, analysis tool setup, and discussion of the repo's lint configuration.

## Priority summary

| Priority | Lint rule | File | Issue | Fix |
|----------|-----------|------|-------|-----|
| **Intentional** | `discarded_futures` | `lib/main.dart:58,62,66,68,71,75,77` | `onPressed: () => setColor(...)` — 7 buttons call async method without await | No fix — standard Flutter `onPressed` pattern |

## Issue 1 — `discarded_futures`: `onPressed` callbacks calling async `setColor()`

### The code

`lib/main.dart:22-24` defines the async method:
```dart
Future<void> setColor(int r, int g, int b) async {
  await channel.invokeMethod('setColor', <int>[r, g, b]);
}
```

Seven `OutlinedButton` widgets call it without awaiting (lines 58, 62, 66, 68, 71, 75, 77):
```dart
OutlinedButton(
  child: const Text('Flutter Navy'),
  onPressed: () => setColor(0x04, 0x2b, 0x59),
),
OutlinedButton(
  child: const Text('Flutter Blue'),
  onPressed: () => setColor(0x05, 0x53, 0xb1),
),
// ... 5 more identical patterns with different colors
```

### Assessment

**No fix needed.** This is the standard Flutter pattern for `onPressed` callbacks that trigger async work. The `onPressed` signature is `void Function()?` — it doesn't accept a `Future` return type. The arrow function `() => setColor(...)` returns the Future from `setColor()`, but the `onPressed` handler discards it by design.

The `setColor()` method invokes a platform method channel to change the native texture color. If the call fails, the texture simply won't change color — there's no user-visible error state to handle, and no resource leak. Each button press is independent, so there's no ordering concern if a user taps multiple buttons quickly.

To suppress this under strict linting, the idiomatic approach would be to wrap each call in `unawaited()`:
```dart
onPressed: () => unawaited(setColor(0x04, 0x2b, 0x59)),
```
However, this adds verbosity without changing behavior and conflicts with the repo's convention of keeping `onPressed` callbacks concise.
