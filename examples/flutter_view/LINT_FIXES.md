# Lint issues found in `flutter_view`

See [`../hello_world/LINT_FIXES.md`](../hello_world/LINT_FIXES.md) for full methodology, analysis tool setup, and discussion of the repo's lint configuration.

## Priority summary

| Priority | Lint rule | File | Issue | Fix |
|----------|-----------|------|-------|-----|
| **Intentional** | `discarded_futures` | `lib/main.dart:58` | `platform.send(_pong)` fire-and-forget | No fix — already has `// ignore: unawaited_futures` comment |

## Issue 1 — `discarded_futures`: fire-and-forget `platform.send()`

**Rule:** [`discarded_futures`](https://dart.dev/lints/discarded_futures) — "Don't invoke asynchronous functions in non-async blocks."

### The code

```dart
void _sendFlutterIncrement() {
  platform.send(_pong); // ignore: unawaited_futures
}
```

`BasicMessageChannel.send()` returns `Future<String?>`, but the caller is a synchronous `void` method that intentionally fires and forgets the platform message. The `// ignore: unawaited_futures` comment already documents this intent.

### Assessment

**No fix needed.** This is a deliberate fire-and-forget pattern. The Flutter View example communicates bidirectionally with the host platform via `BasicMessageChannel`. The send operation doesn't need to be awaited because the app doesn't depend on the result — it simply notifies the host of a counter increment. The existing ignore comment correctly documents the intent.
