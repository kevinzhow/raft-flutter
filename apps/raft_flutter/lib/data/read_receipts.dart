import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

/// Current-server transport and identity needed by read receipts.
abstract interface class ReadReceiptsAuthority {
  RaftClient get client;
  RaftRecord? get server;
}

/// Web `readReceiptDomain` PeerReadState: how far one peer has read a scope.
@immutable
class PeerReadState {
  const PeerReadState(this.peerKind, this.peerId, this.maxReadSeq);
  final String peerKind, peerId;
  final int maxReadSeq;
  String get key => '$peerKind:$peerId';
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

int? _seq(dynamic v) => v is int && v >= 0 ? v : null;

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
      final peer = PeerReadState(kind as String, id, seq);
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
          return PeerReadState(p.peerKind, p.peerId, marks[p.key]!);
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
/// or `peerReadSummary`) is the client-side `read_receipts_v0` gate; a live
/// `scope_read:updated` frame is ignored until its scope is hydrated.
class ReadReceipts extends ChangeNotifier {
  ReadReceipts(this.w);
  final ReadReceiptsAuthority w;
  final Map<String, ReadReceiptScope> _scopes = {};
  final Map<String, Future<void>> _inFlight = {};
  Object? _identity;
  int _epoch = 0;
  bool _disposed = false;

  int _scope() {
    final identity = (
      w.client.origin,
      w.client.user?.id,
      w.client.generation,
      w.client.serverId,
    );
    if (identity != _identity) {
      _identity = identity;
      _epoch++;
      _scopes.clear();
      _inFlight.clear();
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

  /// Reads the scope's detail once at a time.
  Future<void> hydrate(String scopeId) {
    final epoch = _scope();
    final existing = _inFlight[scopeId];
    if (existing != null) return existing;
    late final Future<void> request;
    request = _fetch(scopeId, epoch).whenComplete(() {
      if (identical(_inFlight[scopeId], request)) _inFlight.remove(scopeId);
    });
    return _inFlight[scopeId] = request;
  }

  Future<void> _fetch(String scopeId, int epoch) async {
    try {
      final data = await w.client.get('/channels/$scopeId');
      if (_disposed || _scope() != epoch) return;
      final hydrate = normalizeReadReceiptHydrate(data);
      if (hydrate == null) {
        if (_scopes.remove(scopeId) != null) notifyListeners();
        return;
      }
      _scopes[scopeId] = mergeReadReceiptHydrate(_scopes[scopeId], hydrate);
      notifyListeners();
    } catch (_) {
      // A failed detail leaves the scope disabled; a later mount or
      // `summaryChanged` frame retries.
    }
  }

  void clearScope(String scopeId) {
    _scope();
    if (_scopes.remove(scopeId) != null) notifyListeners();
  }

  /// Delivered by the owning workspace's existing session subscription.
  void consumeEvent(RaftEvent event) {
    if (_disposed || event.name != 'scope_read:updated') return;
    _scope();
    final payload = event.payload;
    if (payload is! Map) return;
    final id = payload['scopeId'];
    if (id is! String || id.isEmpty) return;
    final current = _scopes[id];
    // Hydrate presence is the gate: never enable receipts from a frame alone.
    if (current == null) return;
    if (payload['summaryChanged'] == true) {
      if (!current.isSummary) return;
      final pending = _inFlight[id];
      unawaited(
        pending == null ? hydrate(id) : pending.then((_) => hydrate(id)),
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
      for (var i = 0; i < peers.length; i++)
        i == index ? PeerReadState(kind as String, peer, seq) : peers[i],
    ]);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _scopes.clear();
    _inFlight.clear();
    super.dispose();
  }
}
