import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_dashboard.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';
import 'home_tasks/fixture_workspace.dart';
import 'screens/screen_fixture.dart';

class _ArtifactFixtureClient extends ScreenFixtureClient {
  _ArtifactFixtureClient(super.route, {super.user, super.server, super.origin});

  @override
  bool get signedIn => true;

  @override
  Future<Uint8List> getBytes(String path) async {
    final answer = await get('${path.split('?').first}/content') as Map;
    return Uint8List.fromList(utf8.encode(answer['content'] as String));
  }
}

Widget _artifactsCollection(ParityContext ctx) {
  final wire = ScreenWire(ctx.fixtureData);
  final fixture = ctx.fixtures['ext:artifacts'] as Map;
  final routes = fixture['routes'] as Map;
  final server = RaftRecord(wire.server());
  final client = _ArtifactFixtureClient(
    (method, path, query) =>
        routes['$method ${path.split('?').first}'] ??
        wire.common(method, path, query),
    user: wire.me(),
    server: server.id,
    origin: 'https://api.raft.build',
  );
  final workspace = WorkspaceController(client)..server = server;
  ctx.onDispose(() {
    workspace.dispose();
    client.dispose();
  });
  final phone = ctx.props['platform'] == 'mobile';
  return Scaffold(
    body: Builder(
      builder: (context) => ColoredBox(
        color: RaftTokens.of(context).ui.layerCanvas,
        child: Padding(
          padding: phone
              ? EdgeInsets.zero
              : const EdgeInsets.only(left: 49, top: 44),
          child: ArtifactDashboard(
            workspace: workspace,
            clock: () => parityNow(ctx),
            onBack: phone ? () => Navigator.maybePop(context) : null,
          ),
        ),
      ),
    ),
  );
}

Future<void> _verifyArtifactState(
  WidgetTester tester,
  ParityContext ctx,
) async {
  await tester.pump(const Duration(milliseconds: 450));
  final state = ctx.props['extCase'] as String;
  final ready = switch (state) {
    'grid' => find.byKey(const Key('artifact-grid')),
    'table' => find.byKey(const Key('artifact-table')),
    'list' => find.byKey(const Key('artifact-list')),
    'picker-conv' ||
    'picker-author' => find.byKey(const Key('artifact-dashboard-filter')),
    'viewer' => find.byKey(const Key('artifact-viewer-text')),
    'viewer-menu' => find.byKey(const Key('artifact-viewer-menu-surface')),
    'visibility' => find.text('Anyone with the link'),
    'visibility-confirm' => find.text('Turn on link sharing?'),
    'rename' => find.byKey(const Key('artifact-manage-dialog')),
    'display-report' => find.byKey(const Key('artifact-comment-input')),
    'delete-confirm' => find.byKey(const Key('artifact-delete-dialog')),
    _ => throw StateError('No capture target for Artifacts state $state'),
  };
  expect(ready.hitTestable(), findsOneWidget);
  if (state == 'display-report') {
    final field = tester.widget<EditableText>(
      find.descendant(of: ready, matching: find.byType(EditableText)),
    );
    expect(
      field.controller.text,
      startsWith("Display report from Raft's viewer:"),
    );
  }
  if (state == 'delete-confirm') {
    expect(find.text('Delete this Artifact?'), findsOneWidget);
  }
}

const _artifactStates = {
  'desktop': [
    'grid',
    'table',
    'picker-conv',
    'picker-author',
    'viewer',
    'viewer-menu',
    'visibility',
    'visibility-confirm',
    'rename',
    'display-report',
    'delete-confirm',
  ],
  'phone': [
    'grid',
    'list',
    'picker-conv',
    'viewer',
    'rename',
    'display-report',
    'delete-confirm',
  ],
};

final Map<String, ParityCase> extArtifactCollectionCases = {
  for (final platform in _artifactStates.keys)
    for (final state in _artifactStates[platform]!)
      for (final suffix in ['brutal', 'elegant-dark'])
        'components.artifacts.$platform.$state.$suffix': const ParityCase(
          widgets: ['ArtifactDashboard', 'ArtifactWorkspaceViewer'],
          build: _artifactsCollection,
          interact: _verifyArtifactState,
          settle: Duration(milliseconds: 500),
        ),
};
