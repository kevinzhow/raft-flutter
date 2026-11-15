import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/account_security_dialogs.dart';
import 'package:raft_flutter/features/account_security_passkeys.dart';
import 'package:raft_flutter/features/account_security_two_step.dart';
import 'package:raft_flutter/features/second_factor_step_up.dart';
import 'package:raft_ui/raft_ui.dart';

import 'close_dialogs_test.dart' show anyX, ignoreOverflow, openFromButton;
import 'support/close_registry_dialogs.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';
import 'support/second_factor_server.dart';

/// The two-step dialogs (Web `StepDialog`, `disablePointerDismissal`): the X,
/// Esc and Back close them at every width; a press outside and, on a phone,
/// a drag down do not. Checked on "Verify it's you" and on the new backup
/// codes, which are shown once.
const _corner = Offset(6, 6);
final _handle = find.byKey(const ValueKey('raft-sheet-handle'));

Future<SurfaceProbe> _stepUp(WidgetTester t, Size size) async {
  final client = SecondFactorServerClient();
  addTearDown(client.dispose);
  await openFromButton(
    t,
    size,
    (context) => unawaited(
      showVerifyItsYou(
        context,
        client,
        methods: const [SecondFactorMethod.totp, SecondFactorMethod.backupCode],
        description: StepUpReason.other.description,
        onAnswer: (_) async {},
      ),
    ),
  );
  final dialog = find.byType(RaftFormDialog);
  return SurfaceProbe(
    isOpen: () => dialog.evaluate().isNotEmpty,
    x: find.descendant(of: dialog, matching: anyX),
    scrim: _corner,
    dragHandle: _handle,
  );
}

/// Settings › Two-step verification › Regenerate, answered.
Future<SurfaceProbe> _newCodes(WidgetTester t, Size size) async {
  ignoreOverflow();
  await t.pumpWidget(const SizedBox.shrink());
  t.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final client = SecondFactorServerClient()
    ..enabled = true
    ..totp = true
    ..codesRemaining = 2;
  final w = WorkspaceController(client);
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    w.dispose();
    await client.dispose();
  });
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
  await frames(t, 20);
  await t.ensureVisible(find.byKey(const ValueKey('two-step-regenerate')));
  await t.tap(find.byKey(const ValueKey('two-step-regenerate')));
  await frames(t, 20);
  await t.enterText(
    find.descendant(
      of: find.byKey(const ValueKey('second-factor-answer-totp')),
      matching: find.byType(EditableText),
    ),
    SecondFactorServerClient.goodCode,
  );
  await t.pump();
  await t.tap(find.byKey(const ValueKey('second-factor-step-commit')));
  await frames(t, 20);
  final codes = find.text('New backup codes');
  expect(codes, findsOneWidget);
  return SurfaceProbe(
    isOpen: () => codes.evaluate().isNotEmpty,
    x: find.descendant(of: find.byType(SecondFactorStepDialog), matching: anyX),
    scrim: _corner,
    dragHandle: _handle,
  );
}

void main() {
  final surface = dialogSurfaces.singleWhere(
    (s) => s.id == 'second-factor-step',
  );
  registerCloseTests([surface], {'second-factor-step': _stepUp});

  for (final (name, size) in closeSizes) {
    final width = widthKey(name);
    testWidgets('new backup codes @ $name close via the registered exits', (
      t,
    ) async {
      for (final exit in surface.at(width)) {
        await expectCloses(t, surface, name, exit, await _newCodes(t, size));
      }
    });

    for (final (what, open) in [
      ('verify it is you', _stepUp),
      ('new backup codes', _newCodes),
    ]) {
      testWidgets('$what @ $name ignores a press outside and a drag down', (
        t,
      ) async {
        final probe = await open(t, size);
        await t.tapAt(probe.scrim!);
        await frames(t, 20);
        expect(probe.isOpen(), isTrue, reason: 'a scrim press closed it');
        final handle = probe.dragHandle!.hitTestable();
        // The handle exists only where the window is a sheet (below 768).
        if (handle.evaluate().isNotEmpty) {
          await t.fling(handle.first, const Offset(0, 500), 2000);
          await frames(t, 20);
          expect(probe.isOpen(), isTrue, reason: 'a drag down closed it');
        }
        expect(
          surface.at(width).intersection({Affordance.scrim, Affordance.drag}),
          isEmpty,
        );
      });
    }
  }
}
