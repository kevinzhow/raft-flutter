import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/user_activity.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show contextRows;

/// Source messageStore read-state parity: opening clears the local unread,
/// the read receipt survives the user backing out, scrolling back to the
/// latest end reads, and returning to the foreground reads.
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
  test('[BP-READ-001] opening a conversation clears its Home unread even when the user backs out before the receipt resolves', () async {
    final c = _Client();
    final w = await _mobile(c);
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    expect(w.section, 'home');
    expect(w.unread['c'], 1);
    c.pendingRead = Completer<dynamic>();
    final open = w.selectChannel(w.channels.single);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    // Source clears the local unread on open, before any network round trip.
    expect(w.unread['c'], 0);
    expect(c.calls, contains('POST:/channels/c/read'));
    // Back to Home while the receipt is still in flight.
    w.setSection('home');
    c.pendingRead!.complete({'maxReadSeq': 1, 'readStateVersion': 1});
    await open;
    await Future<void>.delayed(Duration.zero);
    expect(w.section, 'home');
    expect(w.unread['c'] ?? 0, 0);
  });

  test('opening a conversation clears its mention marker with the count (Web clearUnread)', () async {
    final c = _Client();
    final w = await _mobile(c);
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    w.mentions = {'c'};
    c.pendingRead = Completer<dynamic>();
    final open = w.selectChannel(w.channels.single);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(w.unread['c'], 0);
    expect(w.mentions, isNot(contains('c')));
    c.pendingRead!.complete({'maxReadSeq': 1, 'readStateVersion': 1});
    await open;
  });

  test('a successful receipt for a conversation the user already left clears the stale unread', () async {
    final c = _Client();
    final w = await _mobile(c);
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    await w.selectChannel(w.channels.single);
    expect(w.unread['c'], 0);
    // The member marks it unread, then a read is in flight when they leave.
    w.markUnreadLocally('c');
    expect(w.unread['c'], 1);
    c.pendingRead = Completer<dynamic>();
    final read = w.markRead('c');
    await Future<void>.delayed(Duration.zero);
    w.setSection('home');
    c.pendingRead!.complete({'maxReadSeq': 1, 'readStateVersion': 2});
    await read;
    expect(w.unread['c'], 0);
  });

  test(
    'a failed receipt restores the server unread after the optimistic clear',
    () async {
      final c = _Client();
      final w = await _mobile(c);
      addTearDown(() async {
        w.dispose();
        await c.stream.close();
      });
      c.failRead = true;
      await w.selectChannel(w.channels.single);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(c.reads, 1);
      expect(w.unread['c'], 1);
    },
  );

  test('a stale receipt never erases messages that arrived after it', () async {
    final c = _Client();
    final w = await _mobile(c);
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    await w.selectChannel(w.channels.single);
    c.pendingRead = Completer<dynamic>();
    final read = w.markRead('c');
    await Future<void>.delayed(Duration.zero);
    w.setSection('home');
    c.serverUnread = 1;
    c.stream.add(RaftEvent('message:new', _Client.message('newer', 5)));
    await Future<void>.delayed(Duration.zero);
    expect(w.unread['c'], 1);
    c.pendingRead!.complete({'maxReadSeq': 1, 'readStateVersion': 3});
    await read;
    await Future<void>.delayed(Duration.zero);
    expect(w.unread['c'], 1);
  });

  test(
    '[BP-READ-054] returning to the foreground with the conversation open sends the read',
    () async {
      final c = _Client();
      final w = await _mobile(c);
      addTearDown(() async {
        w.dispose();
        await c.stream.close();
      });
      await w.selectChannel(w.channels.single);
      final before = c.reads;
      w.setForeground(false);
      c.pageRows = [...c.pageRows, _Client.message('later', 2)];
      c.stream.add(RaftEvent('message:new', _Client.message('later', 2)));
      await Future<void>.delayed(Duration.zero);
      // Backgrounded: counted, not read.
      expect(c.reads, before);
      expect(w.unread['c'], 1);
      w.setForeground(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(c.reads, before + 1);
      expect(w.unread['c'], 0);
    },
  );

  test('[BP-READ-015] phone: a live append at the bottom is read with no pointer activity (owner decision 2026-10-12)', () async {
    final c = _Client();
    final w = await _mobile(c);
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    await w.selectChannel(w.channels.single);
    final before = c.reads;
    RaftUserActivity.forget();
    expect(RaftUserActivity.recent, false);
    c.stream.add(RaftEvent('message:new', _Client.message('live', 2)));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.reads, before + 1);
    expect(w.unread['c'] ?? 0, 0);
  });

  test(
    '[BP-READ-016] phone: a live append while scrolled above the bottom stays unread',
    () async {
      final c = _Client();
      final w = await _mobile(c);
      addTearDown(() async {
        w.dispose();
        await c.stream.close();
      });
      await w.selectChannel(w.channels.single);
      final before = c.reads;
      RaftUserActivity.forget();
      w.setTimelineAtBottom('c', false);
      c.stream.add(RaftEvent('message:new', _Client.message('live', 2)));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(c.reads, before);
      expect(w.unread['c'], 1);
    },
  );

  test('desktop: a live append without recent activity stays unread (Web 1 s gate)', () async {
    final c = _Client();
    final w = WorkspaceController(c);
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    await w.bootstrap();
    w.setForeground(true);
    await w.selectChannel(w.channels.single);
    final before = c.reads;
    RaftUserActivity.forget();
    c.stream.add(RaftEvent('message:new', _Client.message('live', 2)));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.reads, before);
    expect(w.unread['c'], 1);
    // With recent activity the same arrival is read.
    RaftUserActivity.mark();
    c.stream.add(RaftEvent('message:new', _Client.message('live2', 3)));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.reads, before + 1);
  });

  test('[BP-READ-016] desktop: a live append while scrolled above the bottom stays unread even with recent activity', () async {
    final c = _Client();
    final w = WorkspaceController(c);
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    await w.bootstrap();
    w.setForeground(true);
    await w.selectChannel(w.channels.single);
    final before = c.reads;
    w.setTimelineAtBottom('c', false);
    RaftUserActivity.mark();
    c.stream.add(RaftEvent('message:new', _Client.message('live', 2)));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.reads, before);
    expect(w.unread['c'], 1);
    // Back at the latest end the same arrival is read.
    w.setTimelineAtBottom('c', true);
    RaftUserActivity.mark();
    c.stream.add(RaftEvent('message:new', _Client.message('live2', 3)));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.reads, before + 1);
  });

  test('[BP-READ-024] a gap fill while scrolled above the bottom counts the arrivals instead of reading them', () async {
    final c = _Client();
    final w = WorkspaceController(c);
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    await w.bootstrap();
    w.setForeground(true);
    await w.selectChannel(w.channels.single);
    final before = c.reads;
    w.setTimelineAtBottom('c', false);
    c.syncRows = [_Client.message('gap1', 2), _Client.message('gap2', 3)];
    await w.messageDomain.navigation.syncVisibleScopes();
    await Future<void>.delayed(Duration.zero);
    expect(w.messageDomain.messages.map((m) => m.id), containsAll(['gap1', 'gap2']));
    expect(c.reads, before, reason: 'the reader never reached these rows');
    expect(w.unread['c'], 2);
  });

  test('[BP-READ-024] a gap fill at the latest end reads the arrivals', () async {
    final c = _Client();
    final w = WorkspaceController(c);
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    await w.bootstrap();
    w.setForeground(true);
    await w.selectChannel(w.channels.single);
    final before = c.reads;
    c.syncRows = [_Client.message('gap1', 2)];
    await w.messageDomain.navigation.syncVisibleScopes();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.reads, before + 1);
    expect(w.unread['c'] ?? 0, 0);
  });

  test('[BP-READ-078] a gap sync page takes numeric and decimal-string seq alike (v1.21.2 leaked strings from /messages/sync)', () async {
    final c = _Client();
    final w = WorkspaceController(c);
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    await w.bootstrap();
    w.setForeground(true);
    await w.selectChannel(w.channels.single);
    c.syncRows = [
      {..._Client.message('as-string', 2), 'seq': '2'},
      {..._Client.message('as-number', 3), 'seq': 3},
    ];
    await w.messageDomain.navigation.syncVisibleScopes();
    await Future<void>.delayed(Duration.zero);
    expect(w.messageDomain.messages.map((m) => m.id), ['m', 'as-string', 'as-number']);
    expect(w.messageDomain.ledger.watermark, BigInt.from(3));
  });

  testWidgets(
    'phone timeline reports its bottom edge; live append reads only at the bottom',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = _Client();
      final w = WorkspaceController(c, mobileNavigation: true);
      addTearDown(() async {
        w.dispose();
        await c.stream.close();
      });
      w.server = RaftRecord({'id': 's', 'role': 'owner'});
      w.channel = RaftChannel({'id': 'c', 'name': 'design', 'joined': true});
      w.channels = [w.channel!];
      w.setForeground(true);
      w.messageDomain.ledger.switchServer('s');
      final rows = [
        for (final r in contextRows('row', count: 60)) {...r, 'channelId': 'c'},
      ];
      w.messageDomain.ledger.ingest(rows, expectedGeneration: w.messageDomain.ledger.generation);
      w.messageDomain.visibleIds['c'] = rows.map((r) => r['id'] as String).toSet();
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(body: RaftChatView(controller: w)),
        ),
      );
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(RaftChatView));
      final ScrollController viewport = state.viewport;
      RaftUserActivity.forget();
      Future<void> arrive(String id, int seq) => tester.runAsync(() async {
        c.stream.add(
          RaftEvent('message:new', {
            ..._Client.message(id, seq),
            'senderId': 'bob',
          }),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
      });
      await arrive('at-bottom', 998);
      await tester.pump();
      expect(c.reads, 1);
      expect(w.unread['c'] ?? 0, 0);
      viewport.jumpTo(viewport.offset - 2400);
      await tester.pumpAndSettle();
      expect(state.atBottom, false);
      await arrive('above', 999);
      await tester.pump();
      expect(c.reads, 1);
      expect(w.unread['c'], 1);
      viewport.jumpTo(viewport.position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(c.reads, 2);
      expect(w.unread['c'], 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final (family, dark) in [(RaftFamily.elegant, false)]) {
    testWidgets(
      '$family/$dark live message while scrolled up stays unread; scrolling to the bottom reads it',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final c = _Client();
        final w = WorkspaceController(c);
        addTearDown(() async {
          w.dispose();
          await c.stream.close();
        });
        w.server = RaftRecord({'id': 's', 'role': 'owner'});
        w.channel = RaftChannel({'id': 'c', 'name': 'design', 'joined': true});
        w.channels = [w.channel!];
        w.setForeground(true);
        w.messageDomain.ledger.switchServer('s');
        final rows = [
          for (final r in contextRows('row', count: 60))
            {...r, 'channelId': 'c'},
        ];
        w.messageDomain.ledger.ingest(rows, expectedGeneration: w.messageDomain.ledger.generation);
        w.messageDomain.visibleIds['c'] = rows.map((r) => r['id'] as String).toSet();
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        await tester.pumpAndSettle();
        final dynamic state = tester.state(find.byType(RaftChatView));
        final ScrollController viewport = state.viewport;
        viewport.jumpTo(viewport.offset - 2400);
        await tester.pumpAndSettle();
        expect(state.atBottom, false);
        // Idle user: the live arrival counts instead of reading.
        RaftUserActivity.forget();
        await tester.runAsync(() async {
          c.stream.add(
            RaftEvent('message:new', {
              ..._Client.message('live', 999),
              'senderId': 'bob',
            }),
          );
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pump();
        expect(w.unread['c'], 1);
        expect(c.reads, 0);
        // Back to the latest end.
        viewport.jumpTo(viewport.position.maxScrollExtent);
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
        expect(state.atBottom, true);
        expect(c.reads, 1);
        expect(w.unread['c'], 0);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
