import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'workspace_source_location_contract_test.dart' show pageFixture, frames;
import 'workspace_shell_contract_test.dart' show retire;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '[K08j] $family/$dark actual mouse server reorder PATCH is Source-shaped and stale role handler cannot write',
      (t) async {
        final (w, api) = await pageFixture(t, section: 'chat');
        w.servers = [
          w.server!,
          RaftRecord({
            'id': 's2',
            'name': 'Beta',
            'slug': 'beta',
            'role': 'owner',
          }),
          RaftRecord({
            'id': 's3',
            'name': 'Gamma',
            'slug': 'gamma',
            'role': 'owner',
          }),
        ];
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [];
        api.routes['GET /servers/unread-summary'] = (_) => [];
        final writes = <dynamic>[];
        api.routes['PATCH /servers/order'] = (request) {
          writes.add(request.data);
          return request.data;
        };
        t.view.physicalSize = const Size(1280, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: WorkspaceView(
              controller: w,
              appearance: RaftAppearance(light: family),
              onAppearance: (_) async {},
              onLogout: () async {},
              onChooseServer: () {},
            ),
          ),
        );
        await frames(t, () {});
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('rail-workspace')));
        await t.pumpAndSettle();
        final stale = t
            .widget<RaftServerSwitcher>(find.byType(RaftServerSwitcher))
            .onReorder!;
        final start = t.getCenter(
          find.byKey(const ValueKey('server-menu-reorder-s1')),
        );
        final mouse = await t.startGesture(
          start,
          kind: PointerDeviceKind.mouse,
        );
        final last = t.getRect(
          find.byKey(const ValueKey('server-menu-reorder-s3')),
        );
        final end = Offset(start.dx, last.bottom + last.height / 2);
        for (var step = 1; step <= 10; step++) {
          await mouse.moveTo(Offset.lerp(start, end, step / 10)!);
          await t.pump(const Duration(milliseconds: 32));
        }
        await t.pump(const Duration(milliseconds: 300));
        await mouse.up();
        await frames(t, () {});
        await t.pumpAndSettle();
        expect(writes, [
          {
            'serverOrder': ['s2', 's3', 's1'],
          },
        ]);
        expect(w.servers.map((s) => s.id), ['s2', 's3', 's1']);
        w.server = RaftRecord({...w.server!.json, 'role': 'member'});
        w.notifyListeners();
        await frames(t, () {});
        expect(find.byKey(const Key('server-switcher-menu')), findsNothing);
        stale(0, 1);
        await frames(t, () {});
        expect(writes.length, 1);
        await retire(t);
      },
    );
    testWidgets(
      '[K08h] $family/$dark actual WorkspaceView server menu closes current without URI/history and delegates global chooser',
      (t) async {
        final (w, api) = await pageFixture(t, section: 'chat');
        w.servers = [w.server!];
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [];
        api.routes['GET /servers/unread-summary'] = (_) => [
          {'serverId': 's1', 'unreadCount': 88, 'activityUnreadCount': 77},
        ];
        t.view.physicalSize = const Size(1280, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        var choose = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: WorkspaceView(
              controller: w,
              appearance: RaftAppearance(light: family),
              onAppearance: (_) async {},
              onLogout: () async {},
              onChooseServer: () => choose++,
            ),
          ),
        );
        await frames(t, () {});
        await t.pumpAndSettle();
        final uri = w.location.toString(), history = w.navigation.index;
        await t.tap(find.byKey(const Key('rail-workspace')));
        await frames(t, () {});
        await t.pumpAndSettle();
        expect(find.byKey(const Key('server-switcher-menu')), findsOneWidget);
        expect(find.byType(SimpleDialog), findsNothing);
        expect(find.text('77'), findsNothing);
        expect(find.text('Invite human'), findsOneWidget);
        expect(find.text('Join Community'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('server-menu-row-s1')));
        await t.pumpAndSettle();
        expect(w.location.toString(), uri);
        expect(w.navigation.index, history);
        expect(find.byKey(const Key('server-switcher-menu')), findsNothing);
        await t.tap(find.byKey(const Key('rail-workspace')));
        await t.pumpAndSettle();
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(w.location.toString(), uri);
        await t.tap(find.byKey(const Key('rail-workspace')));
        await t.pumpAndSettle();
        await t.tap(find.text('Switch or Create Server'));
        await t.pumpAndSettle();
        expect(choose, 1);
        expect(find.byKey(const Key('server-switcher-menu')), findsNothing);
        await retire(t);
      },
    );
    testWidgets(
      '[K08i] $family/$dark actual server menu Invite is capability gated and sends trimmed member email before Source administration route',
      (t) async {
        final (w, api) = await pageFixture(t, section: 'chat');
        w.servers = [w.server!];
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [];
        api.routes['GET /servers/unread-summary'] = (_) => [];
        final posted = <dynamic>[];
        api.routes['POST /servers/s1/invites'] = (request) {
          posted.add(request.data);
          return {};
        };
        t.view.physicalSize = const Size(1280, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: WorkspaceView(
              controller: w,
              appearance: RaftAppearance(light: family),
              onAppearance: (_) async {},
              onLogout: () async {},
              onChooseServer: () {},
            ),
          ),
        );
        await frames(t, () {});
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('rail-workspace')));
        await t.pumpAndSettle();
        await t.tap(find.text('Invite human'));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('server-switcher-menu')), findsNothing);
        expect(find.byType(RaftFormDialog), findsOneWidget);
        await t.enterText(find.byType(TextFormField), ' invalid@.email ');
        await t.tap(find.text('Send invitations'));
        await frames(t, () {});
        expect(posted, isEmpty);
        expect(find.text('Enter a valid email address'), findsOneWidget);
        await t.enterText(find.byType(TextFormField), ' person@example.com ');
        await t.tap(find.text('Send invitations'));
        await frames(t, () {});
        await t.pumpAndSettle();
        expect(posted, [
          {'email': 'person@example.com', 'role': 'member'},
        ]);
        expect(w.location.toString(), '/s/demo/settings/administration');
        w.server = RaftRecord({...w.server!.json, 'role': 'member'});
        w.notifyListeners();
        await frames(t, () {});
        await t.tap(find.byKey(const Key('rail-workspace')));
        await t.pumpAndSettle();
        expect(find.text('Invite human'), findsNothing);
        await retire(t);
      },
    );
  }
}
