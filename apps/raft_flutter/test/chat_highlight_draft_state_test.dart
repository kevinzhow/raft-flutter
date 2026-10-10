import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '[K13d] $family/$dark actual highlight timer retains composer draft and keyboard selection',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(411, 915);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        w.ledger.switchServer('s1');
        w.ledger.ingest([
          {
            'id': 'target',
            'channelId': 'c1',
            'seq': 1,
            'senderId': 'alice',
            'senderType': 'user',
            'senderName': 'Alice',
            'content': 'Visible highlighted message',
            'messageType': 'chat',
          },
        ], expectedGeneration: w.ledger.generation);
        w.visibleIds['c1'] = {'target'};
        w.highlightedMessageId = 'target';
        api.routes['GET /servers/s1/setup-projection'] = (_) => {
          'phase': 'complete',
          'surface': 'complete',
          'blocksChat': false,
        };
        api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [];
        api.routes['GET /channels/c1/available-mentions'] = (_) => {
          'humans': [],
          'agents': [],
        };
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        // Observe the accepted visible highlight before the real two-second
        // timer expires; do not replace expiry with a direct state setter.
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(w.highlightedMessageId, 'target');
        const draft = '中文 draft 日本語';
        final input = find.descendant(
          of: find.byType(RaftComposer),
          matching: find.byType(EditableText),
        );
        expect(input, findsOneWidget);
        await tester.tap(input);
        await tester.enterText(input, draft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        final field = tester.widget<EditableText>(input);
        final selection = field.controller.selection;
        expect(selection.isCollapsed, isFalse);
        expect(field.focusNode.hasFocus, isTrue);
        expect(w.drafts[w.draftScope()], draft);
        await tester.pump(const Duration(milliseconds: 2200));
        await tester.pump();
        expect(w.highlightedMessageId, isNull);
        final after = tester.widget<EditableText>(input);
        expect(after.controller.text, draft);
        expect(after.controller.selection, selection);
        expect(after.focusNode.hasFocus, isTrue);
        expect(w.drafts[w.draftScope()], draft);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
