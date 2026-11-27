// An Artifact opened from an Activity row or a Search hit (task #380), in the
// real WorkspaceView: beside the list on wide windows, a page over it on a
// phone. Ids and data: tool/parity-ext/build-list-artifact.py,
// fixtures/list-artifact.json (fixtures['ext:list-artifact']); the React side
// is tool/parity-ext/host/ListArtifactCases.tsx.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/app_services_fixture.dart';
import '../parity_harness.dart';
import 'screens/screen_fixture.dart';

const _serverId = 'visual-server';

class _Client extends ScreenFixtureClient {
  _Client(super.route, {super.user, super.server});

  @override
  bool get signedIn => true;

  /// A file's bytes: the text its content route answers (the Web reads that).
  @override
  Future<Uint8List> getBytes(String path) async {
    final answer = await get('${path.split('?').first}/content') as Map;
    return Uint8List.fromList(utf8.encode(answer['content'] as String));
  }
}

class _Shell extends StatefulWidget {
  const _Shell({required this.ctx});
  final ParityContext ctx;
  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  late final WorkspaceController w = _workspace(widget.ctx);

  static WorkspaceController _workspace(ParityContext ctx) {
    SharedPreferences.setMockInitialValues({});
    // The React provider pins its clock to the fixture instant.
    final now = DateTime.fromMillisecondsSinceEpoch(
      (ctx.fixtureData['locale']['nowEpochMillis'] as num).toInt(),
    );
    sourceTimeNow = () => now;
    addTearDown(() => sourceTimeNow = DateTime.now);
    final routes = (ctx.fixtures['ext:list-artifact'] as Map)['routes'] as Map;
    final wire = ScreenWire(ctx.fixtureData);
    final client = _Client(
      (method, path, query) =>
          routes['$method ${path.split('?').first}'] ??
          wire.common(method, path, query),
      user: wire.me(),
      server: _serverId,
    );
    final channel = (ctx.fixtureData['channels'] as Map)['design'] as Map;
    // Search's Free-plan notice reads the wall clock (ResourceView without a
    // clock), past the Free trial the Web's pinned instant is still in: a Pro
    // record shows neither side's notice, as the Web does at that instant.
    final server = RaftRecord({...wire.server(), 'plan': 'pro'});
    final w = WorkspaceController(
      client,
      mobileNavigation: ctx.props['platform'] == 'mobile',
    );
    w
      ..servers = [server]
      ..server = server
      ..channels = [
        RaftChannel({
          'id': channel['id'],
          'serverId': _serverId,
          'name': channel['name'],
          'description': channel['description'],
          'type': 'channel',
          'joined': true,
          'createdAt': channel['createdAtIso'],
        }),
      ];
    w.messageDomain.ledger.switchServer(_serverId);
    final search = ctx.props['source'] == 'search';
    w.navigation.navigate(
      RaftLocation.at(
        serverSlug: w.location.serverSlug,
        route: search ? RaftRoute.search : RaftRoute.activity,
        query: search ? const {'q': 'plan'} : const {},
      ),
      kind: RaftNavigationKind.replace,
    );
    return w;
  }

  @override
  void dispose() {
    w.dispose();
    super.dispose();
  }

  @override
  // The Web reference is the browser app: the browser host (no native
  // title-bar history controls), as ext_shell.dart's browser cases.
  Widget build(BuildContext context) => withAppServices(
    WorkspaceHostScope(
      browser: true,
      child: WorkspaceView(
        controller: w,
        appearance: RaftAppearance(
          mode: widget.ctx.dark ? ThemeMode.dark : ThemeMode.light,
        ),
        onAppearance: (_) async {},
        onLogout: () async {},
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester, ParityContext ctx) async {
  for (var frame = 0; frame < 30; frame++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  final row = find.byKey(ValueKey(ctx.props['openKey'] as String));
  expect(row.hitTestable(), findsOneWidget);
  await tester.tap(row.hitTestable());
  for (var frame = 0; frame < 30; frame++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  await tester.pumpAndSettle();
  final viewer = find.byType(ArtifactWorkspaceViewer);
  expect(viewer.hitTestable(), findsOneWidget);
  final phone = ctx.props['platform'] == 'mobile';
  if (phone) {
    expect(row.hitTestable(), findsNothing, reason: 'a page over the list');
  } else {
    expect(row.hitTestable(), findsOneWidget, reason: 'the list stays');
    final list = tester.getRect(row), detail = tester.getRect(viewer);
    expect(detail.left, greaterThanOrEqualTo(list.right - 1));
    ctx.captureEvidence['listRect'] = [list.left, list.right];
    ctx.captureEvidence['viewerRect'] = [detail.left, detail.right];
  }
}

final Map<String, ParityCase> extListArtifactCases = {
  for (final (size, sources) in const [
    ('desktop', ['activity', 'search']),
    ('phone', ['activity', 'search']),
    ('fold-841x701', ['activity']),
    ('fold-884x1104', ['activity']),
    ('tablet-1180x820', ['activity']),
  ])
    for (final source in sources)
      for (final theme in const ['brutal', 'elegant-dark'])
        'components.pages.list-artifact.$size.$source.$theme': ParityCase(
          widgets: const [
            'raft_flutter:WorkspaceView',
            'raft_flutter:ArtifactContentSlot',
            'raft_flutter:ArtifactWorkspaceViewer',
          ],
          notes: 'An Artifact opened from its list (list_detail_slot.dart).',
          build: (ctx) => ctx.target(_Shell(ctx: ctx)),
          interact: _open,
          settle: const Duration(milliseconds: 500),
        ),
};
