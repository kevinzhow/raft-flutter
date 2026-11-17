// Server v1.24.0 account deletion (middleware/auth.ts): a person whose
// deletion is scheduled (on Web or another device) gets 403
// `account_deletion_pending` from every API but the deletion's own routes and
// sign-out. The app shows the pending page in place of the shell, with the
// date, the days left, Cancel Deletion (the request-bound DELETE and its
// changed-request / unconfirmed / failed banners), Try again and Sign out
// (Web pages/AccountDeletionPendingPage.tsx, store/accountDeletionPending.ts).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:raft_flutter/features/workspace_view.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

const _requestId = '0a1b2c3d-1111-4222-8333-444455556666';
const _newerId = '9f8e7d6c-1111-4222-8333-444455556666';

/// A deletion that is `days` days away, rounded up, as the server writes it.
String _scheduledFor(int days) => DateTime.now()
    .toUtc()
    .add(Duration(days: days - 1, hours: 12))
    .toIso8601String();

class _Deletion {
  _Deletion(this.f, {int days = 20}) : scheduledFor = _scheduledFor(days) {
    f.overrides['GET /servers'] = (_) {
      if (pending) {
        f.adapter.statuses['GET /servers'] = 403;
        return {
          'error': 'This account is scheduled for deletion. Cancel the deletion to use it again.',
          'code': 'account_deletion_pending',
          'scheduledFor': scheduledFor,
        };
      }
      f.adapter.statuses.remove('GET /servers');
      return f.servers;
    };
    f.overrides['GET /auth/me'] = (_) {
      if (pending) {
        f.adapter.statuses['GET /auth/me'] = 403;
        return {
          'error': 'scheduled',
          'code': 'account_deletion_pending',
          'scheduledFor': scheduledFor,
        };
      }
      f.adapter.statuses.remove('GET /auth/me');
      return {
        'id': 'alice',
        'name': 'alice',
        'email': 'alice@example.invalid',
        'emailVerified': true,
      };
    };
    f.overrides['GET /me/account/deletion'] = (_) => status();
  }
  final RootFixture f;
  final String scheduledFor;
  bool pending = true;
  String id = _requestId;
  bool subscriptionUnconfirmed = false;

  Map<String, dynamic> status() => pending
      ? {
          'status': 'scheduled',
          'requestId': id,
          'requestedAt': DateTime.now().toUtc().toIso8601String(),
          'scheduledFor': scheduledFor,
          if (subscriptionUnconfirmed)
            'subscriptionCancellationUnconfirmed': true,
        }
      : {'status': 'none', 'subscriptionRestoration': 'restored'};

  /// Cancel Deletion answers like the server for [requestId].
  void answerCancel(String requestId, Object? Function() answer) {
    f.adapter.routes['DELETE /me/account/deletion/requests/$requestId'] = (_) =>
        answer();
  }

  int calls(String method, String path) =>
      f.adapter.calls.where((c) => c.method == method && c.path == path).length;
}

/// A person who was in Alpha before: their account record is cached on the
/// device, and the server they were in is remembered.
Future<void> _mount(RootFixture f, WidgetTester t, double width) => f.mount(
  t,
  'light',
  width,
  cachedSession: true,
  preferences: {
    'raft.server-surface.${Uri.encodeComponent('https://fixture.invalid')}.alice.last':
        'alpha',
  },
);

String _date(String scheduledFor) =>
    DateFormat.MMMMd('en').format(DateTime.parse(scheduledFor).toLocal());

void main() {
  testWidgets('403 pending replaces the shell with the pending page', (
    t,
  ) async {
    final f = RootFixture();
    final d = _Deletion(f);
    await _mount(f, t, 390);
    expect(find.byType(WorkspaceView), findsNothing);
    expect(
      find.byKey(const ValueKey('account-deletion-pending-page')),
      findsOneWidget,
    );
    expect(
      find.text('Your account will be deleted on ${_date(d.scheduledFor)}'),
      findsOneWidget,
    );
    expect(find.text('20 days left'), findsOneWidget);
    expect(
      find.text(
        'Once cancelled, sign in again on your devices and reconnect your computers.',
      ),
      findsOneWidget,
    );
    expect(find.text('Cancel deletion'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    // Nothing is wrong yet: no banner, no Try again.
    expect(find.text('Try again'), findsNothing);
    // The shell is not asked again behind the page.
    final asked = d.calls('GET', '/servers');
    await t.pump(const Duration(seconds: 3));
    expect(d.calls('GET', '/servers'), asked);
    await f.close(t);
  });

  testWidgets('Sign Out signs out and shows the sign-in page', (t) async {
    final f = RootFixture();
    _Deletion(f);
    await _mount(f, t, 390);
    await t.tap(find.byKey(const ValueKey('account-deletion-sign-out')));
    await f.flush(t);
    expect(f.adapter.calls.where((c) => c.path == '/auth/logout'), isNotEmpty);
    expect(
      find.byKey(const ValueKey('account-deletion-pending-page')),
      findsNothing,
    );
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    await f.close(t);
  });

  testWidgets('Cancel Deletion sends the request id and reopens the app', (
    t,
  ) async {
    final f = RootFixture();
    final d = _Deletion(f);
    d.answerCancel(_requestId, () {
      d.pending = false;
      return {'status': 'none', 'subscriptionRestoration': 'restored'};
    });
    await _mount(f, t, 1280);
    await t.tap(find.byKey(const ValueKey('account-deletion-cancel')));
    await f.flush(t);
    expect(d.calls('DELETE', '/me/account/deletion/requests/$_requestId'), 1);
    expect(
      find.byKey(const ValueKey('account-deletion-pending-page')),
      findsNothing,
    );
    expect(find.byType(WorkspaceView), findsOneWidget);
    // Back in Settings > Account of the server the person was in.
    expect(
      f.router(t).currentConfiguration.toString(),
      startsWith('/s/alpha/settings/account'),
    );
    await f.close(t);
  });

  testWidgets(
    'a person who boots into a scheduled deletion has no account record',
    (t) async {
      final f = RootFixture();
      _Deletion(f);
      await f.mount(t, 'light', 390);
      expect(
        find.byKey(const ValueKey('account-deletion-pending-page')),
        findsOneWidget,
      );
      expect(find.byType(WorkspaceView), findsNothing);
      expect(find.byKey(const Key('login-submit')), findsNothing);
      await f.close(t);
    },
  );

  testWidgets('a cancel that lost the race to a newer request says so', (
    t,
  ) async {
    final f = RootFixture();
    final d = _Deletion(f);
    d.answerCancel(_requestId, () {
      f.adapter.statuses['DELETE /me/account/deletion/requests/$_requestId'] =
          409;
      d.id = _newerId;
      return {'code': 'account_deletion_pending', 'error': 'newer'};
    });
    await _mount(f, t, 390);
    await t.tap(find.byKey(const ValueKey('account-deletion-cancel')));
    await f.flush(t);
    expect(
      find.byKey(const ValueKey('account-deletion-request-changed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('account-deletion-cancel-failed')),
      findsNothing,
    );
    // The read after the failed DELETE asked about the request it cancelled.
    expect(
      f.adapter.calls.where(
        (c) =>
            c.path == '/me/account/deletion' &&
            c.queryParameters['requestId'] == _requestId,
      ),
      hasLength(1),
    );
    // The next press cancels the newer request.
    d.answerCancel(_newerId, () {
      d.pending = false;
      return {'status': 'none', 'subscriptionRestoration': 'restored'};
    });
    await t.tap(find.byKey(const ValueKey('account-deletion-cancel')));
    await f.flush(t);
    expect(d.calls('DELETE', '/me/account/deletion/requests/$_newerId'), 1);
    await f.close(t);
  });

  testWidgets('a failed cancel keeps the request and offers Try again', (
    t,
  ) async {
    final f = RootFixture();
    final d = _Deletion(f);
    d.answerCancel(_requestId, () {
      f.adapter.statuses['DELETE /me/account/deletion/requests/$_requestId'] =
          500;
      return {'error': 'boom'};
    });
    await _mount(f, t, 390);
    await t.tap(find.byKey(const ValueKey('account-deletion-cancel')));
    await f.flush(t);
    expect(
      find.byKey(const ValueKey('account-deletion-cancel-failed')),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    final reads = d.calls('GET', '/me/account/deletion');
    await t.tap(find.byKey(const ValueKey('account-deletion-retry')));
    await f.flush(t);
    expect(d.calls('GET', '/me/account/deletion'), reads + 1);
    expect(
      find.byKey(const ValueKey('account-deletion-cancel-failed')),
      findsNothing,
    );
    await f.close(t);
  });

  testWidgets(
    'a deletion already gone on the read after a failed cancel is done',
    (t) async {
      final f = RootFixture();
      final d = _Deletion(f);
      d.answerCancel(_requestId, () {
        // The DELETE's answer was lost, but the deletion is cancelled.
        f.adapter.statuses['DELETE /me/account/deletion/requests/$_requestId'] =
            500;
        d.pending = false;
        return {'error': 'lost'};
      });
      await _mount(f, t, 390);
      await t.tap(find.byKey(const ValueKey('account-deletion-cancel')));
      await f.flush(t);
      expect(
        find.byKey(const ValueKey('account-deletion-pending-page')),
        findsNothing,
      );
      expect(find.byType(WorkspaceView), findsOneWidget);
      await f.close(t);
    },
  );

  testWidgets('an unrestored subscription is told before going back', (
    t,
  ) async {
    final f = RootFixture();
    final d = _Deletion(f);
    d.answerCancel(_requestId, () {
      d.pending = false;
      return {'status': 'none', 'subscriptionNotResumed': true};
    });
    await _mount(f, t, 390);
    await t.tap(find.byKey(const ValueKey('account-deletion-cancel')));
    await f.flush(t);
    expect(
      find.byKey(const ValueKey('account-deletion-cancel-warning')),
      findsOneWidget,
    );
    expect(find.text('Deletion cancelled'), findsOneWidget);
    expect(
      find.text(
        "Your subscription wasn't automatically restored. Go to Plan & Billing to subscribe again.",
      ),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('account-deletion-go-to-raft')));
    await f.flush(t);
    expect(find.byType(WorkspaceView), findsOneWidget);
    await f.close(t);
  });

  testWidgets('a request that cannot be confirmed cannot be cancelled', (
    t,
  ) async {
    final f = RootFixture();
    final d = _Deletion(f);
    f.overrides['GET /me/account/deletion'] = (_) {
      f.adapter.statuses['GET /me/account/deletion'] = 500;
      return {'error': 'boom'};
    };
    await _mount(f, t, 390);
    expect(
      find.byKey(const ValueKey('account-deletion-request-unconfirmed')),
      findsOneWidget,
    );
    await t.tap(
      find.byKey(const ValueKey('account-deletion-cancel')),
      warnIfMissed: false,
    );
    await f.flush(t);
    expect(d.calls('DELETE', '/me/account/deletion/requests/$_requestId'), 0);
    // Try again reads it once more, and now it can be cancelled.
    f.adapter.statuses.remove('GET /me/account/deletion');
    f.adapter.routes['GET /me/account/deletion'] = (_) => d.status();
    await t.tap(find.byKey(const ValueKey('account-deletion-retry')));
    await f.flush(t);
    expect(
      find.byKey(const ValueKey('account-deletion-request-unconfirmed')),
      findsNothing,
    );
    await f.close(t);
  });

  testWidgets(
    'the cancel is not confirmed for subscriptions that renewal could not stop',
    (t) async {
      final f = RootFixture();
      final d = _Deletion(f)..subscriptionUnconfirmed = true;
      await _mount(f, t, 390);
      expect(
        find.byKey(const ValueKey('account-deletion-unconfirmed-subscription')),
        findsOneWidget,
      );
      expect(d.calls('DELETE', '/me/account/deletion/requests/$_requestId'), 0);
      await f.close(t);
    },
  );
}
