import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_offline_notice.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';
import 'package:raft_ui/raft_ui.dart';

class _Transport implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    final login = o.path == '/auth/login',
        read = o.path == '/channels/c1/read',
        create = o.path == '/agents' && o.method == 'POST';
    return ResponseBody.fromString(
      jsonEncode(
        login
            ? {
                'accessToken': 'test-only',
                'refreshToken': 'test-only',
                'user': {'id': 'alice'},
              }
            : read
            ? {'maxReadSeq': 5, 'readStateVersion': 7}
            : create
            ? {'id': 'created-agent'}
            : {'error': 'offline'},
      ),
      login || read || create ? 200 : 503,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _NoticeClient extends RaftClient {
  _NoticeClient()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );

  final messages = StreamController<RaftEvent>.broadcast(sync: true);

  @override
  Stream<RaftEvent> get events => messages.stream;
}

void main() {
  testWidgets(
    'cached startup is marked offline until the session is accepted',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final client = _NoticeClient()..restoredOffline = true;
        addTearDown(client.messages.close);
        addTearDown(client.dispose);

        final badge = find.byKey(const Key('workspace-offline-indicator'));
        final reason = find.byKey(const Key('workspace-offline-reason'));
        Widget view() => MaterialApp(
          theme: raftTheme(),
          home: Column(
            children: [
              WorkspaceOfflineNotice(
                client: client,
                presentation: WorkspaceOfflinePresentation.compactIndicator,
              ),
              WorkspaceOfflineNotice(
                client: client,
                presentation: WorkspaceOfflinePresentation.banner,
              ),
            ],
          ),
        );
        await tester.pumpWidget(view());
        expect(badge, findsOneWidget);
        expect(find.text('Offline'), findsOneWidget);
        expect(reason, findsOneWidget);

        client.messages.add(const RaftEvent('session:degraded', null));
        await tester.pump();
        expect(badge, findsOneWidget);

        client.restoredOffline = false;
        client.messages.add(const RaftEvent('session:recovered', null));
        await tester.pump();
        expect(badge, findsNothing);
        expect(reason, findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(view());
        expect(badge, findsNothing);
      } finally {
        semantics.dispose();
      }
    },
  );

  test('a failed secondary unread refresh cannot turn an accepted command into a failed creation', () async {
    final client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = _Transport(),
    );
    await client.login('test', 'test');
    client.selectServer('s1');
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'});
    addTearDown(w.dispose);
    final result = await w.command(
      'POST',
      '/agents',
      data: {'name': 'Fixture agent'},
    );
    expect(result['id'], 'created-agent');
  });
  test('accepted read receipt persists across an offline native restart even when summary fails', () async {
    final client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = _Transport(),
    );
    await client.login('test', 'test');
    client.selectServer('s1');
    final db = DriftWorkspaceCache(NativeDatabase.memory());
    final server = RaftRecord({'id': 's1', 'role': 'owner'});
    final channel = RaftChannel({
      'id': 'c1',
      'name': 'cached-channel',
      'joined': true,
    });
    final w = WorkspaceController(client, cache: db);
    w.server = server;
    w.channel = channel;
    w.channels = [channel];
    w.messageDomain.ledger.switchServer('s1');
    w.messageDomain.ledger.ingest([
      {'id': 'm1', 'channelId': 'c1', 'content': 'cached', 'seq': '5'},
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds['c1'] = {'m1'};
    await db.write(client.origin, 'alice', 's1', 'channels', '', {
      'channels': [channel.json],
      'dms': [],
    });
    await db.write(client.origin, 'alice', 's1', 'selection', '', 'c1');
    await w.markRead('c1');
    await w.flushCache();
    expect(w.readState.state('s1', 'alice', 'c1')?['readStateVersion'], 7);
    w.dispose();
    final restoredClient = RaftClient(
      origin: client.origin,
      sessionStore: client.sessionStore,
      transport: Dio()..httpClientAdapter = _Transport(),
    );
    expect(await restoredClient.restore(), true);
    expect(restoredClient.restoredOffline, true);
    final restored = WorkspaceController(restoredClient, cache: db);
    await restored.selectServer(server);
    expect(restored.channel?.id, 'c1');
    expect(restored.readState.state('s1', 'alice', 'c1')?['maxReadSeq'], 5);
    expect(
      restored.readState.state('s1', 'alice', 'c1')?['readStateVersion'],
      7,
    );
    restored.revokeServer('s1');
    await restored.flushCache();
    expect(
      await db.read(client.origin, 'alice', 's1', 'read-frontiers', ''),
      isNull,
    );
    restored.dispose();
    await db.close();
    await client.dispose();
  });
}
