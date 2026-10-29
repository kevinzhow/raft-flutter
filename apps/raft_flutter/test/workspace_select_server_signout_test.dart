import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_cache.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://signout.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('server');
  }
  final eventsController = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => eventsController.stream;
  @override
  Future<List<RaftChannel>> channels({bool dm = false}) async => dm
      ? []
      : [
          RaftChannel({'id': 'a', 'type': 'private', 'joined': true}),
        ];
  @override
  void joinChannel(String id) {}
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => {};
  @override
  Future<dynamic> post(String path, {dynamic data}) async => {};
}

/// Holds the channel-list cache write so the test can end the session while
/// selectServer is suspended on it.
class _GatedCache implements WorkspaceCache {
  _GatedCache(this.db);
  final DriftWorkspaceCache db;
  final gate = Completer<void>();
  final entered = Completer<void>();
  @override
  Future<dynamic> read(String o, String p, String s, String kind, String id) =>
      db.read(o, p, s, kind, id);
  @override
  Future<void> write(
    String o,
    String p,
    String s,
    String kind,
    String id,
    dynamic value,
  ) async {
    if (kind == 'channels') {
      if (!entered.isCompleted) entered.complete();
      await gate.future;
    }
    return db.write(o, p, s, kind, id, value);
  }

  @override
  Future<void> revokeChannel(String o, String p, String s, String c) =>
      db.revokeChannel(o, p, s, c);
  @override
  Future<void> revokeServer(String o, String p, String s) =>
      db.revokeServer(o, p, s);
  @override
  Future<void> clearAccount(String o, String p) => db.clearAccount(o, p);
  @override
  Future<List<Map<String, dynamic>>> readTranslations(
    String o,
    String p,
    String s,
  ) => db.readTranslations(o, p, s);
  @override
  Future<void> writeTranslations(
    String o,
    String p,
    String s,
    List<Map<String, dynamic>> entries,
  ) => db.writeTranslations(o, p, s, entries);
  @override
  Future<void> close() => db.close();
}

void main() {
  // `selectServer` read `client.user!` after awaiting the channel-list cache
  // write; a sign-out in that window nulled the user and threw a null check.
  test('signing out while the channel list is cached does not throw', () async {
    final client = _Client();
    final cache = _GatedCache(DriftWorkspaceCache(NativeDatabase.memory()));
    final w = WorkspaceController(client, cache: cache);
    addTearDown(() async {
      w.dispose();
      await client.eventsController.close();
    });
    final selecting = w.selectServer(
      RaftRecord({'id': 'server', 'role': 'owner'}),
    );
    await cache.entered.future.timeout(const Duration(seconds: 10));
    await client.dispose();
    cache.gate.complete();
    await selecting;
  });
}
