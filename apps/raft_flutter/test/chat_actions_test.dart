import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  testWidgets(
    'message actions remain reachable in a short keyboard-inset window',
    (tester) async {
      final (w, _) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      w.ledger.switchServer('s1');
      w.ledger.ingest([
        {
          'id': 'm',
          'channelId': 'c1',
          'seq': '1',
          'messageType': 'chat',
          'content': 'Actions',
          'senderName': 'Alice',
        },
      ], expectedGeneration: w.ledger.generation);
      w.visibleIds['c1'] = {'m'};
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(body: RaftChatView(controller: w)),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final open = tester
          .widget<RaftMessageTile>(find.byType(RaftMessageTile))
          .onActions!;
      tester.view.physicalSize = const Size(360, 360);
      tester.view.viewInsets = const FakeViewPadding(bottom: 100);
      open();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      final last = find.text('Create task from message');
      await tester.ensureVisible(last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(last.hitTestable(), findsOneWidget);
      expect(find.text('Select messages'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
