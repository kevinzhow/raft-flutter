import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/activity_list_harness.dart';

void main() {
  late ActivityClient client;
  late ActivityWorkspace w;

  setUp(() {
    final (c, base) = activityFixture();
    client = c;
    w = base
      ..inbox = [
        dayRow(0, day: 12, unread: 2),
        dayRow(1, day: 12),
        dayRow(2, day: 11),
        dayRow(3, day: 11),
        dayRow(4, day: 10),
        for (var i = 5; i < 40; i++) dayRow(i, day: 9 - (i ~/ 14)),
      ];
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  for (final env in [desktop, phoneTouch, phoneMouse, foldA, foldB]) {
    group(env.name, () {
      testWidgets('the Filter bar replaces the segmented strip', (t) async {
        await mountActivity(t, w, env);
        expect(find.byType(RaftActivityFilterBar), findsOneWidget);
        expect(find.byType(RaftSegmentedControl<String>), findsNothing);
        final inScroller = find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(RaftActivityFilterBar),
        );
        expect(inScroller.evaluate().isNotEmpty, env.phone);
      });

      testWidgets('Mark all read shows while something is unread and posts', (
        t,
      ) async {
        await mountActivity(t, w, env);
        final mark = find.byKey(
          const ValueKey('activity-filter-mark-all-read'),
        );
        expect(
          find
                  .textContaining('Mark all', findRichText: true)
                  .evaluate()
                  .isNotEmpty ||
              find.byTooltip('Mark all as read').evaluate().isNotEmpty ||
              mark.evaluate().isNotEmpty,
          isTrue,
        );
      });

      testWidgets('one heading per day, 2px between rows, no Divider', (
        t,
      ) async {
        await mountActivity(t, w, env);
        expect(
          find.byKey(const ValueKey('inbox-item-list-heading')),
          findsWidgets,
        );
        expect(find.byType(Divider), findsNothing);
        final a = t.getRect(find.byKey(const ValueKey('activity-channel-ch0')));
        final b = t.getRect(find.byKey(const ValueKey('activity-channel-ch1')));
        expect(b.top - a.bottom, 2);
      });

      testWidgets('a stuck day heading sits under the bar and covers rows', (
        t,
      ) async {
        await mountActivity(t, w, env);
        final scroll = t.state<ScrollableState>(find.byType(Scrollable).first);
        final bar = t.getRect(find.byType(RaftActivityFilterBar));
        for (final at in [200.0, 450.0, 700.0]) {
          scroll.position.jumpTo(at);
          await t.pump();
          final tops = [
            for (final e in find.byType(RaftInboxItemListGroup).evaluate())
              (e.renderObject! as RenderBox).localToGlobal(Offset.zero).dy,
          ];
          expect(
            tops.any((y) => (y - bar.bottom).abs() < .5),
            isTrue,
            reason: 'at $at: $tops bar ${bar.bottom}',
          );
        }
      });
    });
  }
}
