import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/activity_list_harness.dart';

void main() {
  late ServerClient client;
  late ActivityWorkspace w;

  setUp(() {
    final (c, base) = serverFixture();
    client = c;
    w = base..inbox = [dayRow(0, unread: 2), dayRow(1), dayRow(2, unread: 1)];
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Finder rowOf(String key) => find.byKey(ValueKey(key));

  testWidgets('right swipe on an unread row reads it, once, with no toast', (
    t,
  ) async {
    await mountActivity(t, w, phoneTouch);
    await t.drag(rowOf('activity-channel-ch0'), const Offset(260, 0));
    await t.pumpAndSettle();
    expect(client.posts.where((p) => p.endsWith('/read-all')), hasLength(1));
    expect(find.textContaining("Couldn't mark"), findsNothing);
    expect(rowOf('activity-channel-ch0'), findsOneWidget);
  });

  testWidgets('a failed Mark as Read says so (Web thread.row.markReadFailed)', (
    t,
  ) async {
    client.failPaths.add('POST /channels/ch0/read-all');
    await mountActivity(t, w, phoneTouch);
    await t.drag(rowOf('activity-channel-ch0'), const Offset(260, 0));
    await t.pumpAndSettle();
    expect(find.text("Couldn't mark it as read. Try again."), findsOneWidget);
    // The row is back as the server has it: unread.
    expect(rowOf('activity-channel-ch0'), findsOneWidget);
  });

  testWidgets(
    'a failed Mark as Unread says so (Web thread.row.markUnreadFailed)',
    (t) async {
      client.failPaths.add('POST /channels/ch1/unread');
      await mountActivity(t, w, phoneTouch);
      await t.drag(rowOf('activity-channel-ch1'), const Offset(260, 0));
      await t.pumpAndSettle();
      expect(
        find.text("Couldn't mark it as unread. Try again."),
        findsOneWidget,
      );
    },
  );
}
