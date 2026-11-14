import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

// Source: packages/web/src/features/sidebar/hooks/useSidebarSync.ts
// (markUnreadSidebarItemRead) at v1.24.0-source.1
class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://public-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
    selectServer('s');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final calls = <String>[];
  Completer<dynamic>? pendingRead;
  bool failRead = false;
  int serverUnread = 1;
  List<Map<String, dynamic>> pageRows = [message('m', 1)];
  List<Map<String, dynamic>> syncRows = [];
  final channelRows = [
    RaftChannel({'id': 'c', 'name': 'design', 'joined': true}),
  ];

  static Map<String, dynamic> message(String id, int seq) => {
    'id': id,
    'channelId': 'c',
    'serverId': 's',
    'seq': '$seq',
    'content': 'Public fixture $id',
    'senderId': 'other',
    'senderType': 'user',
    'createdAt': '2026-10-08T00:00:00Z',
  };

  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<List<RaftRecord>> servers() async => [
    RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'}),
  ];
  @override
  Future<List<RaftChannel>> channels({bool dm = false}) async =>
      dm ? [] : channelRows;
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    calls.add('messages:$id');
    return {'messages': pageRows, 'threadSummariesByParentMessageId': {}};
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add('GET:$path');
    if (path == '/channels/unread') {
      return {
        'channels': {'c': serverUnread},
      };
    }
    if (path == '/messages/sync') return syncRows;
    if (path == '/channels/c') {
      return {'id': 'c', 'serverId': 's', 'name': 'design', 'joined': true};
    }
    if (path.endsWith('/sidebar-order')) {
      return {'pinned': [], 'customSections': [], 'sectionPlacements': []};
    }
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    }
    if (path == '/auth/providers') return {'providers': []};
    if (path == '/auth/identities') {
      return {'passwordConfigured': true, 'identities': []};
    }
    return [];
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    calls.add('POST:$path');
    if (path.endsWith('/read')) {
      if (pendingRead != null) return pendingRead!.future;
      if (failRead) throw const RaftApiException('boom', status: 500);
      serverUnread = 0;
      return {'maxReadSeq': int.parse('${data['seq']}'), 'readStateVersion': 1};
    }
    if (path == '/feature-flags/evaluate') return {'evaluations': []};
    return {};
  }

  int get reads => calls.where((c) => c == 'POST:/channels/c/read').length;
}

Future<WorkspaceController> _mobile(_Client c) async {
  final w = WorkspaceController(c, mobileNavigation: true);
  await w.bootstrap();
  w.setForeground(true);
  return w;
}

void main() {
  test('[BP-READ-034] a row that only shows an @ mark is read on tap: the mark clears at once and the read is posted', () async {
    final c = _Client()..serverUnread = 0;
    final w = await _mobile(c);
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    // Web v1.24: `!unreadCounts[id] && !mentionFlags[id]` returns, so a row
    // with a mention flag and no count is read like any unread row.
    expect(w.conversationReads.unread['c'] ?? 0, 0);
    w.conversationReads.mentions = {'c'};
    c.pendingRead = Completer<dynamic>();
    final open = w.selectChannel(w.channels.single);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(w.conversationReads.mentions, isNot(contains('c')));
    expect(c.reads, 1, reason: 'the read is posted before the receipt returns');
    c.pendingRead!.complete({'maxReadSeq': 1, 'readStateVersion': 1});
    await open;
    expect(c.reads, 1);
  });
}
