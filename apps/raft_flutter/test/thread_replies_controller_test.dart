import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_sync/raft_sync.dart';

class _Client extends RaftClient {
  _Client(_Transport transport)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = transport,
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<void> dispose() async {
    await stream.close();
    await super.dispose();
  }
}

class _Transport implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Completer<void>? snapshot;
  final snapshotStarted = Completer<void>();
  var snapshotReads = 0;
  bool prefsEnabled = true;
  Completer<void>? flags;
  Map<String, dynamic> channelPage = {
    'messages': <dynamic>[],
    'threadSummariesByParentMessageId': {},
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? cancel,
  ) async {
    requests.add(o);
    dynamic body;
    if (o.path == '/auth/login') {
      body = {
        'accessToken': 'fixture',
        'refreshToken': 'fixture',
        'user': {'id': 'alice'},
      };
    } else if (o.path == '/feature-flags/evaluate') {
      if (flags != null) await flags!.future;
      body = {
        'evaluations': [
          {'key': 'sync_core_messages_v0', 'enabled': false},
          {'key': notificationPrefsFlag, 'enabled': prefsEnabled},
        ],
      };
    } else if (o.path == '/messages/channel/thread' ||
        o.path == '/channels/channel/threads/parent') {
      snapshotReads++;
      if (snapshotReads == 2 && !snapshotStarted.isCompleted) {
        snapshotStarted.complete();
      }
      if (snapshot != null) await snapshot!.future;
      body = o.path.startsWith('/messages')
          ? {
              'messages': [_reply(4), _reply(6)],
              'historyLimited': true,
            }
          : {'threadChannelId': 'thread', 'replyCount': 6};
    } else if (o.path == '/messages/channel/channel') {
      body = channelPage;
    } else {
      body = {'channels': {}};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _reply(int seq) => {
  'id': 'r$seq',
  'seq': seq,
  'content': 'Reply $seq 中文',
  'senderType': 'user',
  'senderId': 'alice',
  'senderName': 'alice',
  'senderDisplayName': 'Alice',
  'senderAvatarUrl': 'https://example.invalid/avatar.png',
  'createdAt': '2026-10-08T00:00:00Z',
  'conversationContext': {
    'channelType': 'thread',
    'parentMessageId': 'parent',
    'parentChannelId': 'channel',
    'parentChannelType': 'private',
  },
};
Map<String, dynamic> _frame(int seq, {String epoch = 'one'}) => {
  'parentMessageId': 'parent',
  'threadChannelId': 'thread',
  'replyCount': seq,
  'lastReplyAt': '2026-10-08T00:00:00Z',
  'participantIds': ['alice'],
  'latestReply': _reply(seq),
  'syncCoreReplyWindow': {
    'producer': threadRepliesProducer,
    'discussion': {
      'root': {'kind': 'message', 'serverId': 'server', 'id': 'parent'},
      'relation': {'kind': 'replies'},
      'backing': 'sync-scope',
      'parentScopeKey': {
        'serverId': 'server',
        'scopeKind': 'private',
        'scopeId': 'channel',
      },
    },
    'window': {
      'kind': 'sync-scope-window',
      'scopeCursor': null,
      'epoch': epoch,
    },
  },
};
Future<WorkspaceController> _fixture(_Transport t) async {
  final c = _Client(t);
  await c.login('fixture', 'fixture');
  c.selectServer('server');
  final w = WorkspaceController(c)
    ..server = RaftRecord({'id': 'server', 'role': 'owner'})
    ..servers = [
      RaftRecord({'id': 'server', 'role': 'owner'}),
    ]
    ..channels = [
      RaftChannel({'id': 'channel', 'type': 'private', 'joined': true}),
    ];
  // Summaries are held per parent channel; the selected one is projected.
  w.channel = w.channels.single;
  w.ledger.switchServer('server');
  return w;
}

void _emit(WorkspaceController w, Map<String, dynamic> p) =>
    (w.client as _Client).stream.add(RaftEvent('thread:updated', p));
Future<void> _settle() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Map<String, dynamic> _prefs(
  int version, {
  String server = 'server',
  bool muted = true,
}) => {
  'serverId': server,
  'scopeId': 'channel',
  'prefsVersion': version,
  'prefs': {'activityMuted': muted, 'muteFromSeq': '42'},
};
void main() {
  test('actual controller eligible threads use sparse adapter even message flag off', () async {
    final t = _Transport(), w = await _fixture(t);
    addTearDown(w.dispose);
    await w.refreshMessageSyncFlag();
    expect(w.syncCoreMessagesEnabled, false);
    _emit(w, _frame(3));
    _emit(w, _frame(10));
    _emit(w, _frame(4));
    expect(w.threadSummaries['parent']['replyCount'], 10);
    expect(
      (w.threadSummaries['parent']['latestReplies'] as List).map(
        (dynamic r) => r['seq'],
      ),
      [3, 10],
    );
    expect(t.snapshotReads, 0);
  });
  test(
    'accepted thread summaries update locally without an unread snapshot',
    () async {
      final t = _Transport()..snapshot = Completer<void>();
      final w = await _fixture(t);
      addTearDown(w.dispose);
      int unreadReads() =>
          t.requests.where((o) => o.path == '/channels/unread').length;
      // A tracked followed thread takes the server's own per-thread count.
      w.unread = {'thread': 5};
      _emit(w, {..._frame(90), 'unreadCount': 2});
      await _settle();
      expect(w.threadSummaries['parent']['replyCount'], 90);
      expect(w.unread['thread'], 2);
      _emit(w, _frame(90));
      _emit(w, _frame(9));
      await _settle();
      _emit(w, _frame(5, epoch: 'two'));
      await t.snapshotStarted.future;
      _emit(w, _frame(7, epoch: 'two'));
      await _settle();
      t.snapshot!.complete();
      await _settle();
      // Rebaselined snapshot (6) plus the replayed pending frame (7).
      expect(w.threadSummaries['parent']['replyCount'], 7);
      expect(unreadReads(), 0);
    },
  );
  test('epoch rebaseline uses mounted snapshot pair and replays newest pending frame', () async {
    final t = _Transport()..snapshot = Completer<void>();
    final w = await _fixture(t);
    addTearDown(w.dispose);
    _emit(w, _frame(90));
    _emit(w, _frame(5, epoch: 'two'));
    await t.snapshotStarted.future;
    _emit(w, _frame(7, epoch: 'two'));
    _emit(w, _frame(7, epoch: 'two'));
    expect(t.snapshotReads, 2);
    expect(w.threadSummaries['parent']['replyCount'], 90);
    expect(
      t.requests
          .singleWhere((o) => o.path == '/messages/channel/thread')
          .queryParameters,
      {'limit': 3},
    );
    t.snapshot!.complete();
    await _settle();
    final summary = w.threadSummaries['parent'];
    expect(summary['replyCount'], 7);
    final previews = summary['latestReplies'] as List;
    expect(previews.map((dynamic r) => r['seq']), [4, 6, 7]);
    expect(previews.first['senderName'], 'alice');
    expect(previews.first['senderDisplayName'], 'Alice');
    expect(
      previews.first['senderAvatarUrl'],
      'https://example.invalid/avatar.png',
    );
    final id = w.threadRepliesSync.scopeId(
      'server',
      'alice',
      'parent',
      'thread',
    );
    expect(w.threadRepliesSync.scope(id)!.historyLimited, true);
  });
  for (final change in ['role', 'channel', 'workspace']) {
    test(
      'late private reply snapshot cannot reapply after $change authority change',
      () async {
        final t = _Transport()..snapshot = Completer<void>();
        final w = await _fixture(t);
        addTearDown(w.dispose);
        _emit(w, _frame(90));
        _emit(w, _frame(5, epoch: 'two'));
        await t.snapshotStarted.future;
        if (change == 'role') {
          w.applyMembershipRole({
            'serverId': 'server',
            'userId': 'alice',
            'role': 'member',
          });
        } else if (change == 'channel') {
          (w.client as _Client).stream.add(
            RaftEvent('channel:removed', {'channelId': 'channel'}),
          );
        } else {
          w.client.selectServer('other');
          w.server = RaftRecord({'id': 'other', 'role': 'owner'});
          w.notifyListeners();
        }
        t.snapshot!.complete();
        await _settle();
        final id = w.threadRepliesSync.scopeId(
          'server',
          'alice',
          'parent',
          'thread',
        );
        expect(w.threadRepliesSync.scope(id), isNull);
        expect(w.threadSummaries['parent'], isNull);
      },
    );
  }
  test('bundled HTTP previews hydrate watermark and legacy count-only summary survives', () async {
    final t = _Transport()
      ..channelPage = {
        'messages': [
          {
            'id': 'parent',
            'channelId': 'channel',
            'seq': 1,
            'content': 'Parent',
          },
        ],
        'threadSummariesByParentMessageId': {
          'parent': {
            'threadChannelId': 'thread',
            'replyCount': 3,
            'latestReplies': [projectThreadReply(_reply(3))],
          },
        },
      };
    final w = await _fixture(t);
    addTearDown(w.dispose);
    await w.selectChannel(w.channels.single, autoRead: false);
    _emit(w, _frame(2));
    expect(w.threadSummaries['parent']['replyCount'], 3);
    _emit(w, {
      'parentMessageId': 'parent',
      'threadChannelId': 'thread',
      'replyCount': 4,
    });
    expect(w.threadSummaries['parent']['replyCount'], 4);
  });
  test('real preference flag/query and socket projection reject regression and wrong server', () async {
    final t = _Transport(), w = await _fixture(t);
    addTearDown(w.dispose);
    await w.refreshMessageSyncFlag();
    expect(w.syncCoreNotificationPrefsEnabled, true);
    expect(t.requests.last.data['keys'], [
      'sync_core_messages_v0',
      notificationPrefsFlag,
    ]);
    final c = w.client as _Client;
    c.stream.add(RaftEvent('notification_prefs:updated', _prefs(2)));
    expect(w.channels.single.json['activityMuted'], true);
    c.stream.add(
      RaftEvent('notification_prefs:updated', _prefs(1, muted: false)),
    );
    c.stream.add(
      RaftEvent(
        'notification_prefs:updated',
        _prefs(99, server: 'other', muted: false),
      ),
    );
    expect(w.channels.single.json['activityMuted'], true);
    c.stream.add(
      RaftEvent('notification_prefs:updated', {
        'serverId': 'server',
        'scopeId': 'server',
        'prefsVersion': 8,
        'prefs': {'serverPushMuted': true},
      }),
    );
    expect(w.server!.json['serverPushMuted'], true);
    expect(w.server!.json['notificationPrefsVersion'], 8);
  });
  test('late preference flag response cannot enable same-generation role or workspace', () async {
    final t = _Transport()..flags = Completer<void>();
    final w = await _fixture(t);
    addTearDown(w.dispose);
    final pending = w.refreshMessageSyncFlag();
    w.server = RaftRecord({'id': 'server', 'role': 'member'});
    w.notifyListeners();
    t.flags!.complete();
    await pending;
    expect(w.syncCoreNotificationPrefsEnabled, false);
  });
}
