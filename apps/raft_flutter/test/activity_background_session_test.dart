import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/session_owner.dart';

import 'activity_incremental_refresh_test.dart' show channelRow;
import 'app_global_server_selector_test.dart' show RootFixture;

const _memory = 'raft.server-surface.https%3A%2F%2Ffixture.invalid.alice';

/// The reported failure: while a background refresh held the session, opening
/// Activity ended in "Background session recovery is still running". The
/// foreground owns the session now, so Activity loads whatever the guest does.
void main() {
  for (final guestKind in ['no worker','hung worker', 'dead worker engine']) {
    testWidgets(
      'Activity loads its rows with a $guestKind holding the session',
      (t) async {
        final ui = NativeSessionOwner(supported: true);
        final guest = NativeSessionOwner(
          supported: true,
          onPreempt: () => Completer<void>().future,
        );
        addTearDown(ui.release);
        addTearDown(guest.release);
        if (guestKind == 'no worker') {
        } else if (guestKind == 'hung worker') {
          guest.registerGuest();
        } else {
          final dead = ReceivePort();
          IsolateNameServer.registerPortWithName(
            dead.sendPort,
            sessionOwnerName,
          );
          dead.close();
        }
        final f = RootFixture(sessionOwner: ui);
        f.overrides['GET /channels/inbox'] = (_) => {
          'items': [channelRow(0, unread: 1)],
          'hasMore': false,
          'totalUnreadCount': 1,
        };
        await f.mount(
          t,
          'light',
          412,
          cachedSession: true,
          preferences: {'$_memory.last': 'alpha', '$_memory.a': '/s/alpha'},
        );
        await t.tap(find.byKey(const Key('nav-activity')));
        await f.flush(t);
        await t.pump(const Duration(seconds: 2));
        expect(find.textContaining('Background session'), findsNothing);
        expect(find.textContaining('Please retry'), findsNothing);
        expect(find.text('1 active · 1 unread'), findsOneWidget);
        expect(find.text('Activity is empty'), findsNothing);
        await f.close(t);
      },
    );
  }
}
