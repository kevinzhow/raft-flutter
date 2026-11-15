// Web v1.24.0 TwoStepVerificationSection.tsx `StepDialog` and
// VerifyItsYouDialog.tsx open their raft-ui Dialog with
// `disablePointerDismissal`: a press outside does not close them, so a stray
// tap cannot throw away the backup codes shown once or a typed code. Esc and
// the X still close them, as on Web. On a phone the step is a sheet: a drag
// down is a pointer dismissal too and must leave it open.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/account_security_passkeys.dart';
import 'package:raft_flutter/features/account_security_two_step.dart';
import 'package:raft_flutter/features/second_factor_step_up.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/second_factor_server.dart';

const _desktop = Size(1280, 900), _phone = Size(390, 844);

void main() {
  late SecondFactorServerClient client;
  late WorkspaceController w;
  setUp(() {
    client = SecondFactorServerClient()
      ..enabled = true
      ..totp = true
      ..codesRemaining = 2;
    w = WorkspaceController(client);
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  void size(WidgetTester t, Size s) {
    t.view
      ..physicalSize = s
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  Future<void> tapKey(WidgetTester t, String key) async {
    await t.ensureVisible(find.byKey(ValueKey(key)));
    await t.tap(find.byKey(ValueKey(key)));
    await t.pumpAndSettle();
  }

  /// Settings › Two-step verification › Regenerate, answered: the ten new
  /// codes are on screen.
  Future<void> openNewCodes(WidgetTester t, Size s) async {
    size(t, s);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AccountSecuritySections(
              controller: w,
              passkeys: (s) => PasskeysSection(controller: w, settings: s),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await tapKey(t, 'two-step-regenerate');
    await t.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('second-factor-answer-totp')),
        matching: find.byType(EditableText),
      ),
      SecondFactorServerClient.goodCode,
    );
    await t.pump();
    await tapKey(t, 'second-factor-step-commit');
    expect(find.text('New backup codes'), findsOneWidget);
  }

  void expectCodesShown() {
    expect(find.text('New backup codes'), findsOneWidget);
    for (final code in SecondFactorServerClient.freshCodes()) {
      expect(find.text(code), findsOneWidget);
    }
  }

  /// A press on the scrim, away from the dialog or sheet.
  Future<void> pressOutside(WidgetTester t) async {
    await t.tapAt(const Offset(4, 4));
    await t.pumpAndSettle();
  }

  /// A finger drags the sheet down by its title, then flings it.
  Future<void> dragDown(WidgetTester t, Finder title) async {
    await t.drag(title, const Offset(0, 700));
    await t.pumpAndSettle();
    await t.fling(title, const Offset(0, 400), 2400);
    await t.pumpAndSettle();
  }

  group('new backup codes', () {
    testWidgets('a press outside the dialog keeps them; Esc closes', (t) async {
      await openNewCodes(t, _desktop);
      await pressOutside(t);
      expectCodesShown();
      // Web closes a StepDialog on Esc.
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('New backup codes'), findsNothing);
    });

    testWidgets('on a phone neither the scrim nor a drag down closes them', (
      t,
    ) async {
      await openNewCodes(t, _phone);
      expect(find.byType(RaftFormSheet), findsOneWidget);
      await pressOutside(t);
      expectCodesShown();
      await dragDown(t, find.text('New backup codes'));
      expectCodesShown();
      await tapKey(t, 'second-factor-step-done');
      expect(find.text('New backup codes'), findsNothing);
    });
  });

  group("Verify it's you", () {
    Future<void> openStepUp(WidgetTester t, Size s) async {
      size(t, s);
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
                    methods: const [
                      SecondFactorMethod.totp,
                      SecondFactorMethod.backupCode,
                    ],
                    description: StepUpReason.other.description,
                    onAnswer: (_) async {},
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
      expect(find.text("Verify it's you"), findsOneWidget);
      await t.enterText(
        find.descendant(
          of: find.byType(RaftFormDialog),
          matching: find.byType(EditableText),
        ),
        '123',
      );
      await t.pump();
    }

    void expectStillOpen() {
      expect(find.text("Verify it's you"), findsOneWidget);
      // The typed code survives.
      expect(find.text('123'), findsOneWidget);
    }

    testWidgets('a press outside the dialog keeps it and the typed code', (
      t,
    ) async {
      await openStepUp(t, _desktop);
      await pressOutside(t);
      expectStillOpen();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text("Verify it's you"), findsNothing);
    });

    testWidgets('on a phone neither the scrim nor a drag down closes it', (
      t,
    ) async {
      await openStepUp(t, _phone);
      expect(find.byType(RaftFormSheet), findsOneWidget);
      await pressOutside(t);
      expectStillOpen();
      await dragDown(t, find.text("Verify it's you"));
      expectStillOpen();
    });
  });
}
