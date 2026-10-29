@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/resource_search.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final threaded in [false, true]) {
      testWidgets(
        '1000 search results stay lazy ${dark ? 'dark' : 'light'}/thread=$threaded',
        (t) async {
          Map<String, dynamic>? selected;
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
              home: Scaffold(
                body: ResourceSearchResults(
                  query: 'result',
                  rows: [
                    for (var i = 0; i < 1000; i++)
                      {
                        'id': 'hit-$i',
                        'channelId': 'c',
                        'channelName': 'Fixture',
                        'channelType': threaded ? 'thread' : 'channel',
                        'parentMessageId': 'parent',
                        'parentMessageContent': 'Thread context',
                        'parentChannelName': 'Fixture',
                        'senderName': 'Alice',
                        'senderType': 'user',
                        'senderId': 'alice',
                        'content': 'result $i',
                        'createdAt': '2026-10-01T00:00:00Z',
                      },
                  ],
                  entities: const [],
                  origin: 'https://fixture.invalid',
                  plan: 'pro',
                  now: DateTime.utc(2026, 10, 11),
                  selectedKey: null,
                  onMessage: (row) => selected = row,
                  onEntity: (_) {},
                  hasMore: false,
                  onMore: () {},
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(
            find.byType(RaftSearchResultSurface).evaluate().length,
            lessThan(30),
          );
          await t.scrollUntilVisible(
            find.text('result 999', findRichText: true),
            3000,
            scrollable: find.byType(Scrollable),
            maxScrolls: 50,
          );
          await t.tap(find.text('result 999', findRichText: true));
          expect(selected?['id'], 'hit-999');
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
