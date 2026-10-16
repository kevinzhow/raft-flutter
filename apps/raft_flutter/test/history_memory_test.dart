import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

Map<String, dynamic> row(String channel, int seq) => {
  'id': '$channel-$seq', 'channelId': channel, 'seq': '$seq',
  'content': 'Saved message $seq 中文', 'senderType': 'user', 'senderId': 'alice',
};

class HistoryClient extends RaftClient {
  HistoryClient() : super(origin: 'https://memory.invalid', sessionStore: MemorySessionStore()) {
    user = RaftRecord({'id': 'alice'}); selectServer('server');
  }
  final arrivals = StreamController<RaftEvent>.broadcast(sync: true);
  bool offline = false;
  int oldReads = 0;
  @override
  Stream<RaftEvent> get events => arrivals.stream;
  @override
  void resume(BigInt seq) {}
  @override
  void joinChannel(String id) {}
  @override
  Future<dynamic> post(String path, {dynamic data}) async => {};
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => {};
  @override
  Future<Map<String, dynamic>> messagePage(String id, {int limit = 50, BigInt? before, BigInt? after}) async {
    if (offline) { if (before != null || after != null) oldReads++; throw StateError('Synthetic offline'); }
    final end = before != null ? before.toInt() - 1 : after != null ? (after.toInt()+limit).clamp(0,1000) : 1000;
    final first = after != null ? after.toInt()+1 : (end-limit+1).clamp(1,1001);
    return {'messages': [for(var n=first;n<=end;n++) row(id,n)], 'historyLimited':false};
  }
}

WorkspaceController receiver(HistoryClient client, DriftWorkspaceCache db) {
  final w = WorkspaceController(client, cache: db)
    ..server = RaftRecord({'id':'server','role':'owner'})
    ..channels = [RaftChannel({'id':'chat','type':'private','joined':true})];
  w.ledger.switchServer('server');
  return w;
}

void main() {
  test('1000 visited rows stay on disk while the live receiver releases old bodies', () async {
    final db=DriftWorkspaceCache(NativeDatabase.memory()), client=HistoryClient();
    final w=receiver(client,db);
    try {
      await w.selectChannel(w.channels.single,autoRead:false);
      for(var n=0;n<19;n++) await w.older();
      await w.flushCache();
      await Future<void>.delayed(const Duration(milliseconds:1800));
      expect(w.ledger.messages('chat').length, lessThanOrEqualTo(500));
      expect(w.messages.length,lessThanOrEqualTo(500));
      final saved=await db.messageHistory.readContext(MessageHistoryPages.scope(w,'chat')!,'chat-1',radius:0);
      expect(saved!['messages'],hasLength(1));
      expect((saved['messages'] as List).single['content'],'Saved message 1 中文');
    } finally { await w.flushCache();w.dispose();await client.arrivals.close();await db.close(); }
  });
}
