import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_incremental_refresh_test.dart'
    show activityFixture, channelRow, shown, skeleton;
import 'support/app_services_fixture.dart';

void main() {
  testWidgets('a phone presentation borrows its source session store', (
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
    expect(mirror.activityUnread, same(store));
    expect(mirror.activityUnreadIfBound, same(store));
    mirror.dispose();
    expect(workspace.activityUnreadIfBound, same(store));
    await tester.pump(const Duration(seconds: 3));
    expect(workspace.inboxQueries, isEmpty);
  });
  testWidgets('creating a session store does not start inbox work', (
    tester,
  ) async {
    final (_, workspace) = (await tester.runAsync(() async {
      final fixture = activityFixture();
      await fixture.$1.login('fixture', 'fixture');
      return fixture;
    }))!;
    addTearDown(workspace.dispose);
    final store = workspace.activityUnread;
    await tester.pump(const Duration(seconds: 3));
    expect(workspace.inboxQueries, isEmpty);
    expect(store.hasAcceptedWindow, isFalse);
  });

  testWidgets('invalid session activation schedules no timer or request', (
    tester,
  ) async {
    final (_, workspace) = activityFixture();
    addTearDown(workspace.dispose);
    workspace.server = null;
    final timers = <Duration>[];
    runZoned(
      () => workspace.activityUnread.start(),
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          timers.add(duration);
          return parent.createTimer(zone, duration, callback);
        },
      ),
    );
    expect(timers, isEmpty);
    await tester.pump(const Duration(seconds: 3));
    expect(workspace.inboxQueries, isEmpty);
  });

  testWidgets('session activation boots once without pages or notifications', (
    tester,
  ) async {
    final (_, workspace) = (await tester.runAsync(() async {
      final fixture = activityFixture();
      await fixture.$1.login('fixture', 'fixture');
      return fixture;
    }))!;
    addTearDown(workspace.dispose);
    final store = workspace.activityUnread..start();
    await tester.pump(const Duration(milliseconds: 1999));
    expect(workspace.inboxQueries, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(workspace.inboxQueries, hasLength(1));
    expect(store.totalUnreadCount, 2);
    store.start();
    await tester.pump(const Duration(seconds: 3));
    expect(workspace.inboxQueries, hasLength(1));
  });

  for (final mobile in [false, true]) {
    testWidgets(
      '${mobile ? 'phone' : 'desktop'} Activity counts leave chat message rows unchanged',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = mobile
            ? const Size(390, 844)
            : const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (client, workspace) = (await tester.runAsync(() async {
          final fixture = activityFixture();
          await fixture.$1.login('fixture', 'fixture');
          return fixture;
        }))!;
        addTearDown(workspace.dispose);
        workspace
          ..loading = false
          ..section = 'chat'
          ..channel = workspace.channels.first;
        workspace.messageDomain.ledger.switchServer('s1');
        final message = {
          'id': 'held-message',
          'channelId': workspace.channel!.id,
          'content': 'Unrelated chat stays visible',
          'senderId': 'bob',
          'senderType': 'user',
          'senderName': 'Bob',
          'seq': 1,
          'createdAt': '2026-10-14T10:00:00Z',
        };
        client.responses['GET /messages/channel/ch0'] = {
          'messages': [message],
          'hasMore': false,
        };
        void retainChat() {
          workspace.messageDomain.ledger.ingest([
            message,
          ], expectedGeneration: workspace.messageDomain.ledger.generation);
          workspace.messageDomain.visibleIds[workspace.channel!.id] = {
            'held-message',
          };
        }

        retainChat();
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: withAppServices(
              WorkspaceView(
                controller: workspace,
                appearance: const RaftAppearance(),
                onAppearance: (_) async {},
                onLogout: () async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (mobile) {
          await tester.tap(find.byKey(const ValueKey('sidebar-channel-ch0')));
          await tester.pumpAndSettle();
          expect(workspace.error, isNull);
        }
        expect(
          find.text('Unrelated chat stays visible', findRichText: true),
          findsOneWidget,
        );
        expect(find.byType(RaftMessageRow), findsOneWidget);
        final counts = <String, int>{};
        debugOnRebuildDirtyWidget = (element, builtOnce) => counts.update(
          '${element.widget.runtimeType}',
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        try {
          final store = workspace.activityUnread;
          store.acceptWindow({
            'items': [],
            'totalUnreadCount': 5,
          }, scope: store.scope);
          await tester.pump();
          for (final type in [
            'RaftMessageRow',
            'RaftMessageTile',
            'RaftMessageTimeline',
          ]) {
            expect(counts[type] ?? 0, 0, reason: '$type rebuilt: $counts');
          }
          expect(store.totalUnreadCount, 5);
          expect(
            find.text('Unrelated chat stays visible', findRichText: true),
            findsOneWidget,
          );
        } finally {
          debugOnRebuildDirtyWidget = null;
          await tester.pumpWidget(const SizedBox());
        }
      },
    );

    testWidgets(
      '${mobile ? 'phone' : 'desktop'} pages borrow the session window across complete unmount',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = mobile
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
        final store = workspace.activityUnread;
        final hydration = store.refresh();
        await tester.pumpAndSettle();
        await hydration;
        expect(shown('Preview 9'), findsOneWidget);
        expect(store.totalUnreadCount, 3);
        final serial = store.windowSerial;
        expect(serial, greaterThan(0));
        final requests = workspace.inboxQueries.length;
        await tester.pumpWidget(const SizedBox());
        expect(workspace.activityUnreadIfBound, same(store));
        expect(store.windowSerial, serial);
        expect(store.totalUnreadCount, 3);
        expect(store.acceptedRows.single['channelId'], 'ch9');
        await tester.pump(const Duration(seconds: 3));
        expect(workspace.inboxQueries, hasLength(requests));

        await tester.pumpWidget(page());
        expect(shown('Preview 9'), findsOneWidget);
        expect(skeleton, findsNothing);
        expect(workspace.activityUnread, same(store));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        workspace.dispose();
        expect(store.hasAcceptedWindow, isFalse);
        expect(store.windowSince(0), isNull);
      },
    );
  }
}
