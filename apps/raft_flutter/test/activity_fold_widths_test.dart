import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;
import 'workspace_activity_activation_test.dart' show channelRow, message;
import 'support/app_services_fixture.dart';

/// Activity click C on every width where the shell is multi-column (>= 768,
/// foldables included, flag evaluated off or on): first click previews and the
/// list stays; only the SAME row twice upgrades; phone (< 768) opens the page.
Future<void> click(WidgetTester t, Finder row, PointerDeviceKind kind) async {
  final gesture = await t.startGesture(t.getCenter(row), kind: kind);
  await gesture.up();
}

void main() {
  const sizes = <Size>[
    Size(390, 844),
    Size(767, 900),
    Size(768, 900),
    Size(816, 900),
    Size(900, 1200),
    Size(1024, 768),
    Size(1280, 800),
  ];
  final dm = {
    ...channelRow,
    'kind': 'dm',
    'channelId': 'd1',
    'channelName': 'Alice',
    'firstUnreadMessageId': 'first-dm',
    'lastMessageId': 'latest-dm',
    'firstMentionMessageId': null,
  };
  for (final size in sizes) {
    final wide = size.width >= 768;
    for (final flagOn in [false, true]) {
      for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
        testWidgets(
          '${size.width.toInt()}x${size.height.toInt()} flag=$flagOn ${kind.name}: '
          '${wide ? 'single click previews, same-row double upgrades, A then B previews B' : 'tap opens the conversation page'}',
          (t) async {
            SharedPreferences.setMockInitialValues({});
            t.view.physicalSize = size;
            t.view.devicePixelRatio = 1;
            addTearDown(t.view.reset);
            final (w, api) = (await t.runAsync(() => fixture('owner')))!;
            addTearDown(w.dispose);
            w.dms = [
              RaftChannel({
                'id': 'd1',
                'name': 'Alice',
                'type': 'dm',
                'joined': true,
              }),
            ];
            api.routes['POST /feature-flags/evaluate'] = (request) => {
              'evaluations': [
                for (final key in (request.data as Map)['keys'] as List)
                  {
                    'key': key,
                    'enabled': key == 'activity_sidebar_inbox_v0' && flagOn,
                  },
              ],
            };
            api.routes['GET /channels/inbox'] = (_) => {
              'items': [channelRow, dm],
            };
            for (final id in ['first-channel', 'mention-channel']) {
              api.routes['GET /messages/context/$id'] = (_) => {
                'messages': [message(id, 'c1')],
              };
            }
            api.routes['GET /messages/context/first-dm'] = (_) => {
              'messages': [message('first-dm', 'd1')],
            };
            api.routes['GET /channels/threads/followed'] = (_) => {
              'threads': [],
            };
            for (final id in ['c1', 'd1']) {
              api.routes['POST /channels/$id/read'] = (_) => {};
              api.routes['POST /channels/$id/read-all'] = (_) => {
                'maxReadSeq': 5,
                'readStateVersion': 7,
              };
            }
            w.loading = false;
            w.section = 'activity';
            w.messageDomain.ledger.switchServer('s1');
            await t.pumpWidget(
              MaterialApp(
                theme: raftTheme(RaftFamily.elegant),
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
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 25)),
            );
            await t.pumpAndSettle();
            final a = find.byKey(const ValueKey('activity-channel-c1'));
            final b = find.byKey(const ValueKey('activity-dm-d1'));
            expect(a, findsOneWidget);
            final entries = w.navigation.entries.length;
            await click(t, a, kind);
            await t.pump(const Duration(milliseconds: 80));
            if (!wide) {
              expect(w.location.route, RaftRoute.channel);
              expect(w.location.entityId, 'c1');
              expect(w.navigation.entries.length, entries + 1);
              await t.pumpAndSettle();
              expect(find.byType(ResourceView), findsNothing);
              expect(find.byType(RaftChatView), findsOneWidget);
              return;
            }
            // Preview: Activity stays the route and the list stays mounted.
            expect(w.location.route, RaftRoute.activity);
            expect(w.location.content?.kind, RaftContentKind.channel);
            expect(w.location.content?.id, 'c1');
            expect(w.navigation.entries.length, entries);
            expect(find.byType(ResourceView), findsOneWidget);
            expect(find.byType(RaftChatView), findsOneWidget);
            expect(a, findsOneWidget);
            expect(b, findsOneWidget);
            final tint = t.widget<RaftConversationCard>(a);
            expect(tint.selected, isTrue);
            // A different row retargets the preview, never navigates.
            await click(t, b, kind);
            await t.pump(const Duration(milliseconds: 80));
            expect(w.location.route, RaftRoute.activity);
            expect(w.location.content?.kind, RaftContentKind.dm);
            expect(w.location.content?.id, 'd1');
            expect(w.navigation.entries.length, entries);
            expect(find.byType(ResourceView), findsOneWidget);
            // The same row twice upgrades into the conversation.
            await click(t, b, kind);
            await t.pump(const Duration(milliseconds: 80));
            expect(w.location.route, RaftRoute.dm);
            expect(w.location.entityId, 'd1');
            expect(w.location.content, isNull);
            expect(w.navigation.entries.length, entries + 1);
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
          },
        );
      }
    }
  }
}
