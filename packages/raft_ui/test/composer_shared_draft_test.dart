import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'shared draft updates a focused editor without losing selection or IME ${dark ? 'dark' : 'light'}',
      (t) async {
        final edits = <String>[];
        Widget host(String draft, int revision) => MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RaftComposer(
                initialDraft: draft,
                draftRevision: revision,
                onDraftChanged: edits.add,
                onSend: (_) async => true,
              ),
            ),
          ),
        );
        await t.pumpWidget(host('existing 中文', 0));
        final field = find.byType(TextField);
        await t.tap(field);
        await t.pump();
        final controller = t.widget<TextField>(field).controller!;
        controller.value = const TextEditingValue(
          text: 'existing 中文',
          selection: TextSelection(baseOffset: 9, extentOffset: 11),
          composing: TextRange(start: 9, end: 11),
        );
        await t.pump();
        final before = controller.value;
        edits.clear();
        await t.pumpWidget(host('existing 中文\nshared file caption', 1));
        await t.pump();
        expect(controller.text, 'existing 中文');
        expect(controller.selection, before.selection);
        expect(controller.value.composing, before.composing);
        expect(t.widget<TextField>(field).focusNode!.hasFocus, isTrue);
        expect(edits.last, 'existing 中文\nshared file caption');
        // Native input continues immediately while projected drafts persist.
        controller.value = const TextEditingValue(
          text: 'existing 中文继续',
          selection: TextSelection.collapsed(offset: 13),
          composing: TextRange(start: 9, end: 13),
        );
        await t.pump();
        expect(controller.text, 'existing 中文继续');
        expect(edits.last, 'existing 中文继续\nshared file caption');
        controller.value = controller.value.copyWith(
          composing: TextRange.empty,
        );
        await t.pump();
        await t.pump();
        expect(controller.text, 'existing 中文继续\nshared file caption');
        expect(controller.selection.baseOffset, 13);
        // Ordinary rebuilds/persistence do not overwrite committed input.
        await t.enterText(field, 'user continues editing');
        await t.pumpWidget(host('existing 中文\nshared file caption', 1));
        expect(controller.text, 'user continues editing');
        expect(edits.last, 'user continues editing');
        expect(t.takeException(), isNull);
      },
    );
  }
}
