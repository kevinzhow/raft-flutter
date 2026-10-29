import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_incremental_refresh_test.dart'
    show
        ActivityClient,
        ActivityWorkspace,
        activityFixture,
        channelRow,
        shown,
        skeleton;
import 'support/app_services_fixture.dart';

/// The Activity badge and the Activity list read one accepted inbox window
/// (Web's inboxStore): whatever lit the badge is already in the list when it
/// opens, so the first frame is final and the revalidation runs behind it.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late ActivityClient client;
  late ActivityWorkspace w;
  setUp(() => (client, w) = activityFixture());
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });
  for (final (dark) in [(true)]) {
    for (final mobile in [false, true]) {
      for (final revisit in [false, true]) {
        final label =
            '${dark ? 'dark' : 'light'} ${mobile ? 'mobile' : 'desktop'} '
            '${revisit ? 'revisit with a retained snapshot' : 'first open'}';
        testWidgets(
          '$label: a realtime arrival lights the badge and opens in the list on the first frame',
          (tester) async {
            SharedPreferences.setMockInitialValues({});
            tester.view.physicalSize = mobile
                ? const Size(390, 844)
                : const Size(1440, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.runAsync(() => client.login('fixture', 'fixture'));
            client.selectServer('s1');
            w.activityUnread.start();
            w.loading = false;
            w.section = 'chat';
            w.inbox = [for (var i = 0; i < 5; i++) channelRow(i)];
            await tester.pumpWidget(
              MaterialApp(
                theme: raftTheme(dark: dark),
                home: withAppServices(
                  WorkspaceView(
                    controller: w,
                    appearance: RaftAppearance(),
                    onAppearance: (_) async {},
                    onLogout: () async {},
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(seconds: 3));
            await settle(tester);
            final store = w.activityUnread;
            expect(store.hasAttention, isFalse);
            Finder attention() => find.descendant(
              of: find.byKey(const ValueKey('rail-activity')),
              matching: find.byType(RaftRailAttention),
            );
            Future<void> openActivity() async {
              if (mobile) {
                await tester.tap(find.byKey(const Key('nav-activity')));
              } else {
                await tester.tap(find.byKey(const ValueKey('rail-activity')));
              }
            }

            Future<void> leaveActivity() async {
              w.section = 'chat';
              w.notifyListeners();
              await settle(tester);
            }

            if (revisit) {
              await openActivity();
              await settle(tester);
              expect(shown('Preview 0'), findsOneWidget);
              await leaveActivity();
              expect(shown('Preview 0'), findsNothing);
            }

            // A live arrival in a channel the user is not looking at.
            w.inbox = [
              channelRow(9, unread: 1, seq: 5000),
              ...w.inbox,
            ];
            client.emit('message:new', {
              'id': 'm9',
              'channelId': 'ch9',
              'seq': 5000,
              'content': 'Preview 9',
              'senderId': 'bob',
              'senderType': 'user',
            });
            await tester.pump(const Duration(milliseconds: 150));
            await settle(tester);
            expect(store.hasAttention, isTrue);
            if (!mobile) expect(attention(), findsOneWidget);

            // Opening Activity: any request still pending must not gate the row.
            final gate = w.hold = Completer<void>();
            final before = w.inboxQueries.length;
            await openActivity();
            await tester.pump();
            expect(shown('Preview 9'), findsOneWidget);
            expect(skeleton, findsNothing);
            expect(
              w.inboxQueries.length,
              before + 1,
              reason: 'the in-place revalidation is requested, not awaited',
            );
            // Held revalidation and every later frame keep the row in place.
            await tester.pump(const Duration(milliseconds: 16));
            expect(shown('Preview 9'), findsOneWidget);
            expect(skeleton, findsNothing);
            gate.complete();
            w.hold = null;
            await settle(tester);
            expect(shown('Preview 9'), findsOneWidget);
            expect(
              store.hasAttention,
              isTrue,
              reason: 'opening Activity does not mark anything read',
            );
            expect(
              w.client is ActivityClient &&
                  (w.client as ActivityClient).posts.any(
                    (p) => p.contains('/read'),
                  ),
              isFalse,
            );

            // Revisit stays instant: leaving and opening again paints at once.
            await leaveActivity();
            w.hold = Completer<void>();
            await openActivity();
            await tester.pump();
            expect(shown('Preview 9'), findsOneWidget);
            expect(skeleton, findsNothing);
            w.hold!.complete();
            w.hold = null;
            await settle(tester);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}
