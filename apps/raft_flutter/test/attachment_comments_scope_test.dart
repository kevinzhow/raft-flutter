import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_comments_view.dart';
import 'package:raft_ui/raft_ui.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  final reads = <({String path, Completer<dynamic> result})>[];
  final writes = <({String path, dynamic data, Completer<dynamic> result})>[];
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) {
    final result = Completer<dynamic>();
    reads.add((path: path, result: result));
    return result.future;
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) {
    final result = Completer<dynamic>();
    writes.add((path: path, data: data, result: result));
    return result.future;
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  int refreshes = 0;
  @override
  Future<void> refreshUnread() async {
    ++refreshes;
  }
}

Map<String, dynamic> response(String body, {bool canComment = true}) => {
  'comments': [
    {
      'id': body,
      'content': body,
      'senderId': 'human',
      'senderType': 'user',
      'senderName': 'Public Human',
      'createdAt': '2026-06-22T00:00:00Z',
    },
  ],
  'viewer': {'canComment': canComment, 'reason': 'read_only'},
};

void main() {
  late _Client client;
  late _Workspace w;
  setUp(() {
    client = _Client()..user = RaftRecord({'id': 'alice'});
    client.selectServer('server');
    w = _Workspace(client)
      ..server = RaftRecord({'id': 'server', 'role': 'owner'})
      ..channel = RaftChannel({'id': 'channel', 'joined': true});
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });
  Widget host(
    String id, {
    bool Function()? authorized,
    WorkspaceController? owner,
  }) => MaterialApp(
    theme: raftTheme(RaftFamily.elegant),
    home: Scaffold(
      body: AttachmentCommentsView(
        key: const Key('same-comments-slot'),
        controller: owner ?? w,
        attachmentId: id,
        filename: '$id.txt',
        authorized: authorized,
      ),
    ),
  );

  testWidgets(
    'same State rebind discards old attachment read and captured send',
    (t) async {
      await t.pumpWidget(host('first'));
      client.reads[0].result.complete(response('first-private'));
      await t.pump();
      final state = t.state(find.byType(AttachmentCommentsView));
      final oldSend = t.widget<RaftComposer>(find.byType(RaftComposer)).onSend;
      await t.pumpWidget(host('second'));
      expect(t.state(find.byType(AttachmentCommentsView)), same(state));
      expect(find.text('first-private'), findsNothing);
      expect(await oldSend('stale'), false);
      expect(client.writes, isEmpty);
      client.reads[1].result.complete(response('second-public'));
      await t.pump();
      expect(find.text('second-public'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'same State controller replacement detaches old authority listener',
    (t) async {
      final otherClient = _Client()..user = RaftRecord({'id': 'bob'});
      otherClient.selectServer('server');
      final other = _Workspace(otherClient)
        ..server = RaftRecord({'id': 'server', 'role': 'owner'})
        ..channel = RaftChannel({'id': 'channel', 'joined': true});
      await t.pumpWidget(host('file'));
      await t.pumpWidget(host('file', owner: other));
      otherClient.reads.single.result.complete(response('bob-public'));
      await t.pump();
      w.server = null;
      w.notifyListeners();
      client.reads.single.result.complete(response('alice-private'));
      await t.pump();
      expect(find.text('bob-public'), findsOneWidget);
      expect(find.text('alice-private'), findsNothing);
      await t.pumpWidget(const SizedBox());
      other.dispose();
      await otherClient.dispose();
    },
  );

  testWidgets('pending old read cannot overwrite new attachment projection', (
    t,
  ) async {
    await t.pumpWidget(host('first'));
    await t.pumpWidget(host('second'));
    client.reads[1].result.complete(response('second-public'));
    await t.pump();
    client.reads[0].result.complete(response('first-private'));
    await t.pump();
    expect(find.text('second-public'), findsOneWidget);
    expect(find.text('first-private'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'same generation authority revokes visible rows and old callback before POST',
    (t) async {
      await t.pumpWidget(host('file'));
      client.reads[0].result.complete(response('private-row'));
      await t.pump();
      final send = t.widget<RaftComposer>(find.byType(RaftComposer)).onSend;
      final generation = client.generation;
      w.server = RaftRecord({'id': 'server', 'role': 'member'});
      w.notifyListeners();
      await t.pump();
      expect(client.generation, generation);
      expect(find.text('private-row'), findsNothing);
      expect(await send('stale'), false);
      expect(client.writes, isEmpty);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'attachment visibility revocation fences pending mutation and hidden unread refresh',
    (t) async {
      var visible = true;
      await t.pumpWidget(host('file', authorized: () => visible));
      client.reads[0].result.complete(response('private-row'));
      await t.pump();
      final send = t.widget<RaftComposer>(find.byType(RaftComposer)).onSend;
      final pending = send('allowed');
      expect(client.writes.single.path, '/attachments/file/comments');
      visible = false;
      w.notifyListeners();
      client.writes.single.result.complete({});
      expect(await pending, false);
      await t.pump();
      expect(w.refreshes, 0);
      expect(client.reads, hasLength(1));
      expect(find.text('private-row'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('viewer write gate and source HTML y sorting are preserved', (
    t,
  ) async {
    await t.pumpWidget(host('file'));
    Map<String, dynamic> comment(String name, int y) => {
      ...((response(name)['comments'] as List).single as Map<String, dynamic>),
      'anchor': {
        'type': 'html-region',
        'data': {'y': y},
      },
    };
    client.reads[0].result.complete({
      'comments': [comment('last', 100), comment('first', 10)],
      'viewer': {'canComment': false, 'reason': 'archived'},
    });
    await t.pump();
    expect(
      t.getTopLeft(find.text('first')).dy,
      lessThan(t.getTopLeft(find.text('last')).dy),
    );
    expect(find.byType(RaftComposer), findsNothing);
    expect(find.text('Channel archived'), findsOneWidget);
    expect(client.writes, isEmpty);
    await t.pumpWidget(const SizedBox());
  });
}
