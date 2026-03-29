// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// The type of a telemetry event.
enum TelemetryEventType {
  /// A frame timing event from `SchedulerBinding.addTimingsCallback`.
  frameTiming,

  /// A navigation push event.
  navigationPush,

  /// A navigation pop event.
  navigationPop,

  /// A navigation replace event.
  navigationReplace,

  /// A navigation remove event.
  navigationRemove,

  /// An app lifecycle state change.
  lifecycleChange,

  /// A custom span with a measured duration.
  customSpan,

  /// A custom instant (zero-duration) event.
  customInstant,
}

/// A single telemetry event with a timestamp, optional duration, and
/// arbitrary data payload.
@immutable
class TelemetryEvent {
  /// Creates a telemetry event.
  const TelemetryEvent({
    required this.type,
    required this.name,
    required this.timestampMicros,
    this.durationMicros,
    this.data,
  });

  /// The category of this event.
  final TelemetryEventType type;

  /// A human-readable name describing the event.
  final String name;

  /// The timestamp in microseconds when this event occurred, obtained
  /// from [FlutterTimeline.now].
  final int timestampMicros;

  /// The duration in microseconds. Null for instant events.
  final int? durationMicros;

  /// Arbitrary data associated with this event.
  final Map<String, Object>? data;

  /// Converts this event to a JSON-compatible map.
  Map<String, Object?> toJson() => <String, Object?>{
    'type': type.name,
    'name': name,
    'timestampMicros': timestampMicros,
    if (durationMicros != null) 'durationMicros': durationMicros,
    if (data != null) 'data': data,
  };

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is TelemetryEvent &&
          type == other.type &&
          name == other.name &&
          timestampMicros == other.timestampMicros &&
          durationMicros == other.durationMicros &&
          mapEquals(data, other.data);

  @override
  int get hashCode => Object.hash(type, name, timestampMicros, durationMicros, data);

  @override
  String toString() {
    final dur = durationMicros != null ? ', $durationMicrosµs' : '';

    return 'TelemetryEvent(${type.name}, $name, $timestampMicros$dur)';
  }
}

/// A stopwatch-based span for measuring the duration of an operation.
///
/// Call [finish] to record the span as a [TelemetryEvent] in the
/// telemetry service.
class TelemetrySpan {
  /// Creates and starts a span with the given [name].
  TelemetrySpan({
    required this.name,
    required this.startTimeMicros,
    required final void Function(TelemetrySpan) onFinish,
  }) : _onFinish = onFinish {
    _stopwatch.start();
  }

  /// The name of this span.
  final String name;

  /// The timestamp in microseconds when this span started.
  final int startTimeMicros;

  final void Function(TelemetrySpan) _onFinish;
  final _stopwatch = Stopwatch();
  var _finished = false;

  /// Whether this span has been finished.
  bool get isFinished => _finished;

  /// The elapsed duration in microseconds. Only valid after [finish].
  int get elapsedMicros => _stopwatch.elapsedMicroseconds;

  /// Finishes this span and records it as a telemetry event.
  ///
  /// Calling this more than once has no effect.
  void finish() {
    if (_finished) {
      return;
    }
    _finished = true;
    _stopwatch.stop();
    _onFinish(this);
  }
}

/// Running statistics about frame timings.
@immutable
class FrameStats {
  /// Creates frame statistics.
  const FrameStats({
    required this.frameCount,
    required this.jankCount,
    required this.totalBuildMicros,
    required this.totalRasterMicros,
  });

  /// An empty set of frame statistics.
  static const empty = FrameStats(
    frameCount: 0,
    jankCount: 0,
    totalBuildMicros: 0,
    totalRasterMicros: 0,
  );

  /// Total number of frames observed.
  final int frameCount;

  /// Number of frames that exceeded the 16ms budget (jank).
  final int jankCount;

  /// Total build duration across all frames in microseconds.
  final int totalBuildMicros;

  /// Total raster duration across all frames in microseconds.
  final int totalRasterMicros;

  /// Average build duration per frame in microseconds, or 0 if no
  /// frames observed.
  double get avgBuildMicros => frameCount > 0 ? totalBuildMicros / frameCount : 0;

  /// Average raster duration per frame in microseconds, or 0 if no
  /// frames observed.
  double get avgRasterMicros => frameCount > 0 ? totalRasterMicros / frameCount : 0;

  /// Converts to a JSON-compatible map.
  Map<String, Object> toJson() => <String, Object>{
    'frameCount': frameCount,
    'jankCount': jankCount,
    'totalBuildMicros': totalBuildMicros,
    'totalRasterMicros': totalRasterMicros,
    'avgBuildMicros': avgBuildMicros,
    'avgRasterMicros': avgRasterMicros,
  };

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is FrameStats &&
          frameCount == other.frameCount &&
          jankCount == other.jankCount &&
          totalBuildMicros == other.totalBuildMicros &&
          totalRasterMicros == other.totalRasterMicros;

  @override
  int get hashCode => Object.hash(frameCount, jankCount, totalBuildMicros, totalRasterMicros);

  @override
  String toString() =>
      'FrameStats(frames: $frameCount, jank: $jankCount, '
      'avgBuild: ${avgBuildMicros.toStringAsFixed(0)}µs, '
      'avgRaster: ${avgRasterMicros.toStringAsFixed(0)}µs)';
}

/// A snapshot of the current telemetry buffer and frame statistics.
@immutable
class TelemetrySnapshot {
  /// Creates a telemetry snapshot.
  const TelemetrySnapshot({required this.events, required this.frameStats});

  /// The buffered events at the time of the snapshot.
  final List<TelemetryEvent> events;

  /// Running frame statistics at the time of the snapshot.
  final FrameStats frameStats;

  /// Converts the entire snapshot to a JSON string.
  String toJson() => json.encode(<String, Object>{
    'events': events.map((final event) => event.toJson()).toList(),
    'frameStats': frameStats.toJson(),
  });

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is TelemetrySnapshot &&
          listEquals(events, other.events) &&
          frameStats == other.frameStats;

  @override
  int get hashCode => Object.hash(events, frameStats);
}
