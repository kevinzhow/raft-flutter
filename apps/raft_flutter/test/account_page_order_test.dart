// Web v1.24.0 AccountSection order after the profile card: Passkeys, Two-step
// verification, Apps you signed in to with Raft, usage data, Session (Sign
// out), then the Delete Account danger zone. Revoking the last App moves focus
// to the Session heading; Sign out is a settings row that confirms first.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/account_settings.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/second_factor_server.dart';

class _Client extends SecondFactorServerClient {
  final logins = <Map<String, Object?>>[
    {
      'id': 'g',
      'clientId': 'app_a',
      'name': 'Notes',
      'logoUrl': null,
      'scopes': ['openid'],
      'grantedAt': '2025-01-02T08:00:00.000Z',
    },
  ];

  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    if (path == '/me/app-logins') return [...logins];
    if (path.startsWith('/me/app-logins/')) {
      logins.clear();
      return null;
    }
    return super.request(method, path, data: data, query: query);
  }
}

void main() {
  late _Client client;
  late WorkspaceController w;
  var signedOut = 0;

  Future<void> mount(
    WidgetTester t, {
    Size size = const Size(1280, 3000),
  }) async {
    client = _Client();
    client.user = RaftRecord({
      'id': 'u',
      'name': 'handle',
      'email': 'fixture@example.invalid',
    });
    w = WorkspaceController(client);
    signedOut = 0;
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      w.dispose();
      await client.dispose();
    });
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        builder: (context, child) => RaftToastHost(child: child!),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AccountSettings(
              controller: w,
              onLogout: () async => signedOut++,
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  double top(WidgetTester t, String key) =>
      t.getTopLeft(find.byKey(ValueKey(key))).dy;

  testWidgets('sections follow the Web order', (t) async {
    await mount(t);
    final order = [
      top(t, 'passkeys-section'),
      top(t, 'app-logins-section'),
      top(t, 'usage-data-card'),
      top(t, 'account-session-heading'),
    ];
    expect(order, [...order]..sort());
    expect(order.toSet(), hasLength(4));
    expect(
      t.getTopLeft(find.byKey(const Key('account-logout'))).dy,
      greaterThan(order.last),
    );
  });

  testWidgets('Sign out is a settings row that confirms first', (t) async {
    await mount(t);
    expect(find.text('Session'), findsOneWidget);
    expect(
      find.text(
        'Sign out of this browser. Your account and data stay; you can sign back in any time.',
      ),
      findsOneWidget,
    );
    await t.ensureVisible(find.byKey(const Key('account-logout')));
    await t.tap(find.byKey(const Key('account-logout')));
    await t.pumpAndSettle();
    expect(signedOut, 0);
    await t.tap(find.byKey(const Key('account-logout-confirm-button')));
    await t.pumpAndSettle();
    expect(signedOut, 1);
  });

  testWidgets('revoking the last App focuses the Session heading', (t) async {
    await mount(t);
    await t.ensureVisible(find.byKey(const ValueKey('app-login-revoke-app_a')));
    await t.tap(find.byKey(const ValueKey('app-login-revoke-app_a')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('app-login-revoke-confirm')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-logins-section')), findsNothing);
    expect(find.text('Notes revoked'), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'account session heading',
    );
  });
}
