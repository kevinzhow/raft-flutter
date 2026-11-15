// Web v1.24.0 VerifyItsYouDialog.tsx with TwoStepVerificationSection.tsx
// `StepDialog` (`<form onSubmit>`) and `AnswerField`, secondFactorAnswer.ts:
// Enter in the code field submits; the code field asks for the number pad and
// the one-time-code suggestion; Verify stays disabled until a code is typed;
// a wrong code sits under the field and goes once the field is edited; a
// switch to the other way starts empty, without the last failure.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/second_factor_step_up.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/second_factor_server.dart';

const _wrong =
    "That code didn't work. Check the time on your phone is set automatically, then try the newest code.";
const _locked = 'Too many wrong codes. Try again after';

void main() {
  late SecondFactorServerClient client;
  setUp(() => client = SecondFactorServerClient());
  tearDown(() => client.dispose());

  /// "Verify it's you" with an answer that [server] decides.
  Future<List<StepUpAnswer>> open(
    WidgetTester t, {
    required Future<void> Function(StepUpAnswer) server,
    List<SecondFactorMethod> methods = const [
      SecondFactorMethod.totp,
      SecondFactorMethod.backupCode,
    ],
  }) async {
    final sent = <StepUpAnswer>[];
    t.view
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showVerifyItsYou(
                  context,
                  client,
                  methods: methods,
                  description: StepUpReason.other.description,
                  onAnswer: (answer) async {
                    sent.add(answer);
                    await server(answer);
                  },
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    return sent;
  }

  Finder field() => find.descendant(
    of: find.byType(RaftFormDialog),
    matching: find.byType(EditableText),
  );

  Future<void> pressEnter(WidgetTester t) async {
    await t.showKeyboard(field());
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
  }

  RaftButton verify(WidgetTester t) => t.widget<RaftButton>(
    find.ancestor(of: find.text('Verify'), matching: find.byType(RaftButton)),
  );

  testWidgets('Enter in the code field verifies', (t) async {
    final sent = await open(t, server: (_) async {});
    await t.enterText(field(), '123 456');
    await pressEnter(t);
    expect(sent.single.code, '123456');
    expect(find.text("Verify it's you"), findsNothing);
  });

  testWidgets('the code field: number pad and the one-time-code suggestion; '
      'a backup code: text keyboard, no suggestion', (t) async {
    await open(t, server: (_) async {});
    var input = t.widget<EditableText>(field());
    expect(input.keyboardType, TextInputType.number);
    expect(input.autofillHints, [AutofillHints.oneTimeCode]);
    expect(input.autocorrect, isFalse);
    await t.tap(find.byKey(const ValueKey('step-up-use-backup_code')));
    await t.pumpAndSettle();
    input = t.widget<EditableText>(field());
    expect(input.keyboardType, TextInputType.text);
    expect(input.autofillHints, isNull);
    expect(input.autocorrect, isFalse);
  });

  testWidgets('Verify is disabled until a code is typed', (t) async {
    final sent = await open(t, server: (_) async {});
    expect(verify(t).onPressed, isNull);
    await pressEnter(t);
    expect(sent, isEmpty);
    // The old required-field text never shows: nothing was sent.
    expect(find.textContaining('is required'), findsNothing);
    await t.enterText(field(), '1');
    await t.pump();
    expect(verify(t).onPressed, isNotNull);
  });

  testWidgets('a wrong code sits under the field until the field is edited', (
    t,
  ) async {
    await open(
      t,
      server: (_) async =>
          throw secondFactorRefusal(400, 'second_factor_code_invalid'),
    );
    await t.enterText(field(), '000000');
    await pressEnter(t);
    expect(
      find.descendant(
        of: find.byType(TextFormField),
        matching: find.text(_wrong),
      ),
      findsOneWidget,
    );
    expect(find.byType(RaftErrorBanner), findsNothing);
    await t.enterText(field(), '0000001');
    await t.pump();
    expect(find.text(_wrong), findsNothing);
  });

  testWidgets('a lock goes in the banner; switching the way clears it and '
      'the typed text', (t) async {
    await open(
      t,
      server: (_) async => throw secondFactorRefusal(
        429,
        'second_factor_locked',
        extra: {'lockedUntil': '2026-11-15T12:00:00.000Z'},
      ),
    );
    await t.enterText(field(), '000000');
    await pressEnter(t);
    expect(
      find.descendant(
        of: find.byType(RaftErrorBanner),
        matching: find.textContaining(_locked),
      ),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('step-up-use-backup_code')));
    await t.pumpAndSettle();
    expect(find.textContaining(_locked), findsNothing);
    expect(find.text('Backup code'), findsOneWidget);
    expect(t.widget<EditableText>(field()).controller.text, isEmpty);
  });
}
