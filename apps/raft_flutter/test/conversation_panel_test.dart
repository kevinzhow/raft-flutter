import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/features/conversation_panel.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark actual tab bodies preserve draft/cursor and reject hidden reads',
      (t) async {
        final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        w.ledger.switchServer('s1');
        w.ledger.ingest([
          {
            'id': 'm1',
            'channelId': 'c1',
            'seq': 1,
            'senderId': 'alice',
            'senderType': 'user',
            'content': 'Public message',
            'createdAt': '2026-06-22T02:30:00Z',
          },
        ], expectedGeneration: w.ledger.generation);
        w.visibleIds['c1'] = {'m1'};
        transport.routes['GET /agents'] = (_) => [];
        transport.routes['GET /servers/s1/members'] = (_) => [];
        transport.routes['GET /tasks/channel/c1'] = (_) => {
          'tasks': [],
          'nextCursor': null,
        };
        transport.routes['GET /channels/c1/files'] = (_) => {
          'files': [],
          'nextCursor': null,
        };
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: ConversationPanel(controller: w)),
          ),
        );
        await t.pumpAndSettle();
        final editor = find.descendant(
          of: find.byType(RaftComposer),
          matching: find.byType(TextField),
        );
        await t.enterText(editor, 'Retained 中文 draft');
        final field = t.widget<TextField>(editor);
        field.controller!.selection = const TextSelection.collapsed(offset: 5);
        final original = t.state(find.byType(RaftComposer));
        final tabs = find.byKey(const Key('conversation-tabs'));
        await t.tap(find.descendant(of: tabs, matching: find.text('Tasks')));
        await t.pumpAndSettle();
        await t.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 40));
        });
        await t.pumpAndSettle();
        expect(
          transport.calls.where((r) => r.path == '/tasks/channel/c1'),
          isNotEmpty,
        );
        expect(
          transport.calls.where((r) => r.path == '/tasks/server'),
          isEmpty,
        );
        expect(editor, findsNothing);
        final before = transport.calls.length;
        await t.runAsync(() => w.markRead('c1'));
        expect(transport.calls.length, before);
        await t.tap(find.descendant(of: tabs, matching: find.text('Files')));
        await t.pumpAndSettle();
        await t.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 40));
        });
        await t.pumpAndSettle();
        expect(
          transport.calls.where((r) => r.path == '/channels/c1/files'),
          hasLength(1),
        );
        expect(find.text('No files yet'), findsOneWidget);
        await t.tap(find.descendant(of: tabs, matching: find.text('Chat')));
        await t.pumpAndSettle();
        expect(t.state(find.byType(RaftComposer)), same(original));
        expect(t.widget<TextField>(editor).controller, same(field.controller));
        expect(field.controller!.text, 'Retained 中文 draft');
        expect(field.controller!.selection.baseOffset, 5);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
      },
    );
  }
}
