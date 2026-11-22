import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/global_server_selector.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'unknown /s/<slug> waits for the user to choose a server ($width)',
      (t) async {
        final f = RootFixture();
        await f.mount(t, 'light', width, uri: Uri(path: '/s/ghost'));
        expect(find.byType(RaftServerAccessDeniedPage), findsOneWidget);
        expect(find.text('Server not found'), findsOneWidget);
        expect(find.text('Raft', findRichText: true), findsNothing);
        expect(find.text('Choose a server'), findsOneWidget);
        final button = t.widget<RaftButton>(
          find.widgetWithText(RaftButton, 'Choose a server'),
        );
        expect(button.resolvedVariant, RaftButtonVariant.standard);
        expect(button.resolvedSize, RaftButtonSize.md);
        expect(find.byType(GlobalServerSelector), findsNothing);
        expect(f.router(t).currentConfiguration.path, '/s/ghost');
        await t.pump(const Duration(seconds: 4));
        expect(find.byType(RaftServerAccessDeniedPage), findsOneWidget);
        expect(f.router(t).currentConfiguration.path, '/s/ghost');
        await t.tap(find.text('Choose a server'));
        await f.flush(t);
        expect(find.byType(RaftServerAccessDeniedPage), findsNothing);
        expect(find.byType(GlobalServerSelector), findsOneWidget);
        await f.close(t);
      },
    );
  }

  testWidgets(
    'a forbidden link inside a running workspace names the current server',
    (t) async {
      final f = RootFixture();
      await f.mount(t, 'light', 1280, uri: Uri(path: '/s/beta'));
      expect(f.workspace(t).server!.id, 'b');
      await f.pushUri(t, '/s/not-mine/channel/x');
      expect(find.byType(RaftServerAccessDeniedPage), findsOneWidget);
      await t.tap(find.text('Back to Beta'));
      await f.flush(t);
      expect(find.byType(WorkspaceView), findsOneWidget);
      expect(f.workspace(t).server!.id, 'b');
      await f.close(t);
    },
  );

  testWidgets('an account without servers is not told it was denied', (
    t,
  ) async {
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
    expect(find.text('找不到这个服务器'), findsOneWidget);
    expect(find.text('链接可能已失效，或者你没有加入这个服务器。'), findsOneWidget);
    expect(find.text('选择一个服务器'), findsOneWidget);
    await f.close(t);
  });
}
