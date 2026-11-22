import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'workspace_activity_activation_test.dart' show channelRow, message;
import 'workspace_source_location_contract_test.dart'
    show frames, mountPage, pageFixture, waitForPainted;

void main() {
  for (final section in ['activity', 'search']) {
    for (final kind in ['agent', 'human']) {
      testWidgets('wide $section DM opens the $kind peer profile', (t) async {
        final (w, api) = await pageFixture(t, section: section);
        const id = 'peer', name = 'Actual peer', dmId = 'd1', target = 'm1';
        final agent = kind == 'agent';
        final dm = RaftChannel({
          'id': dmId,
          'type': 'dm',
          'name': 'Stored DM name',
          'joined': true,
          'peerId': id,
          'peerType': agent ? 'agent' : 'user',
          'peerDisplayName': name,
        });
        w.dms = [dm];
        final actor = {
          'id': id,
          'userId': id,
          'name': 'peer',
          'displayName': name,
          if (agent) 'status': 'active',
          if (agent) 'runtime': 'claude',
          if (agent) 'model': 'sonnet',
        };
        api.routes.addAll({
          'GET /channels/inbox': (_) => {
            'items': [
              {
                ...channelRow,
                'kind': 'dm',
                'channelId': dmId,
                'channelName': dm.name,
                'firstUnreadMessageId': target,
              },
            ],
          },
          'GET /messages/search': (_) => {
            'results': [
              {
                ...message(target, dmId),
                'channelName': dm.name,
                'channelType': dm.type,
                'content': 'Search needle',
              },
            ],
            'hasMore': false,
          },
          'GET /messages/context/$target': (_) => {
            'messages': [message(target, dmId)],
          },
          'POST /channels/$dmId/read': (_) => {},
          'GET /agents': (_) => [if (agent) actor],
          'GET /agents/$id': (_) => actor,
          'GET /agents/$id/skills': (_) => {'global': [], 'workspace': []},
          'GET /servers/s1/machines': (_) => {'machines': []},
          'GET /servers/s1/members': (_) => [if (!agent) actor],
          'GET /servers/s1/members/$id/profile': (_) => actor,
        });
        await mountPage(t, w, false, platform: TargetPlatform.linux);
        try {
          final search = section == 'search';
          final row = search
              ? find.byType(RaftSearchResultSurface).first
              : find.byKey(const ValueKey('activity-dm-d1'));
          if (search) {
            await t.enterText(find.byType(TextField).first, 'needle');
            await t.pump(const Duration(milliseconds: 210));
          }
          await frames(t, () {});
          await t.tap(row.hitTestable(), kind: PointerDeviceKind.mouse);
          await waitForPainted(t, target);
          expect(row.hitTestable(), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(RaftDmHeader),
              matching: find.text(name),
            ),
            findsOneWidget,
          );
          final avatar = find.byKey(const Key('dm-header-avatar-button'));
          final panel = find.byKey(ValueKey('profile-$kind-$id'));
          expect(panel, findsNothing);
          await t.tap(avatar.hitTestable(), kind: PointerDeviceKind.mouse);
          await t.pumpAndSettle();
          expect(
            find.descendant(of: panel, matching: find.text(name)),
            findsWidgets,
          );
          expect(find.byType(RaftDmHeader), findsOneWidget);
          expect(row.hitTestable(), findsOneWidget);

          expect(find.byTooltip('Close Detail'), findsNothing);
          if (search) {
            expect(
              t
                  .widget<TextField>(find.byType(TextField).first)
                  .controller!
                  .text,
              'needle',
            );
          }
        } finally {
          await t.pumpWidget(const SizedBox.shrink());
          await t.pump();
          expect(t.takeException(), isNull);
        }
      });
    }
  }
}
