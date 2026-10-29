import 'dart:async';

import 'package:raft_sync/raft_sync.dart' show canonicalUint64;

import 'resource_row_reconcile.dart';

/// One message a conversation's row in the accepted window must reach.
class InboxWant {
  InboxWant({required this.channelId, this.messageId, this.seq});

  /// The Activity scope the message belongs to (a thread's own channel for a
  /// reply).
  final String channelId;
  String? messageId;
  BigInt? seq;
  int attempts = 0;
  final timers = <Timer>[];
  bool get exhausted => attempts >= InboxConvergence.delays.length;

  /// Whether [rows] (an accepted window's items) already show this message in
  /// its conversation's row.
  bool satisfiedBy(Iterable<Map> rows) {
    for (final row in rows) {
      if (activityScopeId(row) != channelId) continue;
      if (messageId == null && seq == null) return true;
      final last = row['kind'] == 'thread'
          ? row['latestActivityMessageId']
          : row['lastMessageId'];
      if (messageId != null && last == messageId) return true;
      final frontier = activityFrontier(row);
      if (seq != null && frontier != null && frontier >= seq!) return true;
    }
    return false;
  }
}

/// The server's inbox is a checkpoint-consistent view that includes a new
/// message about a second after the socket announced it, so the refresh a
/// `message:new` starts 150 ms later reads a window that predates the message.
/// Nothing retried, so the list and the unread count stayed stale until the
/// next event. [InboxConvergence] remembers the newest message per
/// conversation that the accepted window must reach and re-reads at 0.7 s,
/// 1.5 s and 3 s after the event until it does.
class InboxConvergence {
  InboxConvergence({
    required this.retry,
    DateTime Function()? now,
    this.budget = 30,
    this.budgetWindow = const Duration(seconds: 30),
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// Re-read the inbox (the owner coalesces it with any read in flight).
  final void Function() retry;

  /// Offsets from the event, at most one retry each.
  static const delays = [
    Duration(milliseconds: 700),
    Duration(milliseconds: 1500),
    Duration(seconds: 3),
  ];

  /// A conversation whose series of retries ran out unsatisfied twice in a row
  /// is one this window does not list (or the server is far behind): it gets
  /// no more retries for [quietFor], so it cannot keep the client reading.
  static const quietFor = Duration(seconds: 60);

  /// A safety valve over every conversation: at most [budget] retries per
  /// [budgetWindow].
  final int budget;
  final Duration budgetWindow;
  final _wants = <String, InboxWant>{};
  final _waiters = <InboxWant, List<(Completer<bool>, Timer)>>{};
  final _spent = <DateTime>[];
  final _failures = <String, int>{};
  final _quietUntil = <String, DateTime>{};
  Timer? _flush;
  bool _disposed = false;

  /// Conversations still waiting for the window to reach them.
  Iterable<InboxWant> get pending => _wants.values.where((w) => !w.exhausted);
  bool get hasPending => pending.isNotEmpty;

  static BigInt? seqOf(Object? value) => switch (value) {
    int v when v >= 0 => BigInt.from(v),
    String v => canonicalUint64(v),
    _ => null,
  };

  /// Record that the window must reach [messageId] / [seq] of [channelId]
  /// (neither: the conversation merely has to be listed). A conversation
  /// already waiting keeps its schedule, so a burst of messages shares one
  /// series of retries; the series only restarts once it has run out.
  InboxWant? expect(String channelId, {String? messageId, Object? seq}) {
    if (_disposed) return null;
    final quiet = _quietUntil[channelId];
    if (quiet != null) {
      if (_now().isBefore(quiet)) return null;
      _quietUntil.remove(channelId);
      _failures.remove(channelId);
    }
    final incoming = seqOf(seq);
    var want = _wants[channelId];
    if (want != null && want.exhausted) {
      // The previous series ran out without the window ever showing it.
      final failed = (_failures[channelId] ?? 0) + 1;
      _failures[channelId] = failed;
      if (failed >= 2) {
        _wants.remove(channelId);
        _quietUntil[channelId] = _now().add(quietFor);
        return null;
      }
    }
    if (want == null || want.exhausted) {
      if (_wants.length > 64) _wants.removeWhere((_, w) => w.exhausted);
      want = _wants[channelId] = InboxWant(
        channelId: channelId,
        messageId: messageId,
        seq: incoming,
      );
      for (var i = 0; i < delays.length; i++) {
        final started = want;
        started.timers.add(Timer(delays[i], () => _due(started)));
      }
    } else if (messageId != null && messageId == want.messageId) {
      want.seq ??= incoming;
    } else if (incoming != null && want.seq != null) {
      if (incoming > want.seq!) {
        want
          ..seq = incoming
          ..messageId = messageId;
      }
    } else if (messageId != null || incoming != null) {
      // Order unknown: the newest announcement is the one to reach.
      want
        ..seq = incoming
        ..messageId = messageId;
    }
    return want;
  }

  /// Resolves true when an accepted window reaches [want], false after
  /// [timeout] (or when the wants are reset).
  Future<bool> whenReached(InboxWant want, Duration timeout) {
    final completer = Completer<bool>();
    late final (Completer<bool>, Timer) entry;
    // ignore: raft_lints/avoid_unreleased_resource -- Cancelled in observe() and reset().
    final timer = Timer(timeout, () {
      _waiters[want]?.remove(entry);
      if (!completer.isCompleted) completer.complete(false);
    });
    entry = (completer, timer);
    (_waiters[want] ??= []).add(entry);
    return completer.future;
  }

  /// A window the owner accepted: forget what it shows.
  void observe(Iterable<Map> rows) {
    if (_disposed || _wants.isEmpty) return;
    final done = [
      for (final want in _wants.values)
        if (want.satisfiedBy(rows)) want,
    ];
    for (final want in done) {
      _wants.remove(want.channelId);
      _failures.remove(want.channelId);
      for (final timer in want.timers) {
        timer.cancel();
      }
      for (final (completer, timer)
          in _waiters.remove(want) ?? const <(Completer<bool>, Timer)>[]) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete(true);
      }
    }
  }

  void _due(InboxWant want) {
    if (_disposed || !identical(_wants[want.channelId], want)) return;
    want.attempts++;
    if (_flush != null) return;
    // Wants that fall due together share one read.
    _flush = Timer(const Duration(milliseconds: 20), () {
      _flush = null;
      if (_disposed) return;
      final now = _now();
      _spent.removeWhere((at) => now.difference(at) >= budgetWindow);
      if (_spent.length >= budget) {
        // Out of budget: give the conversations up rather than read again.
        for (final want in _wants.values) {
          want.attempts = delays.length;
          for (final timer in want.timers) {
            timer.cancel();
          }
        }
        return;
      }
      _spent.add(now);
      retry();
    });
  }

  /// Forget every want (the scope changed, or access was denied).
  void reset() {
    _flush?.cancel();
    _flush = null;
    for (final want in _wants.values) {
      for (final timer in want.timers) {
        timer.cancel();
      }
    }
    _wants.clear();
    for (final list in _waiters.values) {
      for (final (completer, timer) in list) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete(false);
      }
    }
    _waiters.clear();
    _failures.clear();
    _quietUntil.clear();
  }

  void dispose() {
    _disposed = true;
    reset();
  }
}
