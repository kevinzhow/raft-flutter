import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;
import 'workspace_activity_activation_test.dart' show channelRow, message;
import 'support/app_services_fixture.dart';

void main() {
  for (final (family, dark) in raftThemeMatrix([
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ])) {
    for (final mode in ['other-row', 'other-row-double', 'late', 'detail']) {
      testWidgets('Activity C reflow $family/$dark $mode', (t) async {
        SharedPreferences.setMockInitialValues({});
        t.view.physicalSize = const Size(1440, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        const timing = MethodChannel('app.raft/interaction');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(timing, (_) async => 0.5);
        addTearDown(() => messenger.setMockMethodCallHandler(timing, null));
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        w.loading = false;
        w.section = 'activity';
        w.messageDomain.ledger.switchServer('s1');
        w.channels = [
          w.channel!,
          RaftChannel({'id': 'c2', 'name': 'second', 'joined': true}),
        ];
        final pending = Completer<Map<String, dynamic>>();
        api.routes['GET /channels/inbox'] = (_) => {
          'items': [
            channelRow,
            {
              ...channelRow,
              'channelId': 'c2',
              'channelName': 'second',
              'lastMessagePreview': 'Second row',
              'firstUnreadMessageId': 'second',
            },
          ],
        };
        api.routes['GET /messages/context/first-channel'] = (_) =>
            pending.future;
        api.routes['GET /messages/context/second'] = (_) => {
          'messages': [message('second', 'c2')],
        };
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: withAppServices(
              WorkspaceView(
                controller: w,
                appearance: RaftAppearance(light: family),
                onAppearance: (_) async {},
                onLogout: () async {},
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final first = find.byKey(const ValueKey('activity-channel-c1'));
        final second = find.byKey(const ValueKey('activity-channel-c2'));
        final master = find.byKey(const Key('desktop-master-panel'));
        final initialWidth = t.getSize(master).width;
        expect(find.byKey(const Key('desktop-content-detail')), findsNothing);
        final entries = w.navigation.entries.length;
        await t.tap(first);
        expect(w.location.route, RaftRoute.activity);
        expect(w.location.content?.id, 'c1');
        expect(w.location.messageId, 'first-channel');
        expect(w.navigation.entries.length, entries);
        await t.pump();
        expect(find.byKey(const Key('desktop-content-detail')), findsOneWidget);
        expect(t.getSize(master).width, lessThan(initialWidth));
        await t.pump(const Duration(milliseconds: 350));
        if (mode == 'other-row' || mode == 'other-row-double') {
          final point = t.getCenter(second);
          expect(t.getRect(first).contains(point), false);
          expect(t.getRect(master).contains(point), true);
          await t.tapAt(point);
          expect(w.location.route, RaftRoute.activity);
          expect(w.location.content?.id, 'c2');
          expect(w.location.messageId, 'second');
          expect(w.navigation.entries.length, entries);
          await t.pump();
          expect(find.byType(ResourceView), findsOneWidget);
          if (mode == 'other-row-double') {
            // Past A's window, but within B's new window: B owns the double.
            await t.pump(const Duration(milliseconds: 350));
            await t.tap(second);
            expect(w.location.route, RaftRoute.channel);
            expect(w.location.entityId, 'c2');
            expect(w.location.messageId, 'second');
            expect(w.navigation.entries.length, entries + 1);
            await t.pump();
            expect(find.byType(ResourceView), findsNothing);
          }
        } else {
          if (mode == 'late') {
            await t.pump(const Duration(milliseconds: 151));
          } else {
            await t.tap(find.byTooltip('Close detail'));
            expect(w.location.route, RaftRoute.activity);
            expect(w.location.content, isNull);
            await t.pump();
            expect(
              find.byKey(const Key('desktop-content-detail')),
              findsNothing,
            );
            expect(t.getSize(master).width, initialWidth);
          }
          await t.tap(second);
          expect(w.location.route, RaftRoute.activity);
          expect(w.location.content?.id, 'c2');
          expect(w.location.messageId, 'second');
          expect(w.navigation.entries.length, entries);
        }
        pending.complete({
          'messages': [message('first-channel', 'c1')],
        });
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await t.pumpAndSettle();
        expect(
          w.location.route,
          mode == 'other-row-double' ? RaftRoute.channel : RaftRoute.activity,
        );
        expect(
          mode == 'other-row-double'
              ? w.location.entityId
              : w.location.content?.id,
          'c2',
        );
        await t.pumpWidget(const SizedBox());
        expect(t.takeException(), isNull);
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
    }
  }
}
