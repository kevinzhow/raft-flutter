// Web v1.24.0 Settings › Account › Two-step verification
// (TwoStepVerificationSection.tsx): turn on (password first when the server
// asks, QR code and key, one code, backup codes once), regenerate, turn off.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/account_security_passkeys.dart';
import 'package:raft_flutter/features/account_security_two_step.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/second_factor_server.dart';

void main() {
  late SecondFactorServerClient client;
  late WorkspaceController w;
  setUp(() {
    client = SecondFactorServerClient();
    w = WorkspaceController(client);
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Future<void> mount(WidgetTester t) async {
    t.view
      ..physicalSize = const Size(900, 1600)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
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
  }

  Finder field(String kind) => find.descendant(
    of: find.byKey(ValueKey('second-factor-answer-$kind')),
    matching: find.byType(EditableText),
  );

  Future<void> tapKey(WidgetTester t, String key) async {
    await t.ensureVisible(find.byKey(ValueKey(key)));
    await t.tap(find.byKey(ValueKey(key)));
    await t.pumpAndSettle();
  }

  Future<void> commit(WidgetTester t) => tapKey(t, 'second-factor-step-commit');

  testWidgets('turn on: password, QR and key, one code, the codes once', (
    t,
  ) async {
    await mount(t);
    expect(find.text('Two-step verification'), findsWidgets);
    expect(find.text('Off'), findsOneWidget);
    // Off: only the offer, no method rows.
    expect(
      find.byKey(const ValueKey('two-step-backup-codes-row')),
      findsNothing,
    );

    await tapKey(t, 'two-step-turn-on');
    // The server wants a recent sign-in: the password comes first.
    expect(find.text("Verify it's you"), findsOneWidget);
    await t.enterText(field('password'), 'wrong-password');
    await t.pump();
    await commit(t);
    expect(find.text('That password is incorrect. Try again.'), findsOneWidget);
    await t.enterText(field('password'), 'right-password');
    await t.pump();
    await commit(t);

    expect(find.text('Set up authenticator app'), findsOneWidget);
    expect(find.byKey(const ValueKey('two-step-totp-qr')), findsOneWidget);
    // The key wraps anywhere (zero-width breaks between its characters).
    final key = t.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('two-step-totp-secret')),
        matching: find.byType(Text),
      ),
    );
    expect(key.data!.replaceAll(RegExp('[^A-Z0-9]'), ''), 'JBSWY3DPEHPK3PXP');
    expect(
      find.text(
        'Turning it on signs you out of your other browsers. Computers and the raft CLI stay connected.',
      ),
      findsOneWidget,
    );
    await t.enterText(field('totp'), '000000');
    await t.pump();
    await commit(t);
    expect(
      find.text(
        "That code didn't work. Check the time on your phone is set automatically, then try the newest code.",
      ),
      findsOneWidget,
    );
    await t.enterText(field('totp'), '123 456');
    await t.pump();
    await commit(t);
    expect(client.to('/auth/second-factor/enable').last.data, {
      'code': '123456',
    });

    expect(find.text('Two-step verification is on.'), findsOneWidget);
    for (final code in SecondFactorServerClient.freshCodes()) {
      expect(find.text(code), findsOneWidget);
    }
    await tapKey(t, 'second-factor-step-done');
    expect(find.text('Two-step verification is on.'), findsNothing);
    expect(find.text('On'), findsOneWidget);
    expect(find.text('Authenticator app'), findsOneWidget);
    expect(find.text('10 of 10 left'), findsOneWidget);
    expect(find.byKey(const ValueKey('two-step-low-codes')), findsNothing);
  });

  testWidgets('low backup codes ask to regenerate; Regenerate clears it', (
    t,
  ) async {
    client
      ..enabled = true
      ..totp = true
      ..codesRemaining = 2;
    await mount(t);
    expect(find.text('2 of 10 left'), findsOneWidget);
    expect(
      find.text(
        "Only 2 backup codes left. Regenerate them so you don't get locked out.",
      ),
      findsOneWidget,
    );
    await tapKey(t, 'two-step-regenerate');
    expect(find.text('Regenerate backup codes?'), findsOneWidget);
    // An authenticator code only: the server refuses a backup code here.
    expect(
      find.byKey(const ValueKey('second-factor-use-backupCode')),
      findsNothing,
    );
    await t.enterText(field('totp'), '123456');
    await t.pump();
    await commit(t);
    expect(find.text('New backup codes'), findsOneWidget);
    await tapKey(t, 'second-factor-step-done');
    expect(find.text('10 of 10 left'), findsOneWidget);
    expect(find.byKey(const ValueKey('two-step-low-codes')), findsNothing);
  });

  testWidgets('turn off with a backup code; closing changes nothing', (
    t,
  ) async {
    client
      ..enabled = true
      ..totp = true
      ..codesRemaining = 10;
    await mount(t);
    await tapKey(t, 'two-step-turn-off');
    expect(find.text('Turn off two-step verification?'), findsOneWidget);
    await tapKey(t, 'second-factor-step-cancel');
    expect(client.to('/auth/second-factor/disable'), isEmpty);
    expect(find.text('On'), findsOneWidget);

    await tapKey(t, 'two-step-turn-off');
    await tapKey(t, 'second-factor-use-backupCode');
    expect(find.text('Backup code'), findsOneWidget);
    await t.enterText(field('backupCode'), SecondFactorServerClient.goodBackup);
    await t.pump();
    await commit(t);
    expect(client.to('/auth/second-factor/disable').single.data, {
      'backupCode': SecondFactorServerClient.goodBackup,
    });
    expect(find.text('Off'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('two-step-backup-codes-row')),
      findsNothing,
    );
  });

  testWidgets('a 404 keeps the section away; a failed first read says so', (
    t,
  ) async {
    client.statusFailure = 404;
    await mount(t);
    expect(
      find.byKey(const ValueKey('two-step-verification-section')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('passkeys-section')), findsNothing);

    client.statusFailure = 500;
    final other = SecondFactorServerClient()..statusFailure = 500;
    final w2 = WorkspaceController(other);
    addTearDown(() async {
      w2.dispose();
      await other.dispose();
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AccountSecuritySections(
              key: const ValueKey('second account'),
              controller: w2,
              passkeys: (s) => PasskeysSection(controller: w2, settings: s),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.text(
        "Couldn't load two-step verification. Reload the page to try again.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('an account without a password is told to sign in again', (
    t,
  ) async {
    client.passwordConfigured = false;
    await mount(t);
    await tapKey(t, 'two-step-turn-on');
    expect(
      find.text(
        'Your account signs in without a password. Sign out and sign in again, then turn on two-step verification within 10 minutes.',
      ),
      findsOneWidget,
    );
    await tapKey(t, 'second-factor-step-done');
    expect(client.to('/auth/second-factor/reauth/password'), isEmpty);
  });
}
