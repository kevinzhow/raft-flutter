import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/apps_route.dart';
import 'package:raft_flutter/features/integrations_views.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/screens/screen_fixture.dart';

void main() {
  for (final (viewport, toolbarHeight) in [
    (const Size(390, 844), 72.0),
    (const Size(1280, 900), 34.0),
  ]) {
    testWidgets('Apps view switch fits the Web toolbar at $viewport', (
      tester,
    ) async {
      final client = ScreenFixtureClient(
        (method, path, _) => switch (path) {
          '/mcp/apps' => {'apps': <Object?>[]},
          '/integrations/marketplace' => [_installed('Garden Journal')],
          '/integrations/marketplace/listings' => {'items': [], 'total': 0},
          _ => const <Object?>[],
        },
        user: const {'id': 'member'},
        server: 'workspace',
      );
      final workspace = WorkspaceController(client)
        ..server = RaftRecord({
          'id': 'workspace',
          'slug': 'garden',
          'name': 'Garden',
          'role': 'owner',
        });
      addTearDown(workspace.dispose);
      addTearDown(client.dispose);
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: TargetPlatform.linux),
          home: Scaffold(body: AppsRoute(workspace: workspace)),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(RaftFitToolbar)).height, toolbarHeight);
      final card = find.ancestor(
        of: find.text('Garden Journal'),
        matching: find.byType(RaftCard),
      );
      final gridSize = tester.getSize(card);
      if (viewport.width < 640) {
        await tester.tap(find.byKey(const ValueKey('apps-toolbar-more')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('List view').hitTestable());
      } else {
        await tester.tap(
          find.byKey(const ValueKey('connected-apps-view-list')).hitTestable(),
        );
      }
      await tester.pumpAndSettle();
      expect(tester.getSize(card).height, lessThan(gridSize.height));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('narrow Settings Applications uses the Apps scope picker', (
    tester,
  ) async {
    final client = ScreenFixtureClient(
      (method, path, _) => switch (path) {
        '/mcp/apps' => {'apps': <Object?>[]},
        '/integrations/marketplace/listings' => {'items': [], 'total': 0},
        _ => const <Object?>[],
      },
      user: const {'id': 'member'},
      server: 'workspace',
    );
    final workspace = WorkspaceController(client)
      ..server = RaftRecord({
        'id': 'workspace',
        'slug': 'garden',
        'name': 'Garden',
        'role': 'owner',
      });
    addTearDown(workspace.dispose);
    addTearDown(client.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: Scaffold(body: IntegrationsView(controller: workspace)),
      ),
    );
    await tester.pumpAndSettle();

    const scope = ValueKey('connected-apps-scope-select');
    expect(find.byKey(scope), findsOneWidget);
    expect(tester.getSize(find.byKey(scope)).height, 32);
    expect(find.text('Third-party apps for this server'), findsNothing);
    await tester.tap(find.byKey(scope));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marketplace'));
    await tester.pumpAndSettle();
    expect(find.byKey(scope), findsOneWidget);
    expect(find.text('No apps in the Marketplace yet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'touch refresh keeps the installed list until the read finishes',
    (tester) async {
      final refreshed = Completer<List<Object?>>();
      var reads = 0, mcpReads = 0;
      final client = ScreenFixtureClient(
        (method, path, _) => switch (path) {
          '/integrations/marketplace' =>
            ++reads == 1 ? [_installed('Garden Journal')] : refreshed.future,
          '/mcp/apps' =>
            ++mcpReads == 1
                ? throw const RaftApiException(
                    'MCP Apps temporarily unavailable',
                    status: 503,
                  )
                : {'apps': <Object?>[]},
          '/integrations/marketplace/listings' => {'items': [], 'total': 0},
          _ => const <Object?>[],
        },
        user: const {'id': 'member'},
        server: 'workspace',
      );
      final workspace = WorkspaceController(client)
        ..server = RaftRecord({
          'id': 'workspace',
          'slug': 'garden',
          'name': 'Garden',
          'role': 'owner',
        });
      addTearDown(workspace.dispose);
      addTearDown(client.dispose);
      tester.view.physicalSize = const Size(856, 944);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: TargetPlatform.android),
          home: Scaffold(body: AppsRoute(workspace: workspace)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Garden Journal'), findsOneWidget);
      final app = find.ancestor(
        of: find.text('Garden Journal'),
        matching: find.byType(RaftCard),
      );
      expect(tester.getTopLeft(app).dx, 20);
      expect(reads, 1);
      expect(mcpReads, 1);
      final warning = find.ancestor(
        of: find.text("Couldn't load MCP Apps."),
        matching: find.byType(RaftBanner),
      );
      expect(warning, findsOneWidget);
      expect(
        find.descendant(of: warning, matching: find.byType(RaftButton)),
        findsNothing,
      );
      expect(tester.getTopLeft(warning).dy - tester.getBottomLeft(app).dy, 8);

      final scroller = find.byType(CustomScrollView);
      final gesture = await tester.startGesture(
        tester.getTopLeft(scroller) + const Offset(80, 20),
        kind: PointerDeviceKind.touch,
      );
      await gesture.moveBy(const Offset(0, 24));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 220));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(reads, 2);
      expect(mcpReads, 2);
      expect(find.text('Garden Journal'), findsOneWidget);
      refreshed.complete([_installed('Garden Planner')]);
      await tester.pumpAndSettle();
      expect(find.text('Garden Planner'), findsOneWidget);
      expect(find.text('Garden Journal'), findsNothing);
      expect(warning, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('empty Marketplace keeps applied filters first', (tester) async {
    var listingsReads = 0;
    final client = ScreenFixtureClient(
      (method, path, _) {
        if (path == '/integrations/marketplace/listings') {
          listingsReads++;
          return {'items': <Object?>[], 'total': 0};
        }
        if (path == '/mcp/apps') return {'apps': <Object?>[]};
        return const <Object?>[];
      },
      user: const {'id': 'member'},
      server: 'workspace',
    );
    final workspace = WorkspaceController(client)
      ..server = RaftRecord({
        'id': 'workspace',
        'slug': 'garden',
        'name': 'Garden',
        'role': 'owner',
      });
    addTearDown(workspace.dispose);
    addTearDown(client.dispose);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: Scaffold(body: AppsRoute(workspace: workspace)),
      ),
    );
    await tester.pumpAndSettle();
    expect(listingsReads, 1);
    await tester.tap(find.text('Browse marketplace'));
    await tester.pumpAndSettle();

    expect(listingsReads, 2);
    expect(find.text('No apps in the Marketplace yet'), findsOneWidget);
    expect(
      find.text('Apps appear here once Raft has reviewed them.'),
      findsOneWidget,
    );
    expect(find.text('Browse marketplace'), findsNothing);

    final type = find.byKey(const ValueKey('apps-filter-type'));
    final category = find.byKey(
      const ValueKey('connected-apps-category-filter'),
    );
    expect(
      tester.getTopLeft(type).dx,
      lessThan(tester.getTopLeft(category).dx),
    );
    await tester.tap(category);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Communication').hitTestable());
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(category).dx,
      lessThan(tester.getTopLeft(type).dx),
    );
  });

  testWidgets('cold Apps waits one second before showing its placeholders', (
    tester,
  ) async {
    final clients = Completer<List<Object?>>();
    final client = ScreenFixtureClient(
      (method, path, _) => switch (path) {
        '/integrations/clients' => clients.future,
        '/mcp/apps' => {'apps': <Object?>[]},
        '/integrations/marketplace/listings' => {'items': [], 'total': 0},
        _ => const <Object?>[],
      },
      user: const {'id': 'member'},
      server: 'workspace',
    );
    final workspace = WorkspaceController(client)
      ..server = RaftRecord({
        'id': 'workspace',
        'slug': 'garden',
        'name': 'Garden',
        'role': 'owner',
      });
    addTearDown(workspace.dispose);
    addTearDown(client.dispose);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: Scaffold(body: AppsRoute(workspace: workspace)),
      ),
    );
    const placeholders = ValueKey('apps-installed-loading-collection');
    await tester.pump(const Duration(milliseconds: 999));
    expect(find.byKey(placeholders), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(placeholders), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(placeholders)).dx, 16);
    clients.complete([]);
    await tester.pumpAndSettle();
    expect(find.byKey(placeholders), findsNothing);
    expect(find.text('No apps installed yet'), findsOneWidget);
  });

  testWidgets('Marketplace Retry reads listings and replaces the error', (
    tester,
  ) async {
    final listingQueries = <Map<String, dynamic>?>[];
    final client = ScreenFixtureClient(
      (method, path, query) {
        if (path == '/integrations/marketplace/listings') {
          listingQueries.add(query);
          if (listingQueries.length == 2) {
            return const RaftApiException('Unavailable', status: 503);
          }
          if (listingQueries.length == 3) {
            return {
              'items': [
                {
                  'kind': 'app',
                  'id': 'app:garden-journal',
                  'app': {..._installed('Garden Journal'), 'installedAt': null},
                },
              ],
              'total': 1,
            };
          }
          return {'items': <Object?>[], 'total': 0};
        }
        if (path == '/mcp/apps') return {'apps': <Object?>[]};
        return const <Object?>[];
      },
      user: const {'id': 'member'},
      server: 'workspace',
    );
    final workspace = WorkspaceController(client)
      ..server = RaftRecord({
        'id': 'workspace',
        'slug': 'garden',
        'name': 'Garden',
        'role': 'owner',
      });
    addTearDown(workspace.dispose);
    addTearDown(client.dispose);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: Scaffold(body: AppsRoute(workspace: workspace)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browse marketplace'));
    await tester.pumpAndSettle();

    const failure = ValueKey('apps-marketplace-load-failed');
    expect(find.byKey(failure), findsOneWidget);
    expect(find.text('No apps in the Marketplace yet'), findsNothing);
    await tester.tap(
      find.descendant(of: find.byKey(failure), matching: find.text('Retry')),
    );
    await tester.pumpAndSettle();

    expect(listingQueries, hasLength(3));
    expect(listingQueries.last, listingQueries[1]);
    expect(find.byKey(failure), findsNothing);
    final card = find.byKey(const ValueKey('connected-app-garden-journal'));
    final count = find.text('Showing 1 / 1');
    expect(card, findsOneWidget);
    expect(tester.getTopLeft(count).dy - tester.getBottomLeft(card).dy, 12);
  });
}

Map<String, Object?> _installed(String name) => {
  'id': 'garden-journal',
  'clientId': 'garden-journal',
  'name': name,
  'publishStatus': 'published',
  'installedAt': '2026-11-20T00:00:00Z',
};
