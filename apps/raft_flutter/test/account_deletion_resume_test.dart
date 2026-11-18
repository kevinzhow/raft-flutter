// While the pending-deletion page replaces the shell, the workspace behind it
// stays in the background, also when the app comes back from the background
// (Web AccountDeletionGate unmounts the workspace; every request there would
// be refused with 403 account_deletion_pending).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

void main() {
  testWidgets('app resume keeps the workspace in the background', (t) async {
    final f = RootFixture();
    var pending = false;
    Object? refuse(String path) {
      f.adapter.statuses[path] = 403;
      return {
        'error': 'scheduled',
        'code': 'account_deletion_pending',
        'scheduledFor': DateTime.now()
            .toUtc()
            .add(const Duration(days: 20))
            .toIso8601String(),
      };
    }

    f.overrides['GET /servers'] = (_) {
      if (pending) return refuse('GET /servers');
      f.adapter.statuses.remove('GET /servers');
      return f.servers;
    };
    await f.mount(t, 'light', 1280, uri: Uri.parse('/s/alpha'));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    final w = f.workspace(t);
    expect(w.foreground, isTrue);

    // Deletion was scheduled elsewhere: the next request is refused.
    pending = true;
    Object? refused;
    unawaited(w.client.get('/servers').catchError((Object e) => refused = e));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(refused, isA<RaftApiException>());
    expect(
      find.byKey(const ValueKey('account-deletion-pending-page')),
      findsOneWidget,
    );
    expect(w.foreground, isFalse);

    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    expect(w.foreground, isFalse, reason: 'the gate holds on resume');
    await f.close(t);
  });
}
