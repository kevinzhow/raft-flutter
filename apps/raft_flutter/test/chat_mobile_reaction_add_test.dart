import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark actual mobile add opens scoped picker without mutation and Escape preserves draft',
      (t) async {
        final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        w.ledger.switchServer('s1');
        w.ledger.ingest([
          {
            'id': 'm1',
            'channelId': 'c1',
            'seq': 1,
            'senderId': 'agent',
            'senderType': 'agent',
            'senderName': 'Cindy',
            'content': 'Public body',
            'createdAt': '2026-06-22T02:30:00Z',
            'reactions': [
              {
                'emoji': '👍',
                'count': 2,
                'reactorIds': ['user'],
                'reactorNames': ['Public viewer'],
              },
            ],
          },
        ], expectedGeneration: w.ledger.generation);
        w.visibleIds['c1'] = {'m1'};
        transport.routes['GET /agents'] = (_) => [];
        transport.routes['GET /servers/s1/members'] = (_) => [];
        transport.routes['GET /tasks/channel/c1'] = (_) => {'tasks': []};
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: MediaQuery(
              data: const MediaQueryData(size: Size(390, 720)),
              child: Scaffold(
                body: RaftDensityScope(
                  density: RaftDensity.touch,
                  child: SizedBox(
                    width: 390,
                    child: RaftChatView(controller: w),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextField), 'Retained 中文');
        await t.pump();
        final add = find.byKey(const ValueKey('message-reaction-add'));
        expect(add, findsOneWidget);
        expect(t.getSize(add).height, 20);
        await t.tap(add);
        await t.pump();
        expect(find.byType(RaftQuickReactionPicker), findsOneWidget);
        expect(find.byType(RaftReactionGlyph), findsNWidgets(8));
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pump();
        expect(find.byType(RaftQuickReactionPicker), findsNothing);
        expect(
          t.widget<EditableText>(find.byType(EditableText)).controller.text,
          'Retained 中文',
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pump();
      },
    );
  }
}
