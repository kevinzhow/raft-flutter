import 'dart:async';
import 'dart:convert';

import 'package:raft_client/raft_client.dart';

import '../data/workspace_cache.dart';

/// Only authored composer records cross this boundary. The primary engine
/// remains the sole owner of the durable database; projections stay ephemeral.
class DesktopDraftOwner {
  WorkspaceCache? cache;
  bool _retired = false;
  final _revoked = <String>{};
  Future<void> _writes = Future<void>.value();
  Future<void> get settled => _writes;
  bool get available => cache != null && !_retired;

  Future<void> retire() {
    _retired = true;
    return _writes;
  }

  Future<dynamic> read(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
    bool Function() current,
  ) async {
    _validate(kind, id, null);
    await _writes;
    if (!available || _revoked.contains(server) || !current()) {
      throw const RaftApiException.staleScope();
    }
    return cache!.read(origin, principal, server, kind, 'desktop-window:$id');
  }

  Future<void> write(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
    dynamic value,
    bool Function() current,
  ) {
    _validate(kind, id, value);
    if (!available || _revoked.contains(server) || !current()) {
      throw const RaftApiException.staleScope();
    }
    // Capture the immutable database owner. Retirement fences queued work and
    // drains already-started work before the account purge is permitted.
    final store = cache!;
    final writing = _writes.then((_) async {
      if (_retired || _revoked.contains(server) || !current()) {
        throw const RaftApiException.staleScope();
      }
      await store.write(
        origin,
        principal,
        server,
        kind,
        'desktop-window:$id',
        value,
      );
    });
    _writes = writing.then<void>((_) {}, onError: (Object _) {});
    return writing;
  }

  void revokeServer(String origin, String principal, String server) {
    _revoked.add(server);
    final store = cache;
    _writes = _writes.then(
      (_) => store?.revokeServer(origin, principal, server),
    );
  }

  static void _validate(String kind, String id, dynamic value) {
    if (!const {'draft', 'attempt'}.contains(kind) ||
        id.isEmpty ||
        id.length > 512 ||
        value != null && value is! Map ||
        utf8.encode(jsonEncode(value)).length > 1024 * 1024) {
      throw const FormatException('Invalid desktop composer record.');
    }
    if (value is Map && kind == 'draft' && value['channelId'] != id) {
      throw const FormatException('Invalid desktop composer scope.');
    }
  }
}

typedef DesktopDraftRead = Future<dynamic> Function(
  String origin,
  String principal,
  String server,
  String kind,
  String id,
);
typedef DesktopDraftWrite = Future<void> Function(
  String origin,
  String principal,
  String server,
  String kind,
  String id,
  dynamic value,
);

/// A child never opens SQLite. Other cache kinds have no durable projection.
class DesktopDraftCache implements WorkspaceCache {
  DesktopDraftCache({required this.readRecord, required this.writeRecord});
  final DesktopDraftRead readRecord;
  final DesktopDraftWrite writeRecord;
  final Map<String, _PendingDraftWrite> _pending = {};
  Future<void> flush() async {
    for (final entry in _pending.entries.toList()) {
      final w = entry.value;
      await writeRecord(w.origin, w.principal, w.server, w.kind, w.id, w.value);
      if (identical(_pending[entry.key], w)) _pending.remove(entry.key);
    }
  }

  @override
  Future<dynamic> read(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
  ) => const {'draft', 'attempt'}.contains(kind)
      ? readRecord(origin, principal, server, kind, id)
      : Future.value();
  @override
  Future<void> write(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
    dynamic value,
  ) async {
    if (!const {'draft', 'attempt'}.contains(kind)) return;
    final key = jsonEncode([origin, principal, server, kind, id]);
    final pending = _PendingDraftWrite(
      origin,
      principal,
      server,
      kind,
      id,
      value,
    );
    _pending[key] = pending;
    await writeRecord(origin, principal, server, kind, id, value);
    if (identical(_pending[key], pending)) _pending.remove(key);
  }

  // Authority changes are handled once by the primary database owner.
  @override
  Future<void> clearAccount(String origin, String principal) async {}
  @override
  Future<void> revokeServer(
    String origin,
    String principal,
    String server,
  ) async {}
  @override
  Future<void> revokeChannel(
    String origin,
    String principal,
    String server,
    String channel,
  ) async {}
  @override
  Future<List<Map<String, dynamic>>> readTranslations(
    String origin,
    String principal,
    String server,
  ) async => [];
  @override
  Future<void> writeTranslations(
    String origin,
    String principal,
    String server,
    List<Map<String, dynamic>> entries,
  ) async {}
  @override
  Future<void> close() async {}
}

class _PendingDraftWrite {
  _PendingDraftWrite(
    this.origin,
    this.principal,
    this.server,
    this.kind,
    this.id,
    this.value,
  );
  final String origin, principal, server, kind, id;
  final dynamic value;
}
