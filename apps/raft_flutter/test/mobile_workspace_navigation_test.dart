import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/mobile_workspace_navigation.dart';
import 'package:raft_flutter/features/settings_page.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
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
  final removedMetadata = <String>{};
  final pendingMetadata = <String, Completer<dynamic>>{};
  Completer<Map<String, dynamic>>? pendingMessages;
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
    if (pendingMetadata[path] case final pending?) return pending.future;
    if (removedMetadata.contains(path)) {
      throw const RaftApiException('Channel not found', status: 404);
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
    if (path.endsWith('/read')) {
      return {'maxReadSeq': '2', 'readStateVersion': '1'};
    }
    if (path == '/feature-flags/evaluate') return {'evaluations': []};
    return {};
  }
}

class _Notifications extends NativeNotificationService {
  _Notifications() {
    enabled = true;
    permitted = true;
    available = true;
  }
  final sent = <String>[];
  @override
  bool get receivesMessages => true;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> bind(String? scope) async {}
  @override
  Future<void> show({
    required String title,
    required String body,
    required String payload,
  }) async {
    sent.add(payload);
  }
}

void main() {
  test('only tab roots show navigation; details return to the owning root', () {
    for (final entry in {
      'home': 'chat',
      'tasks': 'tasks',
      'members': 'members',
      'settings': 'settings',
    }.entries) {
      expect(
        mobileWorkspaceRootTab(
          entry.key,
          threadOpen: false,
          settingsDetail: false,
        ),
        entry.value,
      );
    }
    for (final section in [
      'chat',
      'search',
      'activity',
      'saved',
      'computers',
      'agents',
      'workspace-settings',
    ]) {
      expect(
        mobileWorkspaceRootTab(
          section,
          threadOpen: false,
          settingsDetail: false,
        ),
        isNull,
      );
    }
    expect(
      mobileWorkspaceRootTab(
        'settings',
        threadOpen: false,
        settingsDetail: true,
      ),
      isNull,
    );
    expect(
      mobileWorkspaceRootTab('home', threadOpen: true, settingsDetail: false),
      isNull,
    );
    expect(mobileWorkspaceBackSection('computers'), 'settings');
    expect(mobileWorkspaceBackSection('search'), 'home');
  });
  test('mobile bootstrap Home never loads or marks a hidden conversation; real selection restores read', () async {
    final c = _Client();
    final mobile = WorkspaceController(c, mobileNavigation: true);
    addTearDown(() async {
      mobile.dispose();
      await c.stream.close();
    });
    await mobile.bootstrap();
    expect(mobile.section, 'home');
    expect(mobile.channel?.id, 'c');
    expect(c.calls.where((call) => call.startsWith('messages:')), isEmpty);
    mobile.setForeground(true);
    final unreadBefore = mobile.unread['c'] ?? 0;
    int snapshots() =>
        c.calls.where((call) => call == 'GET:/channels/unread').length;
    final snapshotsBefore = snapshots();
    c.stream.add(RaftEvent('message:new', c.message('new')));
    await Future<void>.delayed(Duration.zero);
    expect(c.calls.where((call) => call.endsWith('/read')), isEmpty);
    // Hidden behind Home: counted locally, without an unread snapshot GET.
    expect(mobile.unread['c'], unreadBefore + 1);
    expect(snapshots(), snapshotsBefore);
    await mobile.selectChannel(mobile.channels.single);
    expect(mobile.section, 'chat');
    expect(c.calls, contains('messages:c'));
    expect(c.calls, contains('POST:/channels/c/read'));
    final readsBefore = c.calls.where((call) => call.endsWith('/read')).length;
    c.pendingMessages = Completer<Map<String, dynamic>>();
    final lateSelection = mobile.selectChannel(mobile.channels.single);
    await Future<void>.delayed(Duration.zero);
    mobile.setSection('home');
    c.pendingMessages!.complete({
      'messages': [c.message('new')],
      'threadSummariesByParentMessageId': {},
    });
    await lateSelection;
    expect(mobile.section, 'home');
    expect(c.calls.where((call) => call.endsWith('/read')).length, readsBefore);
  });
  test('folded main receives live data without read ACK; visible thread retains read admission', () async {
    final c = _Client();
    final w = WorkspaceController(c);
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    await w.bootstrap();
    w.threadParent = RaftMessage(c.message('m'));
    w.threadChannelId = 'thread';
    w.navigation.navigate(w.location.withQuery({'thread': 'c:m'}));
    w.ledger.ingest([
      {...c.message('reply'), 'channelId': 'thread'},
    ], expectedGeneration: w.ledger.generation);
    w.visibleIds['thread'] = {'reply'};
    final owner = Object();
    w.setConversationPresentation(owner, main: false, thread: true);
    c.calls.clear();
    w.setForeground(true);
    c.stream.add(RaftEvent('message:new', c.message('new')));
    await Future<void>.delayed(Duration.zero);
    await w.markRead('c');
    await w.markRead('thread');
    expect(w.messages.map((m) => m.id), contains('new'));
    expect(c.calls, isNot(contains('POST:/channels/c/read')));
    expect(c.calls, contains('POST:/channels/thread/read'));
    w.releaseConversationPresentation(Object());
    await w.markRead('c');
    expect(c.calls, isNot(contains('POST:/channels/c/read')));
    w.setConversationPresentation(owner, main: true, thread: false);
    await w.markRead('c');
    expect(c.calls, contains('POST:/channels/c/read'));
  });
  test('Home retains selected channel without suppressing its notification; actual Chat suppresses', () async {
    final c = _Client();
    c.selectServer('s');
    final w = WorkspaceController(c, mobileNavigation: true)
      ..server = RaftRecord({'id': 's', 'role': 'owner'})
      ..channel = c.channelRows.single
      ..section = 'home';
    final n = _Notifications();
    final coordinator = NativeContentCoordinator(
      notifications: n,
      links: const Stream.empty(),
    );
    addTearDown(() async {
      await coordinator.dispose();
      w.dispose();
      await c.stream.close();
    });
    await coordinator.init();
    coordinator.bindWorkspace(w);
    final event = {
      'serverId': 's',
      'kind': 'channel',
      'channelId': 'c',
      'messageId': 'm',
      'title': 'Raft',
      'body': 'Public fixture',
    };
    c.stream.add(RaftEvent('notification:push', event));
    await Future<void>.delayed(Duration.zero);
    expect(n.sent, hasLength(1));
    w.section = 'chat';
    c.stream.add(
      RaftEvent('notification:push', {...event, 'messageId': 'new'}),
    );
    await Future<void>.delayed(Duration.zero);
    expect(n.sent, hasLength(1));
  });
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final knownRevoked in [true, false]) {
      testWidgets(
        'actual mobile Back rejects a deleted channel $family/$dark known=$knownRevoked',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final c = _Client()..selectServer('s');
          final gone = RaftChannel({
            'id': 'gone',
            'name': 'Removed channel',
            'joined': true,
          });
          c.channelRows.add(gone);
          final w = WorkspaceController(c, mobileNavigation: true)
            ..server = RaftRecord({
              'id': 's',
              'name': 'Fixture',
              'role': 'owner',
            })
            ..channels = [...c.channelRows]
            ..channel = c.channelRows.first;
          addTearDown(() async {
            w.dispose();
            await c.stream.close();
          });
          // Accepted product selections, then authoritative directory removal.
          await w.selectChannel(gone);
          await w.selectChannel(c.channelRows.first);
          c.channelRows.remove(gone);
          c.removedMetadata.add('/channels/gone');
          if (knownRevoked) {
            await w.refreshChannels();
          } else {
            // No deletion event/directory ACK has arrived yet. Back must handle
            // the actual metadata 404 without throwing from its async callback.
            w.channels = w.channels.where((row) => row.id != gone.id).toList();
          }
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: WorkspaceView(
                controller: w,
                appearance: RaftAppearance(
                  mode: dark ? ThemeMode.dark : ThemeMode.light,
                  light: family,
                ),
                onAppearance: (_) async {},
                onLogout: () async {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          c.calls.clear();
          await tester.tap(find.byKey(const Key('mobile-detail-back')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(c.calls.contains('GET:/channels/gone'), !knownRevoked);
          expect(w.missingConversationChannelId, 'gone');
          expect(find.text('LOADING CHANNEL'), findsNothing);
          expect(find.text('SELECT A CHANNEL'), findsWidgets);
          expect(w.error, isNull);
          // The unavailable Source body owns its real Back control; the old
          // conversation header is intentionally absent on this route.
          await tester.tap(
            find.descendant(
              of: find.byType(RaftChannelResolutionBody),
              matching: find.byTooltip('Back'),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('workspace-mobile-home')),
            findsOneWidget,
          );
          expect(find.byType(RaftComposer), findsNothing);
        },
      );
    }
  }
  testWidgets('a late Back metadata failure cannot replace the new channel', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = _Client()..selectServer('s');
    final gone = RaftChannel({
      'id': 'gone',
      'name': 'Removed channel',
      'joined': true,
    });
    final w = WorkspaceController(c, mobileNavigation: true)
      ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'})
      ..channels = [...c.channelRows, gone]
      ..channel = c.channelRows.first;
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    await w.selectChannel(gone);
    await w.selectChannel(c.channelRows.first);
    w.channels = [...c.channelRows];
    final held = Completer<dynamic>();
    c.pendingMetadata['/channels/gone'] = held;
    await tester.pumpWidget(
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
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-detail-back')));
    await tester.pump();
    expect(c.calls, contains('GET:/channels/gone'));
    await w.selectChannel(c.channelRows.first);
    held.completeError(
      const RaftApiException('Channel not found', status: 404),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(w.channel?.id, 'c');
    expect(w.location.entityId, 'c');
    expect(w.missingConversationChannelId, isNot('gone'));
    expect(w.error, isNull);
    expect(find.text('SELECT A CHANNEL'), findsNothing);
  });
  testWidgets(
    'actual mobile Home channel drill-in/back and settings reset hide detail tabs',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = _Client();
      c.selectServer('s');
      final w = WorkspaceController(c, mobileNavigation: true)
        ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'})
        ..channels = c.channelRows
        ..dms = [
          RaftChannel({
            'id': 'dm',
            'name': 'Fixture peer',
            'type': 'dm',
            'joined': true,
          }),
        ]
        ..channel = c.channelRows.single
        ..section = 'home';
      addTearDown(() async {
        w.dispose();
        await c.stream.close();
      });
      await tester.pumpWidget(
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
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('workspace-mobile-home')), findsOneWidget);
      expect(
        tester
            .widget<Material>(find.byKey(const Key('workspace-mobile-home')))
            .color,
        RaftTokens.of(
          tester.element(find.byKey(const Key('workspace-mobile-home'))),
        ).sidebar,
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('nav-search'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('nav-activity'))).dy),
      );
      final sidebar = tester.widget<ListView>(
        find.byKey(const Key('workspace-sidebar')),
      );
      expect(
        sidebar.padding,
        const EdgeInsetsDirectional.fromSTEB(8, 12, 8, 68),
      );
      final channelRow = find.byKey(const ValueKey('sidebar-channel-c'));
      expect(
        tester.widget<RaftNavItem>(channelRow).conversationKind,
        RaftConversationNavKind.channel,
      );
      final channelGlyph = find.descendant(
        of: channelRow,
        matching: find.byType(RaftIcon),
      );
      expect(tester.widget<RaftIcon>(channelGlyph).size, 14);
      expect(tester.widget<RaftIcon>(channelGlyph).strokeWidth, 2);
      final dmRow = find.byKey(const ValueKey('sidebar-channel-dm'));
      expect(
        tester.widget<RaftNavItem>(dmRow).conversationKind,
        RaftConversationNavKind.directMessage,
      );
      final dmGlyph = tester.widget<RaftIcon>(
        find.descendant(of: dmRow, matching: find.byType(RaftIcon)),
      );
      expect(dmGlyph.glyph, RaftGlyph.user);
      // Source AvatarSlot.tsx90–95/126/229–230: the sidebar-list avatar
      // occupies 18px, contains a 16px face, and its placeholder User is 10px.
      final dmAvatar = find.descendant(
        of: dmRow,
        matching: find.byType(RaftAvatar),
      );
      expect(tester.getSize(dmAvatar), const Size(18, 18));
      expect(
        tester.widget<RaftAvatar>(dmAvatar).mountedContext,
        RaftMountedAvatarContext.sidebarList,
      );
      expect(dmGlyph.size, 10);

      expect(find.byKey(const Key('nav-tasks')), findsNothing);
      expect(find.byKey(const Key('account-navigation')), findsNothing);
      expect(find.byKey(const Key('mobile-tab-members')), findsOneWidget);
      final section = find.byKey(
        const ValueKey('sidebar-section-system:channels'),
      );
      final disclosure = find.byKey(
        const ValueKey('sidebar-disclosure-system:channels'),
      );
      expect(tester.widget<RaftSidebarSectionHeader>(section).count, 1);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('sidebar-group-system:pinned')))
            .top,
        tester.getRect(find.byKey(const Key('nav-saved'))).bottom,
      );
      expect(
        tester.getRect(section).top,
        tester
            .getRect(find.byKey(const ValueKey('sidebar-group-system:joint')))
            .bottom,
      );
      expect(tester.getRect(disclosure).top - tester.getRect(section).top, 12);
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sidebar-channel-c')), findsNothing);
      expect(tester.widget<RaftSidebarSectionHeader>(section).count, 1);
      expect(c.calls.where((call) => call.endsWith('/read')), isEmpty);
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sidebar-channel-c')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sidebar-channel-c')));
      await tester.pumpAndSettle();
      expect(w.section, 'chat');
      expect(w.location.route.name, 'channel');
      expect(w.location.entityId, 'c');
      expect(
        find.byKey(const Key('workspace-mobile-navigation')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('mobile-detail-back')));
      await tester.pumpAndSettle();
      expect(w.section, 'home');
      expect(w.location.toString(), '/s/s');
      await tester.tap(find.byKey(const Key('mobile-tab-settings')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('workspace-settings-nav-account')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('workspace-settings-nav-appearance')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('workspace-mobile-navigation')),
        findsNothing,
      );
      expect(w.location.settingsPath, ['appearance']);
      await tester.tap(find.byKey(const Key('mobile-settings-back')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('workspace-mobile-navigation')),
        findsOneWidget,
      );
      expect(w.location.settingsPath, isEmpty);
      final rootIndex = w.navigation.index;
      // Tapping active Settings repeats the source reset-to-root contract.
      await tester.tap(find.byKey(const Key('mobile-tab-settings')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('workspace-settings-nav-appearance')),
        findsOneWidget,
      );
      expect(w.navigation.index, rootIndex + 1);
      final retained = tester
          .widget<RaftMobileNav>(
            find.byKey(const Key('workspace-mobile-navigation')),
          )
          .onSelected;
      w.server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'guest'});
      w.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mobile-tab-members')), findsNothing);
      retained('tasks');
      await tester.pumpAndSettle();
      expect(w.section, 'settings');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'settings controlled root reset exposes list and detail callbacks',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final states = <bool>[];
      Widget app(int revision) => MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: RaftSettingsPage(
            mobileRoot: true,
            mobileResetRevision: revision,
            onMobileDetailChanged: states.add,
            destinations: [
              RaftSettingsDestination(
                'account',
                'Account',
                RaftGlyph.user,
                (_) => const Text('Actual account detail'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(app(0));
      expect(find.text('Actual account detail'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('workspace-settings-nav-account')),
      );
      await tester.pump();
      expect(states, [true]);
      expect(find.text('Actual account detail'), findsOneWidget);
      await tester.pumpWidget(app(1));
      await tester.pump();
      expect(find.text('Actual account detail'), findsNothing);
    },
  );
}
