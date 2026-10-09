import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/desktop_directory_view.dart';
import 'package:raft_flutter/features/member_profile_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://public-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final calls = <String>[];
  Completer<Map<String, dynamic>>? pendingMessages;
  final people = <Map<String, dynamic>>[];
  final pendingDms = <String, Completer<dynamic>>{};
  final channelRows = [
    RaftChannel({'id': 'c', 'name': 'design', 'joined': true}),
  ];
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
    if (pendingMessages != null) return pendingMessages!.future;
    return {
      'messages': [message('m')],
      'threadSummariesByParentMessageId': {},
    };
  }

  Map<String, dynamic> message(String id) => {
    'id': id,
    'channelId': 'c',
    'serverId': 's',
    'seq': id == 'm' ? '1' : '2',
    'content': 'Public fixture',
    'senderId': 'other',
    'senderType': 'user',
    'createdAt': '2026-10-08T00:00:00Z',
  };
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add('GET:$path');
    if (path.endsWith('/members')) return people;
    if (path.contains('/members/') && path.endsWith('/profile')) {
      return {
        'userId': path.split('/')[4],
        'name': 'Selected human',
        'description': 'Public profile',
      };
    }
    if (path == '/messages/search') {
      return {
        'results': [
          {
            ...message('hit'),
            'content': 'Selected public hit',
            'channelName': 'design',
            'senderName': 'Public sender',
          },
        ],
        'hasMore': false,
      };
    }
    if (path == '/channels/c') {
      return {'id': 'c', 'serverId': 's', 'name': 'design', 'joined': true};
    }
    if (path.startsWith('/messages/context/')) {
      return {
        'messages': [message(path.split('/').last)],
      };
    }
    if (path == '/channels/unread') {
      return {
        'channels': {'c': 1},
      };
    }
    if (path.endsWith('/sidebar-order')) {
      return {'pinned': [], 'customSections': [], 'sectionPlacements': []};
    }
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    }
    if (path == '/auth/identities') {
      return {'passwordConfigured': true, 'identities': []};
    }
    if (path == '/auth/providers') return {'providers': []};
    return [];
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    calls.add('POST:$path');
    if (path == '/channels/dm' &&
        data is Map &&
        pendingDms[data['userId']] != null) {
      return pendingDms[data['userId']]!.future;
    }
    if (path.endsWith('/read')) {
      return {'maxReadSeq': '2', 'readStateVersion': '1'};
    }
    if (path == '/feature-flags/evaluate') return {'evaluations': []};
    return {};
  }
}

void main() {
  for (final theme in [
    (name: 'Brutal', family: RaftFamily.brutal, dark: false),
    (name: 'Elegant', family: RaftFamily.elegant, dark: false),
    (name: 'Elegant dark', family: RaftFamily.elegant, dark: true),
  ]) {
    testWidgets(
      '[N22b][L08a][K06a] ${theme.name} known cold channel keeps header/tabs/composer in first frame and across resize',
      (t) async {
        SharedPreferences.setMockInitialValues({});
        t.view.physicalSize = const Size(1280, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final client = _Client()..selectServer('s');
        final w = WorkspaceController(client)
          ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'})
          ..channels = client.channelRows
          ..channel = client.channelRows.single
          ..section = 'chat'
          ..channelLoading = true
          ..loading = true;
        w.ledger.switchServer('s');
        final uri = w.location;
        addTearDown(() async {
          w.dispose();
          await client.stream.close();
        });
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(theme.family, dark: theme.dark),
            home: WorkspaceView(
              controller: w,
              appearance: const RaftAppearance(),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        );
        expect(
          find.byKey(const Key('workspace-channel-header')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('conversation-tabs')), findsOneWidget);
        expect(find.byType(RaftComposer), findsOneWidget);
        final composer = t.state(find.byType(RaftComposer));
        for (final size in [
          const Size(768, 900),
          const Size(767, 900),
          const Size(390, 900),
          const Size(1280, 900),
        ]) {
          t.view.physicalSize = size;
          await t.pump(const Duration(milliseconds: 100));
          await t.pump();
          expect(w.location, uri);
          expect(find.byKey(const Key('conversation-tabs')), findsOneWidget);
          expect(t.state(find.byType(RaftComposer)), same(composer));
          expect(
            find.byKey(
              Key(
                size.width < 768
                    ? 'workspace-mobile-detail-header'
                    : 'workspace-channel-header',
              ),
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('workspace-mobile-navigation')),
            findsNothing,
          );
          expect(t.takeException(), isNull);
        }
        await t.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      '${theme.name} actual Activity location retains master/header/tabs/composer across 768/1024/1280 folds',
      (t) async {
        SharedPreferences.setMockInitialValues({});
        t.view.physicalSize = const Size(1280, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final client = _Client()..selectServer('s');
        final w = WorkspaceController(client)
          ..server = RaftRecord({
            'id': 's',
            'slug': 'fixture',
            'name': 'Fixture',
            'role': 'owner',
          })
          ..channels = client.channelRows
          ..channel = client.channelRows.single
          ..section = 'activity'
          ..channelLoading = true
          ..loading = true;
        w.ledger.switchServer('s');
        w.navigation.navigate(
          w.location.withQuery({'open': 'channel:c', 'msg': 'm'}),
          kind: RaftNavigationKind.replace,
        );
        final uri = w.location;
        addTearDown(() async {
          w.dispose();
          await client.stream.close();
        });
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(theme.family, dark: theme.dark),
            home: WorkspaceView(
              controller: w,
              appearance: const RaftAppearance(),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        );
        // The first frame keeps the known channel chrome while only its body loads.
        expect(find.byKey(const Key('conversation-tabs')), findsOneWidget);
        expect(find.byType(RaftComposer), findsOneWidget);
        expect(find.byKey(const Key('workspace-channel-header')), findsNothing);
        expect(find.byType(ResourceView), findsOneWidget);
        await t.pumpAndSettle();
        final master = t.state(find.byType(ResourceView));
        final composer = t.state(find.byType(RaftComposer));
        for (final size in [
          const Size(1279, 900),
          const Size(1024, 900),
          const Size(1023, 900),
          const Size(768, 900),
          const Size(767, 900),
          const Size(900, 390),
          const Size(390, 900),
          const Size(1280, 900),
        ]) {
          t.view.physicalSize = size;
          await t.pumpAndSettle();
          expect(w.location, uri, reason: '$size must preserve URI');
          expect(w.section, 'activity');
          expect(
            find.byKey(const Key('workspace-channel-header')),
            findsNothing,
          );
          expect(find.byKey(const Key('conversation-tabs')), findsOneWidget);
          expect(
            t.state(find.byType(ResourceView, skipOffstage: false)),
            same(master),
          );
          expect(t.state(find.byType(RaftComposer)), same(composer));
          expect(
            find.byKey(const Key('workspace-mobile-navigation')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('desktop-master-resize-handle')),
            size.width < 768 ? findsNothing : findsOneWidget,
          );
          expect(t.takeException(), isNull);
        }
        // A real close action removes only the content slot and retains the master.
        await t.tap(find.byTooltip('Close detail'));
        await t.pumpAndSettle();
        expect(w.location.content, isNull);
        expect(w.location.route.name, 'activity');
        expect(t.state(find.byType(ResourceView)), same(master));
        await t.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'mounted desktop search retains query/master when result opens and closes',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = const Size(1280, 720);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final client = _Client()..selectServer('s');
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'})
        ..channels = client.channelRows
        ..channel = client.channelRows.single
        ..section = 'search';
      addTearDown(() async {
        w.dispose();
        await client.stream.close();
      });
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: WorkspaceView(
            controller: w,
            appearance: const RaftAppearance(),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('workspace-sidebar-panel')), findsNothing);
      final masterState = t.state(find.byType(ResourceView));
      await t.enterText(find.byType(TextField).first, 'public');
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      expect(find.text('Selected public hit'), findsOneWidget);
      await t.tap(find.text('Selected public hit'));
      await t.pumpAndSettle();
      expect(find.byType(ResourceView), findsOneWidget);
      expect(t.state(find.byType(ResourceView)), same(masterState));
      expect(find.byKey(const Key('desktop-content-detail')), findsOneWidget);
      expect(find.byType(RaftChatView), findsOneWidget);
      expect(find.byKey(const Key('workspace-sidebar-panel')), findsNothing);
      expect(
        t.widget<TextField>(find.byType(TextField).first).controller!.text,
        'public',
      );
      await t.tap(find.byTooltip('Close detail'));
      await t.pumpAndSettle();
      expect(find.byType(RaftChatView), findsNothing);
      expect(w.section, 'search');
      expect(t.state(find.byType(ResourceView)), same(masterState));
      expect(
        t.widget<TextField>(find.byType(TextField).first).controller!.text,
        'public',
      );
    },
  );
  testWidgets(
    'Members col2 remains mounted when a human profile opens and closes',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = const Size(1280, 720);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final client = _Client()..selectServer('s');
      client.people.add({'userId': 'human', 'name': 'Public human'});
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'})
        ..channels = client.channelRows
        ..channel = client.channelRows.single
        ..section = 'members';
      addTearDown(() async {
        w.dispose();
        await client.stream.close();
      });
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: WorkspaceView(
            controller: w,
            appearance: const RaftAppearance(),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      );
      await t.pumpAndSettle();
      final directory = t.state(find.byType(DesktopDirectoryView));
      expect(find.byKey(const Key('workspace-sidebar-panel')), findsNothing);
      expect(
        t.getSize(find.byKey(const Key('desktop-master-panel'))).width,
        240,
      );
      await t.tap(find.text('Public human'));
      await t.pumpAndSettle();
      expect(find.byType(MemberProfileView), findsOneWidget);
      expect(find.text('Public profile'), findsOneWidget);
      expect(t.state(find.byType(DesktopDirectoryView)), same(directory));
      await t.tap(find.byTooltip('Close profile'));
      await t.pumpAndSettle();
      expect(find.byType(MemberProfileView), findsNothing);
      expect(t.state(find.byType(DesktopDirectoryView)), same(directory));
      expect(w.section, 'members');
    },
  );

  testWidgets(
    'older Search DM creation cannot replace a newer selected result',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = const Size(1280, 720);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final client = _Client()..selectServer('s');
      client.people.addAll([
        {'userId': 'a', 'name': 'Person A'},
        {'userId': 'b', 'name': 'Person B'},
      ]);
      client.pendingDms['a'] = Completer<dynamic>();
      client.pendingDms['b'] = Completer<dynamic>();
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'})
        ..channels = client.channelRows
        ..channel = client.channelRows.single
        ..section = 'search';
      addTearDown(() async {
        w.dispose();
        await client.stream.close();
      });
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: WorkspaceView(
            controller: w,
            appearance: const RaftAppearance(),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'Person');
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      await t.tap(find.text('Person A'));
      await t.pump();
      expect(find.byType(MemberProfileView), findsNothing);
      expect(client.calls.where((c) => c.endsWith('/profile')), isEmpty);
      await t.tap(find.text('Person B'));
      await t.pump();
      client.pendingDms['b']!.complete({'id': 'c'});
      await t.pumpAndSettle();
      expect(find.byType(RaftChatView), findsOneWidget);
      final calls = client.calls.length;
      client.pendingDms['a']!.complete({'id': 'old-private-dm'});
      await t.pumpAndSettle();
      expect(w.channel!.id, 'c');
      expect(
        client.calls.skip(calls).where((c) => c.contains('old-private-dm')),
        isEmpty,
      );
      expect(find.byType(MemberProfileView), findsNothing);
    },
  );

  testWidgets(
    'delayed first page positions the real latest message while retaining composer',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final client = _Client()
        ..selectServer('s')
        ..pendingMessages = Completer<Map<String, dynamic>>();
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'})
        ..channels = client.channelRows;
      addTearDown(() async {
        w.dispose();
        await client.stream.close();
      });
      w.ledger.switchServer('s');
      final loading = w.selectChannel(client.channelRows.single);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(body: RaftChatView(controller: w)),
        ),
      );
      await t.pump(const Duration(milliseconds: 600));
      final composer = t.state(find.byType(RaftComposer));
      expect(find.text('Loading...'), findsOneWidget);
      client.pendingMessages!.complete({
        'messages': [
          for (var i = 1; i <= 40; i++)
            {
              ...client.message('item-$i'),
              'seq': '$i',
              'content': 'Public row $i\nSecond line',
            },
        ],
        'threadSummariesByParentMessageId': {},
      });
      await loading;
      expect(w.error, isNull);
      expect(w.messages.length, 40);
      for (var i = 0; i < 180; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(t.state(find.byType(RaftComposer)), same(composer));
      final latest = find.byKey(const ValueKey('message-item-40'));
      expect(latest, findsOneWidget);
      final rect = t.getRect(latest);
      final chatRect = t.getRect(find.byType(RaftChatView));
      expect(rect.overlaps(chatRect), true);
      expect(
        rect.bottom,
        lessThanOrEqualTo(t.getRect(find.byType(RaftComposer)).top + .1),
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('first-page loading retains composer and timeline ownership', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final client = _Client()..selectServer('s');
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'})
      ..channel = client.channelRows.single
      ..channels = client.channelRows
      ..channelLoading = true;
    addTearDown(() async {
      w.dispose();
      await client.stream.close();
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(body: RaftChatView(controller: w)),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(RaftComposer), findsOneWidget);
    expect(find.text('Loading...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final compose = t.state(find.byType(RaftComposer));
    w.channelLoading = false;
    w.notifyListeners();
    await t.pumpAndSettle();
    expect(find.text('Loading...'), findsNothing);
    expect(find.byType(RaftComposer), findsOneWidget);
    expect(t.state(find.byType(RaftComposer)), same(compose));
  });
}
