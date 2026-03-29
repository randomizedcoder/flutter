# Lint issues found in `multiple_windows`

See [`../hello_world/LINT_FIXES.md`](../hello_world/LINT_FIXES.md) for full methodology, analysis tool setup, and discussion of the repo's lint configuration.

## Priority summary

| Priority | Lint rule | File | Issue | Fix |
|----------|-----------|------|-------|-----|
| **Style** | `unnecessary_async` | `lib/app/main_window.dart:114` | `async` keyword on callback that never awaits | No fix — document only |
| **Style** | `unnecessary_async` / `unnecessary_await` | `lib/app/window_settings_dialog.dart:15-16` | Redundant `async { return await ... }` pattern | No fix — document only |
| **Intentional** | `discarded_futures` | `lib/app/dialog_window_edit_dialog.dart:15` | `showDialog()` fire-and-forget | No fix — standard Flutter pattern |
| **Intentional** | `discarded_futures` | `lib/app/regular_window_edit_dialog.dart:15` | `showDialog()` fire-and-forget | No fix — standard Flutter pattern |
| **Intentional** | `discarded_futures` | `lib/app/tooltip_window_edit_dialog.dart:17` | `showDialog()` fire-and-forget | No fix — standard Flutter pattern |
| **Intentional** | `discarded_futures` | `lib/app/main_window.dart:115`, `lib/app/tooltip_button.dart:117`, `lib/app/dialog_window_content.dart:72` | `.destroy()` fire-and-forget | No fix — intentional UI teardown |

## Issue 1 — `unnecessary_async`: async callback without await

### The code

`lib/app/main_window.dart:114-116`:
```dart
onPressed: () async {
  controller.controller.destroy();
},
```

### Assessment

**Document only — no fix applied.** The `async` keyword is unnecessary because `destroy()` is not awaited. However, this is in UI callback code that follows `onPressed: void Function()` signature. Removing `async` is a trivial cleanup but doesn't affect behavior. Not fixing to keep changes focused on real bugs.

## Issue 2 — `unnecessary_async` / `unnecessary_await`: redundant async wrapper

### The code

`lib/app/window_settings_dialog.dart:12-26`:
```dart
Future<void> showWindowSettingsDialog(
  BuildContext context,
  WindowSettings settings,
) async {
  return await showDialog(
    // ...
  );
}
```

### Assessment

**Document only — no fix applied.** The `async { return await expr }` pattern is equivalent to just returning the Future directly. The function could drop `async` and `await` and simply `return showDialog(...)`. This is a minor inefficiency (extra microtask tick) but doesn't affect correctness.

## Issues 3-5 — `discarded_futures`: `showDialog()` fire-and-forget

### The code

Three `show*EditDialog` functions call `showDialog()` without awaiting:

- `dialog_window_edit_dialog.dart:15`: `showDialog(context: context, builder: ...);`
- `regular_window_edit_dialog.dart:15`: `showDialog(context: context, builder: ...);`
- `tooltip_window_edit_dialog.dart:17`: `showDialog(context: context, builder: ...);`

### Assessment

**No fix needed.** These are `void` functions that display edit dialogs. `showDialog()` returns `Future<T?>` that resolves when the dialog is dismissed, but these callers don't need the result — the dialog edits the controller's state directly through the `WindowSettings` model. Fire-and-forget `showDialog()` is a standard Flutter pattern in functions that don't need to react to the dialog's dismissal.

## Issue 6 — `discarded_futures`: `.destroy()` fire-and-forget

### The code

Three locations call `.destroy()` without awaiting:

- `main_window.dart:115`: `controller.controller.destroy();` (delete button)
- `tooltip_button.dart:117`: `_tooltipController!.destroy();` (tooltip toggle)
- `dialog_window_content.dart:72`: `window.destroy();` (close button)

### Assessment

**No fix needed.** `destroy()` on window controllers is an intentional fire-and-forget teardown. The UI is being torn down — there's nothing to do after the window is destroyed. The controller handles its own cleanup asynchronously.
