// Source: packages/web/src/store/inboxStore.ts at v1.24.0-source.1
//   (requestInboxBackgroundRefresh, INBOX_BACKGROUND_REFRESH_INTERVAL_MS)
// Source: packages/web/src/store/hiddenOwedReads.ts at v1.24.0-source.1
//   (inboxRefreshWaitsForShow)
import 'dart:async';

import 'package:flutter/widgets.dart';

/// Realtime-triggered Activity re-reads, throttled leading+trailing to one per
/// [interval], measured from the last reset read of any kind (Web task #33).
/// The first request after a quiet window reads at once; requests inside the
/// window collapse into one trailing read at the window's end. While the app is
/// hidden nothing is read: the read is owed, and showing the app pays it with
/// one read ([takeOwed]).
class InboxBackgroundRefresh {
  InboxBackgroundRefresh({
    required this.read,
    required this.now,
    bool Function()? hidden,
    this.watched = _always,
  }) : hidden = hidden ?? appHidden;

  static bool _always() => true;

  static const interval = Duration(milliseconds: 2500);

  /// Reads the first window (the owner coalesces it with a read in flight).
  final void Function() read;
  final DateTime Function() now;
  final bool Function() hidden;

  /// Whether a surface that shows Activity data is mounted. Only then is a
  /// trailing timer armed; otherwise the read is owed until one is.
  final bool Function() watched;

  DateTime? _lastResetStartedAt;
  Timer? _timer;
  bool _owed = false;

  /// Web `document.hidden`: the app is in the background.
  static bool appHidden() {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
  }

  /// A trailing read is scheduled.
  bool get pending => _timer != null;

  /// A realtime read was asked for while hidden and not paid yet.
  bool get owed => _owed;

  /// A reset read of any kind started now.
  void noteResetStarted() => _lastResetStartedAt = now();

  /// The single entry point for realtime-triggered re-reads.
  void request() {
    if (_waitsForShow()) return;
    if (_timer != null) return;
    final last = _lastResetStartedAt;
    final wait = last == null
        ? Duration.zero
        : last.add(interval).difference(now());
    if (wait <= Duration.zero) return _run();
    if (!watched()) {
      _owed = true;
      return;
    }
    _timer = Timer(wait, () {
      _timer = null;
      _run();
    });
  }

  void _run() {
    // The trailing read's window ended while hidden: owed too.
    if (_waitsForShow()) return;
    read();
  }

  /// Whether a read asked for now has to wait for the app to be shown (and is
  /// owed then). For reads that keep their own schedule.
  bool deferWhileHidden() => _waitsForShow();

  bool _waitsForShow() {
    if (!hidden()) return false;
    _owed = true;
    return true;
  }

  /// Showing the app: whether a realtime read is owed. It stands for every
  /// realtime read asked for before it, a trailing one set while visible too.
  bool takeOwed() {
    final owed = _owed || _timer != null;
    _owed = false;
    _timer?.cancel();
    _timer = null;
    return owed;
  }

  /// The last surface left: drop the trailing timer, owing its read.
  void suspend() {
    if (_timer == null) return;
    _timer!.cancel();
    _timer = null;
    _owed = true;
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _owed = false;
    _lastResetStartedAt = null;
  }
}
