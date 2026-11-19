import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/desktop_drafts_page.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/app_services_fixture.dart';
import 'support/close_registry_drafts.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';
import 'workspace_source_location_contract_test.dart' show pageFixture;

void main() {
  registerCloseTests(draftsSurfaces, {
    'drafts-page': (tester, size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (workspace, api) = await pageFixture(tester, section: 'home');
      api.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'drafts_section_v0', 'enabled': true},
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: TargetPlatform.android),
          home: withAppServices(
            WorkspaceView(
              controller: workspace,
              appearance: RaftAppearance(),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        ),
      );
      await frames(tester, 20);
      await tapAndSettle(tester, find.byKey(const Key('nav-drafts')));
      final page = find.byType(DraftsPage);
      expect(find.byTooltip('Back'), findsOneWidget);
      return SurfaceProbe(
        isOpen: () => page.evaluate().isNotEmpty,
        back: find.descendant(of: page, matching: find.byTooltip('Back')),
      );
    },
  });
}
