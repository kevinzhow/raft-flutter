import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

Map<String, dynamic> _row(int seq, {String? content}) => {
  'id': 'm$seq',
  'channelId': 'chat',
  'seq': '$seq',
  'content': content ?? 'Body $seq',
  'senderType': 'user',
  'senderId': 'alice',
};

class HistoryAuditClient extends RaftClient {
  HistoryAuditClient()
    : super(
        origin: 'https://verify.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('server');
  }
  final incoming = StreamController<RaftEvent>.broadcast(sync: true);
  final edits = <int, String>{}, deleted = <int>{};
  final patches = <int, Map<String, dynamic>>{};
  int bodyBytes = 0, total = 100;
  final calls = <String>[];
  Map<String, dynamic> summaries = {};
  Map<String, dynamic>? channelRecord;
  bool replayExpired = false;
  Completer<void>? gate, started;
  Object? failure;
  @override
  Stream<RaftEvent> get events => incoming.stream;
  @override
  void joinChannel(String id) {}
  @override
  Future<dynamic> post(String path, {dynamic data}) async => {};
  Future<Map<String, dynamic>> _read(String key, int first, int last) async {
    calls.add(key);
    final problem = failure;
    final response = {
      'messages': [
        for (var i = first; i <= last; i++)
          if (!deleted.contains(i))
            {
              ..._row(
                i,
                content: edits[i] ?? (bodyBytes > 0 ? 'x' * bodyBytes : null),
              ),
              ...?patches[i],
            },
      ],
      'historyLimited': false,
      'threadSummariesByParentMessageId': summaries,
    };
    if (started?.isCompleted == false) started!.complete();
    await gate?.future;
    if (problem != null) throw problem;
    return response;
  }

  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    BigInt? before,
    BigInt? after,
    int limit = 50,
  }) async {
    final candidates = [
      for (var i = 1; i <= total; i++)
        if (!deleted.contains(i) &&
            (before == null || BigInt.from(i) < before) &&
            (after == null || BigInt.from(i) > after))
          i,
    ];
    final selected = after == null
        ? candidates
              .skip((candidates.length - limit).clamp(0, candidates.length))
              .toList()
        : candidates.take(limit).toList();
    return _read(
      'page:$before:$after:$limit',
      selected.firstOrNull ?? 1,
      selected.lastOrNull ?? 0,
    );
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/channels/chat' && channelRecord != null) return channelRecord;
    if (path == '/channels' || path == '/channels/dm') {
      return path == '/channels/dm'
          ? <dynamic>[]
          : [
              channelRecord ??
                  {'id': 'chat', 'type': 'private', 'joined': true},
            ];
    }
    if (path == '/messages/sync') return <dynamic>[];
    if (path.startsWith('/messages/context/m')) {
      final target = int.parse(path.split('/m').last);
      if (deleted.contains(target)) {
        calls.add('context:$target');
        throw const RaftApiException('Message unavailable', status: 404);
      }
      final response = await _read(
        'context:$target',
        (target - 15).clamp(1, 100),
        (target + 15).clamp(1, 100),
      );
      return {
        ...response,
        'channelId': 'chat',
        'targetMessageId': 'm$target',
        'hasOlder': target > 16,
        'hasNewer': target < 85,
      };
    }
    return {};
  }
}

class HistoryAuditCase {
  HistoryAuditCase({this.budget = 2 << 30, this.space, this.hardLimit = false});
  final bool hardLimit;
  final Future<int?> Function(String)? space;
  final int budget;
  DateTime now = DateTime.utc(2026, 10, 15);
  final client = HistoryAuditClient();
  late final DriftWorkspaceCache cache = DriftWorkspaceCache(
    NativeDatabase.memory(),
    historyClock: () => now,
    historyBudget: budget,
    historyHardLimitEnabled: hardLimit,
    historyAvailableSpace: space,
    automaticHistoryMaintenance: false,
  );
  late final WorkspaceController w = WorkspaceController(client, cache: cache)
    ..messageDomain.ledger.switchServer('server')
    ..server = RaftRecord({'id': 'server', 'role': 'owner'})
    ..channels = [
      RaftChannel({'id': 'chat', 'type': 'private', 'joined': true}),
    ];
  Future<void> seed() async {
    w.messageDomain.ledger.switchServer('server');
    await w.selectChannel(w.channels.single, autoRead: false);
    await w.messageDomain.older();
    await w.flushCache();
    await cache.messageHistory.reads.settled;
    expect(w.messageDomain.messages.length, 100);
    client.calls.clear();
  }

  void forgetOlder() {
    for (var i = 1; i <= 50; i++) {
      w.messageDomain.ledger.remove('chat', 'm$i');
      w.messageDomain.visibleIds['chat']?.remove('m$i');
    }
    w.messageDomain.state.hasMore = true;
  }

  Future<void> reconnect() async {
    client.incoming.add(const RaftEvent('rooms:joined', {}));
    await w.messageDomain.navigation.syncVisibleScopes();
    await cache.messageHistory.receiver.settled;
    await cache.messageHistory.reads.settled;
    await w.flushCache();
  }

  Future<void> close() async {
    if (client.gate?.isCompleted == false) client.gate!.complete();
    await cache.messageHistory.reads.settled;
    await w.flushCache();
    w.dispose();
    await client.incoming.close();
    await client.dispose();
    await cache.close();
  }
}
