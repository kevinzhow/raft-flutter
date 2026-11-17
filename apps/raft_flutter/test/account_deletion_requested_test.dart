// Right after the app requested the account deletion every sign-in, this one
// too, is gone: the confirmation replaces the whole shell until OK signs out
// (Web pages/AccountDeletionGate.tsx, AccountDeletionRequestedPage.tsx).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

void main() {
  testWidgets('the confirmation replaces the shell and OK signs out', (
    t,
  ) async {
    final f = RootFixture();
    final scheduledFor = DateTime.now()
        .toUtc()
        .add(const Duration(days: 29, hours: 12))
        .toIso8601String();
    await f.mount(t, 'light', 390);
    expect(
      find.byKey(const ValueKey('account-deletion-scheduled')),
      findsNothing,
    );
    f.client.accountDeletion.markRequested(scheduledFor);
    await f.flush(t);
    expect(find.text('Choose server'), findsNothing);
    expect(
      find.byKey(const ValueKey('account-deletion-scheduled')),
      findsOneWidget,
    );
    expect(find.text('Deletion scheduled'), findsOneWidget);
    final date = DateFormat.MMMMd('en')
        .format(DateTime.parse(scheduledFor).toLocal());
    expect(
      find.textContaining('Takes effect on $date', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Sign in to Raft before $date'), findsOneWidget);
    expect(
      find.text("You've been signed out on every device."),
      findsOneWidget,
    );
    // Nothing in the shell keeps asking behind the confirmation.
    final asked = f.adapter.calls.length;
    await t.pump(const Duration(seconds: 3));
    expect(f.adapter.calls.length, asked);
    await t.tap(find.byKey(const ValueKey('account-deletion-ok')));
    await f.flush(t);
    expect(f.adapter.calls.where((c) => c.path == '/auth/logout'), isNotEmpty);
    expect(
      find.byKey(const ValueKey('account-deletion-scheduled')),
      findsNothing,
    );
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    await f.close(t);
  });
}
