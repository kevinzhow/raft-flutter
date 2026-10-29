import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  // The dialog kept one editor per field of its FIRST field set (a lazy
  // snapshot). Rebuilt with other fields (callers show the dialog before its
  // inputs load), the new fields had no editor and submit() asserted
  // `editors[field.id]!`.
  testWidgets('a dialog rebuilt with other fields submits the new fields', (
    t,
  ) async {
    Map<String, String>? submitted;
    Widget app(List<RaftFormField> fields) => MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: RaftFormDialog(
          title: 'Verify',
          fields: fields,
          onSubmit: (values) async => submitted = values,
        ),
      ),
    );
    await t.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      app(const [RaftFormField('first', 'First', initial: 'a')]),
    );
    await t.pumpWidget(
      app(const [
        RaftFormField('second', 'Second', initial: 'b'),
        RaftFormField('third', 'Third', choices: {'x': 'X', 'y': 'Y'}),
      ]),
    );
    expect(t.takeException(), isNull);
    expect(find.byKey(const ValueKey('field-first')), findsNothing);
    await t.tap(find.widgetWithText(RaftButton, 'Save'));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(submitted, {'second': 'b', 'third': 'x'});
  });
}
