import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'mounted_message_navigation_test.dart' show pageFixture, mountPage;

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} recent sidebar keeps order and current indicators through resize and history changes',
      (t) async {
        final (w, _) = await pageFixture(t);
        w.channels.addAll([
          RaftChannel({'id': 'activity-a', 'name': 'Earlier', 'joined': true}),
          RaftChannel({'id': 'activity-b', 'name': 'Later', 'joined': true}),
        ]);
        w.sidebarOrder = {'channelSortMode': 'recent'};
        w.messageDomain.ledger.ingest([
          for (var i = 0; i < 600; i++)
            {
              'id': 'activity-$i',
              'channelId': 'activity-a',
              'seq': '$i',
              'createdAt': DateTime.utc(
                2026,
                10,
                1,
              ).add(Duration(minutes: i)).toIso8601String(),
            },
          {
            'id': 'later',
            'channelId': 'activity-b',
            'seq': '2',
            'createdAt': '2026-10-02T00:00:00Z',
          },
        ], expectedGeneration: w.messageDomain.ledger.generation);
        await mountPage(t, w, dark);
        final a = find.byKey(const ValueKey('sidebar-channel-activity-a'));
        final b = find.byKey(const ValueKey('sidebar-channel-activity-b'));
        final accepted = w.messageDomain.ledger.latestCreatedAt('activity-a');
        for (var i = 0; i < 12; i++) {
          t.view.physicalSize = Size(i.isEven ? 1200 : 1440, 900);
          await t.pump();
          expect(t.getTopLeft(b).dy, lessThan(t.getTopLeft(a).dy));
          expect(
            identical(
              w.messageDomain.ledger.latestCreatedAt('activity-a'),
              accepted,
            ),
            true,
          );
        }
        w.conversationReads.unread['activity-a'] = 3;
        w.drafts['activity-b'] = 'unsent draft';
        w.messageDomain.ledger.ingestUpdate({
          'id': 'activity-599',
          'channelId': 'activity-a',
          'createdAt': '2026-10-03T00:00:00Z',
        }, expectedGeneration: w.messageDomain.ledger.generation);
        w.notifyListeners();
        await t.pump();
        expect(t.getTopLeft(a).dy, lessThan(t.getTopLeft(b).dy));
        expect(t.widget<RaftNavItem>(a).unread, 3);
        expect(t.widget<RaftNavItem>(b).hasDraft, true);
        w.messageDomain.ledger.remove('activity-a', 'activity-599');
        w.notifyListeners();
        await t.pump();
        expect(t.getTopLeft(b).dy, lessThan(t.getTopLeft(a).dy));
        w.messageDomain.ledger.revokeChannel('activity-b');
        w.notifyListeners();
        await t.pump();
        expect(w.messageDomain.ledger.latestCreatedAt('activity-b'), isNull);
        expect(t.getTopLeft(a).dy, lessThan(t.getTopLeft(b).dy));
        expect(t.widget<RaftNavItem>(a).unread, 3);
        expect(t.widget<RaftNavItem>(b).hasDraft, true);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
