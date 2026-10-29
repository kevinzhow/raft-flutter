import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart' show RaftIdleTimer;

import 'history_gaps.dart';
import 'message_history.dart';
import 'history_read_policy.dart';
import 'history_range_reads.dart';
import 'message_history_verification.dart';
import 'message_history_pages.dart';
import 'workspace_message_host.dart';
import 'workspace_messages.dart';
import 'user_error.dart';

/// Event-driven repair for an actually presented conversation. Failed gaps
/// retry with bounded backoff while connected, or resume on reconnect.
class HistoryGapRecovery extends ChangeNotifier {
  HistoryGapRecovery._(WorkspaceMessageHost host, this.thread)
    : w = host.messageDomain;
  final WorkspaceMessages w;
  final bool thread;
  static final _owners = Expando<Map<bool, HistoryGapRecovery>>();
  static HistoryGapRecovery of(WorkspaceMessageHost host, bool thread) {
    final w = host.messageDomain;
    return (_owners[w.context.receiverKey] ??= {}).putIfAbsent(
      thread,
      () => HistoryGapRecovery._(w, thread),
    );
  }

  static void reconnect(WorkspaceMessageHost host) {
    final w = host.messageDomain;
    for (final value
        in _owners[w.context.receiverKey]?.values ?? <HistoryGapRecovery>[]) {
      value._retry.cancel();
      value._attempts.clear();
      value._attempted.clear();
      value._failed.clear();
      value._errors.clear();
      value.refresh();
    }
  }

  final _views = <Object>{};
  final _errors = <String, String>{};
  bool _online = false;
  final _attempted = <Object>{}, _failed = <String>{};
  final _gaps = <String, HistoryGap>{};
  HistoryGapQueries? _source;
  bool _running = false, _again = false, _closed = false;
  Object? _identity;
  final _attempts = <BigInt, int>{};
  final _zone = Zone.current;
  final _retry = RaftIdleTimer(yieldToAnimation: false);
  bool contains(String id) => _gaps.containsKey(id);
  bool failed(String id) => w.session.connected && _failed.contains(id);
  String? error(String id) => failed(id) ? _errors[id] : null;

  /// Explicit recovery after the bounded automatic attempts have failed.
  void retry(String id) {
    final gap = _gaps[id];
    if (_closed || gap == null || !w.session.connected || !failed(id)) return;
    _retry.cancel();
    _attempted.remove((_identity, gap.before));
    _failed.remove(id);
    _errors.remove(id);
    _attempts.remove(gap.before);
    refresh();
  }

  void start(Object view) {
    if (!_views.add(view) || _views.length > 1) return;
    _source = MessageHistoryPages.storage(w.device.cache)?.gaps;
    w.notifications.changes.addListener(refresh);
    _source?.addListener(refresh);
    refresh();
  }

  void stop(Object view) {
    _views.remove(view);
    if (_views.isNotEmpty) return;
    _closed = true;
    HistoryRangeReads.of(w.context.receiverKey).restart();
    _retry.cancel();
    w.notifications.changes.removeListener(refresh);
    _source?.removeListener(refresh);
    _owners[w.context.receiverKey]?.remove(thread);
    dispose();
  }

  void refresh() {
    if (_closed || _views.isEmpty) return;
    if (_online != w.session.connected) {
      _online = w.session.connected;
      notifyListeners();
    }
    if (_running) {
      _again = true;
      return;
    }
    final db = MessageHistoryPages.storage(w.device.cache);
    if (db == null) return;
    _running = true;
    db.reads.background(() async {
      try {
        do {
          _again = false;
          await _scan(db);
        } while (_again && !_closed);
      } finally {
        _running = false;
      }
    });
  }

  Future<void> _scan(MessageHistoryStorage db) async {
    final id = thread ? w.state.threadChannelId : w.presentation.channel?.id;
    final visible = thread ? w.threadWindow?.visible : w.messageWindow?.visible;
    if (id == null ||
        visible != true ||
        !w.presentation.foreground ||
        !w.device.writable) {
      if (_gaps.isNotEmpty && !_closed) {
        _gaps.clear();
        notifyListeners();
      }
      return;
    }
    final scope = MessageHistoryPages.scope(
      w,
      id,
      parent: thread ? w.threadParentChannelId : id,
      parentMessage: thread ? w.threadParentMessageId : null,
    );
    if (scope == null) return;
    final ticket = w.messageHistoryTicket(scope.parentChannel);
    final range = MessageHistoryVerification.ranges(w, scope);
    final identity = (
      scope.origin,
      scope.principal,
      scope.server,
      scope.channel,
      scope.authority,
      ticket,
      w.presentation.navigationRevision,
      range,
      thread ? w.threadGeneration : w.channelGeneration,
    );
    if (_identity != identity) {
      _identity = identity;
      _attempted.clear();
      _failed.clear();
      _errors.clear();
      _retry.cancel();
      _attempts.clear();
    }
    final request = w.messageWindows.request(
      thread: thread,
      allowed: () =>
          w.device.writable &&
          ticket == w.messageHistoryTicket(scope.parentChannel) &&
          id == (thread ? w.state.threadChannelId : w.presentation.channel?.id),
    );
    bool current() =>
        !_closed && request.current && range.current && identity == _identity;
    final savedGaps = await db.gaps.readSaved(scope);
    final gaps = range.remaining(savedGaps);
    if (!current()) return;
    final changed = !setEquals(
      _gaps.keys.toSet(),
      gaps.map((g) => g.newerId).toSet(),
    );
    _gaps
      ..clear()
      ..addEntries(gaps.map((g) => MapEntry(g.newerId, g)));
    _failed.removeWhere((id) => !_gaps.containsKey(id));
    _errors.removeWhere((id, _) => !_gaps.containsKey(id));
    _attempts.removeWhere((before, _) => !gaps.any((g) => g.before == before));
    if (changed) notifyListeners();
    if (w.state.loadingOlder) return;
    final next = gaps.reversed
        .where((gap) => !_attempted.contains((identity, gap.before)))
        .firstOrNull;
    if (next == null) return;
    _attempted.add((identity, next.before));
    _failed.remove(next.newerId);
    notifyListeners();
    Object? failure;
    var success = false;
    w.state.loadingOlder = true;
    w.context.changed();
    try {
      final proof = await MessageHistoryVerification.readRange(
        w,
        request,
        scope,
        before: next.before,
        reason: HistoryReadReason.gap,
        failed: (cause) => failure = cause,
      );
      success = proof != null;
      if (proof != null && !proof.limited && proof.lower <= proof.upper) {
        // Merged coverage now prevents repeats; retain attempts only for an
        // unproven boundary, not one entry for every successful history page.
        _attempted.remove((identity, next.before));
      }
      if (success && current()) {
        db.memory.direction(w.context.receiverKey, id, older: true);
      }
    } finally {
      if (request.current) {
        w.state.loadingOlder = false;
        w.context.changed();
      }
    }
    if (!current()) return;
    if (!success) {
      // A transient failure stays quiet for the initial try and two retries.
      // Offline work resumes on reconnect without displaying an error.
      final denied =
          failure is RaftApiException &&
          {401, 403}.contains((failure as RaftApiException).status);
      final attempt = w.session.connected
          ? _attempts.update(next.before, (n) => n + 1, ifAbsent: () => 1)
          : 0;
      if (w.session.connected && (denied || attempt >= 3)) {
        _failed.add(next.newerId);
        _errors[next.newerId] = userErrorText(
          failure,
          fallback: 'Unable to load messages.',
          statusText: const {
            401: 'Sign in to load messages.',
            403: 'You do not have permission to load these messages.',
          },
          where: 'fill message gap',
        );
        notifyListeners();
      } else if (w.session.connected &&
          w.presentation.foreground &&
          !_retry.isActive) {
        final delay = Duration(seconds: 2 << (attempt - 1));
        _zone.run(
          () => _retry.start(delay, () {
            if (_closed || _identity != identity || !w.session.connected) {
              return;
            }
            for (final gap in _gaps.values) {
              if (!_failed.contains(gap.newerId)) {
                _attempted.remove((identity, gap.before));
              }
            }
            refresh();
          }),
        );
      }
    } else {
      _attempts.remove(next.before);
      if (_attempts.isEmpty) _retry.cancel();
    }
    // Accepted coverage may leave a smaller interval. Verify its new boundary
    // rather than retrying the same failed request.
    _again = true;
  }
}
