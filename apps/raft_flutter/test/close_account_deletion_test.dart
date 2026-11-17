import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/account_deletion_page.dart';
import 'package:raft_ui/raft_ui.dart';

import 'close_dialogs_test.dart' show anyX, ignoreOverflow;
import 'support/account_deletion_server.dart';
import 'support/close_registry_account_deletion.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';

/// Delete Account's confirmations and its proof (Web `ConfirmDialog` and
/// `StepDialog`, both `disablePointerDismissal`): the X, Escape and the
/// Android back gesture close them at every width; a press outside does not.
/// Opened from the page itself, against a scripted server.
Future<AccountDeletionServerClient> _page(WidgetTester t, Size size) async {
  ignoreOverflow();
  await t.pumpWidget(const SizedBox.shrink());
  t.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final client = AccountDeletionServerClient()
    ..checklist = {
      'status': 'none',
      'soleOwnerServers': <Object?>[],
      'soleMemberServers': <Object?>[],
      'paidServersEndingAtPeriodEnd': <Object?>[],
      'agents': [
        {
          'id': 'a1',
          'name': 'Scout',
          'outcome': 'transfer_to_owner',
          'server': deletionServer('srv1', 'Studio'),
        },
      ],
      'computers': [
        {
          'id': 'c1',
          'name': 'Laptop',
          'server': deletionServer('srv1', 'Studio'),
          'agents': [
            {'id': 'a1', 'name': 'Scout', 'ownedByMe': true},
          ],
        },
      ],
      'graceDays': 30,
    };
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
        body: SingleChildScrollView(child: AccountDeletionPage(controller: w)),
      ),
    ),
  );
  await frames(t, 20);
  client.postAnswers.add(
    deletionRefusal(
      403,
      'reauth_required',
      extra: {
        'methods': ['password'],
      },
    ),
  );
  return client;
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(ValueKey(key)));
  await t.tap(find.byKey(ValueKey(key)));
  await frames(t, 25);
}

Future<SurfaceProbe> _archive(WidgetTester t, Size size) async {
  await _page(t, size);
  await _tap(t, 'account-deletion-archive-c1');
  final dialog = find.byKey(const ValueKey('account-deletion-archive-confirm'));
  expect(dialog, findsOneWidget);
  return SurfaceProbe(
    isOpen: () => dialog.evaluate().isNotEmpty,
    x: find.descendant(of: dialog, matching: anyX),
    scrim: const Offset(6, 6),
  );
}

Future<SurfaceProbe> _proof(WidgetTester t, Size size) async {
  await _page(t, size);
  await _tap(t, 'account-deletion-confirm');
  final dialog = find.byKey(const ValueKey('account-deletion-password'));
  expect(dialog, findsOneWidget);
  return SurfaceProbe(
    isOpen: () => dialog.evaluate().isNotEmpty,
    x: find.descendant(of: dialog, matching: anyX),
    scrim: const Offset(6, 6),
  );
}

void main() {
  final byId = {for (final s in accountDeletionSurfaces) s.id: s};
  registerCloseTests(
    [byId['account-deletion-confirm']!],
    {'account-deletion-confirm': _archive},
  );
  registerCloseTests(
    [byId['account-deletion-proof']!],
    {'account-deletion-proof': _proof},
  );

  for (final (name, size) in closeSizes) {
    for (final (what, open) in [('archive', _archive), ('proof', _proof)]) {
      testWidgets('$what @ $name ignores a press outside', (t) async {
        final probe = await open(t, size);
        await t.tapAt(probe.scrim!);
        await frames(t, 20);
        expect(probe.isOpen(), isTrue, reason: 'a scrim press closed it');
      });
    }
  }
}
