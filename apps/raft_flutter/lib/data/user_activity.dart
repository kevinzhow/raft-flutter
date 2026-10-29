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

  /// Listens for a pointer or key. Startup and window focus call this.
  /// Reading [recent] does not.
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
    final last = _last;
    return last != null && clock().difference(last) <= window;
  }
}

/// Open conversations whose timeline is scrolled above the latest end
/// (reported by the chat view on the edge only, never per frame).
class RaftTimelineBottoms {
  final _away = <String>{};

  void set(String id, bool atBottom) {
    if (atBottom) {
      _away.remove(id);
    } else {
      _away.add(id);
    }
  }

  void reset(String id) => _away.remove(id);

  bool away(String id) => _away.contains(id);

  /// Source `addMessage` / `syncGap`: whether a live arrival in [id] is read
  /// as it lands. Only while the timeline sits at the latest end
  /// (`isNearBottom`; a reader scrolled above it keeps the arrival unread),
  /// and only on recent activity (the 1 s gate). Phone (owner decision
  /// 2026-10-12, docs/parity.md): a foreground page at the latest end reads
  /// it with no tap.
  bool readsLiveArrival(String id, bool phone) =>
      !away(id) && (RaftUserActivity.recent || phone);
}
