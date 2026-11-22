import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;

// Web forms are `<form onSubmit>`: Enter in a one-line field submits. A code
// field (Web `AnswerField`) asks for the number pad and the system's
// one-time-code suggestion; a wrong code sits under the field until it is
// edited; Verify stays disabled until something is typed.

Future<void> _show(WidgetTester tester, RaftFormDialog dialog) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  showRaftForm<bool>(context, builder: (_) => dialog),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder _field(String id) => find.descendant(
  of: find.byKey(ValueKey('field-$id')),
  matching: find.byType(EditableText),
);

Future<void> _enter(WidgetTester tester, String id) async {
  await tester.showKeyboard(_field(id));
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  leakDebt(const ['CurvedAnimation']);

  testWidgets('Enter in any one-line field submits', (tester) async {
    final sent = <Map<String, String>>[];
    await _show(
      tester,
      RaftFormDialog(
        title: 'Rename',
        fields: const [
          RaftFormField('name', 'Name'),
          RaftFormField('note', 'Note'),
        ],
        onSubmit: (v) async => sent.add(v),
      ),
    );
    await tester.enterText(_field('name'), 'one');
    await _enter(tester, 'name');
    expect(sent, [
      {'name': 'one', 'note': ''},
    ]);
    expect(find.byType(RaftFormDialog), findsNothing);
  });

  testWidgets('Enter in a multiline field is a new line, not a submit', (
    tester,
  ) async {
    var sent = 0;
    await _show(
      tester,
      RaftFormDialog(
        title: 'Describe',
        fields: const [RaftFormField('text', 'Text', multiline: true)],
        onSubmit: (_) async => sent++,
      ),
    );
    final input = tester.widget<EditableText>(_field('text'));
    expect(input.textInputAction, TextInputAction.newline);
    expect(input.onSubmitted, isNull);
    expect(sent, 0);
  });

  testWidgets('Enter does nothing while the submit action is disabled', (
    tester,
  ) async {
    var sent = 0;
    await _show(
      tester,
      RaftFormDialog(
        title: 'Verify',
        submitLabel: 'Verify',
        submitEnabled: false,
        fields: const [RaftFormField('code', 'Code')],
        onSubmit: (_) async => sent++,
      ),
    );
    await tester.enterText(_field('code'), '123456');
    await _enter(tester, 'code');
    expect(sent, 0);
    expect(find.byType(RaftFormDialog), findsOneWidget);
  });

  testWidgets('submitWhenFilled: Verify and Enter wait for a typed code', (
    tester,
  ) async {
    var sent = 0;
    await _show(
      tester,
      RaftFormDialog(
        title: 'Verify',
        submitLabel: 'Verify',
        submitWhenFilled: true,
        fields: const [RaftFormField.oneTimeCode('code', 'Code')],
        onSubmit: (_) async => sent++,
      ),
    );
    RaftButton verify() => tester.widget<RaftButton>(
      find.ancestor(of: find.text('Verify'), matching: find.byType(RaftButton)),
    );
    expect(verify().onPressed, isNull);
    await _enter(tester, 'code');
    expect(sent, 0);
    // Spaces only is still nothing typed.
    await tester.enterText(_field('code'), '   ');
    await tester.pump();
    expect(verify().onPressed, isNull);
    await tester.enterText(_field('code'), '123456');
    await tester.pump();
    expect(verify().onPressed, isNotNull);
    await _enter(tester, 'code');
    expect(sent, 1);
  });

  testWidgets('a one-time code field: number pad, code suggestion, no '
      'autocorrect; a typed code field: text keyboard, no suggestion', (
    tester,
  ) async {
    await _show(
      tester,
      RaftFormDialog(
        title: 'Verify',
        fields: const [
          RaftFormField.oneTimeCode('totp', 'Authenticator code'),
          RaftFormField.typedCode('backup', 'Backup code'),
        ],
        onSubmit: (_) async {},
      ),
    );
    final totp = tester.widget<EditableText>(_field('totp'));
    expect(totp.keyboardType, TextInputType.number);
    expect(totp.autofillHints, [AutofillHints.oneTimeCode]);
    expect(totp.autocorrect, isFalse);
    expect(totp.enableSuggestions, isFalse);
    final backup = tester.widget<EditableText>(_field('backup'));
    expect(backup.keyboardType, TextInputType.text);
    expect(backup.autofillHints, isNull);
    expect(backup.autocorrect, isFalse);
    // An ordinary field keeps the defaults.
    expect(const RaftFormField('x', 'X').autocorrect, isTrue);
  });

  testWidgets('a RaftFieldError sits under its field and goes when the '
      'field is edited', (tester) async {
    var attempts = 0;
    await _show(
      tester,
      RaftFormDialog(
        title: 'Verify',
        fields: const [RaftFormField.oneTimeCode('code', 'Code')],
        onSubmit: (_) async {
          attempts++;
          throw const RaftFieldError('code', "That code didn't work.");
        },
      ),
    );
    await tester.enterText(_field('code'), '000000');
    await _enter(tester, 'code');
    expect(attempts, 1);
    final error = find.text("That code didn't work.");
    expect(error, findsOneWidget);
    expect(find.byType(RaftErrorBanner), findsNothing);
    expect(
      tester.getTopLeft(error).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(_field('code')).dy),
    );
    expect(find.byType(RaftFormDialog), findsOneWidget);
    await tester.enterText(_field('code'), '0000001');
    await tester.pump();
    expect(error, findsNothing);
  });

  testWidgets('a RaftFieldError for a field not shown goes to the banner', (
    tester,
  ) async {
    await _show(
      tester,
      RaftFormDialog(
        title: 'Verify',
        fields: const [RaftFormField('code', 'Code')],
        onSubmit: (_) async =>
            throw const RaftFieldError('gone', 'Try again later.'),
      ),
    );
    await tester.enterText(_field('code'), '1');
    await _enter(tester, 'code');
    expect(
      find.descendant(
        of: find.byType(RaftErrorBanner),
        matching: find.text('Try again later.'),
      ),
      findsOneWidget,
    );
  });
}
