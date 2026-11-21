import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/integrations_views.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/screens/screen_fixture.dart';

void main() {
  testWidgets('loads the next page, retries in place, and deduplicates rows', (
    tester,
  ) async {
    const path = '/integrations/marketplace/listings';
    final calls = <Map<String, dynamic>>[];
    var failNext = true;
    Map<String, Object?> listing(String id, String name) => {
      'kind': 'app',
      'id': 'app:$id',
      'installed': false,
      'app': {
        'id': id,
        'clientId': id,
        'name': name,
        'publishStatus': 'published',
      },
    };
    final first = listing('one', 'Garden Planner');
    final client = ScreenFixtureClient(
      (method, route, query) {
        if (route == path) {
          calls.add(query!);
          if (query['cursor'] == null) {
            return {
              'items': [first],
              'nextCursor': 'next-page',
              'total': 2,
            };
          }
          if (failNext) {
            failNext = false;
            throw const RaftApiException('Service unavailable', status: 503);
          }
          return {
            'items': [first, listing('two', 'Garden Journal')],
            'nextCursor': null,
            'total': 2,
          };
        }
        return const <Object>[];
      },
      user: const {'id': 'member'},
      server: 'workspace',
    );
    final workspace = WorkspaceController(client)
      ..server = RaftRecord({
        'id': 'workspace',
        'name': 'Garden',
        'role': 'owner',
      });
    addTearDown(workspace.dispose);
    addTearDown(client.dispose);
    tester.view.physicalSize = const Size(944, 856);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.android),
        home: Scaffold(body: IntegrationsView(controller: workspace)),
      ),
    );
    await tester.pumpAndSettle();
    if (calls.isEmpty) {
      await tester.tap(
        find.byKey(const ValueKey('connected-apps-tab-marketplace')),
      );
      await tester.pumpAndSettle();
    }

    expect(calls, [
      {'sort': 'installs'},
    ]);
    expect(find.text('Garden Planner'), findsOneWidget);
    final more = find.text('Load more');
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load more apps."), findsOneWidget);
    expect(find.text('Garden Planner'), findsOneWidget);

    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();

    expect(calls.skip(1), [
      {'sort': 'installs', 'cursor': 'next-page'},
      {'sort': 'installs', 'cursor': 'next-page'},
    ]);
    expect(find.text('Garden Planner'), findsOneWidget);
    expect(find.text('Garden Journal'), findsOneWidget);
    expect(find.text('Showing 2 / 2'), findsOneWidget);
    expect(find.text("Couldn't load more apps."), findsNothing);
    expect(more, findsNothing);
  });
}
