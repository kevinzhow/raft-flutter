import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// Recent explicit user activity in this app window (Source messageStore
/// `rememberExplicitAutoReadUserActivity`: pointerdown/keydown). A live
/// message appended to the open conversation is marked read only when the
/// user was just interacting; arrivals while the user is idle stay unread.
class RaftUserActivity {
  RaftUserActivity._();

  /// Source LIVE_APPEND_AUTO_READ_ACTIVITY_WINDOW_MS.
  static const window = Duration(seconds: 1);

  static bool _installed = false;
  static DateTime? _last;
  static DateTime Function() clock = DateTime.now;

  static void install() {
    if (_installed) return;
    try {
      GestureBinding.instance.pointerRouter.addGlobalRoute((event) {
        if (event is PointerDownEvent || event is PointerSignalEvent) mark();
      });
      HardwareKeyboard.instance.addHandler((event) {
        if (event is KeyDownEvent) mark();
        return false;
      });
      _installed = true;
    } catch (_) {
      // No binding yet (pure unit code): nothing to observe.
    }
  }

  static void mark() => _last = clock();

  /// Forgets activity (window blurred / hidden).
  static void forget() => _last = null;

  static bool get recent {
    install();
    final last = _last;
    return last != null && clock().difference(last) <= window;
  }
}
