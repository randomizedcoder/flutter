# Flutter Web Telemetry Example

## Motivation

We wanted to profile a Flutter web application — not just in debug mode with DevTools, but in **release mode** with real-world timings. The official Flutter performance docs are helpful for getting started:

| Doc | What it covers |
|-----|---------------|
| [Web Performance](https://docs.flutter.dev/perf/web-performance) | General tips for Flutter web performance |
| [UI Performance](https://docs.flutter.dev/perf/ui-performance) | Debug profiling flags, DevTools usage |
| [Rendering Performance](https://docs.flutter.dev/perf/rendering) | Render speed, shader compilation jank |
| [`FrameTiming` API](https://api.flutter.dev/flutter/dart-ui/FrameTiming-class.html) | Per-frame phase timestamps (API reference) |
| [`addTimingsCallback`](https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addTimingsCallback.html) | Registering for frame timing delivery (API reference) |

But there's a gap: **no guide for collecting programmatic telemetry data in release mode**. The docs cover DevTools-based profiling and debug flags extensively, but don't show how to wire up `addTimingsCallback`, lifecycle hooks, and navigation observers into a cohesive telemetry pipeline that works in production.

This example fills that gap using **only built-in Flutter APIs** — no OpenTelemetry SDK, no framework modifications, no third-party dependencies.

In addition to the telemetry code itself, this example demonstrates how to set up a **reproducible Flutter development environment with Nix**. The included [Nix flake](https://nix.dev/concepts/flakes.html) pins the exact Flutter SDK version, provides automated checks (static analysis, formatting, code metrics), and ensures every developer — regardless of their system Flutter install — gets an identical environment with a single command. See [Reproducible Environment with Nix](#reproducible-environment-with-nix) for details.

---

## Table of Contents

- [Quick Start](#quick-start)
- [What This Example Demonstrates](#what-this-example-demonstrates)
- [Project Structure](#project-structure)
- [Flutter's Timing & Tracing Infrastructure](#flutters-timing--tracing-infrastructure)
- [Lifecycle & Event Hooks Used in This Example](#lifecycle--event-hooks-used-in-this-example)
- [What Works in Release Mode vs Debug Only](#what-works-in-release-mode-vs-debug-only)
- [Browser Performance API Integration](#browser-performance-api-integration)
- [Toward OpenTelemetry Support](#toward-opentelemetry-support)
- [Extension Opportunities](#extension-opportunities)
- [Testing](#testing)
- [Static Analysis](#static-analysis)
- [Known Limitations](#known-limitations)
- [Reproducible Environment with Nix](#reproducible-environment-with-nix)
- [Key File Reference](#key-file-reference)

---

## Quick Start

You need a Flutter SDK installed with web support enabled. If you're not sure, run `flutter doctor` and check that Chrome is listed as an available device.

### Standard Flutter

```bash
cd examples/web_telemetry
flutter run -d chrome            # debug mode
flutter run -d chrome --release  # release mode (batched frame timings, no debug overhead)
```

### With Nix (optional)

If you have [Nix](https://nixos.org) installed, you don't need a system Flutter SDK at all — the flake provides one:

```bash
cd examples/web_telemetry
nix develop              # enter dev shell with pinned Flutter SDK
flutter run -d chrome    # run the app (inside nix shell)
```

See [Reproducible Environment with Nix](#reproducible-environment-with-nix) for full details, including automated checks:

```bash
nix flake check              # verify all Nix expressions and check scripts build
nix run .#smoke-test         # unit tests + analysis + web build + HTTP check
nix run .#dart-analyze       # dart analyze
nix run .#dart-code-linter   # dart_code_linter (metrics, unused code, etc.)
nix run .#flutter-analyze    # flutter analyze
nix run .#dart-format-check  # verify dart format compliance
nix fmt                      # format Dart files in-place (page width 100)
```

### What You'll See

The app opens in Chrome with four buttons:

- **Go to Detail Page** — navigates to a second page and back. Both the push and pop are recorded as telemetry events.
- **Run Async Work (Span)** — starts a timed span, waits 300ms, then finishes it. The span duration is recorded.
- **Record Instant Mark** — records a zero-duration `user-tap` event.
- **Show Telemetry** — opens a bottom sheet displaying frame statistics (frame count, jank count, average build/raster times) and a scrollable list of all recorded events, newest first.

Try clicking the buttons in order, then tap **Show Telemetry** to see everything that was captured. If you're running in Chrome, open DevTools → Performance tab → record → interact → stop recording to see the `performance.mark()` and `performance.measure()` entries alongside browser-native metrics.

### Setup Comparison: Ubuntu Manual vs Nix

To appreciate what Nix gives you, here's what it takes to get this example running on a fresh Ubuntu machine each way:

**Without Nix** (manual Flutter install):

```bash
# 1. Install system dependencies
sudo apt update
sudo apt install -y curl git unzip xz-utils clang cmake ninja-build \
  pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev

# 2. Install Chrome (needed for Flutter web)
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main' | sudo tee /etc/apt/sources.list.d/google-chrome.list
sudo apt update && sudo apt install -y google-chrome-stable

# 3. Download and install Flutter SDK
git clone https://github.com/flutter/flutter.git -b stable ~/flutter
export PATH="$HOME/flutter/bin:$PATH"  # also add to ~/.bashrc

# 4. Accept licenses and verify
flutter doctor --android-licenses  # if prompted
flutter doctor                     # verify Chrome is detected

# 5. Run the example
cd examples/web_telemetry
flutter pub get
flutter run -d chrome
```

**With Nix** (two commands):

```bash
# 1. Install Nix (one-time, ~60 seconds)
bash <(curl -L https://nixos.org/nix/install) --daemon

# 2. Run the example (must be in the flake directory)
cd examples/web_telemetry
nix develop
flutter run -d chrome
```

Nix handles the Flutter SDK, Dart, and all tooling automatically. The first `nix develop` takes a few minutes to download everything into `/nix/store/`; subsequent runs are instant. Nothing is installed system-wide — when you exit the shell, it's as if Flutter was never there.

---

## What This Example Demonstrates

1. **Automatic frame timing** — `SchedulerBinding.addTimingsCallback` captures per-frame build, raster, and vsync durations with jank detection (frames exceeding the 16.67ms / 60 FPS budget).
2. **Automatic navigation tracking** — a `NavigatorObserver` records push, pop, replace, and remove events with route names and timestamps.
3. **App lifecycle events** — `AppLifecycleListener` captures resume, inactive, hide, show, pause, and detach transitions.
4. **Manual spans** — `startSpan` / `finish` API for timing arbitrary async operations (e.g., network requests, expensive computations).
5. **Instant marks** — zero-duration `mark()` events for recording discrete user interactions.
6. **Browser DevTools integration** — `performance.mark()` and `performance.measure()` calls make all spans visible in the browser Performance tab.
7. **Telemetry overlay** — an in-app bottom sheet displaying frame statistics and a scrollable event log.

---

## Project Structure

| File | Purpose |
|------|---------|
| `lib/main.dart` | Example app with two pages, async span demo, telemetry overlay |
| `lib/telemetry/telemetry_service.dart` | Core singleton: hooks frame timings, lifecycle, manual span API, data export |
| `lib/telemetry/telemetry_nav_observer.dart` | `NavigatorObserver` subclass feeding navigation events to the service |
| `lib/telemetry/telemetry_event.dart` | Data model: `TelemetryEvent`, `TelemetrySpan`, `TelemetrySnapshot`, `FrameStats` |
| `lib/telemetry/web_perf.dart` | Browser `performance.mark()`/`performance.measure()` via `dart:js_interop` |
| `lib/telemetry/web_perf_stub.dart` | No-op stubs for non-web platforms |
| `test/telemetry_service_test.dart` | 73 table-driven unit tests covering all data models, service lifecycle, and navigation observer |

---

## Flutter's Timing & Tracing Infrastructure

Flutter already has rich timing infrastructure built into the framework and engine. Understanding what exists helps explain why this example works the way it does — and where it fits.

### FlutterTimeline (framework layer)

`FlutterTimeline` (in `foundation/timeline.dart`) wraps `dart:developer` Timeline and provides `startSync` / `finishSync` / `timeSync` for synchronous timing blocks. When `debugCollectionEnabled = true`, timing data is collected as `TimedBlock` objects and retrieved via `debugCollect()`.

**Key limitation**: collection is only available in profile/debug mode, not release builds. This is why our example uses `addTimingsCallback` instead — it works in all build modes.

On the web, `FlutterTimeline.now` uses `window.performance.now()` for sub-millisecond wall-clock precision.

### FrameTiming (engine to framework)

`FrameTiming` delivers per-frame performance data from the engine. Each frame carries microsecond timestamps for these phases:

| Phase | Description |
|-------|-------------|
| `vsyncStart` | Vsync signal received |
| `buildStart` / `buildFinish` | UI thread build |
| `rasterStart` / `rasterFinish` | Raster thread |
| `rasterFinishWallTime` | Raster finish wall-clock time |

Derived getters: `buildDuration`, `rasterDuration`, `vsyncOverhead`, `totalSpan`. Also includes cache statistics (`layerCacheCount`, `layerCacheBytes`, `pictureCacheCount`, `pictureCacheBytes`) and `frameNumber`.

Delivery via `SchedulerBinding.addTimingsCallback()` arrives in batches — approximately once per second in release mode, ~100ms in debug mode.

### Debug Profiling Flags

These boolean flags gate `Timeline` events during the rendering pipeline:

| Flag | Effect |
|------|--------|
| `debugProfileBuildsEnabled` | Timeline event per widget build |
| `debugProfileBuildsEnabledUserWidgets` | Timeline event per user-created widget build |
| `debugProfileLayoutsEnabled` | Timeline event per `RenderObject.layout()` |
| `debugProfilePaintsEnabled` | Timeline event per `RenderObject.paint()` |

These are toggled at runtime via service extensions (`ext.flutter.*`) from DevTools. They are **debug/profile mode only** — not available in release builds.

### Web-Specific Profiler

The web engine has a `Profiler` class (enabled by the `FLUTTER_WEB_ENABLE_PROFILING` compile-time env var) with stopwatch-based timing and an `engineBenchmarkValueCallback` for exporting data to external consumers. This is separate from the `addTimingsCallback` approach used here.

### Engine-Level C++ Tracing

The Flutter engine uses low-level tracing macros (`FML_TRACE_EVENT`, `TRACE_EVENT_ASYNC_BEGIN0/END0`, `FML_TRACE_COUNTER`) that emit to platform-specific backends (Fuchsia trace, Android systrace, etc.). These are not directly accessible from Dart code but show up in system-level profiling tools.

---

## Lifecycle & Event Hooks Used in This Example

This example hooks into three of Flutter's observer patterns to generate telemetry events automatically:

### Frame Scheduling Callbacks

The most important hook for performance telemetry:

| API | Behavior |
|-----|----------|
| `addTimingsCallback(callback)` | Receive `List<FrameTiming>` batches from the engine — **works in release mode** |
| `addPostFrameCallback(callback)` | Called once after current frame completes |
| `addPersistentFrameCallback(callback)` | Called every frame (never removed) |
| `scheduleFrameCallback(callback)` | Called on next frame only |

Our `TelemetryService` uses `addTimingsCallback` to receive frame data, compute jank metrics, and emit browser performance marks.

### App Lifecycle

`AppLifecycleListener` provides named callbacks for platform lifecycle transitions: `onResume`, `onInactive`, `onHide`, `onShow`, `onPause`, `onRestart`, `onDetach`. Our service uses `onStateChange` to record every transition.

For more granular hooks, `WidgetsBindingObserver` also offers `didChangeMetrics`, `didChangeTextScaleFactor`, `didChangePlatformBrightness`, `didHaveMemoryPressure`, and more.

### Navigation Observers

`NavigatorObserver` provides `didPush`, `didPop`, `didRemove`, and `didReplace` callbacks. Our `TelemetryNavObserver` subclass records each navigation event with the route name and timestamp.

For widget-level route awareness, `RouteAware` / `RouteObserver<T>` allows individual widgets to subscribe to navigation events affecting their route.

### Other Hooks (Not Used Here)

- **Widget lifecycle** — `State.initState()`, `dispose()`, etc. can be instrumented manually but require per-widget effort.
- **Memory allocations** — `FlutterMemoryAllocations` provides listener-based object creation/disposal events (requires `kFlutterMemoryAllocationsEnabled`).
- **Platform channel profiling** — `kProfilePlatformChannels` enables timing of method/event/basic message channels.

---

## What Works in Release Mode vs Debug Only

| Capability | Debug | Profile | Release |
|------------|:-----:|:-------:|:-------:|
| `addTimingsCallback` (frame timings) | Yes | Yes | **Yes** |
| `AppLifecycleListener` | Yes | Yes | **Yes** |
| `NavigatorObserver` | Yes | Yes | **Yes** |
| Custom spans (`startSpan` / `finish`) | Yes | Yes | **Yes** |
| Browser `performance.mark()` / `measure()` | Yes | Yes | **Yes** |
| `FlutterTimeline.now` (timestamp) | Yes | Yes | **Yes** |
| `FlutterTimeline` data collection | Yes | Yes | No |
| `debugProfileBuildsEnabled` and friends | Yes | Yes | No |
| Per-widget build timing (via debug flags) | Yes | Yes | No |
| `dart:developer` Timeline events in DevTools | Yes | Yes | No |
| `kProfilePlatformChannels` | Yes | Yes | No |
| `kFlutterMemoryAllocationsEnabled` | Yes | Yes | No |

**This is why the example uses `addTimingsCallback`, lifecycle listeners, and navigation observers** — they are the built-in APIs that work across all build modes. Everything else in the telemetry layer (spans, marks, browser performance API) is pure Dart and naturally works everywhere.

---

## Browser Performance API Integration

On the web, the telemetry service uses `performance.mark()` and `performance.measure()` to make spans visible in Chrome DevTools' Performance tab — alongside network requests, layout, and paint.

### How It Works

The conditional import pattern keeps the web dependency isolated:

```dart
// In telemetry_service.dart
import 'web_perf_stub.dart'
    if (dart.library.js_interop) 'web_perf.dart' as perf;
```

- `web_perf.dart` — calls `performance.mark()` / `performance.measure()` via `dart:js_interop`
- `web_perf_stub.dart` — no-op stubs for non-web platforms

### What Shows Up in DevTools

- **Frame marks**: `frame_1`, `frame_2`, ... appear as markers on the timeline.
- **Span measures**: named measures (e.g., `simulated-work`) show as duration bars between their `start` and `end` marks.
- **Instant marks**: `user-tap` and other marks appear as discrete points.

Open Chrome DevTools → Performance tab → record → interact with the app → stop recording. Flutter telemetry events appear alongside all other browser performance data.

---

## Toward OpenTelemetry Support

Flutter currently has **no built-in OpenTelemetry integration**. Specifically, there is no:

- OTEL SDK or span model in the framework
- W3C trace context propagation (`traceparent` / `tracestate` headers)
- Collector or exporter (OTLP, Jaeger, Zipkin, etc.)
- Distributed tracing across Dart ↔ backend service boundaries
- Baggage propagation

Yet the framework already has most of the raw ingredients. The observer patterns and timing APIs demonstrated in this example map naturally onto an OTEL span model:

### 1. Lightweight Span Model

A `TelemetrySpan` class (like the one in this example) could be extended to:
- Carry a trace ID and parent span ID for distributed context
- Support configurable exporters (console, OTEL collector, browser Performance API)
- Work in all build modes — unlike `FlutterTimeline` collection, which is debug/profile only

### 2. Auto-Instrumentation via Existing Hooks

The same hooks this example uses could generate OTEL-compatible spans automatically:

- **`NavigatorObserver`** → route transition spans
- **`AppLifecycleListener`** → lifecycle state spans
- **`addTimingsCallback`** → frame performance spans
- **`WidgetsBindingObserver`** → platform event spans

### 3. Manual Instrumentation API

A simple user-facing API (similar to what this example provides):

```dart
final span = Telemetry.startSpan('checkout-flow');
try {
  await processCheckout();
} finally {
  span.end();
}
```

### 4. Web-Native Export

On the web, `performance.mark()` / `performance.measure()` (as demonstrated here) means spans are visible in Chrome DevTools, Lighthouse, and WebPageTest with zero collection infrastructure. This is a natural first export target before adopting a full OTEL collector.

### The Gap

The framework has the **collection side** covered — timing data, lifecycle events, navigation hooks. What's missing is the **export and correlation layer**: trace context propagation across HTTP boundaries, parent-child span relationships, and a standard wire format. This example shows that the collection side is straightforward with built-in APIs; building the export layer on top would bring Flutter in line with the observability ecosystem that backend services already use.

---

## Extension Opportunities

Beyond OpenTelemetry, here are other natural next steps:

| Extension | Where to Hook | Effort |
|-----------|--------------|--------|
| HTTP request tracing with W3C headers | `HttpClient` / `dio` interceptor | Medium |
| OTEL span export (OTLP, Jaeger, Zipkin) | New exporter layer on `TelemetryService` | Medium |
| Widget build spans | `debugProfileBuildsEnabled` path (debug/profile only) | Medium |
| Platform channel timing | `kProfilePlatformChannels` flag path | Medium |
| Parent-child span relationships | Extend `TelemetrySpan` with parent ID | Low |
| Batch export to a backend | Periodic flush of the event buffer to a collector | Low |

The framework already has the raw data — navigation observers, frame timings, lifecycle hooks. The gap is an export layer that sends this data somewhere useful in production. This example provides the collection side; you bring the export destination.

---

## Testing

The test suite in `test/telemetry_service_test.dart` contains **73 tests** organized into table-driven groups that cover every public type and method. Tests run in under one second with `flutter test`.

### Running tests

```bash
# Standard Flutter (from examples/web_telemetry/)
flutter test

# With Nix (isolated temp directory, no monorepo dependency)
nix run .#smoke-test
```

### What's tested

| Group | Tests | What's covered |
|-------|------:|----------------|
| `TelemetryEvent` | 19 | `toJson` (4 table-driven: instant, span, data, both), `toString` (2), equality positive (5 including identity), equality negative (8 including cross-type) |
| `FrameStats` | 12 | Averages (4 table-driven: zero frames, even, non-even, single), `toJson` (1), `toString` (2), equality (6 including per-field negative cases) |
| `TelemetrySnapshot` | 6 | `toJson` round-trip (3 table-driven: empty, single, multiple), equality (3: same, different events, different stats) |
| `TelemetrySpan` | 5 | Construction properties, `isFinished` transition, elapsed non-negative, `finish()` idempotency (onFinish called once), stopwatch stops on finish |
| `TelemetryService` | 14 | `init()` idempotency, pre-init behavior (3: navigatorObserver throws, mark works, startSpan works), `dispose()` idempotency, eventStream lifecycle across dispose/reinit, ring buffer eviction (4 table-driven), multiple event types, `dumpToConsole`, `toJson` round-trip, dispose+reinit |
| `TelemetryNavObserver` | 17 | Individual methods (5 table-driven: push/pop with/without previousRoute, remove), `didReplace` (2: named and null routes), unnamed routes (3 table-driven), previousRoute data inclusion (5 table-driven: tests the `case final String prevName` pattern branch), event sequence (1) |
| **Total** | **73** | |

### Test design

- **Table-driven** — Most groups use Dart record types as test case tables, making it easy to add new cases without duplicating test scaffolding.
- **Negative cases** — Equality tests cover every field independently (different type, different name, different timestamp, etc.) plus cross-type comparison (`event == 'not an event'`).
- **Singleton isolation** — Each test gets a fresh `TelemetryService` state via `setUp`/`tearDown` with `dispose()`. Tests that use the service before `init()` explicitly call `init()` at the end so `tearDown`'s `dispose()` can clean up.
- **No mocks** — Tests exercise real objects. The singleton `TelemetryService` pattern is tested as-is, including edge cases like double-init and double-dispose.

---

## Static Analysis

This example enforces maximum-strictness static analysis through three complementary layers, all configured in `analysis_options.yaml` and enforced by the Nix checks.

### Layer 1: Dart Analyzer with strict-mode and flutter_lints

The Dart analyzer runs with all three strict-mode flags enabled:

- `strict-casts: true` — no implicit `dynamic` downcasts
- `strict-inference: true` — no implicit `dynamic` type inference
- `strict-raw-types: true` — no raw generic types (e.g., `List` instead of `List<int>`)

On top of the base `package:flutter_lints/flutter.yaml` rule set, the example enables every additional lint rule that is not removed, deprecated, or in direct conflict with another enabled rule. The ~100 additional rules are organized into categories: type annotations, const/immutability, async, error handling, style/formatting, null safety, class design, Flutter-specific, documentation, and performance/correctness. Where two rules conflict (e.g., `prefer_final_parameters` vs `avoid_final_parameters`), the choice is documented with a comment explaining the resolution.

Run via Nix:

```bash
nix run .#dart-analyze       # dart analyze (uses analysis_options.yaml)
nix run .#flutter-analyze    # flutter analyze (uses analysis_options.yaml)
```

### Layer 2: dart_code_linter (DCL)

[dart_code_linter](https://github.com/bancolombia/dart-code-linter) is a third-party analysis tool that goes beyond standard Dart lints with code metrics, anti-pattern detection, and unused code analysis. It provides 160+ rules not covered by the built-in analyzer.

The example extends DCL's `all.yaml` preset (every rule enabled) plus `metrics_recommended.yaml` (code complexity thresholds), then surgically disables 12 rules that produce false positives on idiomatic Flutter patterns. Each disabled rule has a comment in `analysis_options.yaml` explaining why. The disabled rules are:

| Rule | Why disabled |
|------|-------------|
| `member-ordering` | Conflicts with Dart's `sort_constructors_first` convention |
| `prefer-static-class` | Top-level functions are idiomatic for conditional imports |
| `prefer-match-file-name` | Files intentionally group related types |
| `no-empty-block` / `avoid-unused-parameters` | No-op stubs must match real implementation signatures |
| `prefer-single-widget-per-file` | Small related widgets belong together in a demo |
| `avoid-non-ascii-symbols` | `µs` is the standard microsecond symbol in telemetry |
| `no-magic-number` | Spacing values and buffer sizes are clear from context |
| `prefer-extracting-callbacks` | Small inline callbacks are idiomatic Flutter |
| `arguments-ordering` | Named arg order matching declaration order is not useful |
| `avoid-ignoring-return-values` | `runApp()` and `List.removeAt()` return values intentionally unused |
| `avoid-late-keyword` | `late` is correct for deferred initialization via `init()` |

Three metric thresholds are raised from the defaults to accommodate Flutter's declarative widget tree style, which naturally produces higher halstead volume than imperative code:

| Metric | Default | This example | Why |
|--------|---------|-------------|-----|
| `halstead-volume` | ~200 | 500 | Widget `build` methods nest constructor calls deeply |
| `maintainability-index` | ~50 | 40 | Flutter boilerplate (keys, `debugFillProperties`) lowers the index |
| `number-of-methods` | ~10 | 20 | Service classes with lifecycle hooks need more methods |

DCL runs four checks — all must pass with zero issues:

```bash
nix run .#dart-code-linter   # runs all four checks below:
# 1. analyze lib/              — rule violations and metric thresholds
# 2. check-unused-code lib/    — dead code detection
# 3. check-unused-files lib/   — files not imported anywhere
# 4. check-unnecessary-nullable lib/ — parameters that are never passed null
```

### Layer 3: dart format

All Dart files are formatted at page width 100 (matching the Flutter repo convention). Formatting is enforced as a Nix check:

```bash
nix run .#dart-format-check  # verify formatting (no changes made)
nix fmt                      # format in-place
```

### All checks at once

`nix flake check` verifies that all Nix expressions evaluate correctly and all check scripts build. This is the idiomatic Nix way to validate the flake and is fast (no network access needed).

For a full runtime validation of every target — including actually running the analysis tools, tests, and smoke test — use `nix run .#nix-test`. This is primarily intended for developers working on the Nix infrastructure itself.

---

## Known Limitations

1. **Frame timing batching** — in release mode, `FrameTiming` arrives in batches (~1/sec). Timestamps are accurate; delivery is batched.
2. **Declarative navigation** — `NavigatorObserver` works with imperative `Navigator`. For `GoRouter`, pass via `GoRouter(observers: [...])`.
3. **Timestamp resolution** — `performance.now()` may have 100µs resolution without cross-origin isolation headers (`Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy`).
4. **No per-widget build timing in release** — frame-level build duration is available; individual widget timing requires manual spans.
5. **dart_code_linter version banner** — DCL 3.2.1 prints an "Update available!" banner advertising 4.0.0. DCL 4.0.0 requires `analyzer ^11.0.0`, which is incompatible with the Flutter SDK's pinned `meta 1.17.0`. This is a cosmetic issue — the banner does not affect exit codes or check results. It will resolve itself when a future Flutter SDK ships a compatible `meta` version.

---

## Reproducible Environment with Nix

This example includes a [Nix flake](https://nix.dev/concepts/flakes.html) that provides a fully reproducible development environment with a pinned Flutter SDK. Anyone with Nix installed can run the example identically, regardless of their system Flutter version.

**Nix is entirely optional** — the example works fine with a standard Flutter install.

### Why Nix?

[Nix](https://nixos.org) is a package manager for Linux and macOS that provides **reproducible, isolated** environments. By tracking all dependencies and hashing their content, it ensures every developer uses the same versions of every package.

The goals of using Nix in this example are to:

- **Simplify onboarding** — a single `nix develop` command gives you a working Flutter environment with all tools configured
- **Improve reproducibility** — ensure consistent build environments across developers (no more "it worked on my machine")
- **Reduce setup friction** — eliminate Flutter SDK version mismatches, especially for web examples where SDK differences affect JavaScript output and performance characteristics
- **Enforce quality gates** — `nix flake check` validates the flake, and individual `nix run .#*` commands run each check tool

The flake pattern here could be reused for other Flutter examples.

### What This Repository Provides

This repository includes `flake.nix`, `flake.lock`, and modular Nix files in `nix/`:

| File | Purpose |
|------|---------|
| `flake.nix` | Main entry point — wires up packages, formatter, checks, and dev shell |
| `flake.lock` | Pins exact nixpkgs version so all developers use **identical** inputs |
| `nix/lib.nix` | Helper to iterate over supported systems with a Flutter overlay |
| `nix/shell.nix` | Development shell configuration |
| `nix/packages/default.nix` | Package index — all runnable check scripts |
| `nix/packages/dart-analyze.nix` | `dart analyze` in an isolated temp directory |
| `nix/packages/dart-code-linter.nix` | dart_code_linter: metrics, unused code, unused files, unnecessary nullable |
| `nix/packages/flutter-analyze.nix` | `flutter analyze` in an isolated temp directory |
| `nix/packages/dart-format-check.nix` | Formatting compliance check |
| `nix/packages/nix-test.nix` | Comprehensive test of all nix targets |
| `nix/packages/smoke-test.nix` | Full smoke test: unit tests, analysis, web build + HTTP check |
| `nix/shell-fragments/copy-to-work-dir.sh` | Shared setup: copy sources to temp dir, strip workspace resolution |
| `nix/shell-fragments/flutter-server.sh` | Shared shell functions for starting/stopping the Flutter web server |

Running `nix develop` spawns a shell with the correct Flutter SDK and Dart tools configured for you.

### Installing Nix

Choose **multi-user** (daemon) or **single-user**:

- **Multi-user install** (recommended on most distros):
  ```bash
  bash <(curl -L https://nixos.org/nix/install) --daemon
  ```

- **Single-user install**:
  ```bash
  bash <(curl -L https://nixos.org/nix/install) --no-daemon
  ```

See also: [Nix installation manual](https://nix.dev/manual/nix/2.24/installation/)

#### Video Tutorials

| Platform | Video |
|----------|-------|
| Ubuntu | [Installing Nix on Ubuntu](https://youtu.be/cb7BBZLhuUY) |
| Fedora | [Installing Nix on Fedora](https://youtu.be/RvaTxMa4IiY) |

#### Enable Flakes (if needed)

If you don't have the "flakes" feature enabled, you can run commands with:

```bash
nix --extra-experimental-features 'nix-command flakes' develop .
```

To permanently enable flakes, update `/etc/nix/nix.conf`:

```bash
test -d /etc/nix || sudo mkdir /etc/nix
echo 'experimental-features = nix-command flakes' | sudo tee -a /etc/nix/nix.conf
```

With flakes enabled, simply run `nix develop`.

See also: [Nix Flakes Wiki](https://nixos.wiki/wiki/flakes)

### First Run

On first execution, Nix will download and build all dependencies (including the Flutter SDK), which might take several minutes. On subsequent executions, Nix will reuse the cache in `/nix/store/` and will be essentially instantaneous.

> **Note:** Nix will not interact with any "system" packages you may already have installed. The Nix versions are isolated and will effectively "disappear" when you exit the development shell.

### Usage

```bash
cd examples/web_telemetry

# Enter the dev shell (pinned Flutter + Dart)
nix develop

# Run the automated smoke test
nix run .#smoke-test

# Run individual checks
nix run .#dart-analyze       # dart analyze
nix run .#dart-code-linter   # dart_code_linter (metrics, unused code, etc.)
nix run .#flutter-analyze    # flutter analyze
nix run .#dart-format-check  # verify dart format compliance

# Format Dart files in-place
nix fmt

# Verify all Nix expressions evaluate correctly
nix flake check
```

### What `nix flake check` Does

`nix flake check` is the standard Nix command for validating a flake. It verifies that all Nix expressions evaluate correctly, all check scripts build, and all outputs (packages, formatter, dev shell) resolve without errors. This runs quickly because it only *builds* the wrapper scripts — it does not execute them (since the analysis tools need network access for `flutter pub get`, which the Nix sandbox blocks).

### What `nix-test` Does

For developers working on the Nix infrastructure itself, `nix run .#nix-test` goes further: it actually *runs* every nix target end-to-end. This is 11 tests covering every nix target, both in-tree and isolated:

| # | Test | What it validates |
|---|------|-------------------|
| 1 | `nix flake show` | Flake evaluates without errors (catches missing args, import failures) |
| 2 | `nix develop` | Dev shell enters, Flutter SDK is available |
| 3 | `nix fmt` (dry-run) | Formatter works, all files already formatted |
| 4 | `nix run .#dart-format-check` | Format check script works end-to-end |
| 5 | `nix run .#dart-analyze` | `dart analyze` in isolated temp dir — zero issues |
| 6 | `nix run .#flutter-analyze` | `flutter analyze` in isolated temp dir — zero issues |
| 7 | `nix run .#dart-code-linter` | All 4 DCL checks pass (analyze, unused code/files, unnecessary nullable) |
| 8 | `flutter pub get` (in-tree) | Workspace resolution works with the monorepo's pinned dependencies |
| 9 | `dart analyze` (in-tree) | Analysis passes against the monorepo workspace SDK |
| 10 | `flutter test` (isolated) | All 73 unit tests pass in a standalone temp dir |
| 11 | `nix run .#smoke-test` | Full smoke test: unit tests + analysis + web build + HTTP serve |

Tests 5-7 and 10-11 each run in an isolated temp directory with `resolution: workspace` stripped, verifying the project works both inside the Flutter monorepo and as a standalone package. This catches issues like dependency conflicts (e.g., `dart_code_linter`'s `analyzer` version vs the monorepo's pinned version) that only surface in one context or the other.

### What the Smoke Test Does

The smoke test (`nix run .#smoke-test`) is one of the 11 tests above, but can also be run standalone. It runs three phases:

1. **Unit tests** — `flutter test` on the telemetry service tests (73 tests)
2. **Static analysis** — `flutter analyze` for lint and type errors
3. **Web build + HTTP check** — builds the app in release mode, starts a web server on port 8086, and verifies that `index.html`, `main.dart.js`, and `flutter_bootstrap.js` all return HTTP 200

The test runs in a temporary directory, copies only the necessary source files, and cleans up after itself.

### Why Check Scripts Use Temp Directories (Not Nix Derivations)

If you're familiar with Nix, you might wonder why the check scripts (`dart-analyze`, `flutter-analyze`, `dart-code-linter`, `smoke-test`) use `writeShellApplication` with temp directories instead of proper `mkDerivation` builds that output to `$out`.

The reason is that these scripts need `flutter pub get` to resolve dependencies, and **`flutter pub get` requires network access**. Nix's build sandbox blocks network by default — this is a core Nix design principle that ensures builds are reproducible. To fetch dependencies inside a sandboxed build, you'd need a [fixed-output derivation](https://nix.dev/manual/nix/2.24/language/advanced-attributes#adv-attr-outputHash) (FOD) that pre-fetches pub dependencies by content hash (similar to how `buildGoModule` fetches Go modules or `buildNpmPackage` fetches npm packages), and then a second derivation that consumes those dependencies offline. That's significant infrastructure for an example project.

Using `writeShellApplication` + `nix run` sidesteps the sandbox entirely — the script runs as a normal process with full network access. This is the standard Nix pattern for CI check scripts that need to fetch dependencies at runtime.

Even with `nix run`, we still need a **temp directory** rather than running in-place for two reasons:

1. **Workspace resolution** — The `pubspec.yaml` declares `resolution: workspace` because this example lives inside the Flutter monorepo. The Nix-provided Flutter SDK is a standalone install, not the monorepo, so `flutter pub get` fails unless that line is stripped. We can't modify the source tree in place.
2. **Build artifacts** — `flutter pub get` creates `.dart_tool/`, `pubspec.lock`, `.packages`, and other artifacts. Running in a temp dir keeps the source checkout clean.

The shared setup logic lives in `nix/shell-fragments/copy-to-work-dir.sh`, which all check scripts source. The `smoke-test` also uses the shared `copyToWorkDir` fragment with `EXTRA_DIRS="web"` to include the web directory, and overrides the trap to handle Flutter web server cleanup. The `dart-format-check` script uses a simpler preamble because formatting only needs `lib/` and `test/` — no pubspec, analysis_options, or sed step.

---

## Key File Reference

Framework and engine source files referenced in this document:

| File | Purpose |
|------|---------|
| `packages/flutter/lib/src/foundation/timeline.dart` | `FlutterTimeline` — core timing API |
| `packages/flutter/lib/src/foundation/_timeline_web.dart` | Web `performance.now()` timestamp source |
| `packages/flutter/lib/src/widgets/debug.dart` | `debugProfileBuildsEnabled` and related build flags |
| `packages/flutter/lib/src/rendering/debug.dart` | `debugProfileLayoutsEnabled`, `debugProfilePaintsEnabled` |
| `packages/flutter/lib/src/scheduler/binding.dart` | `SchedulerBinding` — frame callbacks, `FrameTiming` delivery |
| `packages/flutter/lib/src/widgets/framework.dart` | `Widget`, `State`, `Element` — lifecycle methods |
| `packages/flutter/lib/src/widgets/binding.dart` | `WidgetsBindingObserver`, `drawFrame` |
| `packages/flutter/lib/src/widgets/navigator.dart` | `NavigatorObserver` — navigation event hooks |
| `packages/flutter/lib/src/widgets/routes.dart` | `RouteAware`, `RouteObserver` |
| `packages/flutter/lib/src/widgets/app_lifecycle_listener.dart` | `AppLifecycleListener` — platform lifecycle callbacks |
| `packages/flutter/lib/src/rendering/object.dart` | `RenderObject` — layout/paint timeline hooks |
| `packages/flutter/lib/src/services/platform_channel.dart` | Platform channel profiling |
| `packages/flutter/lib/src/foundation/memory_allocations.dart` | `FlutterMemoryAllocations` |
| `engine/src/flutter/lib/web_ui/lib/src/engine/profiler.dart` | Web profiler, `timeAction`, `engineBenchmarkValueCallback` |
| `engine/src/flutter/lib/ui/platform_dispatcher.dart` | `FrameTiming`, `FramePhase` — engine frame metrics |
| `engine/src/flutter/fml/trace_event.h` | C++ tracing macros |
| `packages/flutter_driver/lib/src/driver/timeline_summary.dart` | `TimelineSummary` — frame analysis for CI |
