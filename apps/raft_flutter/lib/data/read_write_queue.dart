import 'dart:async';

/// The client-side bookkeeping Web keeps around the read POST
/// (store/messageStore.ts: pendingReadSeqs, pendingReadRequests,
/// localReadSuppressions, manualUnreadSkipChannels, pendingUnreadReceipts).
///
/// A read is remembered before it is sent. A failed POST keeps it for the next
/// refresh or reconnect. One POST per conversation is in flight, and a newer
/// cursor queued meanwhile goes out right after it. For 30 seconds after a
/// local read a stale unread snapshot cannot repaint the cleared count.
class ReadWriteQueue {
  ReadWriteQueue({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// Web LOCAL_READ_SUPPRESSION_TTL_MS.
  static const suppressionTtl = Duration(seconds: 30);

  final DateTime Function() _now;

  final Map<String, PendingRead> _pending = {};
  final Map<String, Future<void>> _inFlight = {};
  final Map<String, _Suppression> _suppressed = {};
  final Set<String> _manualUnread = {};
  final Map<String, PendingUnreadReceipt> _receipts = {};

  // Pending reads -----------------------------------------------------------

  PendingRead? pending(String id) => _pending[id];

  Iterable<String> get pendingIds => _pending.keys.toList();

  /// Remembers a read up to [seq] (never lowers a newer pending cursor) and
  /// starts the local-read suppression floor.
  void remember(String id, PendingRead read) {
    if (read.seq <= BigInt.zero) return;
    rememberSuppression(id, read.seq);
    final current = _pending[id];
    if (current != null && current.seq > read.seq) return;
    _pending[id] = read;
  }

  /// Drops the pending cursor, or only one at or below [upTo].
  void forgetPending(String id, {BigInt? upTo}) {
    final current = _pending[id];
    if (current == null) return;
    if (upTo != null && current.seq > upTo) return;
    _pending.remove(id);
  }

  Future<void>? inFlight(String id) => _inFlight[id];

  /// Sends the pending cursor of [id] through [send] (true: the server took
  /// it). One request per conversation; a cursor queued while it runs is sent
  /// afterwards, exactly once. A failure keeps the cursor for [flushAll].
  Future<void> flush(String id, Future<bool> Function(PendingRead) send) {
    final existing = _inFlight[id];
    if (existing != null) return existing;
    if (_pending[id] == null) return Future.value();
    late final Future<void> run;
    run = () async {
      try {
        while (true) {
          final entry = _pending[id];
          if (entry == null) return;
          final ok = await Future.sync(() => send(entry));
          if (!ok) return;
          forgetPending(id, upTo: entry.seq);
          final next = _pending[id];
          if (next == null || next.seq <= entry.seq) return;
        }
      } finally {
        if (identical(_inFlight[id], run)) _inFlight.remove(id);
      }
    }();
    _inFlight[id] = run;
    return run;
  }

  /// Web flushAllPendingReads: awaited before every unread snapshot so a
  /// stale snapshot cannot resurrect counts the user already cleared.
  Future<void> flushAll(Future<bool> Function(String, PendingRead) send) =>
      Future.wait([
        for (final id in pendingIds) flush(id, (read) => send(id, read)),
      ]);

  // Local read suppression --------------------------------------------------

  void rememberSuppression(String id, BigInt seq) {
    if (seq <= BigInt.zero) return;
    final current = _suppressed[id];
    final expires = _now().add(suppressionTtl);
    _suppressed[id] = _Suppression(
      current != null && current.seq > seq ? current.seq : seq,
      current != null && current.expires.isAfter(expires)
          ? current.expires
          : expires,
    );
  }

  void forgetSuppression(String id) => _suppressed.remove(id);

  /// A live message past the suppressed cursor lifts the floor.
  void forgetSuppressionIfNewer(String id, BigInt? seq) {
    if (seq == null) return;
    final current = _suppressed[id];
    if (current != null && seq > current.seq) _suppressed.remove(id);
  }

  bool isSuppressed(String id) {
    final current = _suppressed[id];
    if (current == null) return false;
    if (!current.expires.isAfter(_now())) {
      _suppressed.remove(id);
      return false;
    }
    return true;
  }

  // Manual unread -----------------------------------------------------------

  void rememberManualUnread(String id) => _manualUnread.add(id);
  void forgetManualUnread(String id) => _manualUnread.remove(id);

  /// True once for a conversation the member marked unread while it was open:
  /// the open that follows must not read it again.
  bool consumeManualUnread(String id) => _manualUnread.remove(id);

  bool skipsInitialAutoRead(String id) => _manualUnread.contains(id);

  /// Source loadMessages: opening [next] after [left] drops the skip of the
  /// conversation left, and consumes the one of [next]. True: this open must
  /// not read [next].
  bool opening(String? left, String next) {
    if (left != null && left != next) _manualUnread.remove(left);
    return _manualUnread.remove(next);
  }

  // Unread receipts ---------------------------------------------------------

  PendingUnreadReceipt? receipt(String id) => _receipts[id];
  Iterable<MapEntry<String, PendingUnreadReceipt>> get receipts =>
      _receipts.entries.toList();
  void holdReceipt(String id, PendingUnreadReceipt receipt) =>
      _receipts[id] = receipt;
  void dropReceipt(String id) => _receipts.remove(id);

  /// Everything for a new identity (Web resetPendingReads and friends).
  void reset() {
    _pending.clear();
    _inFlight.clear();
    _suppressed.clear();
    _manualUnread.clear();
    _receipts.clear();
  }
}

/// One read cursor waiting for the server, with the identity and window facts
/// the sender must still match when the POST returns.
class PendingRead {
  const PendingRead({
    required this.seq,
    required this.wireSeq,
    required this.origin,
    required this.principal,
    required this.serverId,
    required this.generation,
    required this.window,
  });

  final BigInt seq;
  final Object? wireSeq;
  final String? origin, principal, serverId;
  final int generation, window;
}

/// A `POST /channels/:id/unread` answer held until a snapshot proves the same
/// (or a newer) cursor version (Web pendingUnreadReceipts).
class PendingUnreadReceipt {
  const PendingUnreadReceipt({
    required this.version,
    required this.unreadCount,
    required this.maxReadSeq,
  });

  final int version, unreadCount;
  final BigInt maxReadSeq;

  PendingUnreadReceipt withCount(int count) => PendingUnreadReceipt(
    version: version,
    unreadCount: count,
    maxReadSeq: maxReadSeq,
  );
}

class _Suppression {
  const _Suppression(this.seq, this.expires);
  final BigInt seq;
  final DateTime expires;
}
