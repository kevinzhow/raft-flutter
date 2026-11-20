import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/desktop_drafts_page.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'parity/cases/thread_composer/fake_workspace.dart';
import 'support/app_services_fixture.dart';
import 'support/close_registry_drafts.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';
import 'workspace_source_location_contract_test.dart'
    show mountPage, pageFixture;

void main() {
  for (final (width, platform) in const [
    (390.0, TargetPlatform.android),
    (1280.0, TargetPlatform.linux),
  ]) {
    testWidgets(
      'Home opens the private draft with the mounted header at $width',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final channel = RaftChannel({
          'id': 'c1',
          'serverId': 'visual-server',
          'name': 'release-review',
          'type': 'private',
          'joined': true,
        });
        final api = ParityFakeClient(
          user: {'id': 'alice'},
          routes: {
            'POST /feature-flags/evaluate': {
              'evaluations': [
                {'key': 'drafts_section_v0', 'enabled': true},
              ],
            },
            'GET /channels/c1': channel.json,
          },
        );
        final workspace = WorkspaceController(api)
          ..server = RaftRecord({
            'id': 'visual-server',
            'slug': 'visual',
            'role': 'owner',
          })
          ..channels = [channel]
          ..section = 'home';
        addTearDown(workspace.dispose);
        workspace.drafts[channel.id] = 'Check the composer before the release.';
        try {
          await mountPage(
            tester,
            workspace,
            false,
            width: width,
            height: 844,
            platform: platform,
          );
          await frames(tester, 20);
          expect(
            workspace.drafts[channel.id],
            'Check the composer before the release.',
          );
          final entry = find.byKey(const Key('nav-drafts'));
          await tapAndSettle(tester, entry);
          final page = find.byType(DraftsPage);
          expect(page, findsOneWidget);
          final shown = tester.widget<DraftsPage>(page).controller;
          expect(
            shown.drafts[channel.id],
            'Check the composer before the release.',
          );
          expect(shown.channelById(channel.id)?.type, 'private');
          expect(shown.can('viewChannel', resource: channel), isTrue);
          await frames(tester, 10);
          final header = find.descendant(
            of: page,
            matching: find.byType(RaftPanelHeaderBar),
          );
          expect(tester.widget<RaftPanelHeaderBar>(header).subtitle, '1 draft');
          final row = find.byKey(const Key('draft-c1'));
          expect(row, findsOneWidget);
          expect(
            find.descendant(
              of: row,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is RaftIcon && widget.glyph == RaftGlyph.lock,
              ),
            ),
            findsOneWidget,
          );
          expect(tester.widget<RaftPanelHeaderBar>(header).inlineMeta, isFalse);
          if (platform == TargetPlatform.linux) {
            final nav = tester.widget<RaftNavItem>(entry);
            expect(nav.selected, isTrue);
            expect(nav.count, 1);
          }
          await tapAndSettle(tester, row);
          expect(find.byType(DraftsPage), findsNothing);
          final editor = tester.widget<EditableText>(
            find.byType(EditableText).last,
          );
          expect(
            editor.controller.text,
            'Check the composer before the release.',
          );
          expect(
            api.requests.where((request) => request == 'POST /v2/messages'),
            isEmpty,
          );
          if (platform == TargetPlatform.linux) {
            await tester.enterText(find.byType(EditableText).last, '');
            await frames(tester, 10);
            expect(tester.widget<RaftNavItem>(entry).count, 0);
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      },
    );
  }

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
