import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('$family/$dark typed draft releases old caret handle and remains selectable', (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sent = <String>[];
      await tester.pumpWidget(MaterialApp(
        theme: raftTheme(family, dark: dark).copyWith(platform: TargetPlatform.android),
        home: Scaffold(body: Align(alignment: Alignment.bottomCenter,
          child: RaftComposer(initialDraft: 'Old draft', onSend: (value) async {
            sent.add(value);
            return true;
          }),
        )),
      ));
      final editor = find.byType(TextField);
      await tester.tap(editor);
      await tester.pumpAndSettle();
      final state = tester.state<EditableTextState>(find.byType(EditableText));
      expect(state.selectionOverlay?.handlesAreVisible, isTrue);
      await tester.enterText(editor, 'Native Flutter E2E 1791519000000 · 中文 日本語');
      await tester.pump();
      expect(state.selectionOverlay?.handlesAreVisible ?? false, isFalse);
      final action = find.byWidgetPredicate((widget) => widget is RaftComposerAction && widget.submit);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(sent, ['Native Flutter E2E 1791519000000 · 中文 日本語']);
      await tester.enterText(editor, 'Select this draft');
      await tester.pumpAndSettle();
      await tester.longPressAt(tester.getTopLeft(editor) + const Offset(25, 10));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(editor).controller!.selection.isCollapsed, isFalse);
      expect(state.selectionOverlay?.handlesAreVisible, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
