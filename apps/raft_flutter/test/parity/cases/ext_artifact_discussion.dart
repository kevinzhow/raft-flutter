import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/artifacts/artifact_session.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';
import 'screens/screen_fixture.dart';

class _DiscussionClient extends ScreenFixtureClient {
  _DiscussionClient(super.route, {super.user, super.server})
    : super(origin: 'https://api.raft.build');

  @override
  bool get signedIn => true;

  @override
  Future<Uint8List> getBytes(String path) async {
    final response = await get('${Uri.parse(path).path}/content') as Map;
    return Uint8List.fromList(utf8.encode(response['content'] as String));
  }
}

Widget _discussionViewer(ParityContext ctx) {
  final wire = ScreenWire(ctx.fixtureData);
  final fixture = ctx.fixtures['ext:artifact-discussion'] as Map;
  final routes = fixture['routes'] as Map;
  final server = RaftRecord(wire.server());
  final id = fixture['artifactId'] as String;
  final viewer = (routes['GET /artifacts/$id'] as Map)['viewer'] as Map;
  final client = _DiscussionClient(
    (method, path, query) =>
        routes['$method ${Uri.parse(path).path}'] ??
        wire.common(method, path, query),
    user: Map<String, dynamic>.from(viewer),
    server: server.id,
  );
  final workspace = WorkspaceController(client)..server = server;
  ctx.onDispose(() {
    workspace.dispose();
    client.dispose();
  });
  return Scaffold(
    body: ArtifactWorkspaceViewer(
      session: ArtifactSession.of(workspace),
      target: ArtifactLinkTarget(id),
      page: ctx.props['platform'] == 'mobile',
      inCollection: true,
      onClose: () {},
      operatingSystem: 'linux',
      commentClock: () => DateTime.parse(fixture['clockIso'] as String),
    ),
  );
}

Future<void> _openDiscussion(WidgetTester tester, ParityContext ctx) async {
  final content = find.byKey(const ValueKey('artifact-viewer-text'));
  final trigger = find.byKey(const ValueKey('artifact-comments-trigger'));
  final panel = find.byKey(const ValueKey('artifact-comments-panel'));
  final close = find.byKey(const ValueKey('artifact-comments-close'));
  final state = ctx.props['extCase'];
  await tester.pumpAndSettle();
  expect(content.hitTestable(), findsOneWidget);
  if (ctx.props['platform'] == 'mobile') {
    final more = find.byKey(const ValueKey('artifact-viewer-menu-trigger'));
    expect(more.hitTestable(), findsOneWidget);
    await tester.tap(more);
    await tester.pumpAndSettle();
    final entry = find.text('Comments (4)').hitTestable();
    expect(entry, findsOneWidget);
    if (state == 'menu') {
      expect(panel, findsNothing);
      return;
    }
    await tester.tap(entry);
  } else {
    expect(trigger.hitTestable(), findsOneWidget);
    await tester.tap(trigger);
  }
  await tester.pumpAndSettle();
  expect(panel.hitTestable(), findsOneWidget);
  final rootBody = find.textContaining('Plain @reviewowner.');
  expect(rootBody, findsOneWidget);
  expect(find.textContaining('Private note for'), findsOneWidget);
  if (state == 'resolved') {
    final resolved = find.text('Resolved (1)');
    if (resolved.hitTestable().evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        resolved,
        120,
        scrollable: find
            .descendant(of: panel, matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();
    }
    expect(resolved.hitTestable(), findsOneWidget);
    await tester.tap(resolved);
    await tester.pumpAndSettle();
    final disclosure = find.ancestor(
      of: resolved,
      matching: find.byType(RaftButton),
    );
    expect(tester.widget<RaftButton>(disclosure).glyph, RaftGlyph.chevronDown);
  } else if (state == 'closed') {
    expect(close.hitTestable(), findsOneWidget);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(content.hitTestable(), findsOneWidget);
  } else {
    expect(rootBody.hitTestable(), findsOneWidget);
    await tester.tap(rootBody);
    await tester.pumpAndSettle();
  }
}

final Map<String, ParityCase> extArtifactDiscussionCases = {
  for (final platform in ['desktop', 'phone'])
    for (final state in [
      'comments',
      'resolved',
      'closed',
      if (platform == 'phone') 'menu',
    ])
      for (final theme in ['light', 'dark'])
        'components.artifact-discussion.$platform.$state.$theme':
            const ParityCase(
              widgets: ['ArtifactWorkspaceViewer', 'ArtifactCommentsPanel'],
              build: _discussionViewer,
              interact: _openDiscussion,
            ),
};
