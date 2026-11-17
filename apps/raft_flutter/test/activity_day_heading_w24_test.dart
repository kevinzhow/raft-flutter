// The real Activity list labels its day groups against the source clock
// (Web formatDayLabel): Today, Yesterday, then the weekday and date.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';

import 'support/activity_list_harness.dart';

void main() {
  late ActivityClient client;
  late ActivityWorkspace w;

  setUp(() {
    final (c, base) = activityFixture();
    // Day labels follow the person's zone; pin it so the host zone (the
    // rig clock is 15:00 UTC, already tomorrow in JST) does not matter.
    client = c..user = RaftRecord({'id': 'alice', 'preferredTimezone': 'UTC'});
    w = base
      ..inbox = [dayRow(0, day: 12), dayRow(1, day: 11), dayRow(2, day: 9)];
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  for (final env in [desktop, phoneTouch]) {
    testWidgets('${env.name}: Today, Yesterday, then the date', (t) async {
      await mountActivity(t, w, env);
      String label(int i) => t
          .widget<Text>(
            find.descendant(
              of: find.byKey(
                ValueKey('inbox-day-heading-2026-10-${'$i'.padLeft(2, '0')}'),
              ),
              matching: find.byType(Text),
            ),
          )
          .data!;
      expect(label(12), 'Today');
      expect(label(11), 'Yesterday');
      expect(label(9), contains('October 9'));
    });
  }
}
