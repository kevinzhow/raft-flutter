import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;
import 'workspace_activity_activation_test.dart'
    show channelRow, message, threadRow;

/// ThreadsInbox.tsx:1104-1175: opening an Activity entry fills the content slot
/// beside the Activity list; the page never gains a full-width channel header
/// on top (workspace-channel-header belongs to the channel route only).
void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final scenario in ['channel', 'dm', 'thread']) {
      testWidgets(
        '[K02] $family/$dark clicking an Activity $scenario entry adds no full-width channel header',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = const Size(1440, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
          addTearDown(w.dispose);
          w.loading = false;
          w.ledger.switchServer('s1');
          w.dms = [
            RaftChannel({
              'id': 'd1',
              'name': 'Alice',
              'type': 'dm',
              'joined': true,
            }),
          ];
          w.section = 'activity';
          api.routes['GET /channels/inbox'] = (_) => {
            'items': [
              threadRow,
              channelRow,
              {
                ...channelRow,
                'kind': 'dm',
                'channelId': 'd1',
                'channelName': 'Alice',
                'firstUnreadMessageId': 'first-dm',
              },
            ],
          };
          final held = Completer<Map<String, dynamic>>();
          api.routes['GET /messages/context/first-channel'] = (_) =>
              held.future;
          api.routes['GET /messages/context/first-dm'] = (_) => held.future;
          api.routes['GET /messages/context/parent'] = (_) => held.future;
          api.routes['GET /messages/context/reply'] = (_) => held.future;
          api.routes['GET /channels/c1/threads/parent'] = (_) => {
            'threadChannelId': 'thread-1',
          };
          api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
          for (final id in ['thread-1', 'c1', 'd1']) {
            api.routes['POST /channels/$id/read'] = (_) => {};
          }
          api.routes['POST /feature-flags/evaluate'] = (_) => {
            'evaluations': [],
          };
          api.routes['GET /servers/s1/setup-projection'] = (_) => {
            'phase': 'complete',
            'surface': 'complete',
            'blocksChat': false,
          };
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: WorkspaceView(
                controller: w,
                appearance: RaftAppearance(light: family),
                onAppearance: (_) async {},
                onLogout: () async {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          const header = Key('workspace-channel-header');
          final entry = find.byKey(
            ValueKey(switch (scenario) {
              'thread' => 'activity-thread-thread-1',
              'dm' => 'activity-dm-d1',
              _ => 'activity-channel-c1',
            }),
          );
          expect(entry, findsOneWidget);
          expect(find.byKey(header), findsNothing);
          final activityTop = tester.getTopLeft(entry).dy;

          await tester.tap(entry);
          // Pending context request, the 220 ms wait and every frame after it.
          var opened = false;
          for (var frame = 0; frame < 40; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(find.byKey(header), findsNothing, reason: 'frame $frame');
            expect(w.location.route, RaftRoute.activity);
            expect(w.section, 'activity');
            expect(entry, findsOneWidget);
            // The Activity list does not move down to make room for a header.
            expect(tester.getTopLeft(entry).dy, activityTop);
            opened = opened || w.location.content != null;
          }
          expect(
            opened,
            isTrue,
            reason: 'the entry opened in the content slot',
          );
          expect(
            find.byKey(const Key('desktop-content-detail')),
            findsOneWidget,
          );

          // The destination settles into the same slot, still without a header.
          await tester.runAsync(() async {
            held.complete({
              'messages': [
                message(
                  switch (scenario) {
                    'thread' => 'reply',
                    'dm' => 'first-dm',
                    _ => 'first-channel',
                  },
                  switch (scenario) {
                    'thread' => 'thread-1',
                    'dm' => 'd1',
                    _ => 'c1',
                  },
                ),
              ],
            });
            await Future<void>.delayed(const Duration(milliseconds: 35));
          });
          for (var frame = 0; frame < 10; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(find.byKey(header), findsNothing, reason: 'settle $frame');
            expect(tester.getTopLeft(entry).dy, activityTop);
          }
          await tester.pumpAndSettle();
          expect(find.byKey(header), findsNothing);
          expect(find.byType(RaftChatView), findsOneWidget);
          expect(w.section, 'activity');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        },
      );
    }
  }
}
