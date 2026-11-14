// Web v1.24.0 Settings › Account › Passkeys (PasskeysSection.tsx): the list,
// rename, delete (with two-step verification on: "Verify it's you" in the
// same request), and the last factor that can't go. Adding stays disabled
// (no native passkey provider here; WP-PASSKEY).
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
    client = SecondFactorServerClient()
      ..passkeys.addAll([
        fixturePasskey(
          '11111111-1111-4111-8111-111111111111',
          'iCloud Keychain',
          synced: true,
        ),
        fixturePasskey(
          '22222222-2222-4222-8222-222222222222',
          'YubiKey',
          lastUsedAt: '2026-02-01T08:00:00.000Z',
        ),
      ]);
    w = WorkspaceController(client);
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  const first = '11111111-1111-4111-8111-111111111111';

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

  Future<void> tapKey(WidgetTester t, String key) async {
    await t.ensureVisible(find.byKey(ValueKey(key)));
    await t.tap(find.byKey(ValueKey(key)));
    await t.pumpAndSettle();
  }

  Future<void> menu(WidgetTester t, String id, String item) async {
    await tapKey(t, 'passkey-actions-$id');
    await t.tap(find.text(item).last);
    await t.pumpAndSettle();
  }

  testWidgets('lists the passkeys; Add is disabled with the reason', (t) async {
    await mount(t);
    expect(find.text('iCloud Keychain'), findsOneWidget);
    expect(find.text('Synced'), findsOneWidget);
    expect(find.text('YubiKey'), findsOneWidget);
    expect(find.textContaining('Not used yet'), findsOneWidget);
    expect(find.textContaining('Last used'), findsOneWidget);
    expect(find.byKey(const ValueKey('passkeys-unsupported')), findsOneWidget);
    final add = t.widget<RaftButton>(
      find.byKey(const ValueKey('passkeys-add')),
    );
    expect(add.onPressed, isNull);
  });

  testWidgets('rename sends the trimmed name and shows it', (t) async {
    await mount(t);
    await menu(t, first, 'Rename');
    expect(find.text('Rename passkey'), findsOneWidget);
    await t.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('passkeys-rename-name')),
        matching: find.byType(EditableText),
      ),
      '  Work laptop ',
    );
    await t.pump();
    await tapKey(t, 'second-factor-step-commit');
    expect(client.to('/auth/second-factor/passkeys/$first').single.data, {
      'name': 'Work laptop',
    });
    expect(find.text('Rename passkey'), findsNothing);
    expect(find.text('Work laptop'), findsOneWidget);
  });

  testWidgets('delete with two-step verification on asks to verify first', (
    t,
  ) async {
    client
      ..enabled = true
      ..totp = true
      ..codesRemaining = 10;
    await mount(t);
    await menu(t, first, 'Delete');
    expect(find.text('Delete “iCloud Keychain”?'), findsOneWidget);
    await tapKey(t, 'passkeys-delete-confirm');
    // The server asked for a second-factor answer: nothing was removed yet.
    expect(find.text("Verify it's you"), findsOneWidget);
    expect(
      find.text(
        "Two-step verification is on. Verify it's you to delete this passkey.",
      ),
      findsOneWidget,
    );
    expect(client.passkeys, hasLength(2));
    await t.enterText(
      find.descendant(
        of: find.byType(RaftFormDialog),
        matching: find.byType(EditableText),
      ),
      '123456',
    );
    await t.tap(find.text('Verify'));
    await t.pumpAndSettle();
    final deletes = client.to('/auth/second-factor/passkeys/$first');
    expect(deletes, hasLength(2));
    expect(deletes.last.data, {'code': '123456'});
    expect(find.text('iCloud Keychain'), findsNothing);
    expect(find.text('YubiKey'), findsOneWidget);
  });

  testWidgets('the last factor stays; its link opens Turn off', (t) async {
    client
      ..enabled = true
      ..totp = false
      ..codesRemaining = 10
      ..passkeys.removeLast();
    await mount(t);
    expect(find.byKey(const ValueKey('passkeys-last-factor')), findsOneWidget);
    await tapKey(t, 'passkey-actions-$first');
    final delete = find.text('Delete').last;
    await t.tap(delete);
    await t.pumpAndSettle();
    // Disabled: no confirmation opened.
    expect(find.text('Delete “iCloud Keychain”?'), findsNothing);
    if (find.text('Rename').evaluate().isNotEmpty) {
      await t.tapAt(Offset.zero);
      await t.pumpAndSettle();
    }

    await tapKey(t, 'passkeys-last-factor-turn-off');
    expect(find.text('Turn off two-step verification?'), findsOneWidget);
    // Without an authenticator app only a backup code (no passkeys here).
    expect(find.text('Backup code'), findsOneWidget);
  });
}
