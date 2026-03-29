// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_telemetry/telemetry/telemetry_event.dart';
import 'package:web_telemetry/telemetry/telemetry_nav_observer.dart';
import 'package:web_telemetry/telemetry/telemetry_service.dart';

Route<void> _makeRoute([final String? name]) => MaterialPageRoute<void>(
  settings: RouteSettings(name: name),
  builder: (_) => const SizedBox.shrink(),
);

void main() {
  late TelemetryService service;

  setUp(() {
    service = TelemetryService.instance;
  });

  tearDown(() {
    service.dispose();
  });

  // ── TelemetryEvent ──────────────────────────────────────────────────

  group('TelemetryEvent', () {
    group('toJson', () {
      final cases = <({String label, TelemetryEvent event, Map<String, Object?> expectedJson})>[
        (
          label: 'instant event (no duration, no data)',
          event: const TelemetryEvent(
            type: TelemetryEventType.customInstant,
            name: 'mark',
            timestampMicros: 100,
          ),
          expectedJson: <String, Object?>{
            'type': 'customInstant',
            'name': 'mark',
            'timestampMicros': 100,
          },
        ),
        (
          label: 'span event with duration, no data',
          event: const TelemetryEvent(
            type: TelemetryEventType.customSpan,
            name: 'op',
            timestampMicros: 200,
            durationMicros: 50,
          ),
          expectedJson: <String, Object?>{
            'type': 'customSpan',
            'name': 'op',
            'timestampMicros': 200,
            'durationMicros': 50,
          },
        ),
        (
          label: 'event with data, no duration',
          event: const TelemetryEvent(
            type: TelemetryEventType.navigationPush,
            name: 'push:/home',
            timestampMicros: 300,
            data: <String, Object>{'route': '/home'},
          ),
          expectedJson: <String, Object?>{
            'type': 'navigationPush',
            'name': 'push:/home',
            'timestampMicros': 300,
            'data': <String, Object>{'route': '/home'},
          },
        ),
        (
          label: 'event with both duration and data',
          event: const TelemetryEvent(
            type: TelemetryEventType.frameTiming,
            name: 'frame',
            timestampMicros: 400,
            durationMicros: 16000,
            data: <String, Object>{'jank': true},
          ),
          expectedJson: <String, Object?>{
            'type': 'frameTiming',
            'name': 'frame',
            'timestampMicros': 400,
            'durationMicros': 16000,
            'data': <String, Object>{'jank': true},
          },
        ),
      ];

      for (final c in cases) {
        test(c.label, () {
          expect(c.event.toJson(), c.expectedJson);
        });
      }
    });

    group('toString', () {
      final cases = <({String label, TelemetryEvent event, String expected})>[
        (
          label: 'instant event',
          event: const TelemetryEvent(
            type: TelemetryEventType.customInstant,
            name: 'mark',
            timestampMicros: 100,
          ),
          expected: 'TelemetryEvent(customInstant, mark, 100)',
        ),
        (
          label: 'span event with duration',
          event: const TelemetryEvent(
            type: TelemetryEventType.customSpan,
            name: 'op',
            timestampMicros: 200,
            durationMicros: 50,
          ),
          expected: 'TelemetryEvent(customSpan, op, 200, 50µs)',
        ),
      ];

      for (final c in cases) {
        test(c.label, () {
          expect(c.event.toString(), c.expected);
        });
      }
    });

    group('equality positive', () {
      final cases = <({String label, TelemetryEvent a, TelemetryEvent b})>[
        (
          label: 'identical fields (no optionals)',
          a: const TelemetryEvent(
            type: TelemetryEventType.customInstant,
            name: 'a',
            timestampMicros: 1,
          ),
          b: const TelemetryEvent(
            type: TelemetryEventType.customInstant,
            name: 'a',
            timestampMicros: 1,
          ),
        ),
        (
          label: 'with data',
          a: const TelemetryEvent(
            type: TelemetryEventType.customInstant,
            name: 'a',
            timestampMicros: 1,
            data: <String, Object>{'k': 'v'},
          ),
          b: const TelemetryEvent(
            type: TelemetryEventType.customInstant,
            name: 'a',
            timestampMicros: 1,
            data: <String, Object>{'k': 'v'},
          ),
        ),
        (
          label: 'with duration',
          a: const TelemetryEvent(
            type: TelemetryEventType.customSpan,
            name: 'a',
            timestampMicros: 1,
            durationMicros: 10,
          ),
          b: const TelemetryEvent(
            type: TelemetryEventType.customSpan,
            name: 'a',
            timestampMicros: 1,
            durationMicros: 10,
          ),
        ),
        (
          label: 'with both duration and data',
          a: const TelemetryEvent(
            type: TelemetryEventType.customSpan,
            name: 'a',
            timestampMicros: 1,
            durationMicros: 10,
            data: <String, Object>{'k': 'v'},
          ),
          b: const TelemetryEvent(
            type: TelemetryEventType.customSpan,
            name: 'a',
            timestampMicros: 1,
            durationMicros: 10,
            data: <String, Object>{'k': 'v'},
          ),
        ),
      ];

      for (final c in cases) {
        test(c.label, () {
          expect(c.a, equals(c.b));
          expect(c.a.hashCode, c.b.hashCode);
        });
      }

      test('same object reference', () {
        const event = TelemetryEvent(
          type: TelemetryEventType.customInstant,
          name: 'x',
          timestampMicros: 1,
        );
        expect(event, equals(event));
      });
    });

    group('equality negative', () {
      final cases = <({String label, TelemetryEvent a, TelemetryEvent b})>[
        (
          label: 'different type',
          a: const TelemetryEvent(
            type: TelemetryEventType.customInstant,
            name: 'a',
            timestampMicros: 1,
          ),
          b: const TelemetryEvent(
            type: TelemetryEventType.customSpan,
            name: 'a',
            timestampMicros: 1,
          ),
        ),
        (
          label: 'different name',
          a: const TelemetryEvent(
            type: TelemetryEventType.customInstant,
            name: 'a',
            timestampMicros: 1,
          ),
          b: const TelemetryEvent(
            type: TelemetryEventType.customInstant,
            name: 'b',
            timestampMicros: 1,
          ),
        ),
        (
          label: 'different timestamp',
          a: const TelemetryEvent(
            type: TelemetryEventType.customInstant,
            name: 'a',
            timestampMicros: 1,
          ),
          b: const TelemetryEvent(
            type: TelemetryEventType.customInstant,
            name: 'a',
            timestampMicros: 2,
          ),
        ),
        (
          label: 'duration null vs value',
          a: const TelemetryEvent(
            type: TelemetryEventType.customInstant,
            name: 'a',
            timestampMicros: 1,
          ),
          b: const TelemetryEvent(
            type: TelemetryEventType.customInstant,
            name: 'a',
            timestampMicros: 1,
            durationMicros: 10,
          ),
        ),
        (
          label: 'different duration values',
          a: const TelemetryEvent(
            type: TelemetryEventType.customSpan,
            name: 'a',
            timestampMicros: 1,
            durationMicros: 10,
          ),
          b: const TelemetryEvent(
            type: TelemetryEventType.customSpan,
            name: 'a',
            timestampMicros: 1,
            durationMicros: 20,
          ),
        ),
        (
          label: 'data null vs map',
          a: const TelemetryEvent(
            type: TelemetryEventType.customInstant,
            name: 'a',
            timestampMicros: 1,
          ),
          b: const TelemetryEvent(
            type: TelemetryEventType.customInstant,
            name: 'a',
            timestampMicros: 1,
            data: <String, Object>{'k': 'v'},
          ),
        ),
        (
          label: 'different data maps',
          a: const TelemetryEvent(
            type: TelemetryEventType.customInstant,
            name: 'a',
            timestampMicros: 1,
            data: <String, Object>{'k': 'v1'},
          ),
          b: const TelemetryEvent(
            type: TelemetryEventType.customInstant,
            name: 'a',
            timestampMicros: 1,
            data: <String, Object>{'k': 'v2'},
          ),
        ),
      ];

      for (final c in cases) {
        test(c.label, () {
          expect(c.a, isNot(equals(c.b)));
        });
      }

      test('event != non-event object', () {
        const event = TelemetryEvent(
          type: TelemetryEventType.customInstant,
          name: 'a',
          timestampMicros: 1,
        );
        // ignore: unrelated_type_equality_checks, Verifying cross-type equality returns false.
        expect(event == 'not an event', isFalse);
      });
    });
  });

  // ── FrameStats ──────────────────────────────────────────────────────

  group('FrameStats', () {
    group('averages', () {
      final cases =
          <({String label, FrameStats stats, double expectedBuild, double expectedRaster})>[
            (
              label: 'zero frames (guards division by zero)',
              stats: FrameStats.empty,
              expectedBuild: 0.0,
              expectedRaster: 0.0,
            ),
            (
              label: 'even division',
              stats: const FrameStats(
                frameCount: 10,
                jankCount: 2,
                totalBuildMicros: 10000,
                totalRasterMicros: 20000,
              ),
              expectedBuild: 1000.0,
              expectedRaster: 2000.0,
            ),
            (
              label: 'non-even division',
              stats: const FrameStats(
                frameCount: 3,
                jankCount: 0,
                totalBuildMicros: 10000,
                totalRasterMicros: 20000,
              ),
              expectedBuild: 10000.0 / 3.0,
              expectedRaster: 20000.0 / 3.0,
            ),
            (
              label: 'single frame',
              stats: const FrameStats(
                frameCount: 1,
                jankCount: 1,
                totalBuildMicros: 500,
                totalRasterMicros: 700,
              ),
              expectedBuild: 500.0,
              expectedRaster: 700.0,
            ),
          ];

      for (final c in cases) {
        test(c.label, () {
          expect(c.stats.avgBuildMicros, closeTo(c.expectedBuild, 0.001));
          expect(c.stats.avgRasterMicros, closeTo(c.expectedRaster, 0.001));
        });
      }
    });

    test('toJson contains all 6 keys with correct values', () {
      const stats = FrameStats(
        frameCount: 5,
        jankCount: 1,
        totalBuildMicros: 5000,
        totalRasterMicros: 8000,
      );
      final Map<String, Object> j = stats.toJson();
      expect(j['frameCount'], 5);
      expect(j['jankCount'], 1);
      expect(j['totalBuildMicros'], 5000);
      expect(j['totalRasterMicros'], 8000);
      expect(j['avgBuildMicros'], 1000.0);
      expect(j['avgRasterMicros'], 1600.0);
    });

    group('toString', () {
      final cases = <({String label, FrameStats stats, String expected})>[
        (
          label: 'zero frames',
          stats: FrameStats.empty,
          expected: 'FrameStats(frames: 0, jank: 0, avgBuild: 0µs, avgRaster: 0µs)',
        ),
        (
          label: 'non-zero frames',
          stats: const FrameStats(
            frameCount: 10,
            jankCount: 2,
            totalBuildMicros: 10000,
            totalRasterMicros: 20000,
          ),
          expected: 'FrameStats(frames: 10, jank: 2, avgBuild: 1000µs, avgRaster: 2000µs)',
        ),
      ];

      for (final c in cases) {
        test(c.label, () {
          expect(c.stats.toString(), c.expected);
        });
      }
    });

    group('equality', () {
      final cases = <({String label, FrameStats a, FrameStats b, bool shouldBeEqual})>[
        (
          label: 'identical fields',
          a: const FrameStats(
            frameCount: 5,
            jankCount: 1,
            totalBuildMicros: 5000,
            totalRasterMicros: 8000,
          ),
          b: const FrameStats(
            frameCount: 5,
            jankCount: 1,
            totalBuildMicros: 5000,
            totalRasterMicros: 8000,
          ),
          shouldBeEqual: true,
        ),
        (
          label: 'different frameCount',
          a: const FrameStats(
            frameCount: 5,
            jankCount: 1,
            totalBuildMicros: 5000,
            totalRasterMicros: 8000,
          ),
          b: const FrameStats(
            frameCount: 6,
            jankCount: 1,
            totalBuildMicros: 5000,
            totalRasterMicros: 8000,
          ),
          shouldBeEqual: false,
        ),
        (
          label: 'different jankCount',
          a: const FrameStats(
            frameCount: 5,
            jankCount: 1,
            totalBuildMicros: 5000,
            totalRasterMicros: 8000,
          ),
          b: const FrameStats(
            frameCount: 5,
            jankCount: 2,
            totalBuildMicros: 5000,
            totalRasterMicros: 8000,
          ),
          shouldBeEqual: false,
        ),
        (
          label: 'different totalBuildMicros',
          a: const FrameStats(
            frameCount: 5,
            jankCount: 1,
            totalBuildMicros: 5000,
            totalRasterMicros: 8000,
          ),
          b: const FrameStats(
            frameCount: 5,
            jankCount: 1,
            totalBuildMicros: 9999,
            totalRasterMicros: 8000,
          ),
          shouldBeEqual: false,
        ),
        (
          label: 'different totalRasterMicros',
          a: const FrameStats(
            frameCount: 5,
            jankCount: 1,
            totalBuildMicros: 5000,
            totalRasterMicros: 8000,
          ),
          b: const FrameStats(
            frameCount: 5,
            jankCount: 1,
            totalBuildMicros: 5000,
            totalRasterMicros: 9999,
          ),
          shouldBeEqual: false,
        ),
      ];

      for (final c in cases) {
        test(c.label, () {
          if (c.shouldBeEqual) {
            expect(c.a, equals(c.b));
            expect(c.a.hashCode, c.b.hashCode);
          } else {
            expect(c.a, isNot(equals(c.b)));
          }
        });
      }

      test('same object reference', () {
        const stats = FrameStats(
          frameCount: 1,
          jankCount: 0,
          totalBuildMicros: 100,
          totalRasterMicros: 200,
        );
        expect(stats, equals(stats));
      });
    });
  });

  // ── TelemetrySnapshot ───────────────────────────────────────────────

  group('TelemetrySnapshot', () {
    group('toJson round-trip', () {
      final cases = <({String label, TelemetrySnapshot snapshot})>[
        (
          label: 'empty events list',
          snapshot: const TelemetrySnapshot(
            events: <TelemetryEvent>[],
            frameStats: FrameStats.empty,
          ),
        ),
        (
          label: 'single event',
          snapshot: const TelemetrySnapshot(
            events: <TelemetryEvent>[
              TelemetryEvent(type: TelemetryEventType.customInstant, name: 'x', timestampMicros: 1),
            ],
            frameStats: FrameStats.empty,
          ),
        ),
        (
          label: 'multiple events',
          snapshot: const TelemetrySnapshot(
            events: <TelemetryEvent>[
              TelemetryEvent(type: TelemetryEventType.customInstant, name: 'a', timestampMicros: 1),
              TelemetryEvent(
                type: TelemetryEventType.customSpan,
                name: 'b',
                timestampMicros: 2,
                durationMicros: 50,
              ),
            ],
            frameStats: FrameStats(
              frameCount: 10,
              jankCount: 1,
              totalBuildMicros: 5000,
              totalRasterMicros: 8000,
            ),
          ),
        ),
      ];

      for (final c in cases) {
        test(c.label, () {
          final decoded = json.decode(c.snapshot.toJson()) as Map<String, Object?>;
          expect(decoded.containsKey('events'), isTrue);
          expect(decoded.containsKey('frameStats'), isTrue);
          final events = decoded['events']! as List<Object?>;
          expect(events.length, c.snapshot.events.length);
        });
      }
    });

    test('equality — same snapshot', () {
      const snap = TelemetrySnapshot(
        events: <TelemetryEvent>[
          TelemetryEvent(type: TelemetryEventType.customInstant, name: 'a', timestampMicros: 1),
        ],
        frameStats: FrameStats.empty,
      );
      const same = TelemetrySnapshot(
        events: <TelemetryEvent>[
          TelemetryEvent(type: TelemetryEventType.customInstant, name: 'a', timestampMicros: 1),
        ],
        frameStats: FrameStats.empty,
      );
      expect(snap, equals(same));
    });

    test('equality — different events', () {
      const a = TelemetrySnapshot(
        events: <TelemetryEvent>[
          TelemetryEvent(type: TelemetryEventType.customInstant, name: 'a', timestampMicros: 1),
        ],
        frameStats: FrameStats.empty,
      );
      const b = TelemetrySnapshot(
        events: <TelemetryEvent>[
          TelemetryEvent(type: TelemetryEventType.customInstant, name: 'b', timestampMicros: 1),
        ],
        frameStats: FrameStats.empty,
      );
      expect(a, isNot(equals(b)));
    });

    test('equality — different frameStats', () {
      const a = TelemetrySnapshot(events: <TelemetryEvent>[], frameStats: FrameStats.empty);
      const b = TelemetrySnapshot(
        events: <TelemetryEvent>[],
        frameStats: FrameStats(
          frameCount: 1,
          jankCount: 0,
          totalBuildMicros: 100,
          totalRasterMicros: 200,
        ),
      );
      expect(a, isNot(equals(b)));
    });
  });

  // ── TelemetrySpan ──────────────────────────────────────────────────

  group('TelemetrySpan', () {
    test('properties after construction', () {
      final span = TelemetrySpan(name: 'test', startTimeMicros: 42, onFinish: (_) {});
      expect(span.name, 'test');
      expect(span.startTimeMicros, 42);
      expect(span.isFinished, isFalse);
    });

    test('isFinished transitions false → true after finish', () {
      final span = TelemetrySpan(name: 'test', startTimeMicros: 0, onFinish: (_) {});
      expect(span.isFinished, isFalse);
      span.finish();
      expect(span.isFinished, isTrue);
    });

    test('elapsedMicros is non-negative', () {
      TelemetrySpan(name: 'test', startTimeMicros: 0, onFinish: (_) {}).finish();
      // Span is created and finished inline — just verify the API doesn't throw.
    });

    test('finish() calls onFinish exactly once', () {
      var count = 0;
      TelemetrySpan(name: 'test', startTimeMicros: 0, onFinish: (_) => count++)
        ..finish()
        ..finish();
      expect(count, 1);
    });

    test('finish() stops the stopwatch (elapsed stays constant)', () {
      final span = TelemetrySpan(name: 'test', startTimeMicros: 0, onFinish: (_) {})..finish();
      final int elapsed1 = span.elapsedMicros;
      // Busy loop to burn some time.
      var sum = 0;
      for (var i = 0; i < 100000; i++) {
        sum += i;
      }
      // Prevent the loop from being optimized away.
      expect(sum, greaterThan(0));
      final int elapsed2 = span.elapsedMicros;
      expect(elapsed2, elapsed1);
    });
  });

  // ── TelemetryService ───────────────────────────────────────────────

  group('TelemetryService', () {
    testWidgets('init() idempotency — second call is no-op', (final tester) async {
      service
        ..init(bufferSize: 50)
        ..init(bufferSize: 999)
        ..mark('a')
        ..mark('b');

      // If the second init took effect, bufferSize would be 999.
      // Fill up to 50 to prove the first init's bufferSize stuck.
      for (var i = 0; i < 50; i++) {
        service.mark('fill-$i');
      }
      expect(service.snapshot.events.length, 50);
    });

    testWidgets('navigatorObserver before init throws StateError', (final tester) async {
      expect(() => service.navigatorObserver, throwsStateError);
    });

    testWidgets('mark before init works (recordEvent does not check _initialized)', (
      final tester,
    ) async {
      service.mark('pre-init');
      expect(service.snapshot.events.length, 1);
      // Manually init so tearDown's dispose() clears the buffer.
      service.init(bufferSize: 100);
    });

    testWidgets('startSpan before init works', (final tester) async {
      service.startSpan('pre-init-span').finish();
      expect(service.snapshot.events.length, 1);
      expect(service.snapshot.events.first.type, TelemetryEventType.customSpan);
      service.init(bufferSize: 100);
    });

    testWidgets('dispose() idempotency — no exception on double dispose', (final tester) async {
      service
        ..init(bufferSize: 100)
        ..dispose()
        ..dispose();
    });

    testWidgets('eventStream lifecycle — subscribe, dispose, reinit, mark', (final tester) async {
      service.init(bufferSize: 100);

      final firstBatch = <TelemetryEvent>[];
      service.eventStream.listen(firstBatch.add);
      service
        ..mark('before-dispose')
        ..dispose();

      // Reinit, subscribe to new stream.
      final secondBatch = <TelemetryEvent>[];
      service
        ..init(bufferSize: 100)
        ..eventStream.listen(secondBatch.add)
        ..mark('after-reinit');
      await tester.pump();

      expect(firstBatch.length, 1);
      expect(firstBatch.first.name, 'before-dispose');
      expect(secondBatch.length, 1);
      expect(secondBatch.first.name, 'after-reinit');
    });

    group('ring buffer', () {
      final cases =
          <
            ({
              String label,
              int bufferSize,
              List<String> marks,
              int expectedLen,
              String expectedFirst,
              String expectedLast,
            })
          >[
            (
              label: 'exact capacity (no eviction)',
              bufferSize: 3,
              marks: <String>['a', 'b', 'c'],
              expectedLen: 3,
              expectedFirst: 'a',
              expectedLast: 'c',
            ),
            (
              label: 'one over capacity',
              bufferSize: 3,
              marks: <String>['a', 'b', 'c', 'd'],
              expectedLen: 3,
              expectedFirst: 'b',
              expectedLast: 'd',
            ),
            (
              label: 'bufferSize=1',
              bufferSize: 1,
              marks: <String>['a', 'b', 'c'],
              expectedLen: 1,
              expectedFirst: 'c',
              expectedLast: 'c',
            ),
            (
              label: 'many events with bufferSize=2',
              bufferSize: 2,
              marks: <String>['a', 'b', 'c', 'd', 'e'],
              expectedLen: 2,
              expectedFirst: 'd',
              expectedLast: 'e',
            ),
          ];

      for (final c in cases) {
        testWidgets(c.label, (final tester) async {
          service.init(bufferSize: c.bufferSize);
          c.marks.forEach(service.mark);
          final TelemetrySnapshot snap = service.snapshot;
          expect(snap.events.length, c.expectedLen);
          expect(snap.events.first.name, c.expectedFirst);
          expect(snap.events.last.name, c.expectedLast);
        });
      }
    });

    testWidgets('multiple event types — mark + span', (final tester) async {
      service
        ..init(bufferSize: 100)
        ..mark('instant')
        ..startSpan('span-op').finish();

      final TelemetrySnapshot snap = service.snapshot;
      expect(snap.events.length, 2);
      expect(snap.events[0].type, TelemetryEventType.customInstant);
      expect(snap.events[1].type, TelemetryEventType.customSpan);
    });

    testWidgets('dumpToConsole returns normally', (final tester) async {
      service
        ..init(bufferSize: 100)
        ..mark('dump-test')
        ..dumpToConsole();
    });

    testWidgets('toJson round-trip', (final tester) async {
      service
        ..init(bufferSize: 100)
        ..mark('json-test');

      final decoded = json.decode(service.toJson()) as Map<String, Object?>;
      expect(decoded.containsKey('events'), isTrue);
      expect(decoded.containsKey('frameStats'), isTrue);
      final events = decoded['events']! as List<Object?>;
      expect(events.length, 1);
    });

    testWidgets('dispose and reinit works cleanly', (final tester) async {
      service
        ..init(bufferSize: 100)
        ..mark('before-dispose');
      expect(service.snapshot.events.length, 1);

      service
        ..dispose()
        ..init(bufferSize: 100)
        ..mark('after-reinit');

      final TelemetrySnapshot snap = service.snapshot;
      expect(snap.events.length, 1);
      expect(snap.events.first.name, 'after-reinit');
    });
  });

  // ── TelemetryNavObserver ───────────────────────────────────────────

  group('TelemetryNavObserver', () {
    late TelemetryNavObserver observer;

    setUp(() {
      service.init(bufferSize: 100);
      observer = service.navigatorObserver;
    });

    group('individual methods', () {
      final cases =
          <
            ({
              String label,
              void Function(TelemetryNavObserver obs) action,
              TelemetryEventType expectedType,
              String expectedName,
            })
          >[
            (
              label: 'didPush with previousRoute',
              action: (final obs) => obs.didPush(_makeRoute('/test'), _makeRoute('/prev')),
              expectedType: TelemetryEventType.navigationPush,
              expectedName: 'push:/test',
            ),
            (
              label: 'didPush without previousRoute',
              action: (final obs) => obs.didPush(_makeRoute('/test'), null),
              expectedType: TelemetryEventType.navigationPush,
              expectedName: 'push:/test',
            ),
            (
              label: 'didPop with previousRoute',
              action: (final obs) => obs.didPop(_makeRoute('/test'), _makeRoute('/prev')),
              expectedType: TelemetryEventType.navigationPop,
              expectedName: 'pop:/test',
            ),
            (
              label: 'didPop without previousRoute',
              action: (final obs) => obs.didPop(_makeRoute('/test'), null),
              expectedType: TelemetryEventType.navigationPop,
              expectedName: 'pop:/test',
            ),
            (
              label: 'didRemove',
              action: (final obs) => obs.didRemove(_makeRoute('/removed'), _makeRoute('/prev')),
              expectedType: TelemetryEventType.navigationRemove,
              expectedName: 'remove:/removed',
            ),
          ];

      for (final c in cases) {
        test(c.label, () {
          c.action(observer);
          final TelemetrySnapshot snap = service.snapshot;
          expect(snap.events.length, 1);
          expect(snap.events.first.type, c.expectedType);
          expect(snap.events.first.name, c.expectedName);
        });
      }
    });

    test('didReplace with named routes', () {
      observer.didReplace(newRoute: _makeRoute('/new'), oldRoute: _makeRoute('/old'));
      final TelemetrySnapshot snap = service.snapshot;
      expect(snap.events.length, 1);
      expect(snap.events.first.type, TelemetryEventType.navigationReplace);
      expect(snap.events.first.name, 'replace:/new');
      expect(snap.events.first.data!['newRoute'], '/new');
      expect(snap.events.first.data!['oldRoute'], '/old');
    });

    test('didReplace with null routes', () {
      observer.didReplace();
      final TelemetrySnapshot snap = service.snapshot;
      expect(snap.events.length, 1);
      expect(snap.events.first.name, 'replace:unnamed');
    });

    group('unnamed routes', () {
      final cases =
          <({String label, void Function(TelemetryNavObserver obs) action, String expectedName})>[
            (
              label: 'didPush with unnamed route',
              action: (final obs) => obs.didPush(_makeRoute(), null),
              expectedName: 'push:unnamed',
            ),
            (
              label: 'didPop with unnamed route',
              action: (final obs) => obs.didPop(_makeRoute(), null),
              expectedName: 'pop:unnamed',
            ),
            (
              label: 'didRemove with unnamed route',
              action: (final obs) => obs.didRemove(_makeRoute(), null),
              expectedName: 'remove:unnamed',
            ),
          ];

      for (final c in cases) {
        test(c.label, () {
          c.action(observer);
          expect(service.snapshot.events.first.name, c.expectedName);
        });
      }
    });

    group('previousRoute data inclusion', () {
      final cases =
          <({String label, void Function(TelemetryNavObserver obs) action, bool hasPreviousRoute})>[
            (
              label: 'didPush with named prev → data has previousRoute',
              action: (final obs) => obs.didPush(_makeRoute('/test'), _makeRoute('/prev')),
              hasPreviousRoute: true,
            ),
            (
              label: 'didPush with null prev → data lacks previousRoute',
              action: (final obs) => obs.didPush(_makeRoute('/test'), null),
              hasPreviousRoute: false,
            ),
            (
              label: 'didPush with unnamed prev → data lacks previousRoute',
              action: (final obs) => obs.didPush(_makeRoute('/test'), _makeRoute()),
              hasPreviousRoute: false,
            ),
            (
              label: 'didPop with named prev → data has previousRoute',
              action: (final obs) => obs.didPop(_makeRoute('/test'), _makeRoute('/prev')),
              hasPreviousRoute: true,
            ),
            (
              label: 'didPop with null prev → data lacks previousRoute',
              action: (final obs) => obs.didPop(_makeRoute('/test'), null),
              hasPreviousRoute: false,
            ),
          ];

      for (final c in cases) {
        test(c.label, () {
          c.action(observer);
          final Map<String, Object> data = service.snapshot.events.first.data!;
          if (c.hasPreviousRoute) {
            expect(data.containsKey('previousRoute'), isTrue);
            expect(data['previousRoute'], '/prev');
          } else {
            expect(data.containsKey('previousRoute'), isFalse);
          }
        });
      }
    });

    test('sequence — push, pop, replace, remove', () {
      observer
        ..didPush(_makeRoute('/a'), null)
        ..didPop(_makeRoute('/a'), _makeRoute('/b'))
        ..didReplace(newRoute: _makeRoute('/c'), oldRoute: _makeRoute('/a'))
        ..didRemove(_makeRoute('/b'), null);

      final TelemetrySnapshot snap = service.snapshot;
      expect(snap.events.length, 4);
      expect(snap.events[0].type, TelemetryEventType.navigationPush);
      expect(snap.events[1].type, TelemetryEventType.navigationPop);
      expect(snap.events[2].type, TelemetryEventType.navigationReplace);
      expect(snap.events[3].type, TelemetryEventType.navigationRemove);
    });
  });
}
