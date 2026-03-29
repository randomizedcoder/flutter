// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';

@JS()
@staticInterop
class _DomPerformance {}

@JS('performance')
external _DomPerformance get _performance;

extension _DomPerformanceExtension on _DomPerformance {
  @JS()
  external void mark(final JSString name);

  @JS()
  external void measure(final JSString name, final JSString startMark, final JSString endMark);
}

/// Calls `performance.mark(name)` in the browser.
void performanceMark(final String name) {
  _performance.mark(name.toJS);
}

/// Calls `performance.measure(name, startMark, endMark)` in the browser.
void performanceMeasure(final String name, final String startMark, final String endMark) {
  _performance.measure(name.toJS, startMark.toJS, endMark.toJS);
}
