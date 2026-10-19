import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/conversation_panel.dart';
import 'package:raft_flutter/features/desktop_directory_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_services_fixture.dart';

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
  final agentRows = <Map<String, dynamic>>[];
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
    if (path == '/agents') return agentRows;
    if (path.startsWith('/agents/')) {
      return agentRows
              .where((row) => row['id'] == path.split('/').last)
              .firstOrNull ??
          {};
    }
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

/// Counts every dirty-element rebuild by widget type while [act] and the
/// following [frames] frames run.
Future<Map<String, int>> _rebuilds(
  WidgetTester tester,
  Future<void> Function() act, {
  int frames = 8,
}) async {
  final counts = <String, int>{};
  debugOnRebuildDirtyWidget = (element, _) => counts.update(
    element.widget.runtimeType.toString(),
    (v) => v + 1,
    ifAbsent: () => 1,
  );
  try {
    await act();
    for (var i = 0; i < frames; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
  } finally {
    debugOnRebuildDirtyWidget = null;
  }
  return counts;
}

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
  ]) {
    testWidgets(
      'hidden conversation and folded directory are not rebuilt while another page transitions $family/$dark',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final c = _Client()..selectServer('s');
        c.agentRows.addAll([
          for (var i = 0; i < 6; i++)
            {
              'id': 'agent-$i',
              'name': 'Agent $i',
              'displayName': 'Agent $i',
              'status': 'active',
              'runtime': 'codex',
              'model': 'gpt-6',
              'external': true,
            },
        ]);
        final w = WorkspaceController(c, mobileNavigation: true);
        await tester.runAsync(w.bootstrap);
        addTearDown(() async {
          w.dispose();
          await c.stream.close();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: withAppServices(
              WorkspaceView(
                controller: w,
                appearance: RaftAppearance(
                  mode: dark ? ThemeMode.dark : ThemeMode.light,
                  light: family,
                ),
                onAppearance: (_) async {},
                onLogout: () async {},
              ),
            ),
          ),
        );
        Future<void> settle() async {
          for (var i = 0; i < 20; i++) {
            await tester.runAsync(() => Future<void>.delayed(Duration.zero));
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        await settle();
        // Visit a channel so a conversation page is retained, then leave it.
        await w.selectChannel(w.channels.single);
        await settle();
        expect(find.byType(ConversationPanel), findsOneWidget);
        await tester.binding.handlePopRoute();
        await settle();
        expect(
          find.byType(ConversationPanel, skipOffstage: false),
          findsNothing,
        );

        final toMembers = await _rebuilds(
          tester,
          () => tester.tap(find.byKey(const Key('mobile-tab-members'))),
        );
        expect(
          toMembers['ConversationPanel'] ?? 0,
          0,
          reason: 'a tab switch does not mount an unrelated chat page',
        );
        expect(toMembers['RaftChatView'] ?? 0, 0);
        final notified = await _rebuilds(tester, () async => w.setError(null));
        expect(
          notified['ConversationPanel'] ?? 0,
          0,
          reason: 'workspace notifications skip the hidden conversation',
        );
        expect(notified['RaftChatView'] ?? 0, 0);
        await settle();

        final directory = find.byType(
          DesktopDirectoryView,
          skipOffstage: false,
        );
        await tester.tap(
          find.byKey(const ValueKey('desktop-directory-agent-agent-0')),
        );
        await settle();
        expect(directory, findsOneWidget);
        // The covered directory keeps the widget it last built while a
        // workspace notification rebuilds the visible detail.
        final inDetail = await _rebuilds(tester, () async => w.setError(null));
        expect(inDetail['DesktopDirectoryView'] ?? 0, 0);
        expect(inDetail['RaftNavItem'] ?? 0, 0);
        expect(inDetail['RaftChatView'] ?? 0, 0);

        // Going back shows the directory again, built from the current widget.
        await tester.binding.handlePopRoute();
        await settle();
        expect(
          find.byKey(const ValueKey('desktop-directory-agent-agent-3')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final commit in [false, true]) {
    testWidgets(
      'live events during a predictive back gesture wait for it to end (${commit ? 'commit' : 'cancel'})',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final c = _Client()..selectServer('s');
        final w = WorkspaceController(c, mobileNavigation: true);
        await tester.runAsync(w.bootstrap);
        addTearDown(() async {
          w.dispose();
          await c.stream.close();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(RaftFamily.brutal),
            home: withAppServices(
              WorkspaceView(
                controller: w,
                appearance: const RaftAppearance(),
                onAppearance: (_) async {},
                onLogout: () async {},
              ),
            ),
          ),
        );
        Future<void> settle() async {
          for (var i = 0; i < 20; i++) {
            await tester.runAsync(() => Future<void>.delayed(Duration.zero));
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        Future<void> gesture(String method, [double? progress]) async {
          await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            'flutter/backgesture',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall(
                method,
                progress == null
                    ? null
                    : <String, dynamic>{
                        'touchOffset': <double>[100, 300],
                        'progress': progress,
                        'swipeEdge': 0,
                      },
              ),
            ),
            (_) {},
          );
          await tester.pump();
        }

        await settle();
        await w.selectChannel(w.channels.single);
        await settle();
        expect(find.text('Public fixture'), findsOneWidget);

        await gesture('startBackGesture', 0);
        await gesture('updateBackGestureProgress', 0.3);
        debugPrintScheduleBuildForStacks = true;
        final during = await _rebuilds(tester, () async {
          c.stream.add(
            RaftEvent('message:new', {
              ...c.message('m2'),
              'content': 'Arrived mid gesture',
            }),
          );
          c.stream.add(
            RaftEvent('machine:status', {
              'machineId': 'x',
              'status': 'online',
              'statusVersion': 3,
            }),
          );
          c.stream.add(
            RaftEvent('agent:activity', {
              'agentId': 'agent-0',
              'activity': 'working',
            }),
          );
        });
        // The data is accepted at once; the painted page is not touched.
        expect(
          w.messageDomain.ledger.contains('c', 'm2'),
          isTrue,
          reason: 'state is current while the page is held',
        );
        debugPrintScheduleBuildForStacks = false;
        expect(find.text('Arrived mid gesture'), findsNothing);
        expect(during['RaftChatView'] ?? 0, 0);
        expect(during['RaftMessageRow'] ?? 0, 0);

        await gesture(commit ? 'commitBackGesture' : 'cancelBackGesture');
        await settle();
        if (!commit) {
          expect(find.text('Arrived mid gesture'), findsOneWidget);
        }
        expect(w.messageDomain.ledger.contains('c', 'm2'), isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Home sidebar order follows new messages after navigating away and back',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = _Client()..selectServer('s');
      c.channelRows.add(
        RaftChannel({'id': 'd', 'name': 'ops', 'joined': true}),
      );
      final w = WorkspaceController(c, mobileNavigation: true);
      await tester.runAsync(w.bootstrap);
      w.sidebarOrder = {'channelSortMode': 'recent'};
      addTearDown(() async {
        w.dispose();
        await c.stream.close();
      });
      Map<String, dynamic> message(String id, String channel, String at) => {
        ...c.message(id),
        'channelId': channel,
        'createdAt': at,
      };
      c.stream.add(
        RaftEvent('message:new', message('m-c', 'c', '2026-10-08T01:00:00Z')),
      );
      c.stream.add(
        RaftEvent('message:new', message('m-d', 'd', '2026-10-08T00:00:00Z')),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: withAppServices(
            WorkspaceView(
              controller: w,
              appearance: const RaftAppearance(),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 12; i++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      double top(String id) =>
          tester.getTopLeft(find.byKey(ValueKey('sidebar-channel-$id'))).dy;
      await settle();
      expect(top('c'), lessThan(top('d')));
      // The memoized activity scan must be invalidated by new messages even
      // across navigation, which re-projects the sidebar without other changes.
      await tester.tap(find.byKey(const Key('mobile-tab-members')));
      await settle();
      c.stream.add(
        RaftEvent('message:new', message('m-d2', 'd', '2026-10-08T02:00:00Z')),
      );
      await settle();
      await tester.tap(find.byKey(const Key('mobile-tab-home')));
      await settle();
      expect(top('d'), lessThan(top('c')));
    },
  );

  testWidgets(
    'current live page semantics are available during platform transitions',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      final c = _Client()..selectServer('s');
      c.agentRows.add({
        'id': 'agent-0',
        'name': 'Agent 0',
        'displayName': 'Agent 0',
        'status': 'active',
        'runtime': 'codex',
        'model': 'gpt-6',
        'external': true,
      });
      final w = WorkspaceController(c, mobileNavigation: true);
      await tester.runAsync(w.bootstrap);
      w.setSection('members');
      addTearDown(() async {
        w.dispose();
        await c.stream.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: withAppServices(
            WorkspaceView(
              controller: w,
              appearance: const RaftAppearance(),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      void liveRoute() {
        final detail = find.byKey(
          const ValueKey('workspace-mobile-detail-header'),
        );
        final exclusions = tester.widgetList<ExcludeSemantics>(
          find.ancestor(of: detail, matching: find.byType(ExcludeSemantics)),
        );
        expect(exclusions.every((widget) => !widget.excluding), isTrue);
        expect(find.byType(RawImage), findsNothing);
      }

      await settle();
      expect(find.byType(RawImage), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('desktop-directory-agent-agent-0')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      liveRoute();
      await settle();
      liveRoute();
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(RawImage), findsNothing);
      await settle();
      expect(find.byType(RawImage), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
