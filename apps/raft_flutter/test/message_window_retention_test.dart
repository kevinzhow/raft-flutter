import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/message_window_snapshot.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_cache.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

Map<String, dynamic> row(int seq, {String channel = 'b'}) => {
  'id': '$channel-$seq',
  'channelId': channel,
  'seq': '$seq',
  'content': 'Accepted $seq 中文',
  'senderType': 'user',
  'senderId': 'alice',
};

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://window.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('server');
  }
  final eventsController = StreamController<RaftEvent>.broadcast(sync: true);
  Completer<Map<String, dynamic>>? pending;
  Object? failure;
  bool limited = false;
  @override
  Stream<RaftEvent> get events => eventsController.stream;
  @override
  void joinChannel(String id) {}
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    if (pending != null) return pending!.future;
    if (failure != null) throw failure!;
    return {
      'messages': [
        for (
          var i = before == null ? 51 : 1;
          i <= (before == null ? 100 : 50);
          i++
        )
          row(i, channel: id),
      ],
      'historyLimited': limited,
      'threadSummariesByParentMessageId': {},
    };
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => {};
  @override
  Future<dynamic> post(String path, {dynamic data}) async => {};
}

WorkspaceController _controller(_Client client, WorkspaceCache db) {
  final w = WorkspaceController(client, cache: db)
    ..server = RaftRecord({'id': 'server', 'role': 'owner'})
    ..channels = [
      RaftChannel({'id': 'a', 'type': 'private', 'joined': true}),
      RaftChannel({'id': 'b', 'type': 'private', 'joined': true}),
    ];
  w.ledger.switchServer('server');
  return w;
}

class _DelayedCache implements WorkspaceCache {
  _DelayedCache(this.db);
  final DriftWorkspaceCache db;
  Completer<void>? gate;
  final entered = Completer<void>();
  @override
  Future<dynamic> read(
    String o,
    String p,
    String s,
    String kind,
    String id,
  ) async {
    if (kind == 'window' && id == 'b' && gate != null) {
      if (!entered.isCompleted) entered.complete();
      await gate!.future;
    }
    return db.read(o, p, s, kind, id);
  }

  @override
  Future<void> write(
    String o,
    String p,
    String s,
    String kind,
    String id,
    dynamic value,
  ) => db.write(o, p, s, kind, id, value);
  @override
  Future<void> revokeChannel(String o, String p, String s, String c) =>
      db.revokeChannel(o, p, s, c);
  @override
  Future<void> revokeServer(String o, String p, String s) =>
      db.revokeServer(o, p, s);
  @override
  Future<void> clearAccount(String o, String p) => db.clearAccount(o, p);
  @override
  Future<void> close() => db.close();
}

void main() {
  test('restart hydrates a noninitial channel before pending HTTP and preserves older history', () async {
    final dir = await Directory.systemTemp.createTemp('raft-window-retention-');
    final file = File('${dir.path}/workspace.sqlite');
    var db = DriftWorkspaceCache(NativeDatabase(file));
    var client = _Client();
    var w = _controller(client, db);
    await w.selectChannel(w.channels.last, autoRead: false);
    await w.older();
    await w.flushCache();
    expect(w.messages.length, 100);
    w.dispose();
    await client.eventsController.close();
    await db.close();
    db = DriftWorkspaceCache(NativeDatabase(file));
    client = _Client()..pending = Completer<Map<String, dynamic>>();
    w = _controller(client, db);
    final hydrated = Completer<void>();
    w.addListener(() {
      if (w.messages.length == 100 && !hydrated.isCompleted) {
        hydrated.complete();
      }
    });
    final loading = w.selectChannel(w.channels.last, autoRead: false);
    await hydrated.future.timeout(const Duration(seconds: 3));
    expect(w.channelLoading, true);
    expect(w.messages.first.id, 'b-1');
    client.pending!.complete({
      'messages': [for (var i = 51; i <= 100; i++) row(i)],
      'threadSummariesByParentMessageId': {},
    });
    await loading;
    expect(w.messages.length, 100);
    expect(w.messages.first.id, 'b-1');
    await w.flushCache();
    w.dispose();
    await client.eventsController.close();
    await db.close();
    await dir.delete(recursive: true);
  });
  test('accepted history survives transient refresh but denial revokes persisted and visible rows', () async {
    final db = DriftWorkspaceCache(NativeDatabase.memory());
    final client = _Client();
    final w = _controller(client, db);
    // Use the actual controller client; this helper keeps no authentication data.
    await w.selectChannel(w.channels.last, autoRead: false);
    await w.older();
    client.failure = const RaftApiException('Unavailable', status: 503);
    await w.selectChannel(w.channels.last, autoRead: false);
    expect(w.messages.length, 100);
    client.failure = const RaftApiException('Denied', status: 403);
    await w.selectChannel(w.channels.last, autoRead: false);
    await w.flushCache();
    expect(w.messages, isEmpty);
    expect(
      await db.read(client.origin, 'alice', 'server', 'window', 'b'),
      isNull,
    );
    w.dispose();
    await client.eventsController.close();
    await db.close();
  });
  test('late HTTP cannot apply after role change and owner window is rejected under new role', () async {
    final db = DriftWorkspaceCache(NativeDatabase.memory());
    final current = _Client();
    final w = _controller(current, db);
    await w.selectChannel(w.channels.last, autoRead: false);
    await w.flushCache();
    current.pending = Completer<Map<String, dynamic>>();
    final first = w.selectChannel(w.channels.last, autoRead: false);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    w.server = RaftRecord({'id': 'server', 'role': 'member'});
    w.notifyListeners();
    current.pending!.complete({
      'messages': [row(999)],
      'threadSummariesByParentMessageId': {},
    });
    await first;
    expect(w.messages.any((m) => m.id == 'b-999'), false);
    current.pending = null;
    current.failure = const RaftApiException('Unavailable', status: 503);
    await w.selectChannel(w.channels.last, autoRead: false);
    expect(
      w.messages,
      isEmpty,
      reason: 'Owner cache is not adopted with a new role',
    );
    w.dispose();
    await current.eventsController.close();
    await db.close();
  });
  test(
    'late disk-window read cannot reapply to a newer selected channel',
    () async {
      final db = DriftWorkspaceCache(NativeDatabase.memory());
      final cache = _DelayedCache(db), c = _Client();
      final w = _controller(c, cache);
      await w.selectChannel(w.channels.last, autoRead: false);
      await w.flushCache();
      cache.gate = Completer<void>();
      final old = w.selectChannel(w.channels.last, autoRead: false);
      await cache.entered.future.timeout(const Duration(seconds: 3));
      await w.selectChannel(w.channels.first, autoRead: false);
      expect(w.channel!.id, 'a');
      expect(w.messages.every((m) => m.channelId == 'a'), true);
      cache.gate!.complete();
      await old;
      expect(w.channel!.id, 'a');
      expect(w.messages.every((m) => m.channelId == 'a'), true);
      expect(w.channelLoading, false);
      w.dispose();
      await c.eventsController.close();
      await db.close();
    },
  );
  test('history-limited authoritative response hides previously accepted older range', () async {
    final db = DriftWorkspaceCache(NativeDatabase.memory());
    final c = _Client();
    final w = _controller(c, db);
    await w.selectChannel(w.channels.last, autoRead: false);
    await w.older();
    c.limited = true;
    await w.selectChannel(w.channels.last, autoRead: false);
    expect(w.messages.length, 50);
    expect(w.messages.first.id, 'b-51');
    expect(w.hasMore, false);
    w.dispose();
    await c.eventsController.close();
    await db.close();
  });
  test('fresh range removes deleted rows while preserving strictly older accepted history', () {
    expect(
      reconcileTailWindow(
        [row(1), row(51), row(52), row(200)],
        [row(51), row(53)],
      ),
      {'b-1', 'b-51', 'b-53'},
    );
    expect(reconcileTailWindow([row(1)], []), isEmpty);
    expect(acceptedWindowRows([row(1, channel: 'other')], 'b'), isEmpty);
    expect(acceptedWindowRows([row(1), row(1)], 'b'), isEmpty);
  });
}
