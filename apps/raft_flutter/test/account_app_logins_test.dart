// Web v1.24.0 Settings › Account › Apps you signed in to with Raft
// (AppLoginsSection.tsx, AppLoginRow.tsx): shown only while the list has an
// entry, Revoke → confirm (opens on Cancel) → DELETE; the failure stays in the
// dialog, the success removes the row, toasts and moves focus.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/account_app_logins.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/second_factor_server.dart';

class _AppLoginsClient extends SecondFactorServerClient {
  _AppLoginsClient(List<Map<String, Object?>> logins) {
    this.logins.addAll(logins);
  }
  final logins = <Map<String, Object?>>[];
  bool listFails = false;
  bool revokeFails = false;
  final revoked = <String>[];

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
    if (path == '/me/app-logins') {
      calls.add((method: method, path: path, data: data));
      if (listFails) throw secondFactorRefusal(500, 'boom');
      return [...logins];
    }
    if (path.startsWith('/me/app-logins/')) {
      calls.add((method: method, path: path, data: data));
      if (revokeFails) throw secondFactorRefusal(500, 'boom');
      final id = Uri.decodeComponent(path.substring('/me/app-logins/'.length));
      revoked.add(id);
      logins.removeWhere((l) => l['clientId'] == id);
      return null;
    }
    return super.request(method, path, data: data, query: query);
  }
}

Map<String, Object?> _login(String id, String name, {String? logoUrl}) => {
  'id': 'grant-$id',
  'clientId': id,
  'name': name,
  'logoUrl': logoUrl,
  'scopes': ['openid'],
  'grantedAt': '2025-01-02T08:00:00.000Z',
};

void main() {
  late _AppLoginsClient client;
  late WorkspaceController w;
  final emptied = FocusNode(debugLabel: 'emptied');
  tearDownAll(emptied.dispose);

  Future<void> mount(WidgetTester t, List<Map<String, Object?>> logins) async {
    client = _AppLoginsClient(logins);
    w = WorkspaceController(client);
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      w.dispose();
      await client.dispose();
    });
    t.view
      ..physicalSize = const Size(900, 1400)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        builder: (context, child) => RaftToastHost(child: child!),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                AppLoginsSection(controller: w, emptiedFocus: emptied),
                Focus(focusNode: emptied, child: const Text('Session heading')),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  bool hasFocus(WidgetTester t, String clientId) => t
      .widget<RaftButton>(find.byKey(ValueKey('app-login-revoke-$clientId')))
      .focusNode!
      .hasFocus;

  Future<void> openConfirm(WidgetTester t, String clientId) async {
    await t.tap(find.byKey(ValueKey('app-login-revoke-$clientId')));
    await t.pumpAndSettle();
  }

  testWidgets('renders nothing without an App, or when the list fails', (
    t,
  ) async {
    await mount(t, []);
    expect(find.byKey(const ValueKey('app-logins-section')), findsNothing);
    expect(find.text('Apps you signed in to with Raft'), findsNothing);
    expect(client.to('/me/app-logins'), hasLength(1));

    await t.pumpWidget(const SizedBox.shrink());
    client.listFails = true;
    client.logins.add(_login('app_a', 'Notes'));
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: AppLoginsSection(controller: w)),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-logins-section')), findsNothing);
    expect(find.text('Notes'), findsNothing);
  });

  testWidgets('lists the Apps: header, description, name, date, Revoke', (
    t,
  ) async {
    await mount(t, [
      _login('app_a', 'Team Notes'),
      _login('app_b', 'Plain', logoUrl: null),
    ]);
    expect(find.text('Apps you signed in to with Raft'), findsOneWidget);
    expect(
      find.text(
        'These apps know who you are. Revoking signs you out of the app right away.',
      ),
      findsOneWidget,
    );
    final row = find.byKey(const ValueKey('app-login-row-app_a'));
    expect(
      find.descendant(of: row, matching: find.text('Team Notes')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.textContaining(RegExp(r'^Signed in \d{4}-01-02$')),
      ),
      findsOneWidget,
    );
    // No logo: the initials of the first two words, as Web's initialsForApp.
    expect(find.descendant(of: row, matching: find.text('TN')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('app-login-row-app_b')),
        matching: find.text('PL'),
      ),
      findsOneWidget,
    );
    final revoke = t.widget<RaftButton>(
      find.byKey(const ValueKey('app-login-revoke-app_a')),
    );
    expect(revoke.tone, RaftButtonRecipeVariant.outline);
    expect(find.text('Revoke'), findsNWidgets(2));
  });

  testWidgets('the confirm opens on Cancel; Cancel changes nothing', (t) async {
    await mount(t, [_login('app_a', 'Notes')]);
    await openConfirm(t, 'app_a');
    expect(find.text('Revoke Notes?'), findsOneWidget);
    expect(
      find.text(
        'Notes loses access right away. To use it again, sign in with Raft again.',
      ),
      findsOneWidget,
    );
    final cancel = find.widgetWithText(RaftButton, 'Cancel');
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'confirm cancel');
    await t.tap(cancel);
    await t.pumpAndSettle();
    expect(find.text('Revoke Notes?'), findsNothing);
    expect(client.revoked, isEmpty);
    expect(find.byKey(const ValueKey('app-login-row-app_a')), findsOneWidget);
  });

  testWidgets('a failed revoke stays in the dialog and keeps the row', (
    t,
  ) async {
    await mount(t, [_login('app_a', 'Notes')]);
    client.revokeFails = true;
    await openConfirm(t, 'app_a');
    await t.tap(find.byKey(const ValueKey('app-login-revoke-confirm')));
    await t.pumpAndSettle();
    expect(find.text('Revoke Notes?'), findsOneWidget);
    expect(find.text("Couldn't revoke Notes. Try again."), findsOneWidget);
    expect(find.text('Notes revoked'), findsNothing);
    expect(find.byKey(const ValueKey('app-login-row-app_a')), findsOneWidget);
  });

  testWidgets('a revoke removes the row, toasts, and focuses the next Revoke', (
    t,
  ) async {
    await mount(t, [
      _login('app_a', 'Alpha'),
      _login('app_b', 'Beta'),
      _login('app_c', 'Gamma'),
    ]);
    await openConfirm(t, 'app_b');
    await t.tap(find.byKey(const ValueKey('app-login-revoke-confirm')));
    await t.pumpAndSettle();
    expect(client.revoked, ['app_b']);
    expect(client.to('/me/app-logins/app_b').single.method, 'DELETE');
    expect(find.byKey(const ValueKey('app-login-row-app_b')), findsNothing);
    expect(find.text('Beta revoked'), findsOneWidget);
    expect(find.text('Revoke Beta?'), findsNothing);
    expect(hasFocus(t, 'app_c'), isTrue);

    // The last row: focus goes to the row before it.
    await openConfirm(t, 'app_c');
    await t.tap(find.byKey(const ValueKey('app-login-revoke-confirm')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-login-row-app_c')), findsNothing);
    expect(hasFocus(t, 'app_a'), isTrue);

    // The only row: the section goes and focus lands on the heading.
    await openConfirm(t, 'app_a');
    await t.tap(find.byKey(const ValueKey('app-login-revoke-confirm')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-logins-section')), findsNothing);
    expect(emptied.hasFocus, isTrue);
  });
}
