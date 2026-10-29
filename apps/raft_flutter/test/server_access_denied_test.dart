import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/global_server_selector.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('unknown /s/<slug> shows Server not found and redirects ($width)', (
      t,
    ) async {
      final f = RootFixture();
      await f.mount(t, 'light', width, uri: Uri(path: '/s/ghost'));
      expect(find.byType(RaftServerAccessDeniedPage), findsOneWidget);
      expect(find.text('Server not found'), findsOneWidget);
      expect(find.text('Raft', findRichText: true), findsNothing);
      // The fallback is the first server; the URL still names the request.
      expect(
        find.textContaining('Redirecting to Alpha in 3 seconds.', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Go to My Server'), findsOneWidget);
      expect(find.byType(GlobalServerSelector), findsNothing);
      expect(f.router(t).currentConfiguration.path, '/s/ghost');
      // After 3 seconds the app opens that server.
      await t.pump(const Duration(seconds: 3));
      await f.flush(t);
      expect(find.byType(RaftServerAccessDeniedPage), findsNothing);
      expect(find.byType(WorkspaceView), findsOneWidget);
      expect(f.workspace(t).server!.id, 'a');
      expect(f.router(t).currentConfiguration.path, startsWith('/s/alpha'));
      await f.close(t);
    });
  }

  testWidgets('the button goes to the server at once and cancels the timer', (
    t,
  ) async {
    final f = RootFixture();
    await f.mount(t, 'light', 1280, uri: Uri(path: '/s/ghost'));
    await t.tap(find.byKey(const ValueKey('server-denied-continue')));
    await f.flush(t);
    expect(find.byType(WorkspaceView), findsOneWidget);
    expect(f.workspace(t).server!.id, 'a');
    // No second selection when the old timer would have fired.
    await t.pump(const Duration(seconds: 4));
    expect(find.byType(RaftServerAccessDeniedPage), findsNothing);
    await f.close(t);
  });

  testWidgets('a forbidden link inside a running workspace names the current server', (
    t,
  ) async {
    final f = RootFixture();
    await f.mount(t, 'light', 1280, uri: Uri(path: '/s/beta'));
    expect(f.workspace(t).server!.id, 'b');
    await f.pushUri(t, '/s/not-mine/channel/x');
    expect(find.byType(RaftServerAccessDeniedPage), findsOneWidget);
    expect(
      find.textContaining('Redirecting to Beta in 3 seconds.', findRichText: true),
      findsOneWidget,
    );
    await t.tap(find.text('Go to My Server'));
    await f.flush(t);
    expect(find.byType(WorkspaceView), findsOneWidget);
    expect(f.workspace(t).server!.id, 'b');
    await f.close(t);
  });

  testWidgets('an account without servers is not told it was denied', (t) async {
    final f = RootFixture()..servers.clear();
    await f.mount(t, 'light', 390, uri: Uri(path: '/s/ghost'));
    expect(find.byType(RaftServerAccessDeniedPage), findsNothing);
    expect(find.byType(GlobalServerSelector), findsOneWidget);
    await f.close(t);
  });

  testWidgets('Chinese copy comes from the Web catalog', (t) async {
    final f = RootFixture();
    f.overrides['GET /auth/me'] = (_) => {
      'id': 'alice',
      'name': 'alice',
      'email': 'alice@example.invalid',
      'emailVerified': true,
      'displayLanguage': 'zh-cn',
    };
    await f.mount(t, 'light', 390, uri: Uri(path: '/s/ghost'));
    expect(find.text('未找到服务器'), findsOneWidget);
    expect(
      find.textContaining('3 秒后将跳转到 Alpha。', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('前往我的服务器'), findsOneWidget);
    await f.close(t);
  });
}
