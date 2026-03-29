// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'telemetry_event.dart';
import 'telemetry_nav_observer.dart';
import 'web_perf_stub.dart' if (dart.library.js_interop) 'web_perf.dart' as perf;

/// Threshold in microseconds above which a frame is considered janky
/// (16,667µs ≈ 60 FPS budget).
const _jankThresholdMicros = 16667;

/// A service that collects frame timings, navigation events, lifecycle
/// changes, and custom spans into a ring buffer, with optional browser
/// `performance.mark()`/`performance.measure()` integration.
///
/// Usage:
/// ```dart
/// WidgetsFlutterBinding.ensureInitialized();
/// TelemetryService.instance.init();
/// runApp(MyApp());
/// ```
class TelemetryService {
  TelemetryService._();

  /// The singleton instance.
  static final instance = TelemetryService._();

  var _bufferSize = 2000;
  final _buffer = ListQueue<TelemetryEvent>();

  var _frameCount = 0;
  var _jankCount = 0;
  var _totalBuildMicros = 0;
  var _totalRasterMicros = 0;

  late TelemetryNavObserver _navObserver;
  AppLifecycleListener? _lifecycleListener;
  var _streamController = StreamController<TelemetryEvent>.broadcast();
  var _initialized = false;

  /// The navigator observer to pass to `MaterialApp.navigatorObservers`
  /// or `GoRouter.observers`.
  TelemetryNavObserver get navigatorObserver {
    if (!_initialized) {
      throw StateError('TelemetryService.init() must be called before accessing navigatorObserver');
    }

    return _navObserver;
  }

  /// A broadcast stream of telemetry events as they are recorded.
  Stream<TelemetryEvent> get eventStream => _streamController.stream;

  /// Initializes the telemetry service.
  ///
  /// If already initialized, returns without effect. Call [dispose] first
  /// to reinitialize.
  ///
  /// Hooks frame timings via [SchedulerBinding.addTimingsCallback],
  /// installs an [AppLifecycleListener], and creates the
  /// [TelemetryNavObserver].
  ///
  /// [bufferSize] controls the maximum number of events retained in the
  /// ring buffer. Older events are discarded when the buffer is full.
  void init({final int bufferSize = 2000}) {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _bufferSize = bufferSize;
    _navObserver = TelemetryNavObserver(this);

    // Hook frame timings.
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);

    // Hook app lifecycle.
    _lifecycleListener = AppLifecycleListener(onStateChange: _onLifecycleChange);

    developer.log('TelemetryService initialized (buffer: $bufferSize)', name: 'telemetry');
  }

  void _onFrameTimings(final List<FrameTiming> timings) {
    timings.forEach(_recordFrameTiming);
  }

  void _recordFrameTiming(final FrameTiming timing) {
    final int buildMicros = timing.buildDuration.inMicroseconds;
    final int rasterMicros = timing.rasterDuration.inMicroseconds;
    final int totalMicros = timing.totalSpan.inMicroseconds;
    final bool isJank = totalMicros > _jankThresholdMicros;

    _frameCount += 1;
    _totalBuildMicros += buildMicros;
    _totalRasterMicros += rasterMicros;
    if (isJank) {
      _jankCount += 1;
    }

    perf.performanceMark('frame_$_frameCount');

    recordEvent(
      TelemetryEvent(
        type: TelemetryEventType.frameTiming,
        name: 'frame',
        timestampMicros: FlutterTimeline.now,
        durationMicros: totalMicros,
        data: <String, Object>{
          'buildMicros': buildMicros,
          'rasterMicros': rasterMicros,
          'vsyncOverheadMicros': timing.vsyncOverhead.inMicroseconds,
          'frameNumber': _frameCount,
          'jank': isJank,
        },
      ),
    );
  }

  void _onLifecycleChange(final AppLifecycleState state) {
    recordEvent(
      TelemetryEvent(
        type: TelemetryEventType.lifecycleChange,
        name: 'lifecycle:${state.name}',
        timestampMicros: FlutterTimeline.now,
        data: <String, Object>{'state': state.name},
      ),
    );
  }

  /// Records an event in the ring buffer and broadcasts it on
  /// [eventStream].
  void recordEvent(final TelemetryEvent event) {
    if (_buffer.length >= _bufferSize) {
      _buffer.removeFirst();
    }
    _buffer.add(event);
    _streamController.add(event);
  }

  /// Starts a custom span with the given [name].
  ///
  /// Returns a [TelemetrySpan] — call [TelemetrySpan.finish] when the
  /// operation is complete.
  TelemetrySpan startSpan(final String name) {
    final int startTime = FlutterTimeline.now;
    perf.performanceMark('$name:start');

    return TelemetrySpan(name: name, startTimeMicros: startTime, onFinish: _onSpanFinish);
  }

  void _onSpanFinish(final TelemetrySpan span) {
    perf.performanceMark('${span.name}:end');
    perf.performanceMeasure(span.name, '${span.name}:start', '${span.name}:end');
    recordEvent(
      TelemetryEvent(
        type: TelemetryEventType.customSpan,
        name: span.name,
        timestampMicros: span.startTimeMicros,
        durationMicros: span.elapsedMicros,
      ),
    );
  }

  /// Records an instant (zero-duration) event with the given [name].
  void mark(final String name) {
    perf.performanceMark(name);
    recordEvent(
      TelemetryEvent(
        type: TelemetryEventType.customInstant,
        name: name,
        timestampMicros: FlutterTimeline.now,
      ),
    );
  }

  /// Returns a snapshot of the current event buffer and frame
  /// statistics.
  TelemetrySnapshot get snapshot => TelemetrySnapshot(
    events: List<TelemetryEvent>.unmodifiable(_buffer.toList()),
    frameStats: FrameStats(
      frameCount: _frameCount,
      jankCount: _jankCount,
      totalBuildMicros: _totalBuildMicros,
      totalRasterMicros: _totalRasterMicros,
    ),
  );

  /// Returns the buffered events and frame statistics as a JSON
  /// string.
  String toJson() => snapshot.toJson();

  /// Logs a human-readable summary to the developer console.
  void dumpToConsole() {
    final TelemetrySnapshot telemetrySnapshot = snapshot;
    final buffer = StringBuffer()
      ..writeln('=== Telemetry Snapshot ===')
      ..writeln(telemetrySnapshot.frameStats)
      ..writeln('Events (${telemetrySnapshot.events.length}):');
    for (final TelemetryEvent event in telemetrySnapshot.events) {
      buffer.writeln('  $event');
    }
    developer.log(buffer.toString(), name: 'telemetry');
  }

  /// Removes all callbacks and releases resources.
  ///
  /// After calling dispose, [init] may be called again to restart
  /// the service.
  void dispose() {
    if (!_initialized) {
      return;
    }
    _initialized = false;
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    unawaited(_streamController.close());
    // Create a fresh controller so init() can be called again.
    _streamController = StreamController<TelemetryEvent>.broadcast();
    _buffer.clear();
    _frameCount = 0;
    _jankCount = 0;
    _totalBuildMicros = 0;
    _totalRasterMicros = 0;
  }
}
