import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/saved_sidebar_entry.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityClient, ActivityWorkspace, activityFixture;

/// Source ThreadsInbox `checkSaved` / savedStore: the messages Activity lists
/// are checked with `POST /channels/saved/check`, so a message older than the
/// first Saved page already shows as saved when it is opened.
void main() {
  late ActivityClient client;
  late ActivityWorkspace w;
  setUp(() => (client, w) = activityFixture());
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Iterable<List> checks() => [
    for (var i = 0; i < client.posts.length; i++)
      if (client.posts[i] == 'POST /channels/saved/check')
        (client.bodies[i] as Map)['messageIds'] as List,
  ];

  testWidgets('the listed rows are checked by their message; the answer marks '
      'them saved', (tester) async {
    client.responses['POST /channels/saved/check'] = {
      'savedIds': ['m3', 'unknown-to-the-list'],
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ResourceView(
            controller: w,
            section: 'activity',
            activitySidebarEnabled: true,
            onMessage: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final sent = checks().first;
    expect(sent, containsAll(['m0', 'm3']));
    final saved = SavedCountStore.of(w);
    expect(saved.isSaved('m3'), isTrue);
    expect(saved.isSaved('unknown-to-the-list'), isTrue);
    expect(saved.isSaved('m4'), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a server that fails the check changes nothing', (tester) async {
    client.responses['POST /channels/saved/check'] = 'not an object';
    final saved = SavedCountStore.of(w);
    await saved.check(['m1']);
    expect(saved.isSaved('m1'), isFalse);
  });

  test(
    'at most 200 ids go in one request; empty ids and none are skipped',
    () async {
      final saved = SavedCountStore.of(w);
      await saved.check(const []);
      await saved.check(['', '']);
      expect(checks(), isEmpty);
      await saved.check([for (var i = 0; i < 450; i++) 'id-$i', 'id-1']);
      expect([for (final c in checks()) c.length], [200, 200, 50]);
    },
  );
}
