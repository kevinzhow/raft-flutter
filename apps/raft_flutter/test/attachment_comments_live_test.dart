import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_comments_view.dart';
import 'package:raft_flutter/features/management_support.dart'
    show pageIdentity, writePageSnapshot;
import 'package:raft_flutter/features/private_route_guard.dart';
import 'package:raft_ui/raft_ui.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  final incoming = StreamController<RaftEvent>.broadcast(sync: true);
  final reads = <({String path, Completer<dynamic> result})>[];
  final joins = <String>[];
  @override
  Stream<RaftEvent> get events => incoming.stream;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) {
    if (!path.endsWith('/comments')) return Future.value(<String, dynamic>{});
    final result = Completer<dynamic>();
    reads.add((path: path, result: result));
    return result.future;
  }

  @override
  void joinChannel(String id) => joins.add(id);
  @override
  Future<dynamic> post(String path, {dynamic data}) =>
      throw StateError('An incoming event must not mutate or follow');
  void event(String name, Map<String, dynamic> payload) =>
      incoming.add(RaftEvent(name, payload));
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client) : super(ownsClient: false);
  @override
  Future<void> refreshUnread() async {}
}

Map<String, dynamic> _row(String id) => {
  'id': id,
  'channelId': 'thread',
  'seq': '1',
  'content': id,
  'senderId': 'peer',
  'senderType': 'user',
  'senderName': 'Peer',
  'createdAt': '2026-11-05T00:00:00Z',
  // Canonical shared broadcasts intentionally scrub this viewer-scoped ref.
  'commentRef': null,
};

Map<String, dynamic> _response(List<String> ids, {String? thread = 'thread'}) =>
    {
      'comments': [for (final id in ids) _row(id)],
      'threadChannelId': thread,
      'viewer': {'canComment': true},
    };

Map<String, dynamic> _thread(String parent) => {
  'parentMessageId': parent,
  'threadChannelId': 'thread',
  'replyCount': 1,
  'lastReplyAt': '2026-11-05T00:00:00Z',
  'participantIds': ['peer'],
  'latestReply': {
    ..._row('reply'),
    'conversationContext': {
      'channelType': 'thread',
      'parentChannelId': 'parent-channel',
      'parentMessageId': parent,
    },
  },
};

void main() {
  late _Client client;
  late _Workspace workspace;
  setUp(() {
    client = _Client()..user = RaftRecord({'id': 'viewer'});
    client.selectServer('server');
    workspace = _Workspace(client)
      ..server = RaftRecord({'id': 'server', 'role': 'owner'})
      ..channel = RaftChannel({'id': 'parent-channel', 'joined': true});
  });
  tearDown(() async {
    workspace.dispose();
    await client.dispose();
    await client.incoming.close();
  });
  Widget host({
    String id = 'file',
    String? parent,
    WorkspaceController? owner,
  }) => MaterialApp(
    theme: raftTheme(),
    home: Scaffold(
      body: AttachmentCommentsView(
        controller: owner ?? workspace,
        attachmentId: id,
        filename: 'report.md',
        hostMessageId: parent,
      ),
    ),
  );
  Future<void> opened(
    WidgetTester tester, {
    String? parent,
    List<String> ids = const ['before'],
    String? thread = 'thread',
  }) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(host(parent: parent));
    client.reads.single.result.complete(_response(ids, thread: thread));
    await tester.pump();
    for (final id in ids) {
      expect(find.text(id), findsOneWidget);
    }
  }

  testWidgets('known thread message reloads the real panel without reopening', (
    tester,
  ) async {
    await opened(tester);
    client.event('message:new', _row('incoming'));
    await tester.pump();
    expect(client.reads, hasLength(2));
    expect(find.text('before'), findsOneWidget);
    client.reads.last.result.complete(_response(['before', 'incoming']));
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<RaftAttachmentCommentsPanel>(
            find.byType(RaftAttachmentCommentsPanel),
          )
          .comments!
          .map((row) => row.id),
      ['before', 'incoming'],
    );
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    expect(find.text('incoming'), findsOneWidget);
    expect(client.joins, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'loaded comment update without channel refreshes and keeps draft',
    (tester) async {
      await opened(tester);
      await tester.enterText(find.byType(EditableText), 'draft stays');
      client.event('message:updated', {'id': 'before', 'commentRef': null});
      await tester.pump();
      expect(client.reads, hasLength(2));
      client.reads.last.result.complete(_response(['updated']));
      await tester.pump();
      expect(find.text('updated'), findsOneWidget);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'draft stays',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('events during a held GET retain one subsequent scoped read', (
    tester,
  ) async {
    await opened(tester);
    client.event('message:new', _row('pre-ref'));
    await tester.pump();
    expect(client.reads, hasLength(2));
    client.event('message:updated', _row('post-ref'));
    client.event('message:updated', _row('post-ref'));
    await tester.pump();
    expect(client.reads, hasLength(2));
    client.reads[1].result.complete(_response(['before']));
    await tester.pump();
    expect(client.reads, hasLength(3));
    client.reads[2].result.complete(_response(['committed']));
    await tester.pump();
    expect(find.text('committed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('authorized host parent hint discovers committed first comment', (
    tester,
  ) async {
    await opened(tester, parent: 'host', ids: [], thread: null);
    client.event('thread:updated', _thread('host'));
    await tester.pump();
    expect(client.reads, hasLength(2));
    expect(client.reads.last.path, '/attachments/file/comments');
    client.reads.last.result.complete(_response(['first committed']));
    await tester.pump();
    await tester.pump();
    expect(find.text('first committed'), findsOneWidget);
    expect(client.joins, isEmpty);
  });

  testWidgets('delivered post-ref update survives an empty pre-ref GET', (
    tester,
  ) async {
    await opened(tester, parent: 'host', ids: [], thread: null);
    client.event('thread:updated', _thread('host'));
    await tester.pump();
    expect(client.reads, hasLength(2));
    // The initial server hint is pre-ref. Only a separately DELIVERED later
    // event can guarantee another GET; this test does not prove room delivery.
    client.event('message:updated', _row('now-ref-committed'));
    await tester.pump();
    expect(client.reads, hasLength(2));
    client.reads[1].result.complete(_response([], thread: null));
    await tester.pump();
    expect(client.reads, hasLength(3));
    client.reads[2].result.complete(_response(['now-ref-committed']));
    await tester.pump();
    await tester.pump();
    expect(find.text('now-ref-committed'), findsOneWidget);
    expect(client.joins, isEmpty);
  });

  testWidgets(
    'unknown thread with no delivered post-ref signal is NOT_CLOSED',
    (tester) async {
      await opened(tester, parent: 'host', ids: [], thread: null);
      client.event('thread:updated', _thread('host'));
      await tester.pump();
      client.reads[1].result.complete(_response([], thread: null));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(client.reads, hasLength(2), reason: 'No guessed retry or polling');
      expect(
        client.joins,
        isEmpty,
        reason: 'No hidden follow or room mutation',
      );
      expect(find.text('undelivered committed comment'), findsNothing);
    },
  );

  testWidgets(
    'unrelated parent, server and comment cannot refresh this panel',
    (tester) async {
      await opened(tester, parent: 'host');
      client.event('thread:updated', _thread('another host'));
      client.event('thread:updated', {
        ..._thread('host'),
        'serverId': 'elsewhere',
      });
      client.event('message:new', {..._row('elsewhere'), 'channelId': 'other'});
      client.event('message:updated', {'id': 'not loaded', 'commentRef': null});
      client.event('message:updated', {
        ..._row('before'),
        'serverId': 'elsewhere',
      });
      await tester.pump();
      expect(client.reads, hasLength(1));
      expect(find.text('before'), findsOneWidget);
    },
  );

  testWidgets('missing host context never guesses it from the open channel', (
    tester,
  ) async {
    await opened(tester, ids: [], thread: null);
    client.event('thread:updated', _thread('parent-channel'));
    client.event('thread:updated', _thread('host'));
    await tester.pump();
    expect(client.reads, hasLength(1));
  });

  testWidgets('host context rebind keeps draft and ignores the previous host', (
    tester,
  ) async {
    await opened(tester, parent: 'old host', ids: [], thread: null);
    await tester.enterText(find.byType(EditableText), 'same draft');
    await tester.pumpWidget(host(parent: 'new host'));
    client.event('thread:updated', _thread('old host'));
    await tester.pump();
    expect(client.reads, hasLength(1));
    client.event('thread:updated', _thread('new host'));
    await tester.pump();
    expect(client.reads, hasLength(2));
    client.reads.last.result.complete(_response(['new host row']));
    await tester.pump();
    await tester.pump();
    expect(find.text('new host row'), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'same draft',
    );
  });

  testWidgets('attachment rebind discards old held reads and queued events', (
    tester,
  ) async {
    await opened(tester, parent: 'old host');
    client.event('message:new', _row('pending old'));
    await tester.pump();
    client.event('message:updated', _row('queued old'));
    await tester.pumpWidget(host(id: 'new file', parent: 'new host'));
    expect(client.reads, hasLength(3));
    expect(client.reads.last.path, '/attachments/new file/comments');
    client.reads[1].result.complete(_response(['stale private']));
    client.reads[2].result.complete(
      _response(['new row'], thread: 'new thread'),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('stale private'), findsNothing);
    expect(find.text('new row'), findsOneWidget);
    client.event('message:new', _row('old thread event'));
    await tester.pump();
    expect(client.reads, hasLength(3));
  });

  testWidgets('revocation fences a held read and stops later event requests', (
    tester,
  ) async {
    await opened(tester, parent: 'host');
    client.event('message:new', _row('held'));
    await tester.pump();
    workspace.server = RaftRecord({'id': 'different server', 'role': 'owner'});
    workspace.notifyListeners();
    client.reads[1].result.complete(_response(['old private row']));
    client.event('message:updated', _row('after revoke'));
    await tester.pump();
    expect(client.reads, hasLength(2));
    expect(find.text('old private row'), findsNothing);
  });

  testWidgets('dispose cancels queued work and ignores late read completion', (
    tester,
  ) async {
    await opened(tester);
    client.event('message:new', _row('held'));
    await tester.pump();
    client.event('message:updated', _row('queued'));
    await tester.pumpWidget(const SizedBox());
    client.reads[1].result.complete(_response(['too late']));
    client.event('message:new', _row('after dispose'));
    await tester.pump();
    expect(client.reads, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed live revalidation keeps old content and composer draft', (
    tester,
  ) async {
    await opened(tester);
    await tester.enterText(find.byType(EditableText), 'preserved draft');
    client.event('message:updated', _row('before'));
    await tester.pump();
    client.reads.last.result.completeError(StateError('temporary failure'));
    await tester.pump();
    await tester.pump();
    expect(find.text('before'), findsOneWidget);
    expect(find.text('Failed to load comments'), findsNothing);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'preserved draft',
    );
  });

  testWidgets('controller rebind removes the old client event subscription', (
    tester,
  ) async {
    await opened(tester);
    final other = _Client()..user = RaftRecord({'id': 'viewer'});
    other.selectServer('server');
    final next = _Workspace(other)
      ..server = RaftRecord({'id': 'server', 'role': 'owner'})
      ..channel = RaftChannel({'id': 'parent-channel', 'joined': true});
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      next.dispose();
      await other.dispose();
      await other.incoming.close();
    });
    await tester.pumpWidget(host(owner: next));
    other.reads.single.result.complete(_response(['next controller']));
    await tester.pump();
    client.event('message:new', _row('old receiver'));
    await tester.pump();
    expect(client.reads, hasLength(1));
    expect(other.reads, hasLength(1));
    other.event('message:updated', {'id': 'next controller'});
    await tester.pump();
    expect(other.reads, hasLength(2));
    other.reads.last.result.complete(_response(['current receiver']));
    await tester.pump();
    await tester.pump();
    expect(find.text('current receiver'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('older in-memory snapshot without thread id remains usable', (
    tester,
  ) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    writePageSnapshot(
      workspace,
      'attachment-comments:file',
      pageIdentity(workspace),
      {
        'authority': workspaceAuthority(workspace),
        'comments': [_row('cached old schema')],
        'viewer': <String, dynamic>{'canComment': true},
      },
    );
    await tester.pumpWidget(host());
    expect(find.text('cached old schema'), findsOneWidget);
    client.event('message:updated', {'id': 'cached old schema'});
    await tester.pump();
    expect(client.reads, hasLength(1), reason: 'Initial GET is still held');
    client.reads.single.result.complete(
      _response(['cached old schema'], thread: null),
    );
    await tester.pump();
    expect(client.reads, hasLength(2));
    client.reads.last.result.complete(_response(['fresh server content']));
    await tester.pump();
    await tester.pump();
    expect(find.text('fresh server content'), findsOneWidget);
  });
}
