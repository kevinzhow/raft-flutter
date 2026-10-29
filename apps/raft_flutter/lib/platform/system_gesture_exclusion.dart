import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android system back-gesture exclusion (`app.raft/gesture-exclusion`,
/// `View.setSystemGestureExclusionRects`, API 29+). A rail on the window's
/// right edge asks the system not to start the back gesture over its buttons.
///
/// Android honours at most [maxHeight] dp of exclusion per edge; callers pass
/// rects already within it and this class never sends more.
class SystemGestureExclusion {
  SystemGestureExclusion({MethodChannel? channel, bool? supported})
    : _channel = channel ?? const MethodChannel('app.raft/gesture-exclusion'),
      supported = supported ?? (!kIsWeb && Platform.isAndroid);

  /// The process-wide instance; tests replace it.
  static SystemGestureExclusion instance = SystemGestureExclusion();

  /// Android's cap on the excluded height per edge, in dp.
  static const double maxHeight = 200;

  final MethodChannel _channel;
  final bool supported;

  /// The rects (logical pixels, window coordinates) last sent.
  List<Rect> current = const [];

  /// The vertical stretch of [area] to exclude: the first [maxHeight] dp, the
  /// part holding the most-used destinations.
  static Rect clip(Rect area) => Rect.fromLTWH(
    area.left,
    area.top,
    area.width,
    math.min(area.height, maxHeight),
  );

  Future<void> set(List<Rect> rects, {required double devicePixelRatio}) async {
    if (listEquals(rects, current)) return;
    current = List.of(rects);
    if (!supported) return;
    try {
      await _channel.invokeMethod<bool>('set', {
        'ratio': devicePixelRatio,
        'rects': [
          for (final r in rects) [r.left, r.top, r.right, r.bottom],
        ],
      });
    } on PlatformException {
      /* optional system hint */
    } on MissingPluginException {
      /* no native bridge */
    }
  }

  Future<void> clear() async {
    if (current.isEmpty) return;
    current = const [];
    if (!supported) return;
    try {
      await _channel.invokeMethod<bool>('clear');
    } on PlatformException {
      /* optional system hint */
    } on MissingPluginException {
      /* no native bridge */
    }
  }
}
