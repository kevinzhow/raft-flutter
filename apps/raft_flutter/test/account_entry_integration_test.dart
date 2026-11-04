import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/features/chinese_community.dart';
import 'package:raft_flutter/features/global_server_selector.dart';
import 'package:raft_flutter/features/private_app_invite_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'private_app_invite_root_test.dart' show privateInvite;

void main() {
  for (final cold in [true, false]) {
    testWidgets(
      'actual root receives ${cold ? 'pending' : 'live'} native invite',
      (t) async {
        final f = RootFixture();
        addTearDown(() => f.close(t));
        final location = Uri.parse('raft://v1/integration-invites/test-invite');
        f.overrides['GET /integration-invites/test-invite'] = (_) =>
            privateInvite();
        if (cold) f.content.receiveLink(location);
        await f.mount(t, 'light', 1280, uri: Uri(path: '/s/alpha'));
        if (!cold) {
          expect(find.byType(WorkspaceView), findsOneWidget);
          f.content.receiveLink(location);
          await f.flush(t);
        }
        expect(find.byType(PrivateAppInviteView), findsOneWidget);
        expect(find.text('Shared Calendar'), findsOneWidget);
        expect(
          f.router(t).currentConfiguration.path,
          '/integration-invites/test-invite',
        );
        expect(
          f.adapter.calls.where((c) => c.path.endsWith('/install')),
          isEmpty,
        );
        expect(f.content.bound, isNull);
      },
    );
  }

  testWidgets('standalone invite closes after its prior server is removed', (
    t,
  ) async {
    final f = RootFixture();
    addTearDown(() => f.close(t));
    f.overrides['GET /integration-invites/test-invite'] = (_) =>
        privateInvite();
    await f.mount(t, 'light', 1280, uri: Uri(path: '/s/alpha'));
    f.content.receiveLink(
      Uri.parse('raft://v1/integration-invites/test-invite'),
    );
    await f.flush(t);
    f.servers.removeWhere((s) => s['id'] == 'a');
    f.client.event('server:membership-removed', {'serverId': 'a'});
    await f.flush(t);
    expect(find.byType(PrivateAppInviteView), findsOneWidget);
    expect(
      f.router(t).currentConfiguration.path,
      '/integration-invites/test-invite',
    );
    await t.tap(find.byKey(const ValueKey('private-app-invite-close')));
    await f.flush(t);
    expect(find.byType(PrivateAppInviteView), findsNothing);
    expect(find.byType(GlobalServerSelector), findsOneWidget);
    expect(f.adapter.calls.where((c) => c.path.endsWith('/install')), isEmpty);
  });

  for (final signedIn in [true, false]) {
    testWidgets('Chinese utility page works signed in=$signedIn and closes', (
      t,
    ) async {
      final f = RootFixture();
      addTearDown(() => f.close(t));
      if (!signedIn) f.adapter.statuses['GET /auth/me'] = 401;
      await f.mount(t, 'light', 1280, uri: Uri(path: '/community/chinese'));
      expect(find.byType(ChineseCommunityPage), findsOneWidget);
      expect(find.byType(RaftChineseCommunityPage), findsOneWidget);
      expect(find.byType(AuthView), findsNothing);
      expect(f.adapter.calls.where((c) => c.path.endsWith('/join')), isEmpty);
      await t.tap(find.byKey(const ValueKey('chinese-community-back')));
      await f.flush(t);
      expect(find.byType(ChineseCommunityPage), findsNothing);
      expect(
        find.byType(signedIn ? GlobalServerSelector : AuthView),
        findsOneWidget,
      );
    });
  }

  testWidgets(
    'nonmember Chinese server fallback opens the existing QR utility',
    (t) async {
      final f = RootFixture();
      addTearDown(() => f.close(t));
      const path = '/public/servers/community-cn';
      f.overrides['GET $path'] = (_) => {'error': 'Server not found'};
      f.adapter.statuses['GET $path'] = 404;
      await f.mount(t, 'light', 1280, uri: Uri(path: '/s/community-cn'));
      expect(find.byType(ChineseCommunityPage), findsOneWidget);
      expect(f.adapter.calls.where((c) => c.path.endsWith('/join')), isEmpty);
      expect(f.client.serverId, isNull);
      expect(
        f.engineRoutes.any(
          (r) => '${r['uri']}'.startsWith('/community/chinese'),
        ),
        isTrue,
        reason: '${f.router(t).currentConfiguration}; ${f.engineRoutes}',
      );
    },
  );

  testWidgets('a joined Chinese server retains its ordinary workspace', (
    t,
  ) async {
    final f = RootFixture();
    addTearDown(() => f.close(t));
    f.servers[1]['slug'] = 'community-cn';
    await f.mount(t, 'light', 1280, uri: Uri(path: '/s/community-cn'));
    expect(find.byType(WorkspaceView), findsOneWidget);
    expect(find.byType(ChineseCommunityPage), findsNothing);
    expect(f.client.serverId, 'b');
    expect(f.adapter.calls.where((c) => c.path.endsWith('/join')), isEmpty);
  });

  testWidgets('anonymous unavailable server keeps the Web sign-in fallback', (
    t,
  ) async {
    final f = RootFixture();
    addTearDown(() => f.close(t));
    f.adapter.statuses['GET /auth/me'] = 401;
    const path = '/public/servers/community-cn';
    f.overrides['GET $path'] = (_) => {'error': 'Server not found'};
    f.adapter.statuses['GET $path'] = 404;
    await f.mount(t, 'light', 1280, uri: Uri(path: '/s/community-cn'));
    expect(find.byType(AuthView), findsOneWidget);
    expect(find.byType(ChineseCommunityPage), findsNothing);
    expect(f.adapter.calls.where((c) => c.path.endsWith('/join')), isEmpty);
  });
}
