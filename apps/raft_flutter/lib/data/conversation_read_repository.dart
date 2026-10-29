import 'dart:async';

import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';

import 'read_write_queue.dart';
import 'resource_row_reconcile.dart';
import 'source_read_all_transport.dart';
import 'user_activity.dart';

/// Read cursors and unread projections for one workspace receiver.
///
/// A borrowed presentation keeps its own projections and local storage, but
/// reads the source's effective cursor through the supplied port. Controller
/// entrypoints retain source dispatch, visibility policy and event ordering.
class ConversationReadRepository {
  ConversationReadRepository(
    this.client, {
    required this._readState,
    required this._revokedChannels,
    required this._channelId,
    required this._threadChannelId,
    required this._mobileNavigation,
    required this._mayMarkRead,
    required this._markRead,
    required this._channelRows,
    required this._messages,
    required this._isContext,
    required this._hasNewer,
    required this._save,
    required this._changed,
    required this._prefetch,
    bool Function(String)? isDiskOnly,
    Set<String>? Function(String)? visibleIds,
    int Function()? generation,
    int Function(bool)? windowGeneration,
    bool Function()? isDisposed,
    this._refreshUnread,
  }) : _isDiskOnly = isDiskOnly ?? _noReceiptWindow,
       _visibleIds = visibleIds ?? _noVisibleIds,
       _generation = generation ?? _zeroGeneration,
       _windowGeneration = windowGeneration ?? _zeroWindowGeneration,
       _isDisposed = isDisposed ?? _notDisposed;

  final RaftClient client;
  final ReadStateLedger Function() _readState;
  final Set<String> Function() _revokedChannels;
  final String? Function() _channelId, _threadChannelId;
  final bool Function() _mobileNavigation, _hasNewer;
  final bool Function(String) _mayMarkRead, _isContext;
  final Future<void> Function(String) _markRead;
  final List<RaftChannel> Function() _channelRows;
  final List<Map<String, dynamic>> Function(String) _messages;
  final Future<void> Function(String, String, dynamic) _save;
  final void Function() _changed;
  final Future<void> Function() _prefetch;
  final bool Function(String) _isDiskOnly;
  final Set<String>? Function(String) _visibleIds;
  final int Function() _generation;
  final int Function(bool) _windowGeneration;
  final bool Function() _isDisposed;
  final Future<void> Function()? _refreshUnread;

  // Existing snapshot-only callers remain valid. A receiver must supply
  // current window facts before receipt I/O is admitted.
  static bool _noReceiptWindow(String id) => true;
  static Set<String>? _noVisibleIds(String id) => null;
  static int _zeroGeneration() => 0;
  static int _zeroWindowGeneration(bool thread) => 0;
  static bool _notDisposed() => false;

  /// Reconciles unread counts through the receiver's existing refresh hook.
  Future<void> reconcileUnread() => _refreshUnread?.call() ?? refreshUnread();

  /// Marks every message in [id] read from an explicit Activity action.
  ///
  /// Unlike visible-window receipts, this covers the conversation. Request
  /// coalescing and the captured [identity] remain bound to the client.
  Future<void> markAllRead(String id, {SourceReadAllIdentity? identity}) async {
    final captured = identity ?? SourceReadAllIdentity.capture(client);
    if (_isDisposed() ||
        _revokedChannels().contains(id) ||
        !captured.current(client)) {
      return;
    }
    final receipt = await SourceReadAllTransport.of(client)
        .readAll(id, identity: captured);
    if (_isDisposed() ||
        _revokedChannels().contains(id) ||
        !captured.current(client)) {
      return;
    }
    acceptReadAllAck(
      id,
      receipt,
      serverId: captured.serverId!,
      principalId: captured.principalId!,
    );
  }

  /// Marks [id] unread and reconciles the receiver, even if the write fails.
  ///
  /// Source markUnread: the pending read and the 30 s floor go first, a read
  /// already in flight settles before the write, and no badge is invented
  /// before the server names an eligible message: the count is the answer's.
  /// The open conversation is remembered so its next open does not read it
  /// again. The injected refresh preserves source dispatch and overrides.
  Future<void> markUnread(String id) async {
    await markUnreadWithProjection(id);
  }

  /// True when a versioned server acknowledgement can immediately project
  /// the row, without waiting for the asynchronously updated inbox snapshot.
  Future<bool> markUnreadWithProjection(String id) async {
    final identity = SourceReadAllIdentity.capture(client);
    if (_isDisposed() ||
        _revokedChannels().contains(id) ||
        !identity.current(client)) {
      return false;
    }
    bool current() =>
        !_isDisposed() &&
        !_revokedChannels().contains(id) &&
        identity.current(client);
    final inFlight = queue.inFlight(id);
    queue
      ..forgetPending(id)
      ..forgetSuppression(id);
    if (id == _channelId()) {
      queue.rememberManualUnread(id);
    } else {
      queue.forgetManualUnread(id);
    }
    try {
      if (inFlight != null) await inFlight.catchError((_) {});
      if (!current()) return false;
      final answer = await client.post('/channels/$id/unread');
      if (!current()) return false;
      return _holdUnreadAnswer(id, answer, identity);
    } finally {
      if (current()) await reconcileUnread();
    }
  }

  bool _holdUnreadAnswer(
    String id,
    dynamic answer,
    SourceReadAllIdentity identity,
  ) {
    final count = answer is Map ? answer['unreadCount'] : null;
    final version = answer is Map ? answer['readStateVersion'] : null;
    final maxRead = answer is Map
        ? canonicalWireSeq(answer['maxReadSeq'])
        : null;
    if (count is! num || count < 0) return false;
    var projected = false;
    if (version is int && version > 0 && maxRead != null) {
      final accepted = _readState().state(
        identity.serverId!,
        identity.principalId!,
        id,
      );
      if (accepted != null && accepted['readStateVersion'] > version) {
        return false;
      }
      queue.dropReceipt(id);
      _readState().consumeUpdate(
        {
          'serverId': identity.serverId,
          'scopeId': id,
          'maxReadSeq': maxRead.toInt(),
          'readStateVersion': version,
        },
        serverId: identity.serverId!,
        principalId: identity.principalId!,
      );
      queue.holdReceipt(
        id,
        PendingUnreadReceipt(
          version: version,
          unreadCount: count.toInt(),
          maxReadSeq: maxRead,
        ),
      );
      projected = true;
    } else {
      queue.dropReceipt(id);
    }
    if (id == _channelId() && count > 0) {
      queue.rememberManualUnread(id);
    } else {
      queue.forgetManualUnread(id);
    }
    unread = {...unread, id: count.toInt()};
    persistReadState();
    persistUnread();
    _changed();
    return projected;
  }

  /// Projects an accepted unread acknowledgement into an Activity row while
  /// its canonical inbox snapshot still carries an older read-state version.
  /// The conversation summary and Activity inbox converge independently. A
  /// retained Activity row keeps its accepted unread count when an older inbox
  /// version arrives after the conversation receipt has already retired.
  /// No count is guessed from the read cursor or another projection's total.
  Map<String, dynamic> projectActivityReadState(
    Map<String, dynamic> row, {
    Map<String, dynamic>? retained,
  }) {
    final id = activityScopeId(row);
    final serverId = client.serverId, principal = client.user?.id;
    if (id == null || serverId == null || principal == null) return row;
    final accepted = _readState().state(serverId, principal, id);
    final held = queue.receipt(id);
    final frontier = row['readState'];
    final servedVersion = frontier is Map ? frontier['readStateVersion'] : null;
    var projected = row;
    if (held != null &&
        (accepted == null || accepted['readStateVersion'] <= held.version) &&
        (servedVersion is! int || servedVersion < held.version)) {
      projected = {
        ...row,
        'unreadCount': held.unreadCount,
        if (held.unreadCount == 0) ...{
          'firstUnreadMessageId': null,
          'firstMentionMessageId': null,
          'hasMention': false,
        },
        'readState': {
          if (frontier is Map) ...frontier,
          'kind': 'present',
          'maxReadSeq': held.maxReadSeq.toString(),
          'readStateVersion': held.version,
        },
      };
    }
    final prior = retained?['readState'];
    final priorVersion = prior is Map ? prior['readStateVersion'] : null;
    final priorCursor = prior is Map
        ? canonicalWireSeq(prior['maxReadSeq'])
        : null;
    final priorCount = retained?['unreadCount'];
    final current = projected['readState'];
    final currentVersion = current is Map ? current['readStateVersion'] : null;
    // An optimistic local "read" also paints zero without advancing its cursor
    // version; that zero cannot serve as an accepted unread acknowledgement.
    if (retained != null &&
        activityScopeId(retained) == id &&
        prior is Map &&
        prior['kind'] == 'present' &&
        priorVersion is int &&
        priorVersion > 0 &&
        priorCursor != null &&
        priorCount is int &&
        priorCount > 0 &&
        (accepted == null || accepted['readStateVersion'] <= priorVersion) &&
        (currentVersion is! int || currentVersion < priorVersion)) {
      final priorActivity = prior['latestActivity'];
      final currentActivity = current is Map ? current['latestActivity'] : null;
      final priorLatest = priorActivity is Map
          ? canonicalUint64(priorActivity['seq'])
          : null;
      final currentLatest = currentActivity is Map
          ? canonicalUint64(currentActivity['seq'])
          : null;
      projected = {
        ...projected,
        'unreadCount': priorCount,
        for (final key in const [
          'firstUnreadMessageId',
          'firstMentionMessageId',
          'hasMention',
        ])
          if (retained.containsKey(key)) key: retained[key],
        'readState': {
          if (current is Map) ...current,
          'kind': 'present',
          'maxReadSeq': priorCursor.toString(),
          'readStateVersion': priorVersion,
          if (priorLatest != null &&
              (currentLatest == null || priorLatest > currentLatest))
            'latestActivity': priorActivity,
        },
      };
    }
    return projected;
  }

  /// Read-write bookkeeping of this receiver (Web messageStore module state).
  final queue = ReadWriteQueue();

  final localReadState = ReadStateLedger();
  Map<String, int> unread = {};
  Set<String> mentions = {}, newFlags = {};

  /// Latest activity from snapshots and live rows, including own messages.
  final Map<String, BigInt> latestActivity = {};

  /// Existing open-time receipt counter and per-receiver timeline position.
  /// Projection reset deliberately leaves both objects intact.
  final Map<String, int> readPosts = {};
  final scrolledAway = RaftTimelineBottoms();

  /// A new identity: counts, flags and the read write path start empty.
  void resetProjection() {
    unread = {};
    mentions = {};
    newFlags = {};
    latestActivity.clear();
    queue.reset();
  }

  void persistReadState() {
    final serverId = client.serverId, principal = client.user?.id;
    if (serverId == null || principal == null) return;
    _save('read-frontiers', '', _readState().exportFor(serverId, principal));
    _save('unread', '', Map.of(unread));
  }

  void persistUnread() {
    if (client.serverId == null || client.user == null) return;
    _save('unread', '', Map.of(unread));
  }

  void receiveUnread(Map<String, dynamic> row) {
    final id = row['channelId'];
    if (id is! String || _revokedChannels().contains(id)) return;
    final seq = canonicalWireSeq(row['seq']);
    if (seq != null && seq > (latestActivity[id] ?? BigInt.zero)) {
      latestActivity[id] = seq;
    }
    queue.forgetSuppressionIfNewer(id, seq);
    if ((id == _channelId() || id == _threadChannelId()) &&
        _mayMarkRead(id) &&
        scrolledAway.readsLiveArrival(id, _mobileNavigation())) {
      unawaited(_markRead(id));
      return;
    }
    if (row['senderType'] == 'user' && row['senderId'] == client.user?.id) {
      return;
    }
    final known = _channelRows().where((c) => c.id == id).firstOrNull;
    final counted = known == null
        ? unread.containsKey(id)
        : known.type != 'channel' || known.joined;
    if (!counted) return;
    final serverId = client.serverId, principal = client.user?.id;
    final frontier = serverId == null || principal == null
        ? null
        : _readState().state(serverId, principal, id);
    if (seq != null &&
        frontier != null &&
        BigInt.from(frontier['maxReadSeq']) >= seq) {
      return;
    }
    unread = {...unread, id: (unread[id] ?? 0) + 1};
    final held = queue.receipt(id);
    if (held != null && (seq == null || seq > held.maxReadSeq)) {
      queue.holdReceipt(id, held.withCount(held.unreadCount + 1));
    }
    if (_mentionsMember(row)) mentions = {...mentions, id};
    persistUnread();
    unawaited(_prefetch());
  }

  bool _mentionsMember(Map<String, dynamic> row) {
    final me = client.user?.id, list = row['mentions'];
    return me != null &&
        list is List &&
        list.any((m) => m is Map && m['type'] == 'user' && m['id'] == me);
  }

  void clearMention(String id) {
    if (mentions.contains(id)) mentions = {...mentions}..remove(id);
    if (newFlags.contains(id)) newFlags = {...newFlags}..remove(id);
  }

  void projectReadState(String id) {
    final serverId = client.serverId, principal = client.user?.id;
    if (serverId == null || principal == null || !unread.containsKey(id)) {
      return;
    }
    final state = _readState().state(serverId, principal, id);
    if (state == null) return;
    final maxRead = BigInt.from(state['maxReadSeq']);
    final rows = _messages(id);
    var latest = latestActivity[id];
    if (rows.isNotEmpty) {
      final last = RaftMessage(rows.last).seq;
      if (latest == null || last > latest) latest = last;
    }
    int? count;
    if (latest != null && maxRead >= latest) {
      count = 0;
    } else if (rows.isNotEmpty &&
        !_isContext(id) &&
        !(id == _channelId() && _hasNewer()) &&
        RaftMessage(rows.first).seq <= maxRead) {
      count = rows
          .where(
            (row) =>
                RaftMessage(row).seq > maxRead &&
                !(row['senderType'] == 'user' && row['senderId'] == principal),
          )
          .length;
    }
    if (count == null || unread[id] == count) return;
    unread = {...unread, id: count};
    if (count == 0) clearMention(id);
  }

  Future<void> refreshUnread() async {
    final serverId = client.serverId, principal = client.user?.id;
    if (serverId == null || principal == null) return;
    // Source loadUnreadCounts: settle queued reads first, so a stale snapshot
    // cannot resurrect counts the member already cleared.
    await flushPendingReads();
    if (client.serverId != serverId || client.user?.id != principal) return;
    final requestGeneration = _readState().generation;
    try {
      final value = await client.get('/channels/unread', query: {'summary': 1});
      if (client.serverId != serverId || client.user?.id != principal) return;
      final counts = value is Map ? value['channels'] ?? value : {};
      if (counts is Map) {
        final next = <String, int>{};
        final nextMentions = <String>{};
        final nextNew = <String>{};
        for (final e in counts.entries) {
          final id = e.key.toString(), entry = e.value;
          if (entry is num) {
            next[id] = queue.isSuppressed(id) ? 0 : entry.toInt();
            continue;
          }
          if (entry is! Map) continue;
          final frontier = entry['readState'];
          final outcome = _readState().consumeSnapshot(
            frontier,
            serverId: serverId,
            principalId: principal,
            scopeId: id,
            generationAtRequest: requestGeneration,
            // RisingWave projects this endpoint asynchronously. An absent row
            // cannot erase a newer positive HTTP/socket acknowledgement.
            authoritativeAbsence: false,
          );
          final state = _readState().state(serverId, principal, id);
          final latest = frontier is Map && frontier['latestActivity'] is Map
              ? canonicalUint64(frontier['latestActivity']['seq'])
              : null;
          if (latest != null) {
            latestActivity[id] = latest;
            // Activity past the read cursor lifts the 30 s floor.
            queue.forgetSuppressionIfNewer(id, latest);
          }
          final fullyRead =
              state != null &&
              latest != null &&
              BigInt.from(state['maxReadSeq']) >= latest;
          next[id] = fullyRead
              ? 0
              : outcome == 'corrupt'
              ? (unread[id] ?? 0)
              : ((entry['unreadCount'] ?? 0) as num).toInt();
          // Source pendingUnreadReceipts: the answer to "mark as unread" holds
          // until a snapshot proves the same (or a newer) cursor version.
          final held = queue.receipt(id);
          if (held != null) {
            final caughtUp =
                frontier is Map &&
                frontier['kind'] == 'present' &&
                frontier['readStateVersion'] is int &&
                frontier['readStateVersion'] >= held.version;
            if (caughtUp ||
                state != null && state['readStateVersion'] > held.version) {
              queue.dropReceipt(id);
            }
          }
          // Source rememberLocalReadSuppression: for 30 s after a local read
          // a snapshot cannot repaint the cleared count, mention or new dot.
          if (queue.isSuppressed(id)) {
            next[id] = 0;
            continue;
          }
          if (entry['hasMention'] == true && next[id]! > 0) {
            nextMentions.add(id);
          }
          if (entry['hasNew'] == true) nextNew.add(id);
        }
        // Held answers keep their count, rows or no rows (Web applies them
        // after the snapshot).
        for (final held in queue.receipts) {
          next[held.key] = held.value.unreadCount;
        }
        unread = next;
        mentions = nextMentions;
        newFlags = nextNew;
        persistReadState();
      }
      _changed();
      unawaited(_prefetch());
    } catch (_) {
      /* Keep accepted counts through transient failures. */
    }
  }

  void applyThreadUnread(dynamic threadChannelId, dynamic summary) {
    if (threadChannelId is! String ||
        summary is! Map ||
        !unread.containsKey(threadChannelId) ||
        threadChannelId == _threadChannelId()) {
      return;
    }
    final count = summary['unreadCount'];
    if (count is! int || count < 0 || unread[threadChannelId] == count) return;
    unread = {...unread, threadChannelId: count};
    persistUnread();
  }

  /// Windows painted from disk whose first fresh page has not arrived yet.
  /// Their tail may be stale, so they never send a read receipt (nor clear
  /// the unread count) until revalidated.

  /// Source markCurrentChannelRead / queueAutoReadSync: the cursor is queued,
  /// one POST per conversation is in flight, the receipt clears the unread,
  /// and a failure clears it locally anyway and keeps the cursor for the next
  /// refresh or reconnect (the local clear does not depend on the POST).
  Future<void> markRead(String id) async {
    if (_isDiskOnly(id) || !_mayMarkRead(id)) {
      return;
    }
    final rows = _messages(id)
        .where((m) => _visibleIds(id)?.contains(m['id']) ?? false)
        .toList();
    if (rows.isEmpty) return;
    readPosts[id] = (readPosts[id] ?? 0) + 1;
    queue
      ..dropReceipt(id)
      ..remember(
        id,
        PendingRead(
          seq: RaftMessage(rows.last).seq,
          wireSeq: rows.last['seq'],
          origin: client.origin,
          principal: client.user?.id,
          serverId: client.serverId,
          generation: _generation(),
          window: _windowGeneration(id == _threadChannelId()),
        ),
      );
    await queue.flush(id, (read) => _sendRead(id, read));
  }

  /// Web flushAllPendingReads, awaited before every unread snapshot.
  Future<void> flushPendingReads() =>
      queue.flushAll((id, read) => _sendRead(id, read));

  /// Posts one queued cursor. True: settled (taken, or no longer ours to
  /// send); false: keep it for the next refresh or reconnect.
  Future<bool> _sendRead(String id, PendingRead read) async {
    bool same() =>
        !_isDisposed() &&
        client.origin == read.origin &&
        client.user?.id == read.principal &&
        client.serverId == read.serverId;
    if (!same() || _revokedChannels().contains(id)) return true;
    final dynamic receipt;
    try {
      receipt = await client.post(
        '/channels/$id/read',
        data: {'seq': read.wireSeq},
      );
    } catch (_) {
      if (!same()) return true;
      // Source: the cursor stays queued and the 30 s floor holds the clear.
      if ((unread[id] ?? 0) != 0 || mentions.contains(id)) {
        unread = {...unread, id: 0};
        clearMention(id);
        persistUnread();
        _changed();
      }
      return false;
    }
    if (!same()) return true;
    if (_generation() != read.generation ||
        read.window != _windowGeneration(id == _threadChannelId()) ||
        !_mayMarkRead(id)) {
      // The user left (or the window was replaced) while the receipt was in
      // flight. The server cursor still advanced: fold the accepted frontier
      // in and clear only what it covers, so Home never keeps an indicator
      // for a conversation that was read (Source clearUnread).
      // A reset ledger or a revoked scope never accepts a late receipt.
      if (_generation() == read.generation &&
          !_revokedChannels().contains(id)) {
        _acceptStaleReadReceipt(id, receipt);
      }
      return true;
    }
    if (receipt is Map && client.serverId != null && client.user != null) {
      _readState().consumeUpdate(
        {
          'serverId': client.serverId,
          'scopeId': id,
          'maxReadSeq': receipt['maxReadSeq'],
          'readStateVersion': receipt['readStateVersion'],
        },
        serverId: client.serverId!,
        principalId: client.user!.id,
      );
    }
    // Source clearUnread: the read tail is the latest; no snapshot GET.
    if ((unread[id] ?? 0) != 0) unread = {...unread, id: 0};
    clearMention(id);
    persistReadState();
    _changed();
    return true;
  }

  void _acceptStaleReadReceipt(String id, dynamic receipt) {
    final serverId = client.serverId, principal = client.user?.id;
    if (_isDisposed() || serverId == null || principal == null) return;
    final readGeneration = _readState().generation;
    if (receipt is Map) {
      _readState().consumeUpdate(
        {
          'serverId': serverId,
          'scopeId': id,
          'maxReadSeq': receipt['maxReadSeq'],
          'readStateVersion': receipt['readStateVersion'],
        },
        serverId: serverId,
        principalId: principal,
      );
    }
    final before = unread[id] ?? 0;
    projectReadState(id);
    // Activity is a separate projection: its row can still be unread even
    // when this receiver's chat counter is already zero.
    if (_readState().generation != readGeneration ||
        (unread[id] ?? 0) != before) {
      persistReadState();
      _changed();
    }
    if ((unread[id] ?? 0) != 0) unawaited(reconcileUnread());
  }

  /// Source acceptActivityReadAllAck: an Activity row's persisted read-all
  /// receipt is a read-state fact for [scopeId]. Folding it into the ledger is
  /// what keeps a stale inbox response from re-presenting the row as unread.
  /// Returns false for an invalid receipt or a changed identity.
  bool acceptReadAllAck(
    String scopeId,
    dynamic receipt, {
    required String serverId,
    required String principalId,
  }) {
    if (client.serverId != serverId || client.user?.id != principalId) {
      return false;
    }
    if (receipt is! Map) return false;
    final outcome = _readState().consumeUpdate(
      {
        'serverId': serverId,
        'scopeId': scopeId,
        'maxReadSeq': receipt['maxReadSeq'] ?? receipt['seq'],
        'readStateVersion': receipt['readStateVersion'],
      },
      serverId: serverId,
      principalId: principalId,
    );
    if (outcome == 'corrupt') return false;
    final accepted = _readState().state(serverId, principalId, scopeId);
    if (outcome == 'stale' &&
        accepted != null &&
        receipt['readStateVersion'] is int &&
        accepted['readStateVersion'] > receipt['readStateVersion']) {
      return false;
    }
    // Source markRead (read-all): remember the 30 s floor from the answer's
    // seq, drop the queued cursor and the manual-unread skip, clear locally.
    queue
      ..dropReceipt(scopeId)
      ..forgetPending(scopeId)
      ..forgetManualUnread(scopeId);
    final seq = canonicalWireSeq(receipt['seq']);
    if (seq != null) queue.rememberSuppression(scopeId, seq);
    if ((unread[scopeId] ?? 0) != 0) unread = {...unread, scopeId: 0};
    clearMention(scopeId);
    persistReadState();
    _changed();
    return true;
  }

  void setTimelineAtBottom(String id, bool atBottom) =>
      scrolledAway.set(id, atBottom);
}
