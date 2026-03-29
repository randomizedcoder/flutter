// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'telemetry/telemetry_event.dart';
import 'telemetry/telemetry_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  TelemetryService.instance.init();
  runApp(const TelemetryExampleApp());
}

/// Example app demonstrating the telemetry service.
class TelemetryExampleApp extends StatelessWidget {
  /// Creates the example app.
  const TelemetryExampleApp({super.key});

  @override
  Widget build(final BuildContext context) => MaterialApp(
    title: 'Web Telemetry Example',
    navigatorObservers: <NavigatorObserver>[TelemetryService.instance.navigatorObserver],
    home: const HomePage(),
  );
}

/// Home page with buttons to navigate, trigger spans, and view
/// telemetry.
class HomePage extends StatelessWidget {
  /// Creates the home page.
  const HomePage({super.key});

  @override
  Widget build(final BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Telemetry Example')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: <Widget>[
          ElevatedButton(
            onPressed: () {
              unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    settings: const RouteSettings(name: '/detail'),
                    builder: (_) => const DetailPage(),
                  ),
                ),
              );
            },
            child: const Text('Go to Detail Page'),
          ),
          ElevatedButton(
            onPressed: () => unawaited(_runSimulatedWork()),
            child: const Text('Run Async Work (Span)'),
          ),
          ElevatedButton(
            onPressed: () {
              TelemetryService.instance.mark('user-tap');
            },
            child: const Text('Record Instant Mark'),
          ),
          ElevatedButton(
            onPressed: () => _showTelemetryOverlay(context),
            child: const Text('Show Telemetry'),
          ),
        ],
      ),
    ),
  );

  Future<void> _runSimulatedWork() async {
    final TelemetrySpan span = TelemetryService.instance.startSpan('simulated-work');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    span.finish();
    developer.log('Span finished: ${span.elapsedMicros}µs', name: 'telemetry');
  }

  void _showTelemetryOverlay(final BuildContext context) {
    TelemetryService.instance.dumpToConsole();
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => TelemetryOverlay(snapshot: TelemetryService.instance.snapshot),
      ),
    );
  }
}

/// Bottom-sheet overlay displaying a telemetry snapshot.
class TelemetryOverlay extends StatelessWidget {
  /// Creates the overlay from a [snapshot].
  const TelemetryOverlay({required this.snapshot, super.key});

  /// The telemetry snapshot to display.
  final TelemetrySnapshot snapshot;

  @override
  void debugFillProperties(final DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TelemetrySnapshot>('snapshot', snapshot));
  }

  @override
  Widget build(final BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Telemetry Snapshot', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(snapshot.frameStats.toString()),
        const SizedBox(height: 8),
        Text('Events: ${snapshot.events.length}'),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: snapshot.events.length,
            itemBuilder: (final context, final index) {
              // Display newest events first.
              final TelemetryEvent event = snapshot.events[snapshot.events.length - 1 - index];

              return Text(event.toString(), style: const TextStyle(fontSize: 12));
            },
          ),
        ),
      ],
    ),
  );
}

/// A detail page used to demonstrate navigation tracking.
class DetailPage extends StatelessWidget {
  /// Creates the detail page.
  const DetailPage({super.key});

  @override
  Widget build(final BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detail Page')),
    body: const Center(child: Text('Navigation to this page was tracked.')),
  );
}
