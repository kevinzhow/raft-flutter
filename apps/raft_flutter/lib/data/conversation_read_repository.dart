import 'dart:async';

import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';

import 'user_activity.dart';
import 'source_read_all_transport.dart';

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
  /// The injected refresh preserves source dispatch and receiver overrides.
  Future<void> markUnread(String id) async {
    final identity = SourceReadAllIdentity.capture(client);
    if (_isDisposed() ||
        _revokedChannels().contains(id) ||
        !identity.current(client)) {
      return;
    }
    try {
      await client.post('/channels/$id/unread');
    } finally {
      if (!_isDisposed() &&
          !_revokedChannels().contains(id) &&
          identity.current(client)) {
        await reconcileUnread();
      }
    }
  }

  final localReadState = ReadStateLedger();
  Map<String, int> unread = {};
  Set<String> mentions = {}, newFlags = {};

  /// Latest activity from snapshots and live rows, including own messages.
  final Map<String, BigInt> latestActivity = {};

  /// Existing open-time receipt counter and per-receiver timeline position.
  /// Projection reset deliberately leaves both objects intact.
  final Map<String, int> readPosts = {};
  final scrolledAway = RaftTimelineBottoms();

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
    final requestGeneration = _readState().generation;
    final serverId = client.serverId, principal = client.user?.id;
    if (serverId == null || principal == null) return;
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
            next[id] = entry.toInt();
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
          if (latest != null) latestActivity[id] = latest;
          final fullyRead =
              state != null &&
              latest != null &&
              BigInt.from(state['maxReadSeq']) >= latest;
          next[id] = fullyRead
              ? 0
              : outcome == 'corrupt'
              ? (unread[id] ?? 0)
              : ((entry['unreadCount'] ?? 0) as num).toInt();
          if (entry['hasMention'] == true && next[id]! > 0) {
            nextMentions.add(id);
          }
          if (entry['hasNew'] == true) nextNew.add(id);
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

  void markUnreadLocally(String id) {
    if ((unread[id] ?? 0) > 0) return;
    unread = {...unread, id: 1};
    _changed();
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

  Future<void> markRead(String id) async {
    if (_isDiskOnly(id) || !_mayMarkRead(id)) {
      return;
    }
    final rows = _messages(id)
        .where((m) => _visibleIds(id)?.contains(m['id']) ?? false)
        .toList();
    if (rows.isEmpty) return;
    final origin = client.origin,
        principal = client.user?.id,
        serverId = client.serverId,
        generation = _generation();
    final window = id == _threadChannelId()
        ? _windowGeneration(true)
        : _windowGeneration(false);
    readPosts[id] = (readPosts[id] ?? 0) + 1;
    try {
      final receipt = await client.post(
        '/channels/$id/read',
        data: {'seq': rows.last['seq']},
      );
      if (client.origin != origin ||
          client.user?.id != principal ||
          client.serverId != serverId) {
        return;
      }
      if (_generation() != generation ||
          window !=
              (id == _threadChannelId()
                  ? _windowGeneration(true)
                  : _windowGeneration(false)) ||
          !_mayMarkRead(id)) {
        // The user left (or the window was replaced) while the receipt was in
        // flight. The server cursor still advanced: fold the accepted frontier
        // in and clear only what it covers, so Home never keeps an indicator
        // for a conversation that was read (Source clearUnread).
        // A reset ledger or a revoked scope never accepts a late receipt.
        if (_generation() == generation && !_revokedChannels().contains(id)) {
          _acceptStaleReadReceipt(id, receipt);
        }
        return;
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
    } catch (_) {
      // The cursor did not advance: an optimistic clear must not hide it.
      if (!_isDisposed() &&
          client.origin == origin &&
          client.user?.id == principal &&
          client.serverId == serverId) {
        unawaited(reconcileUnread());
      }
    }
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
    if ((unread[scopeId] ?? 0) != 0) unread = {...unread, scopeId: 0};
    clearMention(scopeId);
    persistReadState();
    _changed();
    return true;
  }

  void setTimelineAtBottom(String id, bool atBottom) =>
      scrolledAway.set(id, atBottom);
}
