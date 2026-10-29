import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  Future<({List<String> attached, List<MethodCall> textInput})> pumpComposer(
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final attached = <String>[];
    final textInput = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (call) async {
        textInput.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: RaftComposer(
              onSend: (_) async => true,
              onAttach: () => attached.add('attach'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return (attached: attached, textInput: textInput);
  }

  EditableText editable(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText));

  testWidgets('a tap on the composer blank space focuses the editor', (
    tester,
  ) async {
    await pumpComposer(tester);
    expect(editable(tester).focusNode.hasFocus, isFalse);
    final shell = tester.getRect(
      find.byKey(const ValueKey('composer-shell-slot')),
    );
    final field = tester.getRect(find.byType(TextField));
    // Blank space: inside the shell, below the first editor line and
    // left of the toolbar's buttons' row centre, away from any button.
    final blank = Offset(shell.center.dx, (field.bottom + shell.bottom) / 2);
    expect(
      tester
          .hitTestOnBinding(blank)
          .path
          .any((entry) => entry.target is RenderEditable),
      isFalse,
      reason: 'the probe must miss the text field itself',
    );
    await tester.tapAt(blank);
    await tester.pump();
    expect(editable(tester).focusNode.hasFocus, isTrue);
  });

  testWidgets('buttons keep their own taps', (tester) async {
    final probe = await pumpComposer(tester);
    await tester.tap(find.byTooltip('Attach File'));
    await tester.pump();
    expect(probe.attached, ['attach']);
    expect(editable(tester).focusNode.hasFocus, isFalse);
  });

  testWidgets('a focused editor with a dismissed keyboard shows it '
      'again', (tester) async {
    final probe = await pumpComposer(tester);
    final shell = tester.getRect(
      find.byKey(const ValueKey('composer-shell-slot')),
    );
    final field = tester.getRect(find.byType(TextField));
    final blank = Offset(shell.center.dx, (field.bottom + shell.bottom) / 2);
    await tester.tapAt(blank);
    await tester.pump();
    probe.textInput.clear();
    await tester.tapAt(blank);
    await tester.pump();
    expect(
      probe.textInput.map((call) => call.method),
      contains('TextInput.show'),
    );
  });
}
