import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/artifact_web_data.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'support/fake_webview.dart';

/// The in-app artifact browser keeps the artifact site's session in the
/// WebView's cookies and storage. Wherever the app ends its own session, that
/// web data is cleared too, so the next person never inherits it.
const _memory = 'raft.server-surface.https%3A%2F%2Ffixture.invalid.alice';

void main() {
  late int clears;
  setUp(() {
    clears = 0;
    artifactWebDataClearer = () async => clears++;
    addTearDown(
      () => artifactWebDataClearer = debugPlatformArtifactWebDataClearer,
    );
  });

  Future<RootFixture> signedIn(WidgetTester t) async {
    final f = RootFixture();
    await f.mount(
      t,
      'light',
      412,
      cachedSession: true,
      preferences: {'$_memory.last': 'alpha', '$_memory.a': '/s/alpha'},
    );
    expect(find.byType(WorkspaceView), findsOneWidget);
    expect(clears, 0, reason: 'nothing is cleared while signed in');
    return f;
  }

  testWidgets('sign-out clears the artifact browser\'s web data', (t) async {
    final f = await signedIn(t);
    final logout = t
        .widget<WorkspaceView>(find.byType(WorkspaceView))
        .onLogout();
    await f.flush(t);
    await logout;
    expect(find.byType(AuthView), findsOneWidget);
    expect(clears, greaterThanOrEqualTo(1));
    await f.close(t);
  });

  testWidgets('a switch to another account clears it', (t) async {
    final f = await signedIn(t);
    // The account record now names another person.
    f.client.user = RaftRecord({
      'id': 'bob',
      'name': 'bob',
      'email': 'bob@example.invalid',
      'emailVerified': true,
    });
    f.client.event('account:updated', null);
    await f.flush(t);
    expect(find.byType(WorkspaceView), findsNothing);
    expect(clears, greaterThanOrEqualTo(1));
    await f.close(t);
  });

  testWidgets('a session the server ended (401 on the account check, refresh '
      'rejected) clears it', (t) async {
    final f = await signedIn(t);
    f.adapter.statuses['GET /auth/me'] = 401;
    final reload = f.client.reloadUser().then<void>(
      (_) {},
      onError: (Object _) {},
    );
    await f.flush(t);
    await reload;
    expect(find.byType(AuthView), findsOneWidget);
    expect(
      find.text('Your session has expired. Sign in again.'),
      findsOneWidget,
    );
    expect(clears, greaterThanOrEqualTo(1));
    await f.close(t);
  });

  testWidgets('a stored session found dead at start-up clears it', (t) async {
    final f = RootFixture();
    f.adapter.statuses['GET /auth/me'] = 401;
    await f.mount(t, 'light', 390);
    expect(find.byType(AuthView), findsOneWidget);
    expect(
      find.text('Your session has expired. Sign in again.'),
      findsOneWidget,
    );
    expect(clears, greaterThanOrEqualTo(1));
    await f.close(t);
  });

  test(
    'the real clearer clears cookies, local storage and the cache',
    () async {
      WebViewPlatform.instance = FakeWebView();
      FakeWebView.reset();
      await debugPlatformArtifactWebDataClearer();
      expect(FakeWebView.cleared, ['cookies', 'localStorage', 'cache']);
    },
  );

  testWidgets('no stored session at start-up: nothing to clear', (t) async {
    final f = RootFixture();
    await f.mount(t, 'light', 390);
    await f.sessions.write('https://fixture.invalid', null);
    expect(clears, 0);
    await f.close(t);
  });
}
