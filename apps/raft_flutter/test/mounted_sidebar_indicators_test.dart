import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'mounted_message_navigation_test.dart' show pageFixture, mountPage;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark actual sidebar reflects mute, membership and drafts',
      (t) async {
        final (w, api) = await pageFixture(t);
        w.channels.addAll([
          RaftChannel({
            'id': 'quiet',
            'name': 'Muted unread',
            'joined': true,
            'activityMuted': true,
          }),
          RaftChannel({
            'id': 'public',
            'name': 'Unjoined unread',
            'joined': false,
          }),
          RaftChannel({'id': 'draft', 'name': 'Channel draft', 'joined': true}),
          RaftChannel({
            'id': 'dm',
            'type': 'dm',
            'name': 'Human DM',
            'peerDisplayName': 'Human DM',
            'peerId': 'human',
          }),
        ]);
        w.unread.addAll({'quiet': 104, 'public': 3});
        w.drafts.addAll({'draft': 'unsent channel', 'dm': 'unsent DM'});
        await mountPage(t, w, family, dark);
        expect(find.byType(RaftSidebarQuietUnreadCount), findsNWidgets(2));
        expect(find.byType(RaftSidebarMutedIcon), findsOneWidget);
        expect(find.byType(RaftSidebarDraftIcon), findsNWidgets(2));
        expect(find.text('99+'), findsOneWidget);
        final muted = find.byKey(const ValueKey('sidebar-channel-quiet'));
        final unjoined = find.byKey(const ValueKey('sidebar-channel-public'));
        expect(t.widget<RaftNavItem>(muted).activityMuted, true);
        expect(t.widget<RaftNavItem>(unjoined).joined, false);
        expect(
          t.widget<Text>(find.text('Muted unread')).style!.fontWeight,
          FontWeight.w500,
        );
        expect(
          t.widget<Text>(find.text('Unjoined unread')).style!.fontWeight,
          FontWeight.w500,
        );
        // An accepted preference event changes the same mounted SDK row rather
        // than letting a stale quiet count/marker survive.
        final index = w.channels.indexWhere((c) => c.id == 'quiet');
        w.channels[index] = RaftChannel({
          ...w.channels[index].json,
          'activityMuted': false,
        });
        await t.runAsync(() async {
          w.notifyListeners();
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await t.pumpAndSettle();
        expect(find.byType(RaftSidebarMutedIcon), findsNothing);
        expect(find.byType(RaftSidebarQuietUnreadCount), findsOneWidget);
        expect(
          t.widget<Text>(find.text('Muted unread')).style!.fontWeight,
          FontWeight.w700,
        );
        api.routes['GET /messages/channel/public'] = (_) => {'messages': []};
        // A dimmed unjoined row stays actionable, as in Source ChannelRow.
        await t.runAsync(() async {
          await t.tap(unjoined);
          for (var frame = 0; frame < 40 && w.channelLoading; frame++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        });
        await t.pump();
        expect(w.channel?.id, 'public');
        expect(w.drafts['draft'], 'unsent channel');
        expect(w.drafts['dm'], 'unsent DM');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
