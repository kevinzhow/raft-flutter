import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/computers_rack/computers_rack_page.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

Map<String, dynamic> computer(String id, {bool lowDisk = false}) => {
  'id': id,
  'name': 'Computer $id',
  'isComputer': true,
  'status': lowDisk ? 'online' : 'offline',
  'computerVersion': '1.0.45',
  'userId': 'alice',
  'computerAttachedByCurrentUser': true,
  'runtimes': ['codex'],
  if (lowDisk)
    'diskStatus': {
      'availableBytes': 1024 * 1024 * 1024,
      'totalBytes': 100 * 1024 * 1024 * 1024,
    },
};

RootFixture fixture(List<Map<String, dynamic>> machines) => RootFixture()
  ..overrides['GET /announcements/active'] = ((_) => {'announcements': []})
  ..overrides['GET /servers/a/machines'] = (_) => {
    'machines': machines,
    'latestComputerVersion': '1.0.45',
  };

Future<void> view(WidgetTester t, RootFixture f, String title) async {
  await t.tap(find.byType(RaftMobileNotificationButton));
  await f.flush(t);
  expect(find.text(title), findsOneWidget);
  final action = find.text('View').hitTestable();
  expect(action, findsOneWidget);
  await t.tap(action);
  await f.flush(t);
  await t.pumpAndSettle();
  expect(find.byType(RaftNotificationCenter), findsNothing);
}

ModalRoute<Object?>? routeOf(WidgetTester t, Finder finder) =>
    ModalRoute.of(t.element(finder));

final computerDetail = find.byWidgetPredicate(
  (widget) => widget is FleetDetail && widget.computers,
);

/// Web useSystemNotifications `nav.toComputer` / `nav.toComputers` move the
/// main area (computerPanel.ts: beside the card wall from 768 px, its own page
/// with Back below); no entry covers the window with a page of its own.
void main() {
  testWidgets('wide: a Computer entry opens the Computer beside the rack', (
    t,
  ) async {
    final f = fixture([computer('m1', lowDisk: true)]);
    await f.mount(t, 'light', 1280, uri: Uri.parse('/s/alpha'));
    final workspaceRoute = routeOf(t, find.byType(WorkspaceView));
    final w = f.workspace(t);
    await view(t, f, 'A computer you added is low on disk space');
    // Web computerPath at 768 px and up: the panel beside the card wall.
    expect(w.location.route, RaftRoute.computers);
    expect(w.location.query('profile'), 'computer:m1');
    expect(computerDetail, findsOneWidget);
    expect(
      routeOf(t, computerDetail),
      same(workspaceRoute),
      reason: 'the Computer opens in the workspace, not on a pushed page',
    );
    expect(
      find.descendant(
        of: find.byType(ComputersRackDesktopPage),
        matching: computerDetail,
      ),
      findsOneWidget,
    );
    expect(find.byType(RaftMobileNotificationButton), findsOneWidget);
    await f.close(t);
  });

  testWidgets('phone: a Computer entry opens its page with Back', (t) async {
    final f = fixture([computer('m1', lowDisk: true)])
      ..overrides['GET /agents'] = (_) => [
        {
          'id': 'a1',
          'name': 'sensor',
          'displayName': 'Sensor Agent',
          'status': 'active',
          'runtime': 'claude',
          'model': 'sonnet',
          'machineId': 'm1',
        },
      ];
    await f.mount(t, 'light', 390, uri: Uri.parse('/s/alpha'));
    final w = f.workspace(t);
    await view(t, f, 'A computer you added is low on disk space');
    expect(w.location.toString(), '/s/alpha/computer/m1');
    expect(find.byKey(const Key('computer-mobile-back')), findsOneWidget);
    final agent = find.descendant(
      of: computerDetail,
      matching: find.text('Sensor Agent'),
    );
    await t.ensureVisible(agent);
    await t.tap(agent.hitTestable());
    await f.flush(t);
    await t.pumpAndSettle();
    expect(w.location.route, RaftRoute.agent);
    expect(await t.binding.handlePopRoute(), isTrue);
    await f.flush(t);
    await t.pumpAndSettle();
    expect(w.location.toString(), '/s/alpha/computer/m1');
    expect(find.byKey(const Key('computer-mobile-back')), findsOneWidget);
    expect(await t.binding.handlePopRoute(), isTrue);
    await f.flush(t);
    await t.pumpAndSettle();
    expect(w.location.toString(), '/s/alpha');
    expect(find.byType(RaftMobileNotificationButton), findsOneWidget);
    await f.close(t);
  });

  testWidgets('phone: Computers need attention opens the filtered list', (
    t,
  ) async {
    final f = fixture([computer('m1'), computer('m2')]);
    await f.mount(t, 'light', 390, uri: Uri.parse('/s/alpha'));
    final w = f.workspace(t);
    await view(t, f, 'Computers need attention');
    expect(w.location.route, RaftRoute.computers);
    expect(w.location.query('filter'), 'attention');
    expect(await t.binding.handlePopRoute(), isTrue);
    await f.flush(t);
    await t.pumpAndSettle();
    expect(w.location.toString(), '/s/alpha');
    await f.close(t);
  });
}
