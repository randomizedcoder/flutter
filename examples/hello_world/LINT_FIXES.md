# Lint issues found in `hello_world`

## Introduction

The Flutter `hello_world` example is the simplest app in the `examples/` directory — a single `Center(child: Text('Hello, world!'))` widget with a unit test and a WebDriver smoke test. Despite its simplicity, applying a strict `analysis_options.yaml` with ~100 additional lint rules revealed four issues across two files, including one genuine async correctness bug that could cause resource leaks and flaky CI failures.

This document describes each issue in detail: the lint rule that found it, its status in the Flutter repo's own configuration, the problem in the code, why it matters, the correction applied, and references to the official Dart documentation and Flutter style guide. The issues are presented in priority order, from the most impactful (a real bug) to the least (a style preference).

Importantly, two of these four issues (P2 and P3) **conflict with the Flutter repo's own style guide** — our strict config enables rules the repo explicitly disables. These are documented here for transparency, with references to the specific style guide sections.

## Table of contents

- [Introduction](#introduction)
- [Priority summary](#priority-summary)
- [Analyzer output](#analyzer-output)
  - [Before fixes (4 issues)](#before-fixes-4-issues)
  - [After fixes (clean)](#after-fixes-clean)
- [Issue 1 — `unawaited_futures`: missing `await` on `driver.close()`](#issue-1--unawaited_futures-missing-await-on-driverclose)
- [Issue 2 — `unnecessary_async`: `async` without `await`](#issue-2--unnecessary_async-async-without-await)
- [Issue 3 — `avoid_types_on_closure_parameters`: redundant `WidgetTester` annotation](#issue-3--avoid_types_on_closure_parameters-redundant-widgettester-annotation)
- [Issue 4 — `prefer_final_parameters`: missing `final` on closure parameter](#issue-4--prefer_final_parameters-missing-final-on-closure-parameter)
- [Git history deep dive: how did this bug survive 6 years?](#git-history-deep-dive-how-did-this-bug-survive-6-years)
- [How these issues were detected](#how-these-issues-were-detected)
  - [Two analysis tools](#two-analysis-tools)
  - [Why the default lints didn't catch these](#why-the-default-lints-didnt-catch-these)
  - [Reproducing](#reproducing)
- [Analysis of lint configurations across all examples](#analysis-of-lint-configurations-across-all-examples)
  - [The repo's authoritative lint config](#the-repos-authoritative-lint-config)
  - [What each example actually uses](#what-each-example-actually-uses)
  - [Async bugs found across all examples](#async-bugs-found-across-all-examples)
- [Style guide references](#style-guide-references)
  - [Where our strict config diverges from the repo](#where-our-strict-config-diverges-from-the-repo)
  - [Gaps in the style guide and example configs](#gaps-in-the-style-guide-and-example-configs)

## Priority summary

| Priority | Lint rule | Category | File | Repo status | Fix |
|----------|-----------|----------|------|-------------|-----|
| **P0 — Bug** | `unawaited_futures` | Async correctness | `smoke_web_engine_test.dart:28` | Disabled (line 216): "too many false positives, especially with AnimationController" | Add `await` |
| **P1 — Symptom** | `unnecessary_async` | Async correctness | `smoke_web_engine_test.dart:27` | Disabled (line 218): "not yet tested" | _(resolved by P0 fix)_ |
| **P2 — Style exception** | `avoid_types_on_closure_parameters` | Type annotations | `hello_test.dart:9` | Disabled (line 81): "not yet tested". **Conflicts with style guide line 802.** | Remove `WidgetTester` type |
| **P3 — Style exception** | `prefer_final_parameters` | Immutability | `hello_test.dart:9` | Disabled (line 172): "adds too much verbosity" | Add `final` keyword |

All "Repo status" references are to `/analysis_options.yaml` (the root config, 176 enabled rules).

**P0** is a real correctness bug — `driver.close()` returns a `Future<void>` that was silently dropped, meaning the WebDriver connection was never reliably closed. This is the kind of issue that causes intermittent CI failures. The repo disables `unawaited_futures` due to false positives with `AnimationController`, but this specific case is a genuine bug regardless of the repo-wide policy.

**P1** is a direct symptom of P0 — the `async` keyword had no purpose because the `await` was missing. Fixing P0 automatically resolves P1.

**P2** conflicts with the Flutter style guide at `docs/contributing/Style-guide-for-Flutter-repo.md:802`: "Give types to all parameters, even in closures and even if you don't use the parameter." Our fix removed the type, which the style guide says to keep. See [Style guide references](#where-our-strict-config-diverges-from-the-repo) for details.

**P3** is disabled repo-wide because it "adds too much verbosity." This is a deliberate style choice, not an oversight.

---

## Analyzer output

### Before fixes (4 issues)

Running `nix develop --command dart analyze .` against the original code:

```
Analyzing ....

   info - test/hello_test.dart:9:42 - The parameter 'tester' should be final.
          Try making the parameter final. - prefer_final_parameters
   info - test/hello_test.dart:9:42 - Unnecessary type annotation on a function
          expression parameter. Try removing the type annotation.
          - avoid_types_on_closure_parameters
   info - test_driver/smoke_web_engine_test.dart:27:20 - Don't make a function
          'async' if it doesn't use 'await'. Try removing the 'async' modifier.
          - unnecessary_async
   info - test_driver/smoke_web_engine_test.dart:28:14 - Missing an 'await' for
          the 'Future' computed by this expression. Try adding an 'await' or
          wrapping the expression with 'unawaited'. - unawaited_futures

4 issues found.
```

### After fixes (clean)

```
Analyzing ....
No issues found!
```

---

## Issue 1 — `unawaited_futures`: missing `await` on `driver.close()`

**Priority:** P0 — Bug
**Dart docs:** [dart.dev/tools/linter-rules/unawaited_futures](https://dart.dev/tools/linter-rules/unawaited_futures)
**Category:** Async correctness
**Included in standard lint sets:** No — not in `core`, `recommended`, or `flutter`. Opt-in only.
**Quick fix available:** Yes
**Repo root config:** Disabled at `/analysis_options.yaml:216` — "too many false positives, especially with the way AnimationController works"

### The rule

In `async` function bodies, `Future` results must either be awaited or explicitly marked as fire-and-forget using `unawaited()` from `dart:async`. Dropping a `Future` silently is almost always a bug.

From the Dart docs:

> Future results in async function bodies must be awaited or marked unawaited using `dart:async`.

The docs explain why this class of bug is so common:

> It's easy to forget await in async methods as naming conventions usually don't tell us if a method is sync or async (except for some in `dart:io`).

**Bad** (from Dart docs):
```dart
void main() async {
  doSomething(); // Likely a bug.
}
```

**Good** (from Dart docs):
```dart
Future doSomething() => ...;

void main() async {
  await doSomething();

  unawaited(doSomething()); // Explicitly-ignored fire-and-forget.
}
```

### The problem

In `test_driver/smoke_web_engine_test.dart:28`, the original code was:

```dart
// Close the connection to the driver after the tests have completed.
tearDownAll(() async {
  driver.close();
});
```

`FlutterDriver.close()` returns `Future<void>`. Calling it without `await` means the `tearDownAll` callback completes and returns to the test runner *before* the driver connection is actually closed. The `Future` is created, starts executing, and then is silently abandoned.

### Why it matters

This was a real bug in the existing code. Without `await`, three things can go wrong:

**1. Resource leak.** The WebDriver connection may not be cleanly closed before the test process exits. In CI environments, this can leave orphaned browser processes or cause flaky port-in-use errors on subsequent test runs. WebDriver sessions hold system resources (TCP connections, browser process handles) that the OS may not reclaim immediately on process exit.

**2. Error swallowing.** If `driver.close()` throws — for example, if the browser crashed during the test — the error is delivered to the `Zone`'s unhandled error handler rather than propagating through the test framework. The test suite would report "passed" even though teardown failed. Worse, the unhandled `Future` error may be silently swallowed entirely depending on the zone configuration.

**3. Race condition.** The test runner may begin subsequent test suites or process cleanup while the driver connection is still shutting down asynchronously. This is a classic source of intermittent CI failures — the kind that pass locally 99% of the time but fail unpredictably on CI machines under different load conditions.

### Why this bug existed undetected

Dart's type system does not require `await` on `Future`-returning calls. Unlike Rust's `#[must_use]` attribute, Dart treats `Future` return values as ignorable by default. This means the compiler is perfectly happy with `driver.close();` — the `Future` is simply created and discarded.

The `unawaited_futures` lint exists precisely to fill this gap in Dart's type system. However, it is disabled in the Flutter repo's root config (`/analysis_options.yaml:216`) because it produces "too many false positives, especially with the way AnimationController works." This is a pragmatic tradeoff — the rule is too noisy for Flutter's framework code, but that doesn't mean the bugs it catches aren't real.

This specific case is unambiguously a bug: `FlutterDriver.close()` manages external resources (a WebDriver connection), and the `async` keyword on the callback makes it clear the original author intended to await.

### Why the repo's root config doesn't catch this

The repo disables both `unawaited_futures` (line 216) and `discarded_futures` (line 106, "too many false positives, similar to unawaited_futures"). This means there is currently **no lint rule enabled in the Flutter repo that catches silently dropped Futures**. This is a known gap — the root config comments acknowledge the rules exist but disable them due to false positive rates.

The related rule `discarded_futures` would also flag this pattern. It catches `Future`-returning calls in *non-async* functions (while `unawaited_futures` catches them in `async` functions). Both are disabled.

### The fix

```dart
// Before
tearDownAll(() async {
  driver.close();
});

// After
tearDownAll(() async {
  await driver.close();
});
```

Adding `await` ensures the test runner waits for the connection to be fully closed before proceeding. Errors from `close()` now propagate through the test framework as expected.

### When fire-and-forget is intentional

If ignoring the `Future` were intentional, the correct way to express that is:

```dart
import 'dart:async';

tearDownAll(() async {
  unawaited(driver.close());
});
```

The `unawaited()` function from `dart:async` satisfies the lint while explicitly signaling to both the analyzer and future readers that the `Future` is being deliberately ignored. In this case, however, the `async` keyword on the callback makes it clear the original author intended to await — they just forgot.

---

## Issue 2 — `unnecessary_async`: `async` without `await`

**Priority:** P1 — Symptom of Issue 1
**Dart docs:** [dart.dev/tools/linter-rules/unnecessary_async](https://dart.dev/tools/linter-rules/unnecessary_async)
**Category:** Async correctness
**Included in standard lint sets:** No — not in `core`, `recommended`, or `flutter`. Opt-in only.
**Quick fix available:** Yes
**Status:** Experimental (released in Dart 3.7)
**Repo root config:** Disabled at `/analysis_options.yaml:218` — "not yet tested"

### The rule

Functions that do not contain any `await` expressions do not need the `async` modifier. Removing it makes the code synchronous, which is faster and easier to reason about.

From the Dart docs:

> No await no async. [...] Usually such functions also do not need to return a `Future`, which allows callers to avoid `await` in their code. Synchronous code in general runs faster and is easier to reason about.

**Bad** (from Dart docs):
```dart
void f() async {
  // await Future.delayed(const Duration(seconds: 2));
  print(0);
}
```

**Good** (from Dart docs):
```dart
void f() {
  // await Future.delayed(const Duration(seconds: 2));
  print(0);
}
```

### The problem

In `test_driver/smoke_web_engine_test.dart:27`, the original code was:

```dart
tearDownAll(() async {
  driver.close();  // no await — Future is dropped
});
```

With the missing `await` on `driver.close()`, the function body contained no `await` expressions at all. The `async` keyword therefore served no purpose — the function was effectively synchronous despite being marked `async`.

### Why it matters (and why it's a symptom, not the root cause)

This issue illustrates how one lint can be a symptom of a deeper problem caught by another lint. On its own, the `unnecessary_async` warning suggests "just remove `async`." But that would be the wrong fix — removing `async` would make the fire-and-forget bug permanent rather than fixing it.

The real diagnosis is:
1. `unawaited_futures` catches the root cause: `driver.close()` needs `await`.
2. `unnecessary_async` catches a symptom: the `async` is "unnecessary" only because the `await` is missing.

Together, these two lints paint a complete picture of what went wrong. This is a good example of why enabling multiple complementary lint rules adds value — each rule sees a different facet of the same underlying problem.

### The fix

No direct fix was needed for this issue. Adding `await driver.close();` (Issue 1's fix) gave the `async` keyword a purpose, and the `unnecessary_async` warning resolved itself.

After the fix, the code is:

```dart
tearDownAll(() async {
  await driver.close();  // async is now justified
});
```

The `async` keyword is necessary because there is now an `await` expression in the body.

---

## Issue 3 — `avoid_types_on_closure_parameters`: redundant `WidgetTester` annotation

**Priority:** P2 — Style exception (conflicts with Flutter style guide)
**Dart docs:** [dart.dev/tools/linter-rules/avoid_types_on_closure_parameters](https://dart.dev/tools/linter-rules/avoid_types_on_closure_parameters)
**Category:** Type annotations
**Included in standard lint sets:** No — not in `core`, `recommended`, or `flutter`. Opt-in only.
**Quick fix available:** Yes
**Incompatible with:** `always_specify_types`
**Repo root config:** Disabled at `/analysis_options.yaml:81` — "not yet tested"
**Style guide conflict:** `docs/contributing/Style-guide-for-Flutter-repo.md:802`

### The rule

The rule enforces that closure (anonymous function) parameters should not carry explicit type annotations when the type can be inferred from the surrounding context. The Dart analyzer already knows the expected parameter types from the function signature that the closure is being passed to.

From the Dart docs:

> Avoid annotating types for function expression parameters.

**Bad** (from Dart docs):
```dart
var names = people.map((Person person) => person.name);
```

**Good** (from Dart docs):
```dart
var names = people.map((person) => person.name);
```

### Style guide conflict

The Flutter repo's style guide explicitly contradicts this rule. At `docs/contributing/Style-guide-for-Flutter-repo.md`, lines 799–808, in the section "Avoid using `var` and `dynamic`":

> All variables and arguments are typed; avoid `dynamic` or `Object` in any case where you could figure out the actual type. Always specialize generic types where possible. Explicitly type all list and map literals. **Give types to all parameters, even in closures and even if you don't use the parameter.**
>
> This achieves two purposes: it verifies that the type that the compiler would infer matches the type you expect, and it makes the code self-documenting in the case where the type is not obvious (e.g. when calling anything other than a constructor).

The style guide's rationale is sound — explicit types on closure parameters serve as a compile-time assertion that the inferred type matches the developer's expectation, and make the code self-documenting.

This rule is disabled in the root config with the comment "not yet tested," and the style guide says to do the opposite. **Our fix violates the Flutter repo's convention.**

### The problem

In `test/hello_test.dart:9`, the original code was:

```dart
testWidgets('Hello world smoke test', (WidgetTester tester) async {
```

The `testWidgets` function has the signature:

```dart
void testWidgets(String description, WidgetTesterCallback callback, ...)
```

where `WidgetTesterCallback` is `typedef WidgetTesterCallback = Future<void> Function(WidgetTester widgetTester)`. Dart's type inference already knows `tester` is a `WidgetTester` from this typedef — the explicit annotation is technically redundant.

### The fix

```dart
// Before
testWidgets('Hello world smoke test', (WidgetTester tester) async {

// After (combined with Issue 4's fix)
testWidgets('Hello world smoke test', (final tester) async {
```

The `WidgetTester` type annotation was removed. The type is still enforced at compile time through the function signature — no type safety is lost.

**Note:** Per the Flutter style guide, the original code with the explicit `WidgetTester` annotation was actually *correct* by repo convention. Our strict config disagrees with the style guide on this point. If adopting this change for the Flutter repo, the style guide at line 802 would need to be updated, or this rule should remain disabled.

### Interaction with other rules

This rule is part of the "omit obvious, specify non-obvious" strategy used in our `analysis_options.yaml`. It works together with `omit_obvious_local_variable_types` and `specify_nonobvious_local_variable_types` to create a consistent policy: let inference handle types that are clear from context, and require explicit annotations only where the type would not be obvious to a reader.

It conflicts with `always_specify_types`, which requires explicit types everywhere. The repo doesn't enable `always_specify_types` either, but the style guide's prose at line 802 aligns more with the "always specify" philosophy for closure parameters.

---

## Issue 4 — `prefer_final_parameters`: missing `final` on closure parameter

**Priority:** P3 — Style exception (explicitly disabled by repo)
**Dart docs:** [dart.dev/tools/linter-rules/prefer_final_parameters](https://dart.dev/tools/linter-rules/prefer_final_parameters)
**Category:** Const / immutability
**Included in standard lint sets:** No — not in `core`, `recommended`, or `flutter`. Opt-in only.
**Quick fix available:** Yes
**Incompatible with:** `unnecessary_final`, `avoid_final_parameters`
**Note:** Deprecated as of Dart 3.11. The `parameter_assignments` rule is recommended as an alternative.
**Repo root config:** Disabled at `/analysis_options.yaml:172` — "adds too much verbosity"

### The rule

Function and closure parameters should be declared `final` when they are never reassigned within the function body. This prevents accidental reassignment and communicates intent to the reader.

From the Dart docs:

> Prefer final for parameter declarations if they are not reassigned.

**Bad** (from Dart docs):
```dart
void badParameter(String label) { // LINT
  print(label);
}

void badExpression(int value) => print(value); // LINT

[1, 4, 6, 8].forEach((value) => print(value + 2)); // LINT
```

**Good** (from Dart docs):
```dart
void goodParameter(final String label) { // OK
  print(label);
}

void goodExpression(final int value) => print(value); // OK

[1, 4, 6, 8].forEach((final value) => print(value + 2)); // OK

void mutableParameter(String label) { // OK — parameter IS reassigned
  print(label);
  label = 'Hello Linter!';
  print(label);
}
```

### Repo's rationale for disabling

The root config disables this rule with the comment "adds too much verbosity." This is a deliberate style choice — the Flutter team decided that requiring `final` on every non-reassigned parameter creates visual noise that outweighs the benefit of the immutability guarantee.

The repo also disables `parameter_assignments` (`/analysis_options.yaml:155`, "we do this commonly"), which means parameter reassignment is permitted as a coding pattern in the Flutter repo.

### The problem

In `test/hello_test.dart:9`, the `tester` parameter is only ever read — it is never reassigned:

```dart
testWidgets('Hello world smoke test', (WidgetTester tester) async {
  hello_world.main();
  await tester.pump();          // read
  expect(find.text('Hello, world!'), findsOneWidget);
});
```

Since `tester` is never reassigned, it could be declared `final`.

### The fix

```dart
// Before
testWidgets('Hello world smoke test', (WidgetTester tester) async {

// After (combined with Issue 3's fix)
testWidgets('Hello world smoke test', (final tester) async {
```

Issues 3 and 4 applied to the same parameter, so the combined fix changed `(WidgetTester tester)` to `(final tester)` — removing the redundant type annotation (Issue 3) and adding `final` (Issue 4) in a single edit.

**Note:** Per the repo's conventions, neither change was necessary — the original code was correct by Flutter standards.

### Deprecation note

As of Dart 3.11, `prefer_final_parameters` is deprecated and will be removed in a future SDK release. The recommended replacement is `parameter_assignments`, which flags the *reassignment* rather than the missing `final` keyword. The effect is similar — preventing accidental parameter reassignment — but `parameter_assignments` does not require the visual overhead of `final` on every parameter. However, the Flutter repo also disables `parameter_assignments`, so neither form of this protection is active.

---

## Git history deep dive: how did this bug survive 6 years?

The `driver.close()` bug (Issue 1) has been present in the Flutter repo since the file was first created. A deep analysis of git history reveals not just how it survived, but that the Flutter team is **actively working to enable `unawaited_futures` repo-wide** — and the examples were simply missed in that ongoing effort.

### Origin: February 2020

The bug was introduced in commit `9ba4eb04dda` on 2020-02-24 by Nurhan Turgut in PR #51003 ("[web] Smoke tests for web engine"):

```dart
// Original code from 2020
tearDownAll(() async {
  if (driver != null) {
    driver.close();  // no await — bug from day one
  }
});
```

The null check (`driver != null`) was later removed during the null-safety migration (#75022), but `driver.close()` never gained an `await` through any of the 23 commits that touched this file over the following 6 years.

### The same bug in three places

The identical pattern exists in `platform_channel/test_driver/button_tap_test.dart` and `platform_channel_swift/test_driver/button_tap_test.dart`. The `platform_channel` version dates back even further — to 2017 (commit `d274888be60`, PR #9018 "Rename platform_services to platform_channel"). All three have survived untouched on upstream master as of March 2026.

### Why it was never caught: the `AnimationController` tradeoff

The root `analysis_options.yaml` has disabled `unawaited_futures` since at least 2020, with the comment:

> `# - unawaited_futures # too many false positives, especially with the way AnimationController works`

The problem is that `AnimationController.forward()`, `.reverse()`, `.animateTo()`, etc. all return `TickerFuture`, and in Flutter code it is idiomatic to call them without `await`:

```dart
// This is correct Flutter code — you don't await animations
_controller.forward();
```

With `unawaited_futures` enabled, every one of these call sites would produce a lint warning, creating enormous noise across the codebase. The Flutter team made a pragmatic decision to disable the rule entirely rather than annotate thousands of legitimate fire-and-forget animation calls.

The collateral damage: genuine bugs like `driver.close()` without `await` went undetected.

### The solution: `@awaitNotRequired` (in progress)

The Flutter team is actively solving this problem. Issue [#168555](https://github.com/flutter/flutter/issues/168555) ("Use `@awaitNotRequired` in Flutter SDK") tracks the effort to:

1. **Annotate legitimate fire-and-forget APIs** with `@awaitNotRequired` from `package:meta` (version 1.17.0). This tells the `unawaited_futures` lint "this function is designed to be called without `await`."

2. **Add `await` to callsites that actually need it** — the real bugs.

3. **Enable `unawaited_futures` repo-wide** once the annotations and fixes are in place.

PR [#181513](https://github.com/flutter/flutter/pull/181513) ("Add @awaitNotRequired annotation to flutter sdk") is the main implementation PR. It has spawned several child PRs that have already landed on master:

| Commit | PR | Description |
|--------|-----|-------------|
| `0fcce5ef36b` | #181513 | Add `@awaitNotRequired` to `AnimationController.forward()`, `.reverse()`, `.animateTo()`, `.animateBack()`, `.toggle()`, `Navigator.push()`, `ScrollController.animateTo()`, and ~70 other APIs |
| `b0eae2a4af2` | #182983 | Add `await` to flutter_test callsites |
| `3b618442ab3` | #182868 | Add `await` to `BasicMessageChannel.send` callsites |
| `1e02e1052e4` | #183334 | Add `await` or ignore to flutter_driver callsites |
| `c777faa6db8` | #183413 | Add `await` to more flutter/flutter callsites |
| `fd89d205aa4` | #183479 | Add `await` to dev/ callsites |
| `41bc812d883` | #183487 | Add `await` to flutter/test callsites |

**Crucially, none of these commits touched the `examples/` directory.** The three `driver.close()` bugs in `hello_world`, `platform_channel`, and `platform_channel_swift` were missed in this otherwise thorough cleanup.

### Timeline

| Date | Event |
|------|-------|
| 2017 | `platform_channel` test driver created with `driver.close()` (no await) |
| 2020-02 | `hello_world` smoke test created with same pattern (PR #51003) |
| ~2020 | `unawaited_futures` disabled repo-wide due to `AnimationController` false positives |
| 2025 | Dart SDK adds `@awaitNotRequired` annotation in `package:meta` 1.17.0 |
| 2026-01 | PR #181513 begins annotating Flutter SDK APIs with `@awaitNotRequired` |
| 2026-01 to 2026-03 | Child PRs land, adding `await` to hundreds of callsites across the repo |
| 2026-03 | The `examples/` directory is not included in the cleanup — bugs remain |

### Conclusion

The `driver.close()` bug is not a case of "Flutter evolved and this became wrong." It was always wrong — `FlutterDriver.close()` has returned `Future<void>` since its creation. The bug survived because:

1. **No lint catches it.** `unawaited_futures` has been disabled repo-wide since ~2020.
2. **The test still passes.** Dropping the `Future` from `close()` in `tearDownAll` doesn't cause a test failure — it just means the cleanup doesn't complete reliably.
3. **The file is rarely modified.** Only 23 commits in 6 years, and none focused on async correctness.
4. **The ongoing cleanup missed examples.** The `@awaitNotRequired` effort (PR #181513) systematically fixed callsites in `packages/`, `dev/`, and `test/`, but not `examples/`.

Our fix aligns with the direction the Flutter team is already heading. Once `@awaitNotRequired` annotations are complete and `unawaited_futures` is enabled repo-wide, this bug would be caught automatically — but the examples need the fix now.

---

## How these issues were detected

### Two analysis tools

Our `analysis_options.yaml` configures two independent analysis tools. All four issues described above were found by the **standard Dart analyzer** (`dart analyze`), not by dart_code_linter.

**Tool 1: Standard Dart analyzer (`dart analyze`)**

This is the built-in Dart SDK static analyzer. Our configuration enables it at maximum strictness with ~100 additional lint rules beyond the default `flutter_lints` package. All four issues in this document were caught by this tool. The specific rules (`unawaited_futures`, `unnecessary_async`, `avoid_types_on_closure_parameters`, `prefer_final_parameters`) are all built-in Dart SDK linter rules — they ship with every Dart installation but are not enabled by default.

**Tool 2: dart_code_linter ([github.com/bancolombia/dart-code-linter](https://github.com/bancolombia/dart-code-linter))**

A third-party analysis tool providing ~160 additional rules focused on areas the standard analyzer does not cover:

- **Code metrics** — cyclomatic complexity, lines of executable code, number of parameters, nesting depth, weight of class
- **Unused code detection** — functions, methods, classes, and fields declared but never referenced
- **Unused file detection** — `.dart` files never imported
- **Unnecessary nullable analysis** — parameters and return types declared nullable but never actually null

It runs four checks: `analyze`, `check-unused-code`, `check-unused-files`, `check-unnecessary-nullable`.

**DCL results on hello_world: zero code issues found.** The only rules disabled were structural/stylistic mismatches with Dart conventions:

| Disabled DCL rule | Reason |
|-------------------|--------|
| `member-ordering` | Conflicts with `sort_constructors_first` — Dart convention places constructors before fields |
| `prefer-static-class` | `main()` is a top-level function, idiomatic for entry points and conditional imports |
| `prefer-match-file-name` | `arabic.dart` doesn't define an `Arabic` class; files group related entry points |
| `avoid-non-ascii-symbols` | `arabic.dart` intentionally uses Arabic script to demonstrate RTL text rendering |
| `avoid-ignoring-return-values` | `runApp()` return value is intentionally unused |
| `no-magic-number` | Too noisy for example code — spacing values and constants are clear from context |

**Which tool found what:**

| Tool | Findings in hello_world |
|------|------------------------|
| Standard Dart analyzer | 4 issues: `unawaited_futures`, `unnecessary_async`, `avoid_types_on_closure_parameters`, `prefer_final_parameters` |
| dart_code_linter | 0 code issues (6 rules disabled for structural reasons) |

### Why the default lints didn't catch these

None of the four lint rules that fired are included in any of Dart's standard lint sets:

| Lint set | Enabled rules | Catches these? |
|----------|--------------|----------------|
| `core` (Dart SDK) | ~30 rules | No |
| `recommended` (extends `core`) | ~56 rules | No |
| `flutter` (extends `recommended`) | ~67 rules | No |
| `flutter_lints` 6.0.0 | Mirrors `flutter` set | No |
| Flutter repo root config | 176 rules | No (all 4 explicitly disabled) |

Even the Flutter repo's own root `analysis_options.yaml` with 176 enabled rules explicitly disables all four of these rules. The async correctness rules (`unawaited_futures`, `discarded_futures`) are disabled due to false positive rates with `AnimationController`. The style rules are disabled as deliberate style choices.

### Reproducing

From the `examples/hello_world/` directory:

```bash
# Standard Dart analyzer (found all 4 issues)
nix develop --command dart analyze .

# Or using the Nix package targets
nix run .#dart-analyze        # dart analyze in isolated temp dir
nix run .#flutter-analyze     # flutter analyze in isolated temp dir

# dart_code_linter (confirmed zero additional issues)
nix run .#dart-code-linter
```

All should report clean results on the fixed code.

---

## Analysis of lint configurations across all examples

### The repo's authoritative lint config

The Flutter repo's authoritative lint configuration is `/analysis_options.yaml` at the repository root. It enables **176 lint rules** with `strict-casts`, `strict-inference`, and `strict-raw-types`, plus 55 explicitly disabled rules with documented rationale for each.

The root config applies to the entire repository — examples are not excluded from its `analyzer.exclude` list (which only excludes `bin/cache/**`, `dev/conductor/lib/proto/*`, and `engine/**`). This means **CI already enforces the root config on all examples**, regardless of whether they have their own `analysis_options.yaml`.

However, a local `analysis_options.yaml` in an example directory **overrides** the root config when running `dart analyze` or `flutter analyze` locally from within that directory. This creates a gap: an example can have weaker local analysis than what CI enforces.

The style guide at `docs/contributing/Style-guide-for-Flutter-repo.md` does not explicitly recommend which `analysis_options.yaml` configuration examples should use. It references the root config implicitly but does not mandate that examples include it.

### What each example actually uses

| Example | Local `analysis_options.yaml` | `include:` directive | Effective local rules | CI rules |
|---------|-------------------------------|---------------------|-----------------------|----------|
| `layers` | Yes | `include: ../../analysis_options.yaml` | **176** (root config) | 176 |
| `api` | Yes | `include: package:flutter_lints/flutter.yaml` | **~67** (flutter_lints) | 176 |
| `multiple_windows` | Yes | `include: package:flutter_lints/flutter.yaml` | **~67** (flutter_lints) | 176 |
| `hello_world` | Yes (ours) | `include: package:flutter_lints/flutter.yaml` + ~100 extra | **~167** (custom strict) | 176 |
| `web_telemetry` | Yes (ours) | `include: package:flutter_lints/flutter.yaml` + ~100 extra | **~167** (custom strict) | 176 |
| `flutter_view` | **No** | _(none)_ | **~30** (Dart defaults) | 176 |
| `image_list` | **No** | _(none)_ | **~30** (Dart defaults) | 176 |
| `platform_channel` | **No** | _(none)_ | **~30** (Dart defaults) | 176 |
| `platform_channel_swift` | **No** | _(none)_ | **~30** (Dart defaults) | 176 |
| `platform_view` | **No** | _(none)_ | **~30** (Dart defaults) | 176 |
| `splash` | **No** | _(none)_ | **~30** (Dart defaults) | 176 |
| `texture` | **No** | _(none)_ | **~30** (Dart defaults) | 176 |

**Key observations:**

1. **Only `layers` gets it right** — it uses `include: ../../analysis_options.yaml` to inherit the root config, so local analysis matches CI.

2. **7 examples have no `analysis_options.yaml` at all.** When running locally (`dart analyze .` from within the example), they get only Dart's ~30 default rules. CI enforces the full 176 rules, but developers working in these directories won't see the same warnings locally.

3. **`api` and `multiple_windows` use `flutter_lints`** (~67 rules), which is less than half the root config. This means local analysis is significantly weaker than CI. The `multiple_windows` config appears to be a boilerplate `flutter create` default that was never updated.

4. **Our `hello_world` and `web_telemetry` use a custom strict config** that enables rules the root config explicitly disables. We are stricter than the repo in some areas (e.g. `avoid_types_on_closure_parameters`) and different in others (e.g. `prefer_int_literals`, which the root disables because it "conflicts with `docs/contributing/Style-guide-for-Flutter-repo.md#use-double-literals-for-double-constants`").

5. **All examples pass the root config.** Running `dart analyze` with the root config against every example produces zero issues. This confirms CI is already enforcing the root config successfully.

**Recommendation:** Every example should follow `layers`' approach: `include: ../../analysis_options.yaml`. This ensures local analysis matches CI and developers see the same warnings in their IDE that CI would catch. The style guide should document this recommendation.

### Async bugs found across all examples

Running our strict `analysis_options.yaml` (which enables `unawaited_futures` and `discarded_futures`) against all examples found async correctness issues beyond `hello_world`. These are genuine bugs — silently dropped `Future` values — regardless of whether the repo enables the lint rules that catch them.

| Example | File | Lint rule | Issue |
|---------|------|-----------|-------|
| `hello_world` | `test_driver/smoke_web_engine_test.dart:28` | `unawaited_futures` | `driver.close()` without `await` |
| `flutter_view` | `lib/main.dart:58` | `discarded_futures` | Future-returning call in non-async function |
| `image_list` | `lib/main.dart:115` | `unawaited_futures` | Missing `await` on Future |
| `image_list` | `lib/main.dart:173` | `discarded_futures` | Future-returning call in non-async function |
| `image_list` | `lib/main.dart:180` | `discarded_futures` | Future-returning call in non-async function |
| `layers` | `rendering/spinning_square.dart:52` | `discarded_futures` | Future-returning call in non-async function |
| `layers` | `services/isolate.dart:128` | `discarded_futures` | Future-returning call in non-async function |
| `layers` | `services/isolate.dart:133` | `discarded_futures` | Future-returning call in non-async function |
| `multiple_windows` | `lib/app/main_window.dart:114` | `unnecessary_async` | `async` without `await` |
| `multiple_windows` | `lib/app/main_window.dart:279` | `discarded_futures` | Future-returning call in non-async function |
| `multiple_windows` | `lib/app/dialog_window_edit_dialog.dart:15` | `discarded_futures` | Future-returning call in non-async function |
| `multiple_windows` | `lib/app/regular_window_edit_dialog.dart:15` | `discarded_futures` | Future-returning call in non-async function |
| `multiple_windows` | `lib/app/rotated_wire_cube.dart:30` | `discarded_futures` | Future-returning call in non-async function |
| `multiple_windows` | `lib/app/tooltip_window_edit_dialog.dart:17` | `discarded_futures` | Future-returning call in non-async function |
| `platform_channel` | `test_driver/button_tap_test.dart:16` | `unnecessary_async` | `async` without `await` |
| `platform_channel` | `test_driver/button_tap_test.dart:17` | `unawaited_futures` | Missing `await` on Future (same `driver.close()` bug as hello_world) |
| `platform_channel_swift` | `test_driver/button_tap_test.dart:16` | `unnecessary_async` | `async` without `await` |
| `platform_channel_swift` | `test_driver/button_tap_test.dart:17` | `unawaited_futures` | Missing `await` on Future (same `driver.close()` bug as hello_world) |

**18 async issues across 8 of 12 examples.** Three of these are the exact same `driver.close()` bug we fixed in `hello_world` — the same pattern appears in `platform_channel` and `platform_channel_swift`.

Note: some of these `discarded_futures` instances may be intentional fire-and-forget patterns (e.g. launching animations), which is why the repo disables the rule. Each would need individual assessment to determine if it's a bug or a deliberate pattern that should use `unawaited()`.

---

## Style guide references

### Where our strict config diverges from the repo

Our `analysis_options.yaml` enables several rules that the repo explicitly disables. For rules that are style-related (not correctness), the repo's choice should be respected. Here are the key divergences:

| Our rule | Repo status | Style guide reference | Verdict |
|----------|------------|----------------------|---------|
| `avoid_types_on_closure_parameters` | Disabled (line 81) | Line 802: "Give types to all parameters, even in closures" | **Our fix violates the style guide.** The original `(WidgetTester tester)` was correct. |
| `prefer_final_parameters` | Disabled (line 172) | No explicit mention. Disabled as "adds too much verbosity." | **Deliberate repo style choice.** Our `final` addition is non-standard. |
| `prefer_int_literals` | Disabled (line 181) | Line 181 references "docs/contributing/Style-guide-for-Flutter-repo.md#use-double-literals-for-double-constants" | **Conflicts with documented style.** |
| `prefer_expression_function_bodies` | Disabled (line 168) | Line 168 references "docs/contributing/Style-guide-for-Flutter-repo.md#consider-using--for-short-functions-and-methods" | **Flutter style is "consider", not "always".** The rule is too strict. |
| `cascade_invocations` | Disabled (line 90) | "doesn't match the typical style of this repo" | **Repo style diverges from this rule.** |
| `parameter_assignments` | Disabled (line 155) | "we do this commonly" | **Reassigning parameters is an accepted pattern in this repo.** |

### Gaps in the style guide and example configs

The following gaps were identified during this analysis:

**1. No documented recommendation for example `analysis_options.yaml` configuration.**

The style guide does not specify what `analysis_options.yaml` examples should use. Only 1 of 12 examples (`layers`) correctly inherits the root config via `include: ../../analysis_options.yaml`. The rest either use the weaker `flutter_lints` package or have no config at all. While CI enforces the root config regardless, local development and IDE analysis are significantly weaker in most example directories.

**Recommendation:** Add to the style guide or a contributing doc that examples should use `include: ../../analysis_options.yaml` to match CI behavior locally.

**2. No lint rule catches silently dropped Futures.**

Both `unawaited_futures` and `discarded_futures` are disabled repo-wide due to false positive rates with `AnimationController` and similar patterns. This means the class of bug found in `hello_world` (and 7 other examples) has no automated detection. The 18 async issues found across examples suggest this is a real problem, not a theoretical one.

**Recommendation:** Consider enabling `unawaited_futures` and/or `discarded_futures` with targeted `// ignore` comments where false positives occur (e.g. AnimationController usage), rather than disabling the rules entirely. Alternatively, document the tradeoff in the style guide so example authors know to manually audit Future-returning calls.

**3. Style guide says "give types to all parameters, even in closures" but the repo's `omit_obvious_local_variable_types` rule is enabled.**

The style guide at line 802 says to always give types to closure parameters. But the root config enables `omit_obvious_local_variable_types` (line 148), which omits types when they are obvious from context. These two positions create tension — the style guide says "always type," but the linter says "omit when obvious." The resolution appears to be: local variables may omit obvious types, but closure parameters should always be typed. This distinction is not explicitly documented.

---

## Proposed GitHub issues

### Issue 1: `examples/` missed in `@awaitNotRequired` cleanup — 3 unawaited `driver.close()` bugs

**Repo:** `flutter/flutter`
**Labels:** `a: tests`, `d: examples`
**Related:** #168555, #181513

**Title:** `examples/: unawaited driver.close() in 3 test_driver files (missed by #181513 cleanup)`

**Body:**

PR #181513 and its child PRs (#182983, #183334, #183413, #183479, #183487) systematically added `await` to unawaited callsites across `packages/`, `dev/`, and `test/`. The `examples/` directory was not included.

Three files have the same bug — `driver.close()` without `await` in `tearDownAll`:

- `examples/hello_world/test_driver/smoke_web_engine_test.dart:28` — since #51003 (2020-02)
- `examples/platform_channel/test_driver/button_tap_test.dart:17` — since #9018 (2017)
- `examples/platform_channel_swift/test_driver/button_tap_test.dart:17` — since #9018 (2017)

`FlutterDriver.close()` returns `Future<void>`. Without `await`, the WebDriver connection is not reliably closed before the test process exits.

**Fix:** Add `await` before `driver.close()` in all three files.

---

### Issue 2: `examples/` has 15 additional `discarded_futures` callsites to audit

**Repo:** `flutter/flutter`
**Labels:** `a: tests`, `d: examples`
**Related:** #168555, #181513

**Title:** `examples/: 15 discarded_futures callsites to audit as part of #181513 rollout`

**Body:**

With `unawaited_futures` and `discarded_futures` enabled, 15 additional callsites in `examples/` produce warnings. Some may be legitimate fire-and-forget patterns that need `unawaited()` or `@awaitNotRequired`; others may be bugs.

- `flutter_view/lib/main.dart:58` — `discarded_futures`
- `image_list/lib/main.dart:115` — `unawaited_futures`
- `image_list/lib/main.dart:173,180` — `discarded_futures` (×2)
- `layers/rendering/spinning_square.dart:52` — `discarded_futures`
- `layers/services/isolate.dart:128,133` — `discarded_futures` (×2)
- `multiple_windows/lib/app/main_window.dart:114` — `unnecessary_async`
- `multiple_windows/lib/app/main_window.dart:279` — `discarded_futures`
- `multiple_windows/lib/app/dialog_window_edit_dialog.dart:15` — `discarded_futures`
- `multiple_windows/lib/app/regular_window_edit_dialog.dart:15` — `discarded_futures`
- `multiple_windows/lib/app/rotated_wire_cube.dart:30` — `discarded_futures`
- `multiple_windows/lib/app/tooltip_window_edit_dialog.dart:17` — `discarded_futures`

Each needs individual assessment: `await`, `unawaited()`, or `@awaitNotRequired` on the called API.

---

### Issue 3: Inconsistent `analysis_options.yaml` across examples — local analysis weaker than CI

**Repo:** `flutter/flutter`
**Labels:** `d: examples`, `a: quality`

**Title:** `examples/: local analysis_options.yaml inconsistent — only 1 of 12 inherits root config`

**Body:**

CI enforces the root `analysis_options.yaml` (176 rules) on all examples. But local `dart analyze` from within an example directory uses whatever local config exists. Current state:

- **1 example** inherits root config: `layers` (`include: ../../analysis_options.yaml`)
- **2 examples** use `flutter_lints` (~67 rules): `api`, `multiple_windows`
- **7 examples** have no config (~30 default rules): `flutter_view`, `image_list`, `platform_channel`, `platform_channel_swift`, `platform_view`, `splash`, `texture`

Developers working in these directories see fewer warnings locally than CI would catch. IDEs show incomplete analysis.

**Fix:** Add `include: ../../analysis_options.yaml` to each example's `analysis_options.yaml`, following `layers`' existing pattern.
