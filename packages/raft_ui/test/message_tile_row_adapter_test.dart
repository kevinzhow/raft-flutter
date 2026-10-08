import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/components.dart';
import 'package:raft_ui/src/message_row_recipe.dart';
import 'package:raft_ui/src/theme.dart';

void main() {
  testWidgets(
    'tile retains actual thread/reaction/file callbacks through the row adapter',
    (tester) async {
      var threads = 0;
      String? reacted;
      Map<String, dynamic>? opened;
      const attachment = <String, dynamic>{
        'id': 'public-attachment',
        'filename': 'public.txt',
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: RaftMessageTile(
              author: 'Public Agent',
              content: 'Public body',
              timestamp: '14:30',
              onThread: () => threads++,
              threadLabel: '3 replies',
              reactions: const [
                {'emoji': '👍', 'count': 2},
              ],
              onReaction: (emoji) => reacted = emoji,
              attachments: const [attachment],
              onAttachment: (a) => opened = a,
              coarsePointer: true,
            ),
          ),
        ),
      );
      expect(find.byType(RaftMessageRow), findsOneWidget);
      await tester.tap(find.text('3 replies'));
      await tester.tap(find.byKey(const ValueKey('reaction-👍')));
      await tester.tap(find.text('public.txt'));
      await tester.pump();
      expect(threads, 1);
      expect(reacted, '👍');
      expect(opened, same(attachment));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tile uses controlled grouping and retains secondary context action',
    (tester) async {
      var actions = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: Scaffold(
            body: RaftMessageTile(
              author: 'Public Agent',
              content: 'Public continuation',
              timestamp: '14:31',
              continuation: true,
              coarsePointer: true,
              onActions: () => actions++,
            ),
          ),
        ),
      );
      expect(find.text('Public Agent'), findsNothing);
      // Row context action stays available in the actual outer message gutter;
      // selectable text owns its own long-press selection gesture.
      final row = tester.getRect(find.byType(RaftMessageRow));
      await tester.longPressAt(Offset(row.left + 20, row.top + 8));
      await tester.pump();
      expect(actions, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
