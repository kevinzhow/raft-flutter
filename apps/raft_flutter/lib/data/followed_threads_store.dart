import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart' show canonicalWireSeq;

import 'workspace_entity_directory.dart' show WorkspaceEntityScope;

/// Source threadStore.followedThreads: the current principal's followed
/// threads for the selected server, shared by every mounted surface.
///
/// Lifecycle mirrors Web: loaded when the server is selected / the socket
/// connects (socketBridge reconnectSnapshot), patched in place by
/// `thread:updated`, reloaded when an update names a thread that is not in the
/// list (the server may auto-follow), and cleared only when the server-level
/// identity (principal, server, generation, role or capabilities) changes.
/// Refreshes keep the previous rows until the replacement is accepted.
///
/// Follow/unfollow are optimistic and revert on failure. An acknowledged write
/// is authoritative over an eventually consistent read issued as its echo
/// (follow refresh, `thread:followers-updated`); it yields to the server again
/// once a read agrees, on reconnect, or after a `thread:updated` for the thread.
class FollowedThreadsStore extends ChangeNotifier {
  FollowedThreadsStore({
    required WorkspaceEntityScope? Function() scope,
    required this.query,
    required this.command,
    this.authority,
    Stream<RaftEvent>? events,
    this.isOpen,
  }) : _readScope = scope {
    authority?.addListener(_authorityChanged);
    _subscription = events?.listen(_event);
  }

  static const path = '/channels/threads/followed';

  /// Rows per request (the server accepts 1 to 200) and the most requests one
  /// reload makes, so a runaway cursor cannot loop.
  static const pageSize = 200, maxPages = 100;

  /// The query of the page after [cursor] (the first page when null).
  static Map<String, dynamic> pageQuery(String? cursor) => {
    'limit': pageSize,
    'cursor': ?cursor,
  };

  /// Source FOLLOWED_THREADS_REFRESH_DELAY_MS: replies into threads that are
  /// not in the list (the server auto-followed them) share one reload.
  static const refreshDelay = Duration(milliseconds: 1500);

  final WorkspaceEntityScope? Function() _readScope;
  final Future<dynamic> Function(String path, {Map<String, dynamic>? query})
  query;
  final Future<dynamic> Function(String path, Map<String, dynamic> data)
  command;
  final Listenable? authority;
  final bool Function(String threadChannelId)? isOpen;
  StreamSubscription<RaftEvent>? _subscription;

  WorkspaceEntityScope? _scope;
  int _epoch = 0;
  bool _disposed = false;

  /// True once the owner asked for this store; reconnects and authority
  /// changes reload only a started store.
  bool started = false;
  List<Map<String, dynamic>> _rows = const [];
  Map<String, Map<String, dynamic>> _byParent = const {};
  final _overrides = <String, _FollowOverride>{};
  final _inFlight = <String>{};
  bool _loaded = false, _settled = false, _again = false, _connected = false;
  Object? _error;
  Future<void>? _pending;
  Timer? _coalesced;

  /// Clears every row when the server-level identity changes.
  bool synchronize() {
    if (_disposed) return false;
    final next = _readScope();
    if (next == _scope) return false;
    _scope = next;
    ++_epoch;
    _rows = const [];
    _byParent = const {};
    _overrides.clear();
    _inFlight.clear();
    _pending = null;
    _coalesced?.cancel();
    _coalesced = null;
    _loaded = _settled = _again = _connected = false;
    _error = null;
    final epoch = _epoch;
    // Getters synchronize lazily; the reload for the new identity is scheduled
    // here so whichever caller observes the change first starts it.
    // ignore: raft_lints/avoid_unreviewed_idle_work -- One-shot deferral out of a build or notification; the callback does not schedule another microtask itself.
    scheduleMicrotask(() {
      if (_disposed || epoch != _epoch) return;
      notifyListeners();
      if (started && _scope != null && !_settled && _pending == null) {
        unawaited(refresh());
      }
    });
    return true;
  }

  void _authorityChanged() => synchronize();

  /// A successful list was accepted for the current identity.
  bool get loaded {
    synchronize();
    return _loaded;
  }

  /// The first read for this identity finished (accepted or failed).
  bool get settled {
    synchronize();
    return _settled;
  }

  Object? get error {
    synchronize();
    return _error;
  }

  bool isFollowing(String parentMessageId) {
    synchronize();
    final override = _overrides[parentMessageId];
    if (override != null) return override.following;
    return _byParent.containsKey(parentMessageId);
  }

  /// A follow/unfollow write for this parent has not been acknowledged yet.
  bool isPending(String parentMessageId) {
    synchronize();
    return _inFlight.contains(parentMessageId);
  }

  String? threadChannelIdFor(String parentMessageId) {
    synchronize();
    final known = _overrides[parentMessageId]?.threadChannelId;
    if (known != null) return known;
    final id = _byParent[parentMessageId]?['threadChannelId'];
    return id is String ? id : null;
  }

  /// Followed rows (Source FollowedThread), newest activity first.
  List<Map<String, dynamic>> get threads {
    synchronize();
    return List.unmodifiable([
      for (final row in _rows)
        if (_overrides[row['parentMessageId']]?.following != false)
          Map<String, dynamic>.unmodifiable(row),
    ]);
  }

  /// Starts the list once per identity. Later calls reuse it.
  void start() {
    started = true;
    synchronize();
    if (!_settled && _pending == null) unawaited(refresh());
  }

  /// Fallback for a surface opened before the owner started the store.
  void ensure() {
    synchronize();
    if (_scope != null && !_settled && _pending == null) start();
  }

  /// Completes when the in-flight read (if any) settles.
  @visibleForTesting
  Future<void> get idle => _pending ?? Future.value();

  /// Stale-while-revalidate read. Concurrent callers share one request and
  /// schedule one trailing request.
  Future<void> refresh() {
    started = true;
    synchronize();
    final scope = _scope;
    if (_disposed || scope == null) return Future.value();
    final existing = _pending;
    if (existing != null) {
      _again = true;
      return existing;
    }
    // `_load` always suspends before its `finally`, so this is set first.
    return _pending = _load(scope, _epoch);
  }

  Future<void> _load(WorkspaceEntityScope scope, int epoch) async {
    try {
      final rows = <Map<String, dynamic>>[];
      // Newest activity first, `pageSize` rows a request; a server before
      // `limit` returns the whole list at once and names no `next`.
      String? cursor;
      for (var page = 0; page < maxPages; page++) {
        final value = await Future.sync(
          () => query(path, query: pageQuery(cursor)),
        );
        if (!_accepts(scope, epoch)) return;
        final raw = value is Map ? value['threads'] : null;
        if (raw is! List) {
          throw const FormatException('Invalid followed threads response.');
        }
        rows.addAll([
          for (final row in raw)
            if (row is Map && row['parentMessageId'] is String)
              Map<String, dynamic>.from(row),
        ]);
        final next = value['next'];
        if (next is! String || next.isEmpty || next == cursor) break;
        cursor = next;
      }
      _setRows(rows);
      for (final entry in _overrides.entries.toList()) {
        if (!_inFlight.contains(entry.key) &&
            _byParent.containsKey(entry.key) == entry.value.following) {
          _overrides.remove(entry.key);
        }
      }
      _loaded = true;
      _error = null;
    } catch (error) {
      if (!_accepts(scope, epoch)) return;
      if (error is RaftApiException && [401, 403].contains(error.status)) {
        _setRows(const []);
        _loaded = false;
      }
      _error = error;
    } finally {
      if (_accepts(scope, epoch)) {
        _settled = true;
        _pending = null;
        notifyListeners();
        if (_again) {
          _again = false;
          unawaited(refresh());
        }
      }
    }
  }

  Future<void> follow(String parentMessageId) =>
      _mutate(parentMessageId, following: true);

  Future<void> unfollow(String parentMessageId, {String? threadChannelId}) =>
      _mutate(
        parentMessageId,
        following: false,
        threadChannelId: threadChannelId,
      );

  Future<void> _mutate(
    String parentMessageId, {
    required bool following,
    String? threadChannelId,
  }) async {
    synchronize();
    final scope = _scope;
    if (_disposed || scope == null) {
      throw StateError('Followed threads are not available.');
    }
    if (_inFlight.contains(parentMessageId)) return;
    final threadId = threadChannelId ?? threadChannelIdFor(parentMessageId);
    if (!following && threadId == null) {
      throw StateError('The thread is not known yet.');
    }
    final epoch = _epoch;
    final previous = _overrides[parentMessageId];
    _overrides[parentMessageId] = _FollowOverride(following, threadId);
    _inFlight.add(parentMessageId);
    notifyListeners();
    try {
      final value = await command(
        following ? '/channels/threads/follow' : '/channels/threads/unfollow',
        following
            ? {'parentMessageId': parentMessageId}
            : {'threadChannelId': threadId},
      );
      if (!_accepts(scope, epoch)) return;
      final acknowledged = value is Map && value['threadChannelId'] is String
          ? value['threadChannelId'] as String
          : threadId;
      _acknowledge(parentMessageId, acknowledged, following);
    } catch (_) {
      if (_accepts(scope, epoch)) {
        if (previous == null) {
          _overrides.remove(parentMessageId);
        } else {
          _overrides[parentMessageId] = previous;
        }
      }
      rethrow;
    } finally {
      if (_accepts(scope, epoch)) {
        _inFlight.remove(parentMessageId);
        notifyListeners();
      }
    }
    // Source followThread refreshes the list for the full row; best effort.
    if (following && _accepts(scope, epoch)) unawaited(refresh());
  }

  /// A follow/unfollow committed by another surface (Activity).
  void acknowledge({
    required String parentMessageId,
    String? threadChannelId,
    required bool following,
  }) {
    synchronize();
    if (_disposed || _scope == null) return;
    _acknowledge(parentMessageId, threadChannelId, following);
    notifyListeners();
  }

  void _acknowledge(String parentMessageId, String? threadId, bool following) {
    if (!following && _byParent.containsKey(parentMessageId)) {
      _setRows([
        for (final row in _rows)
          if (row['parentMessageId'] != parentMessageId) row,
      ]);
    }
    if (_byParent.containsKey(parentMessageId) == following) {
      _overrides.remove(parentMessageId);
    } else {
      _overrides[parentMessageId] = _FollowOverride(following, threadId);
    }
  }

  void _setRows(List<Map<String, dynamic>> rows) {
    _rows = rows;
    _byParent = {for (final row in rows) row['parentMessageId'] as String: row};
  }

  void _retireAcknowledged([String? parentMessageId]) {
    _overrides.removeWhere(
      (id, _) =>
          !_inFlight.contains(id) &&
          (parentMessageId == null || id == parentMessageId),
    );
  }

  bool _accepts(WorkspaceEntityScope scope, int epoch) =>
      !_disposed && epoch == _epoch && scope == _scope && scope == _readScope();

  void _event(RaftEvent event) {
    synchronize();
    if (_disposed || _scope == null || !started) return;
    if (event.name == 'connected') {
      // The first connect of an identity reuses the selection-time read.
      final first = !_connected;
      _connected = true;
      if (first && (_pending != null || _loaded)) return;
      _retireAcknowledged();
      unawaited(refresh());
      return;
    }
    if (event.name != 'thread:updated' || event.payload is! Map) return;
    final payload = event.payload as Map;
    final threadId = payload['threadChannelId'];
    if (threadId is! String) return;
    final index = _rows.indexWhere((row) => row['threadChannelId'] == threadId);
    if (index < 0) {
      final parent = payload['parentMessageId'];
      if (parent is String) _retireAcknowledged(parent);
      _requestRefresh();
      return;
    }
    final row = _rows[index];
    final open = isOpen?.call(threadId) == true;
    final unread = payload['unreadCount'];
    final reply = payload['latestReply'];
    final next = <String, dynamic>{
      ...row,
      if (payload['replyCount'] is num) 'replyCount': payload['replyCount'],
      if (payload.containsKey('lastReplyAt'))
        'lastReplyAt': payload['lastReplyAt'],
      if (!open)
        'unreadCount': unread is num
            ? unread
            : ((row['unreadCount'] as num?) ?? 0) + 1,
      // Source thread:updated: a reply that mentions the member lights the
      // thread's @ mark, and a reply into a fully read thread is its first
      // unread one.
      if (!open && _mentionsMember(reply)) 'hasMention': true,
      if (!open &&
          reply is Map &&
          reply['id'] is String &&
          ((row['unreadCount'] as num?) ?? 0) == 0)
        'firstUnreadMessageId': reply['id'],
    };
    final rows = [..._rows]..[index] = next;
    final order = {for (var i = 0; i < rows.length; i++) rows[i]: i};
    // Source updateFollowedThread: newest reply first, undated rows last.
    rows.sort((a, b) {
      final x = DateTime.tryParse('${a['lastReplyAt']}');
      final y = DateTime.tryParse('${b['lastReplyAt']}');
      final c = x == null || y == null
          ? (x == null ? 1 : 0) - (y == null ? 1 : 0)
          : y.compareTo(x);
      return c != 0 ? c : order[a]!.compareTo(order[b]!);
    });
    _setRows(rows);
    notifyListeners();
  }

  bool _mentionsMember(dynamic reply) {
    final me = _scope?.principal,
        list = reply is Map ? reply['mentions'] : null;
    return me != null &&
        list is List &&
        list.any((m) => m is Map && m['type'] == 'user' && m['id'] == me);
  }

  void _requestRefresh() {
    if (_coalesced?.isActive == true) return;
    // ignore: raft_lints/avoid_unreviewed_idle_work -- One-shot 1.5 s coalescing of followed-thread reloads (Web parity); cancelled by dispose and identity changes.
    _coalesced = Timer(refreshDelay, () {
      _coalesced = null;
      if (!_disposed && started) unawaited(refresh());
    });
  }

  /// Source applyServerThreadUnread, for an accepted `read_state:updated`
  /// scope [fact] that carries the unread count left after the read. A read
  /// only lowers unread, never raises it, and a zero that describes an older
  /// frontier cannot erase a reply this device already knows about.
  void applyReadStateHint(Map fact) {
    synchronize();
    final scope = fact['scopeId'], left = fact['unreadCount'];
    if (_disposed || scope is! String || left is! int || left < 0) return;
    final index = _rows.indexWhere((row) => row['threadChannelId'] == scope);
    if (index < 0) return;
    final row = _rows[index], current = row['unreadCount'];
    if (current is! num || current <= left) return;
    final latest = canonicalWireSeq(row['latestActivitySeq']);
    final read = canonicalWireSeq(fact['maxReadSeq']);
    if (left == 0 && latest != null && read != null && latest > read) return;
    final rows = [..._rows]
      ..[index] = {
        ...row,
        'unreadCount': left,
        // A count, not a position: keep the jump target while anything is
        // unread, drop it once nothing is.
        if (left == 0) 'firstUnreadMessageId': null,
      };
    _setRows(rows);
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _coalesced?.cancel();
    ++_epoch;
    authority?.removeListener(_authorityChanged);
    _subscription?.cancel();
    _rows = const [];
    _byParent = const {};
    _overrides.clear();
    _inFlight.clear();
    _pending = null;
    super.dispose();
  }
}

class _FollowOverride {
  const _FollowOverride(this.following, this.threadChannelId);
  final bool following;
  final String? threadChannelId;
}
