import 'dart:ui' show Display, FlutterView;

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/android_performance_hint.dart';

/// maplegg on macOS (v0.1.0+23): after a short sleep the window crashed in
/// scheduleFrame — `FlutterView.display` threw "Null check operator used on a
/// null value" because the view had no display. Frames are scheduled then, so
/// reading the refresh rate must never throw.
class _View implements FlutterView {
  _View(this._display);
  final Display? _display;
  @override
  Display get display => _display!;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Display implements Display {
  _Display(this.refreshRate);
  @override
  final double refreshRate;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('the display of the view gives the rate', () {
    final display = _Display(120);
    expect(displayRefreshRateOf([_View(display)], [display]), 120);
  });

  test('a view without a display (sleep) falls back, never throws', () {
    expect(displayRefreshRateOf([_View(null)], [_Display(90)]), 90);
  });

  test('no views or no displays: 60', () {
    expect(displayRefreshRateOf(const [], [_Display(120)]), 60);
    expect(displayRefreshRateOf([_View(null)], const []), 60);
  });

  test('a nonsense rate is 60', () {
    final display = _Display(0);
    expect(displayRefreshRateOf([_View(display)], [display]), 60);
  });
}
