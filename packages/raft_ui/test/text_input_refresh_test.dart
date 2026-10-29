import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// macOS: a resized window can leave the engine's text input view without key
// input although the connection is intact; the focused field shows it again.

List<String> _calls(WidgetTester t) => [
  for (final c in t.testTextInput.log) c.method,
];

Future<TextEditingController> _app(WidgetTester t, {bool focus = true}) async {
  t.view.physicalSize = const Size(800, 600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = TextEditingController();
  addTearDown(c.dispose);
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const Expanded(child: SizedBox()),
            RaftComposer(onSend: (_) async => true),
          ],
        ),
      ),
    ),
  );
  if (focus) {
    await t.tap(find.byType(TextField));
    await t.pump();
  }
  return c;
}

void main() {
  testWidgets('a resize shows the focused field again, on the same client', (
    t,
  ) async {
    await _app(t);
    final client = t.testTextInput.log
        .firstWhere((c) => c.method == 'TextInput.setClient')
        .arguments[0];
    t.testTextInput.log.clear();
    t.view.physicalSize = const Size(900, 600);
    await t.pump();
    await t.pump();
    expect(_calls(t), contains('TextInput.show'));
    expect(_calls(t), isNot(contains('TextInput.setClient')));
    expect(_calls(t), isNot(contains('TextInput.clearClient')));
    expect(client, isNotNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a composition is not disturbed by the show', (t) async {
    await _app(t);
    final field = t.state<EditableTextState>(find.byType(EditableText));
    t.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'nihao',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 0, end: 5),
      ),
    );
    await t.pump();
    final before = field.widget.controller.value;
    t.view.physicalSize = const Size(900, 600);
    await t.pump();
    await t.pump();
    expect(field.widget.controller.value, before);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('nothing is sent when no field is focused', (t) async {
    await _app(t, focus: false);
    t.testTextInput.log.clear();
    t.view.physicalSize = const Size(900, 600);
    await t.pump();
    await t.pump();
    expect(_calls(t), isNot(contains('TextInput.show')));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('other platforms are left alone', (t) async {
    await _app(t);
    t.testTextInput.log.clear();
    t.view.physicalSize = const Size(900, 600);
    await t.pump();
    await t.pump();
    expect(_calls(t), isNot(contains('TextInput.show')));
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
