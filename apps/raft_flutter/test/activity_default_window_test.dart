import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_activity_unread_store.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityWorkspace, activityFixture, channelRow, shown, skeleton;
import 'support/app_services_fixture.dart';

void main() {
  Future<(ActivityWorkspace, SourceActivityUnreadStore, dynamic)> mountOwned(
    WidgetTester tester,
  ) async {
    final (_, workspace) = (await tester.runAsync(() async {
      final fixture = activityFixture();
      await fixture.$1.login('fixture', 'fixture');
      return fixture;
    }))!;
    addTearDown(workspace.dispose);
    final store = workspace.activityUnread;
    final boot = store.refresh();
    await tester.pump();
    await boot;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ResourceView(
            controller: workspace,
            section: 'activity',
            activitySidebarEnabled: true,
            onMessage: (_, _) async {},
            onActivityWindowAccepted: (window, {firstPage = false}) {
              if (window != null) {
                store.acceptWindow(
                  window,
                  scope: store.scope,
                  firstPage: firstPage,
                );
              }
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (workspace, store, tester.state(find.byType(ResourceView)));
  }

  testWidgets('a disposed session cannot recreate its Activity store', (
    tester,
  ) async {
    final (_, workspace) = activityFixture();
    workspace.dispose();
    try {
      expect(() => workspace.activityUnread, throwsStateError);
      expect(workspace.activityUnreadIfBound, isNull);
    } finally {
      // Retire the old implementation's incorrectly recreated projection too.
      workspace.activityUnreadIfBound?.dispose();
    }
  });

  testWidgets('a disposed presentation cannot borrow a live session store', (
    tester,
  ) async {
    final (_, workspace) = activityFixture();
    addTearDown(workspace.dispose);
    final store = workspace.activityUnread;
    final mirror = WorkspaceController(
      workspace.client,
      presentationSource: workspace,
      ownsClient: false,
    );
    mirror.dispose();
    expect(() => mirror.activityUnread, throwsStateError);
    expect(mirror.activityUnreadIfBound, isNull);
    expect(workspace.activityUnreadIfBound, same(store));
  });

  for (final phone in [false, true]) {
    testWidgets(
      '${phone ? 'phone' : 'desktop'} page refresh replaces the session first page before remount',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = phone
            ? const Size(390, 844)
            : const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (_, workspace) = (await tester.runAsync(() async {
          final fixture = activityFixture();
          await fixture.$1.login('fixture', 'fixture');
          return fixture;
        }))!;
        addTearDown(workspace.dispose);
        workspace
          ..loading = false
          ..section = 'activity'
          ..inbox = [channelRow(9, unread: 3)];
        final store = workspace.activityUnread;
        final boot = store.refresh();
        await tester.pump();
        await boot;
        workspace.inbox = [channelRow(10, unread: 4)];
        Widget page() => MaterialApp(
          theme: raftTheme(),
          home: withAppServices(
            WorkspaceView(
              controller: workspace,
              appearance: const RaftAppearance(),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        );

        await tester.pumpWidget(page());
        await tester.pumpAndSettle();
        expect(shown('Preview 10'), findsOneWidget);
        expect(store.acceptedRows.single['channelId'], 'ch10');
        await tester.pumpWidget(const SizedBox());
        // Evict page-local presentation state. The session cache must still
        // own the latest accepted first page and survive this eviction.
        workspace.resourceSnapshots.clear();
        final gate = workspace.hold = Completer<void>();
        try {
          await tester.pumpWidget(page());
          expect(shown('Preview 10'), findsOneWidget);
          expect(shown('Preview 9'), findsNothing);
          expect(skeleton, findsNothing);
          expect(store.windowSince(0)!['items'].single['channelId'], 'ch10');
        } finally {
          gate.complete();
          workspace.hold = null;
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox());
        }
      },
    );
  }

  testWidgets('default Activity accepts one canonical window per owned event', (
    tester,
  ) async {
    final (client, workspace) = (await tester.runAsync(() async {
      final fixture = activityFixture();
      await fixture.$1.login('fixture', 'fixture');
      return fixture;
    }))!;
    addTearDown(workspace.dispose);
    workspace.inbox = [channelRow(3, unread: 2)];
    final store = workspace.activityUnread..start();
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ResourceView(
            controller: workspace,
            section: 'activity',
            onMessage: (_, _) async {},
            onActivityWindowAccepted: (window, {firstPage = false}) {
              if (window != null) {
                store.acceptWindow(
                  window,
                  scope: store.scope,
                  firstPage: firstPage,
                );
              }
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    var acceptances = 0;
    store.addListener(() => acceptances++);
    final before = workspace.inboxQueries.length;
    workspace.inbox = [channelRow(3, unread: 5, seq: 5000)];
    client.emit('message:new', {
      'id': 'm3',
      'channelId': 'ch3',
      'seq': 5000,
      'senderId': 'bob',
      'senderType': 'user',
    });
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(workspace.inboxQueries, hasLength(before + 1));
    expect(store.totalUnreadCount, 5);
    expect(acceptances, 1);
    final dynamic state = tester.state(find.byType(ResourceView));
    expect(state.totalUnreadCount, 5);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'filtered and appended windows cannot replace the default cache',
    (tester) async {
      final (workspace, store, state) = await mountOwned(tester);
      final serial = store.windowSerial;
      state.filter = 'unread';
      await state.load();
      expect(store.windowSerial, serial);
      expect(workspace.inboxQueries.last['filter'], 'unread');
      state.filter = 'all';
      await state.load();
      final firstPage = store.windowSince(0)!;
      final firstPageSerial = store.windowSerial;
      await state.load(append: true);
      expect(state.rows, hasLength(60));
      expect(workspace.inboxQueries.last['offset'], 30);
      expect(store.windowSerial, firstPageSerial);
      expect(store.windowSince(0), firstPage);

      workspace.inbox[0] = {
        ...workspace.inbox[0],
        'lastMessagePreview': 'Updated',
      };
      await state.load(keep: true);
      expect(workspace.inboxQueries.last['limit'], 60);
      expect(state.rows, hasLength(60));
      final window = store.windowSince(0)!;
      expect(window['items'], hasLength(30));
      expect(window['items'].first['lastMessagePreview'], 'Updated');
      expect(window['hasMore'], isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final name in [
    'message:updated',
    'message:deleted',
    'read_state:updated',
    'scope_read:updated',
    'thread:deleted',
  ]) {
    testWidgets('mounted Activity still reconciles $name through its owner', (
      tester,
    ) async {
      final (workspace, _, _) = await mountOwned(tester);
      final before = workspace.inboxQueries.length;
      final client = workspace.client;
      // All these facts need the page's existing canonical reconcile. They
      // must not disappear when the page stops listening to the raw socket.
      (client as dynamic).emit(name, {
        'id': 'm3',
        'channelId': 'ch3',
        'scopeId': 'ch3',
        'threadChannelId': 't3',
        'maxReadSeq': 1,
      });
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(workspace.inboxQueries, hasLength(before + 1));
      expect(skeleton, findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('a fresh first page cannot suppress filtered resume refresh', (
    tester,
  ) async {
    final (workspace, store, state) = await mountOwned(tester);
    state.filter = 'unread';
    await state.load();
    expect(store.isFresh, isTrue);
    final before = workspace.inboxQueries.length;
    (workspace.client as dynamic).emit('sync:resume:response', {});
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(workspace.inboxQueries, hasLength(before + 1));
    expect(workspace.inboxQueries.last['filter'], 'unread');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('page-only events add no background reads after unmount', (
    tester,
  ) async {
    final (workspace, store, _) = await mountOwned(tester);
    await tester.pumpWidget(const SizedBox());
    final before = workspace.inboxQueries.length;
    for (final name in [
      'message:updated',
      'read_state:updated',
      'scope_read:updated',
      'thread:deleted',
      'sync:resume:response',
    ]) {
      (workspace.client as dynamic).emit(name, {
        'id': 'm3',
        'channelId': 'ch3',
      });
    }
    await tester.pump(const Duration(seconds: 3));
    expect(workspace.inboxQueries, hasLength(before));
    expect(workspace.activityUnreadIfBound, same(store));
  });
}
