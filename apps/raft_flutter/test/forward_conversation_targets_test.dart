import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/forward_composer_page.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  testWidgets(
    'the forward picker fetches recent threads once and puts this conversation first',
    (tester) async {
      final (w, a) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.channel = RaftChannel({
        'id': 'thread-current',
        'name': 'Current',
        'type': 'thread',
      });
      a.routes['GET /messages/forward/targets/conversations'] = (_) => {
        'targets': [
          {
            'id': 'task',
            'type': 'task',
            'channelId': 'task',
            'title': 'Design review',
            'canForwardNow': true,
          },
          {
            'id': 'thread-current',
            'type': 'thread',
            'channelId': 'thread-current',
            'title': 'Current conversation',
            'canForwardNow': true,
            'current': true,
          },
          {'id': 'bad', 'type': 'channel', 'title': 'Invalid result'},
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: ForwardComposerPage(
              controller: w,
              desktop: false,
              messages: [
                RaftMessage({
                  'id': 'source',
                  'channelId': 'thread-current',
                  'content': 'Body',
                }),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final calls = a.calls.where(
        (r) => r.path == '/messages/forward/targets/conversations',
      );
      expect(calls.single.queryParameters, {
        'limit': 4,
        'currentChannelId': 'thread-current',
      });
      expect(find.text('Threads & tasks'), findsOneWidget);
      expect(find.text('Invalid result'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Current conversation')).dy,
        lessThan(tester.getTopLeft(find.text('Design review')).dy),
      );
      await tester.tap(find.text('Design review'));
      await tester.pumpAndSettle();
      expect(find.text('Add a note'), findsWidgets);
    },
  );
}
