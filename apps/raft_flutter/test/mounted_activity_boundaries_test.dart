import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;
import 'workspace_activity_activation_test.dart' show channelRow, message;

Future<void> flush(WidgetTester t) async {
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 25)),
  );
  await t.pump();
}

Future<void> mount(
  WidgetTester t,
  WorkspaceController w,
  RaftFamily family,
  bool dark,
) async {
  w.loading = false;
  w.section = 'activity';
  w.ledger.switchServer('s1');
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(family, dark: dark),
      home: WorkspaceView(
        controller: w,
        appearance: const RaftAppearance(),
        onAppearance: (_) async {},
        onLogout: () async {},
      ),
    ),
  );
  await flush(t);
  await t.pumpAndSettle();
}

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final enabled in [false, true]) {
      for (final width in [767.0, 768.0, 1023.0, 1024.0]) {
        testWidgets(
          '[N22a] $family/$dark actual evaluated=$enabled width=$width Activity opener',
          (t) async {
            SharedPreferences.setMockInitialValues({});
            t.view.physicalSize = Size(width, 900);
            t.view.devicePixelRatio = 1;
            addTearDown(t.view.reset);
            final (w, api) = (await t.runAsync(() => fixture('owner')))!;
            addTearDown(w.dispose);
            api.routes['POST /feature-flags/evaluate'] = (request) => {
              'evaluations': [
                for (final key in (request.data as Map)['keys'] as List)
                  {
                    'key': key,
                    'enabled': key == 'activity_sidebar_inbox_v0' && enabled,
                  },
              ],
            };
            api.routes['GET /channels/inbox'] = (_) => {
              'items': [channelRow],
            };
            final pending = Completer<Map<String, dynamic>>();
            api.routes['GET /messages/context/first-channel'] = (_) =>
                pending.future;
            api.routes['GET /messages/context/mention-channel'] = (_) =>
                pending.future;
            await mount(t, w, family, dark);
            await t.pump(const Duration(milliseconds: 100));
            final row = find.byKey(const ValueKey('activity-channel-c1'));
            expect(row, findsOneWidget);
            final entries = w.navigation.entries.length;
            await t.tap(row);
            final split = width >= (enabled ? 768 : 1024);
            final target = split ? 'first-channel' : 'mention-channel';
            await t.pump(const Duration(milliseconds: 219));
            if (split) {
              expect(w.location.route, RaftRoute.activity);
              expect(w.location.content, isNull);
            }
            await t.pump(const Duration(milliseconds: 1));
            await flush(t);
            expect(
              w.location.route,
              split ? RaftRoute.activity : RaftRoute.channel,
            );
            expect(
              w.location.content?.kind,
              split ? RaftContentKind.channel : null,
            );
            expect(w.location.messageId, target);
            expect(w.navigation.entries.length, entries + (split ? 0 : 1));
            expect(
              find.byType(ResourceView),
              split ? findsOneWidget : findsNothing,
            );
            expect(find.byType(RaftChatView), findsOneWidget);
            expect(
              t.widget<RaftChatView>(find.byType(RaftChatView)).thread,
              false,
            );
            expect(find.byType(RaftComposer), findsOneWidget);
            pending.complete({
              'messages': [message(target, 'c1')],
            });
            await flush(t);
            await t.pump(const Duration(milliseconds: 16));
            expect(find.byKey(ValueKey('message-$target')), findsOneWidget);
            expect(t.takeException(), isNull);
            await t.pumpWidget(const SizedBox());
          },
        );
      }
    }
    for (final priority in ['mention', 'unread', 'latest']) {
      testWidgets('[N25c] $family/$dark actual mobile DM $priority one PUSH', (
        t,
      ) async {
        SharedPreferences.setMockInitialValues({});
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        w.dms = [
          RaftChannel({
            'id': 'd1',
            'name': 'Actual DM',
            'type': 'dm',
            'joined': true,
          }),
        ];
        final target = 'dm-$priority';
        api.routes['GET /channels/inbox'] = (_) => {
          'items': [
            {
              'kind': 'dm',
              'channelId': 'd1',
              'channelName': 'Actual DM',
              'lastMessagePreview': 'Actual mobile DM target',
              'unreadCount': priority == 'latest' ? 0 : 2,
              if (priority == 'mention') 'firstMentionMessageId': 'dm-mention',
              'firstUnreadMessageId': 'dm-unread',
              'lastMessageId': 'dm-latest',
            },
          ],
        };
        final pending = Completer<Map<String, dynamic>>();
        api.routes['GET /messages/context/$target'] = (_) => pending.future;
        await mount(t, w, family, dark);
        final entries = w.navigation.entries.length;
        await t.tap(find.byKey(const ValueKey('activity-dm-d1')));
        await t.pump();
        expect(w.location.route, RaftRoute.dm);
        expect(w.location.entityId, 'd1');
        expect(w.location.messageId, target);
        expect(w.navigation.entries.length, entries + 1);
        expect(find.byType(ResourceView), findsNothing);
        expect(find.byType(RaftComposer), findsOneWidget);
        expect(find.byType(RaftChatView), findsOneWidget);
        await flush(t);
        await t.pump(const Duration(milliseconds: 16));
        final requests = api.calls.where(
          (r) => r.path.startsWith('/messages/context/'),
        );
        expect(requests.map((r) => r.path), ['/messages/context/$target']);
        expect(requests.single.queryParameters['channelId'], 'd1');
        pending.complete({
          'messages': [message(target, 'd1')],
        });
        await flush(t);
        final painted = find.byKey(ValueKey('message-$target'));
        for (var frame = 0; frame < 20 && painted.evaluate().isEmpty; frame++) {
          await t.pump(const Duration(milliseconds: 16));
        }
        expect(
          painted,
          findsOneWidget,
          reason:
              'uri=${w.location} rows=${w.messages.map((row) => row.id).toList()} '
              'error=${w.error} channel=${w.channel?.id}',
        );
        expect(w.threadIdentity, isNull);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
