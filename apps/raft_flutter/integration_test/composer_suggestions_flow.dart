import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_ui/raft_ui.dart';

Future<void> verifyComposerSuggestions(
  WidgetTester tester,
  WorkspaceController w,
  Future<void> Function(String) capture,
) async {
  final user = w.client.user!, name = w.client.user!.string('name');
  expect(name, isNotEmpty);
  final marker =
      'Native assisted mention ${DateTime.now().microsecondsSinceEpoch}';
  final composer = find.byType(RaftComposer).first;
  final field = find.descendant(of: composer, matching: find.byType(TextField));
  await tester.enterText(field, '$marker @$name');
  final choice = find.byKey(ValueKey('composer-suggestion-user-${user.id}'));
  for (var i = 0; i < 100 && choice.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(choice, findsOneWidget);
  await tester.ensureVisible(choice);
  await tester.pump(const Duration(milliseconds: 300));
  await capture('linux-composer-assisted-mention');
  await tester.tap(choice);
  await tester.pump(const Duration(milliseconds: 300));
  final sent = '$marker @$name';
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  for (var i = 0; i < 100 && !w.messages.any((m) => m.content == sent); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final message = w.messages.singleWhere((m) => m.content == sent);
  final context = await w.query(
    '/messages/context/${message.id}',
    query: {'channelId': w.channel!.id},
  );
  final rows = (context['messages'] as List).whereType<Map>();
  final receipt = rows.singleWhere((m) => m['id'] == message.id);
  expect(
    (receipt['mentions'] as List? ?? []).whereType<Map>().any(
      (m) => m['type'] == 'user' && m['id'] == user.id && m['name'] == name,
    ),
    isTrue,
  );
  expect(
    tester
        .widget<EditableText>(
          find.descendant(of: composer, matching: find.byType(EditableText)),
        )
        .controller
        .text,
    isEmpty,
  );
}
