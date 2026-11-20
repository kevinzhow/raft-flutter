import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../support/app_services_fixture.dart';
import '../parity_harness.dart';
import 'screens/screen_fixture.dart';

Map<String, dynamic> _fixture(ParityContext ctx) =>
    ctx.fixtures['ext:drafts-v124'] as Map<String, dynamic>;

final Map<String, ParityCase> extDraftsCases = {
  for (final platform in ['desktop', 'phone'])
    for (final state in ['empty', 'private'])
      for (final theme in ['brutal', 'elegant-dark'])
        'components.pages.drafts-v124.$platform.$state.$theme': ParityCase(
          widgets: const [
            'raft_flutter:WorkspaceView',
            'raft_flutter:DraftsPage',
          ],
          build: (ctx) {
            final fixture = _fixture(ctx);
            final wire = ScreenWire(ctx.fixtureData);
            final routes = fixture['routes'] as Map<String, dynamic>;
            final channel = RaftChannel(
              (routes['GET /channels'] as List).single as Map<String, dynamic>,
            );
            final client = ScreenFixtureClient(
              (method, path, query) =>
                  routes['$method $path'] ?? wire.common(method, path, query),
              user: wire.me(),
              server: channel.string('serverId'),
            );
            final workspace = WorkspaceController(client)
              ..server = RaftRecord(wire.server())
              ..channels = [channel]
              ..section = 'drafts';
            if (state == 'private') {
              workspace.drafts[channel.id] = fixture['draft'] as String;
            }
            ctx.onDispose(workspace.dispose);
            return ctx.target(
              withAppServices(
                WorkspaceView(
                  controller: workspace,
                  appearance: RaftAppearance(),
                  onAppearance: (_) async {},
                  onLogout: () async {},
                ),
              ),
            );
          },
          interact: (tester, ctx) async {
            for (var frame = 0; frame < 12; frame++) {
              await tester.pump(const Duration(milliseconds: 40));
            }
            if (state == 'empty') {
              expect(find.text('No drafts'), findsOneWidget);
            } else {
              expect(
                find.text(_fixture(ctx)['draft'] as String),
                findsOneWidget,
              );
            }
          },
        ),
};
