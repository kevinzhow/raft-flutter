import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_dashboard.dart';
import 'package:raft_flutter/features/artifacts/artifact_dashboard_data.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/artifact_fake_client.dart';

void main() {
  test(
    'existing device preferences survive the new dashboard preference',
    () async {
      const existingKey = 'appearance';
      SharedPreferences.setMockInitialValues({existingKey: 'dark'});
      addTearDown(DevicePreferences.reset);
      await DevicePreferences.load();
      expect(ArtifactDashboardPreferences.read().grid, isTrue);
      await const ArtifactDashboardPreferences(
        grid: false,
        sort: ArtifactDashboardSort.updated,
        widths: {ArtifactDashboardColumn.author: 180},
      ).write();
      DevicePreferences.reset();
      await DevicePreferences.load();
      expect(ArtifactDashboardPreferences.read().grid, isFalse);
      expect(
        ArtifactDashboardPreferences.read().sort,
        ArtifactDashboardSort.updated,
      );
      expect(DevicePreferences.current!.getString(existingKey), 'dark');
      expect(
        ArtifactDashboardPreferences.read().width(
          ArtifactDashboardColumn.author,
        ),
        180,
      );
      expect(
        ArtifactDashboardPreferences.read().width(
          ArtifactDashboardColumn.comments,
        ),
        84,
      );
    },
  );

  testWidgets('retry loads Artifacts and title search clears an empty result', (
    tester,
  ) async {
    final client = ArtifactFakeClient();
    final workspace = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner', 'name': 'Dev'});
    addTearDown(workspace.dispose);
    addTearDown(client.ingress.close);
    final rows = {
      'rows': [
        {
          'card': {'id': artifactId, 'title': 'Road map'},
        },
      ],
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: ArtifactDashboard(workspace: workspace)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load your Artifacts"), findsOneWidget);
    client.answers['GET /artifacts/dashboard/all?sort=opened'] = (_) => rows;
    client.answers['GET /artifacts/dashboard/all?q=Absent&sort=opened'] = (_) =>
        {'rows': []};
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Road map'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    await tester.enterText(find.byType(EditableText).first, 'Absent');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('No Artifacts match your search'), findsOneWidget);
    await tester.tap(find.text('Clear search and filter'));
    await tester.pumpAndSettle();
    expect(find.text('Road map'), findsOneWidget);
  });

  for (final (size, platform, wide) in [
    (const Size(856, 944), TargetPlatform.android, true),
    (const Size(944, 856), TargetPlatform.android, true),
    (const Size(390, 844), TargetPlatform.linux, false),
  ]) {
    testWidgets('filter and layout at $size on $platform', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final client = ArtifactFakeClient();
      final workspace = WorkspaceController(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner', 'name': 'Dev'});
      addTearDown(workspace.dispose);
      addTearDown(client.ingress.close);
      client.answers['GET /artifacts/dashboard/all?sort=opened'] = (_) => {
        'rows': [
          {'card': artifactCardJson(title: 'Road map')},
        ],
      };
      client.answers['GET /artifacts/dashboard/conversations'] = (_) => {
        'conversations': [
          {'id': 'project', 'name': 'Project notes'},
        ],
      };
      client.answers['GET /artifacts/dashboard/all?conversation=project&sort=opened'] =
          (_) => {
            'rows': [
              {'card': artifactCardJson(title: 'Project road map')},
            ],
          };
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: platform),
          home: Scaffold(body: ArtifactDashboard(workspace: workspace)),
        ),
      );
      await tester.pumpAndSettle();
      if (wide) {
        expect(find.byKey(const Key('artifact-grid')), findsOneWidget);
        await tester.tap(find.text('List'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('artifact-table')), findsOneWidget);
        expect(find.byType(RaftPanelResizeHandle), findsNothing);
      } else {
        expect(find.byKey(const Key('artifact-list')), findsOneWidget);
        expect(find.text('Grid'), findsNothing);
      }
      await tester.tap(find.text('By conversation'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('artifact-dashboard-filter')),
        findsOneWidget,
      );
      await tester.tap(find.text('Project notes'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('artifact-dashboard-filter')), findsNothing);
      expect(find.text('Project road map'), findsOneWidget);
      expect(find.text('Road map'), findsNothing);
    });
  }

  test('dashboard sends the selected filters and reads counts and cards', () async {
    final client = ArtifactFakeClient();
    addTearDown(client.ingress.close);
    client.answers['GET /artifacts/dashboard/all?conversation=channel%2F1&author=agent%3A1&q=Road+map&relevant=1&cursor=next%2Fpage'] =
        (_) => {
          'rows': [
            {
              'card': {'id': artifactId, 'title': 'Road map'},
              'openedAt': '2026-11-19T00:00:00.000Z',
              'news': {'mentions': 1, 'versions': 1, 'comments': 3},
            },
          ],
          'nextCursor': 'third',
          'counts': {'total': 12, 'filtered': 2, 'relevant': 1},
        };
    final page = await ArtifactDashboardApi(client).read(
      const ArtifactDashboardQuery(
        conversation: 'channel/1',
        author: 'agent:1',
        search: 'Road map',
        sort: ArtifactDashboardSort.updated,
        relevant: true,
      ),
      cursor: 'next/page',
    );
    expect(page.rows.single.card.title, 'Road map');
    expect(page.rows.single.openedAt, DateTime.utc(2026, 11, 19));
    expect(page.rows.single.news, (
      mentioned: true,
      updated: true,
      comments: 3,
    ));
    expect(page.counts?.total, 12);
    expect(page.counts?.filtered, 2);
    expect(page.nextCursor, 'third');
  });
}
