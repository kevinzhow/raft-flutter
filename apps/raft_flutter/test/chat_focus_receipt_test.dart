import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  testWidgets(
    'an early void focus receipt retries until the actual lazy target mounts',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final (w, a) = (await tester.runAsync(() => fixture('member')))!;
      addTearDown(w.dispose);
      w.ledger.switchServer('s1');
      List<Map<String, dynamic>> page(String prefix) => [
        for (var i = 0; i < 80; i++)
          {
            'id': '$prefix-$i',
            'channelId': 'c1',
            'seq': '${i + 1}',
            'senderId': 'alice',
            'content': 'Lazy context row $i',
          },
      ];
      final initial = page('old'), replacement = page('new');
      w.ledger.ingest(initial, expectedGeneration: w.ledger.generation);
      w.visibleIds['c1'] = initial.map((r) => r['id'] as String).toSet();
      a.routes['GET /messages/context/new-79'] = (_) => {
        'messages': replacement,
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(body: RaftChatView(controller: w)),
        ),
      );
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(RaftChatView));
      var attempts = 0;
      bool? firstMounted;
      state.adapter.attachScrollMethods(
        scrollToMessageId:
            (
              String id, {
              Duration duration = Duration.zero,
              Curve curve = Curves.linear,
              double alignment = 0,
              double offset = 0,
            }) async {
              attempts++;
              if (attempts == 1) {
                firstMounted = find
                    .byKey(const ValueKey('message-new-79'))
                    .evaluate()
                    .isNotEmpty;
                // A normal void return is permitted while the package has no target
                // in its internal list. It is not a rendered focus acknowledgment.
                return;
              }
              state.viewport.jumpTo(state.viewport.position.maxScrollExtent);
            },
        scrollToIndex: (
          int index, {
          Duration duration = Duration.zero,
          Curve curve = Curves.linear,
          double alignment = 0,
          double offset = 0,
        }) async {},
      );
      await tester.runAsync(() => w.jumpToMessage('c1', 'new-79'));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(firstMounted, isFalse);
      expect(attempts, greaterThanOrEqualTo(2));
      expect(
        find.byKey(const ValueKey('message-new-79')).hitTestable(),
        findsOneWidget,
      );
      expect(state.scrolledHighlight, 'new-79');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}
