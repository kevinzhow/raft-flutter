import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/workspace_view.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

const betaMemory = '/s/beta/settings/account?opaque=keep#resume';
const betaMemoryKey =
    'raft.server-surface.https%3A%2F%2Ffixture.invalid.alice.b';

Future<void> openMenu(WidgetTester t, double width) async {
  await t.tap(
    find.byKey(Key(width < 768 ? 'mobile-server-selector' : 'rail-workspace')),
  );
  await t.pumpAndSettle();
}

void main() {
  for (final theme in ['brutal', 'elegant-light', 'elegant-dark']) {
    testWidgets(
      '[K08m] actual RaftApp $theme invalid server memory PUSHes accepted desktop root then REPLACEs the first real channel',
      (t) async {
        final f = RootFixture();
        await f.mount(
          t,
          theme,
          1280,
          uri: Uri.parse('/s/alpha/members'),
          preferences: {betaMemoryKey: '/s/other/settings/account'},
        );
        f.adapter.routes['GET /servers/unread-summary'] = (_) => [];
        f.engineRoutes.clear();
        await openMenu(t, 1280);
        await t.tap(find.byKey(const ValueKey('server-menu-row-b')));
        await f.flush(t);
        expect(f.workspace(t).server!.id, 'b');
        expect(
          f.router(t).currentConfiguration.toString(),
          '/s/beta/channel/cb',
        );
        final pushes = f.engineRoutes
            .where((r) => r['replace'] == false)
            .toList();
        expect(pushes, hasLength(1));
        expect(pushes.single['uri'], '/s/beta');
        expect(f.engineRoutes.last['uri'], '/s/beta/channel/cb');
        expect(f.engineRoutes.last['replace'], isTrue);
        expect(
          f.engineRoutes.any((r) => '${r['uri']}'.contains('/s/other')),
          isFalse,
        );
        await f.close(t);
      },
    );
    for (final width in [390.0, 1280.0]) {
      testWidgets(
        '[K08k] actual RaftApp $theme/$width menu publishes desktop remembered PUSH or mobile Home REPLACE before held hydration',
        (t) async {
          final f = RootFixture();
          await f.mount(
            t,
            theme,
            width,
            uri: Uri.parse(width < 768 ? '/s/alpha' : '/s/alpha/members'),
            preferences: {betaMemoryKey: betaMemory},
          );
          final w = f.workspace(t);
          f.adapter.routes['GET /servers/unread-summary'] = (_) => [];
          final held = Completer<dynamic>();
          addTearDown(() {
            if (!held.isCompleted) held.complete([]);
          });
          final original = f.adapter.routes['GET /channels']!;
          f.adapter.routes['GET /channels'] = (o) =>
              o.headers['X-Server-Id'] == 'b' ? held.future : original(o);
          await openMenu(t, width);
          expect(find.byType(SimpleDialog), findsNothing);
          expect(find.byKey(const Key('server-switcher-menu')), findsOneWidget);
          f.engineRoutes.clear();
          await t.tap(find.byKey(const ValueKey('server-menu-row-b')));
          await f.flush(t);
          final expected = width < 768 ? '/s/beta' : betaMemory;
          expect(f.router(t).currentConfiguration.toString(), expected);
          expect(find.byType(WorkspaceView), findsNothing);
          expect(
            find.byKey(const Key('server-resolution-loading')),
            findsOneWidget,
          );
          expect(w.foreground, isFalse);
          expect(f.content.bound, isNull);
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await t.pump();
          expect(w.foreground, isFalse);
          final reports = f.engineRoutes
              .where((r) => r['uri'] == expected || r['location'] == expected)
              .toList();
          expect(reports, isNotEmpty);
          expect(reports.first['replace'], width < 768);
          expect(
            reports.where((r) => r['replace'] == false),
            hasLength(width < 768 ? 0 : 1),
          );
          held.complete(
            await original(
              f.adapter.calls.lastWhere(
                (r) => r.path == '/channels' && r.headers['X-Server-Id'] == 'b',
              ),
            ),
          );
          await f.flush(t);
          expect(f.workspace(t).server!.id, 'b');
          expect(f.router(t).currentConfiguration.toString(), expected);
          expect(
            find.byKey(const Key('server-resolution-loading')),
            findsNothing,
          );
          // Router rebuilds may re-report this identical URI as replacement;
          // they must never push a second history entry or expose a channel.
          expect(
            f.engineRoutes.every(
              (r) => r['uri'] == expected || r['location'] == expected,
            ),
            isTrue,
          );
          expect(
            f.engineRoutes.where((r) => r['replace'] == false),
            hasLength(width < 768 ? 0 : 1),
          );
          if (width < 768) {
            expect(
              find.byKey(const Key('mobile-server-selector')),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('workspace-mobile-detail-header')),
              findsNothing,
            );
            await t.tap(find.text('general-b').last);
            await f.flush(t);
            await t.tap(find.byKey(const Key('mobile-detail-back')));
            await f.flush(t);
            expect(f.router(t).currentConfiguration.toString(), '/s/beta');
          }
          await f.close(t);
        },
      );
    }
    testWidgets(
      '[K08l] actual RaftApp $theme Back retires held real-menu server switch and preserves accepted origin URI',
      (t) async {
        final f = RootFixture();
        await f.mount(
          t,
          theme,
          1280,
          uri: Uri.parse('/s/alpha/members'),
          preferences: {betaMemoryKey: betaMemory},
        );
        final w = f.workspace(t), before = w.location.uri;
        f.adapter.routes['GET /servers/unread-summary'] = (_) => [];
        final held = Completer<dynamic>();
        addTearDown(() {
          if (!held.isCompleted) held.complete([]);
        });
        final original = f.adapter.routes['GET /channels']!;
        f.adapter.routes['GET /channels'] = (o) =>
            o.headers['X-Server-Id'] == 'b' ? held.future : original(o);
        await openMenu(t, 1280);
        await t.tap(find.byKey(const ValueKey('server-menu-row-b')));
        await f.flush(t);
        expect(f.router(t).currentConfiguration.toString(), betaMemory);
        final back = f.router(t).popRoute();
        await f.flush(t);
        expect(await back, isTrue);
        expect(f.workspace(t).server!.id, 'a');
        expect(f.router(t).currentConfiguration, before);
        held.complete([
          {
            'id': 'stale-beta',
            'name': 'Stale Beta',
            'serverId': 'b',
            'type': 'channel',
            'joined': true,
          },
        ]);
        await f.flush(t);
        expect(w.server!.id, 'a');
        expect(w.channels.any((c) => c.id == 'stale-beta'), isFalse);
        expect(f.router(t).currentConfiguration, before);
        await f.close(t);
      },
    );
  }
}
