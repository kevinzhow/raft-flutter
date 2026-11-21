import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import 'feature_flag_client_facts.dart';
import 'message_feature_flags.dart';

/// Current-server transport and identity needed by read receipts.
abstract interface class ReadReceiptsAuthority {
  RaftClient get client;
  RaftRecord? get server;
}

/// Web `readReceiptDomain` PeerReadState: how far one peer has read a scope.
@immutable
class PeerReadState {
  const PeerReadState(
    this.peerKind,
    this.peerId,
    this.maxReadSeq, {
    this.stoppedFollowing = false,
    this.mutedChannel = false,
  });
  final String peerKind, peerId;
  final int maxReadSeq;
  final bool stoppedFollowing, mutedChannel;
  String get key => '$peerKind:$peerId';

  PeerReadState advance(int? seq) => seq == null || seq <= maxReadSeq
      ? this
      : PeerReadState(
          peerKind,
          peerId,
          seq,
          stoppedFollowing: stoppedFollowing,
          mutedChannel: mutedChannel,
        );
}

/// Web `ReadReceiptScope`: the peers' own frontiers (small scopes) or an
/// aggregate `readCountAtSeq` ladder (scopes above the peer limit).
@immutable
class ReadReceiptScope {
  const ReadReceiptScope.peers(this.peers) : peerCount = 0, ladder = const [];
  const ReadReceiptScope.summary(this.peerCount, this.ladder) : peers = null;
  final List<PeerReadState>? peers;
  final int peerCount;

  /// `(seq, count)` rows, seq ascending and count strictly descending.
  final List<(int, int)> ladder;
  bool get isSummary => peers == null;
}

/// What a sent message shows (Web `projectReadReceipt`).
@immutable
class ReadReceiptProjection {
  const ReadReceiptProjection(this.readCount, this.peerCount);
  static const none = ReadReceiptProjection(0, 0);
  final int readCount, peerCount;
  bool get read => readCount > 0;
}

int? _seq(dynamic value) =>
    value is int && value >= 0 && value <= 9007199254740991 ? value : null;

/// Web `normalizeReadReceiptHydrate`: null when the detail carries neither
/// shape (the flag is off for the server, or the scope is not a receipt scope),
/// or carries both, or anything malformed.
ReadReceiptScope? normalizeReadReceiptHydrate(dynamic payload) {
  if (payload is! Map) return null;
  final peers = payload['peerReadStates'], summary = payload['peerReadSummary'];
  if (payload.containsKey('peerReadStates') &&
      payload.containsKey('peerReadSummary')) {
    return null;
  }
  if (peers is List) {
    final out = <PeerReadState>[], seen = <String>{};
    for (final item in peers) {
      if (item is! Map) return null;
      final kind = item['peerKind'], id = item['peerId'];
      final seq = _seq(item['maxReadSeq']);
      if ((kind != 'human' && kind != 'agent') ||
          id is! String ||
          id.isEmpty ||
          seq == null) {
        return null;
      }
      final peer = PeerReadState(
        kind as String,
        id,
        seq,
        stoppedFollowing: item['stoppedFollowing'] == true,
        mutedChannel: item['mutedChannel'] == true,
      );
      if (!seen.add(peer.key)) return null;
      out.add(peer);
    }
    return ReadReceiptScope.peers(out);
  }
  if (summary is Map) {
    final count = _seq(summary['peerCount']), rows = summary['readCountAtSeq'];
    if (count == null || rows is! List) return null;
    final ladder = <(int, int)>[];
    var previousSeq = -1, previousCount = count + 1;
    for (final row in rows) {
      if (row is! Map) return null;
      final seq = _seq(row['seq']), n = _seq(row['count']);
      if (seq == null ||
          n == null ||
          seq <= previousSeq ||
          n > count ||
          n >= previousCount) {
        return null;
      }
      ladder.add((seq, n));
      previousSeq = seq;
      previousCount = n;
    }
    return ReadReceiptScope.summary(count, ladder);
  }
  return null;
}

/// Web `mergeReadReceiptHydrate`: a hydrate never lowers a peer frontier a
/// live frame already advanced.
ReadReceiptScope mergeReadReceiptHydrate(
  ReadReceiptScope? current,
  ReadReceiptScope hydrate,
) {
  final known = current?.peers, next = hydrate.peers;
  if (known == null || next == null) return hydrate;
  final marks = {for (final p in known) p.key: p.maxReadSeq};
  var changed = false;
  final merged = [
    for (final p in next)
      if ((marks[p.key] ?? 0) > p.maxReadSeq)
        () {
          changed = true;
          return p.advance(marks[p.key]);
        }()
      else
        p,
  ];
  return changed ? ReadReceiptScope.peers(merged) : hydrate;
}

/// Web `projectReadReceipt`.
ReadReceiptProjection projectReadReceipt(
  ReadReceiptScope? scope,
  int? messageSeq,
) {
  if (scope == null || messageSeq == null || messageSeq <= 0) {
    return ReadReceiptProjection.none;
  }
  final peers = scope.peers;
  if (peers != null) {
    return ReadReceiptProjection(
      peers.where((p) => p.maxReadSeq >= messageSeq).length,
      peers.length,
    );
  }
  for (final (seq, count) in scope.ladder) {
    if (seq >= messageSeq) {
      return ReadReceiptProjection(count, scope.peerCount);
    }
  }
  return ReadReceiptProjection(0, scope.peerCount);
}

/// Web `projectAgentReadReceipt`: null is "unknown", which draws nothing.
bool? projectAgentReadReceipt(
  ReadReceiptScope? scope,
  String agentId,
  int? messageSeq,
) {
  final peers = scope?.peers;
  if (peers == null ||
      messageSeq == null ||
      messageSeq <= 0 ||
      agentId.isEmpty) {
    return null;
  }
  for (final p in peers) {
    if (p.peerKind == 'agent' && p.peerId == agentId) {
      return p.maxReadSeq >= messageSeq;
    }
  }
  return null;
}

/// Web `readReceiptStore`: per scope peer read frontiers of the current
/// server. Hydrating a scope (`GET /channels/:id` answering `peerReadStates`
/// or `peerReadSummary`) is the client-side receipt gate; a live
/// `scope_read:updated` frame is ignored until its scope is hydrated.
class ReadReceipts extends ChangeNotifier {
  ReadReceipts(this.w);
  final ReadReceiptsAuthority w;
  final Map<String, ReadReceiptScope> _scopes = {};
  final Map<String, Future<void>> _inFlight = {};
  final _hydrated = <String, DateTime>{};
  final _detailVersions = <String, int>{};
  final _watches = <String, int>{};
  final _pendingProgress = <String, Map<String, int>>{};
  final _refreshing = <String, Future<void>>{};
  Object? _identity;
  int _epoch = 0;
  bool _disposed = false;
  bool _progressEnabled = false, _flagRequested = false;
  int _flagVersion = 0;

  int _scope() {
    final identity = (
      w.client.origin,
      w.client.user?.id,
      w.client.generation,
      w.client.serverId,
      w.server?.string('role'),
      jsonEncode(w.server?.json['permissions']),
    );
    if (identity != _identity) {
      _identity = identity;
      _epoch++;
      _scopes.clear();
      _inFlight.clear();
      _hydrated.clear();
      _detailVersions.clear();
      _watches.clear();
      _pendingProgress.clear();
      _refreshing.clear();
      _progressEnabled = false;
      _flagRequested = false;
    }
    return _epoch;
  }

  /// Null until the scope is hydrated, or when the server gave no receipts.
  ReadReceiptScope? scope(String scopeId) {
    _scope();
    return _scopes[scopeId];
  }

  ReadReceiptProjection project(String scopeId, int? messageSeq) =>
      projectReadReceipt(scope(scopeId), messageSeq);

  bool wasHydrated(String scopeId) {
    _scope();
    return _hydrated.containsKey(scopeId);
  }

  int get authorityEpoch => _scope();

  bool get progressEnabled {
    _scope();
    return _progressEnabled;
  }

  void ensureProgressFlag({bool refresh = false}) {
    final epoch = _scope();
    final server = w.server;
    if (_disposed ||
        _flagRequested ||
        server == null ||
        server.id != w.client.serverId ||
        w.client.user == null) {
      return;
    }
    _flagRequested = true;
    unawaited(_evaluateProgressFlag(epoch, ++_flagVersion, refresh: refresh));
  }

  Future<void> _evaluateProgressFlag(
    int epoch,
    int version, {
    required bool refresh,
  }) async {
    final flags = await MessageFeatureFlags.of(w.client)
        .evaluate(refresh: refresh);
    final enabled = flags.contains(RaftFeatureFlags.agentReadProgress);
    if (_disposed ||
        _scope() != epoch ||
        _flagVersion != version ||
        _progressEnabled == enabled) {
      return;
    }
    _progressEnabled = enabled;
    notifyListeners();
  }

  Future<void> hydrateIfStale(String scopeId) {
    _scope();
    final request = _inFlight[scopeId];
    if (request != null) return request;
    final loaded = _hydrated[scopeId];
    return loaded != null &&
            DateTime.now().difference(loaded) < const Duration(minutes: 1)
        ? Future.value()
        : hydrate(scopeId);
  }

  VoidCallback watchProgress(String scopeId) {
    final epoch = _scope();
    final count = _watches[scopeId] ?? 0;
    _watches[scopeId] = count + 1;
    if (count == 0) {
      _emitWatch('read_progress:watch', scopeId);
      unawaited(hydrateIfStale(scopeId));
    }
    var released = false;
    return () {
      if (released || _disposed || _scope() != epoch) return;
      released = true;
      final count = _watches[scopeId]!;
      if (count > 1) {
        _watches[scopeId] = count - 1;
        return;
      }
      _watches.remove(scopeId);
      _hydrated.remove(scopeId);
      _emitWatch('read_progress:unwatch', scopeId);
    };
  }

  void _emitWatch(String name, String scopeId) {
    w.client.emitSocketEvent(name, {'scopeId': scopeId});
  }

  /// Reuse a current, authorized channel detail, including an absent gate.
  /// A newer accepted detail also retires any older receipt-only request.
  void acceptDetail(String scopeId, dynamic data) {
    if (_disposed) return;
    _scope();
    _detailVersions[scopeId] = (_detailVersions[scopeId] ?? 0) + 1;
    _hydrated[scopeId] = DateTime.now();
    final pending = _pendingProgress.remove(scopeId);
    final next = normalizeReadReceiptHydrate(data);
    if (next == null) {
      if (_scopes.remove(scopeId) != null) notifyListeners();
    } else {
      final merged = mergeReadReceiptHydrate(_scopes[scopeId], next);
      _scopes[scopeId] = pending == null ? merged : _advance(merged, pending);
      notifyListeners();
    }
  }

  /// Reads the scope's detail once at a time. Navigation may supply its own
  /// current, authorized detail request so optimistic UI shares that same I/O.
  Future<void> hydrate(String scopeId, {Future<dynamic>? detail}) {
    if (_disposed) return Future.value();
    final epoch = _scope();
    final existing = _inFlight[scopeId];
    if (existing != null && detail == null) return existing;
    if (detail != null) {
      _detailVersions[scopeId] = (_detailVersions[scopeId] ?? 0) + 1;
    }
    late final Future<void> request;
    request = _fetch(scopeId, epoch, detail).whenComplete(() {
      if (identical(_inFlight[scopeId], request)) {
        _inFlight.remove(scopeId);
        _pendingProgress.remove(scopeId);
      }
    });
    return _inFlight[scopeId] = request;
  }

  Future<void> _fetch(
    String scopeId,
    int epoch,
    Future<dynamic>? detail,
  ) async {
    final version = _detailVersions[scopeId];
    try {
      final data =
          await (detail ??
              RaftClient.runFresh(() => w.client.get('/channels/$scopeId')));
      if (_disposed ||
          _scope() != epoch ||
          _detailVersions[scopeId] != version) {
        return;
      }
      acceptDetail(scopeId, data);
    } catch (_) {
      // A failed detail leaves the scope disabled; a later mount or
      // `summaryChanged` frame retries.
    }
  }

  void clearScope(String scopeId) {
    _scope();
    _hydrated.remove(scopeId);
    _inFlight.remove(scopeId);
    _pendingProgress.remove(scopeId);
    _refreshing.remove(scopeId);
    _detailVersions[scopeId] = (_detailVersions[scopeId] ?? 0) + 1;
    if (_scopes.remove(scopeId) != null) notifyListeners();
  }

  /// Delivered by the owning workspace's existing session subscription.
  void consumeEvent(RaftEvent event) {
    if (_disposed) return;
    if (event.name == 'channel:removed') {
      final payload = event.payload;
      if (payload case {'channelId': final String id}) {
        clearScope(id);
      }
      return;
    }
    if (event.name == 'server:features-changed') {
      final payload = event.payload;
      if (_flagRequested &&
          payload is Map &&
          payload['serverId'] == w.server?.id &&
          (payload['keys'] is! List ||
              (payload['keys'] as List).contains(
                RaftFeatureFlags.agentReadProgress,
              ))) {
        _flagRequested = false;
        ensureProgressFlag(refresh: true);
      }
      return;
    }
    if (event.name == 'rooms:joined') {
      final epoch = _scope();
      if (_flagRequested) {
        _flagRequested = false;
        ensureProgressFlag(refresh: true);
      }
      _hydrated.clear();
      final held = _watches.keys.toList();
      final latest = held.skip(held.length > 8 ? held.length - 8 : 0);
      for (final id in latest) {
        _emitWatch('read_progress:watch', id);
      }
      for (final id in latest) {
        _refreshFollowState(id, epoch);
      }
      return;
    }
    if (!const {
      'scope_read:updated',
      'read_progress:updated',
      'read_progress:detail_changed',
      'thread:followers-updated',
    }.contains(event.name)) {
      return;
    }
    final epoch = _scope();
    final payload = event.payload;
    if (payload is! Map) return;
    final id =
        payload[event.name == 'thread:followers-updated'
            ? 'threadChannelId'
            : 'scopeId'];
    if (id is! String || id.isEmpty) return;
    final current = _scopes[id];
    if (event.name == 'read_progress:updated') {
      _consumeProgress(id, payload['peers'], current);
      return;
    }
    if (event.name != 'scope_read:updated') {
      if (_watches.containsKey(id) &&
          (_inFlight.containsKey(id) || current?.peers != null)) {
        _refreshFollowState(id, epoch);
      }
      return;
    }
    // Hydrate presence is the gate: never enable receipts from a frame alone.
    if (current == null) return;
    if (payload['summaryChanged'] == true) {
      if (!current.isSummary) return;
      final pending = _inFlight[id];
      unawaited(
        pending == null
            ? hydrate(id)
            : pending.then((_) {
                if (!_disposed &&
                    _scope() == epoch &&
                    _scopes[id]?.isSummary == true) {
                  return hydrate(id);
                }
              }),
      );
      return;
    }
    final kind = payload['peerKind'], peer = payload['peerId'];
    final seq = _seq(payload['maxReadSeq']);
    final peers = current.peers;
    if ((kind != 'human' && kind != 'agent') ||
        peer is! String ||
        peer.isEmpty ||
        seq == null ||
        peers == null) {
      return;
    }
    final index = peers.indexWhere((p) => p.key == '$kind:$peer');
    if (index < 0 || peers[index].maxReadSeq >= seq) return;
    _scopes[id] = ReadReceiptScope.peers([
      for (var indexOfPeer = 0; indexOfPeer < peers.length; indexOfPeer++)
        indexOfPeer == index ? peers[index].advance(seq) : peers[indexOfPeer],
    ]);
    notifyListeners();
  }

  void _consumeProgress(String id, Object? raw, ReadReceiptScope? current) {
    final loading = current == null && _inFlight.containsKey(id);
    if (raw is! List || (!loading && current?.peers == null)) return;
    final marks = loading ? (_pendingProgress[id] ??= {}) : <String, int>{};
    for (final peer in raw.whereType<Map>()) {
      final agentId = peer['peerId'];
      final seq = _seq(peer['maxReadSeq']);
      if (agentId is String &&
          agentId.isNotEmpty &&
          seq != null &&
          seq > (marks[agentId] ?? 0)) {
        marks[agentId] = seq;
      }
    }
    if (current == null || marks.isEmpty) return;
    final next = _advance(current, marks);
    if (identical(next, current)) return;
    _scopes[id] = next;
    notifyListeners();
  }

  ReadReceiptScope _advance(ReadReceiptScope current, Map<String, int> marks) {
    final peers = current.peers;
    if (peers == null) return current;
    List<PeerReadState>? next;
    for (var index = 0; index < peers.length; index++) {
      final peer = peers[index];
      if (peer.peerKind != 'agent') continue;
      final updated = peer.advance(marks[peer.peerId]);
      if (!identical(peer, updated)) (next ??= peers.toList())[index] = updated;
    }
    return next == null ? current : ReadReceiptScope.peers(next);
  }

  void _refreshFollowState(String id, int epoch) {
    final pending = _inFlight[id];
    if (pending == null) {
      unawaited(hydrate(id));
    } else if (!identical(_refreshing[id], pending)) {
      _refreshing[id] = pending;
      unawaited(
        pending.then<void>((_) async {
          if (_disposed ||
              _scope() != epoch ||
              !identical(_refreshing[id], pending)) {
            return;
          }
          _refreshing.remove(id);
          if (_watches.containsKey(id)) await hydrate(id);
        }),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _scopes.clear();
    _inFlight.clear();
    _hydrated.clear();
    _detailVersions.clear();
    _watches.clear();
    _pendingProgress.clear();
    _refreshing.clear();
    super.dispose();
  }
}
