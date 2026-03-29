// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'telemetry_event.dart';
import 'telemetry_service.dart';

/// A [NavigatorObserver] that records navigation events to the
/// [TelemetryService].
class TelemetryNavObserver extends NavigatorObserver {
  /// Creates a navigation observer that reports to [service].
  TelemetryNavObserver(this.service);

  /// The telemetry service to record events to.
  final TelemetryService service;

  static String _routeName(final Route<dynamic>? route) => route?.settings.name ?? 'unnamed';

  void _record(final TelemetryEventType type, final String prefix, final Map<String, Object> data) {
    service.recordEvent(
      TelemetryEvent(
        type: type,
        name: '$prefix:${data.values.first}',
        timestampMicros: FlutterTimeline.now,
        data: data,
      ),
    );
  }

  @override
  void didPush(final Route<dynamic> route, final Route<dynamic>? previousRoute) {
    _record(TelemetryEventType.navigationPush, 'push', <String, Object>{
      'route': _routeName(route),
      if (previousRoute?.settings.name case final String prevName) 'previousRoute': prevName,
    });
  }

  @override
  void didPop(final Route<dynamic> route, final Route<dynamic>? previousRoute) {
    _record(TelemetryEventType.navigationPop, 'pop', <String, Object>{
      'route': _routeName(route),
      if (previousRoute?.settings.name case final String prevName) 'previousRoute': prevName,
    });
  }

  @override
  void didReplace({final Route<dynamic>? newRoute, final Route<dynamic>? oldRoute}) {
    _record(TelemetryEventType.navigationReplace, 'replace', <String, Object>{
      'newRoute': _routeName(newRoute),
      'oldRoute': _routeName(oldRoute),
    });
  }

  @override
  void didRemove(final Route<dynamic> route, final Route<dynamic>? previousRoute) {
    _record(TelemetryEventType.navigationRemove, 'remove', <String, Object>{
      'route': _routeName(route),
    });
  }
}
