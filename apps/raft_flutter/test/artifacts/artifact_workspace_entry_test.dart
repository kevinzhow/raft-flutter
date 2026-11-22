import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/artifacts/artifact_dashboard.dart';
import 'package:raft_flutter/features/artifacts/artifact_open_in_browser.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:raft_ui/raft_ui.dart';

import '../app_global_server_selector_test.dart' show RootFixture;
import '../support/artifact_fake_client.dart';
import '../support/server_tab.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('Artifacts entry stays hidden with the flag off at $width', (
      tester,
    ) async {
      final fixture = RootFixture();
      fixture.overrides['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'workspace_artifacts_v0', 'enabled': false},
        ],
      };
      await fixture.mount(tester, 'light', width, uri: Uri.parse('/s/alpha'));
      await fixture.flush(tester);
      if (width == 390) {
        await openServerPopover(tester, flush: fixture.flush);
        expect(
          find.descendant(
            of: find.byKey(serverPopoverKey),
            matching: find.text('Artifacts'),
          ),
          findsNothing,
        );
      } else {
        expect(find.byKey(const Key('rail-artifacts')), findsNothing);
      }
      await fixture.close(tester);
    });
  }

  testWidgets(
    'Linux Artifacts opens a Markdown document from the desktop rail',
    (tester) async {
      final fixture = RootFixture();
      fixture.overrides['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'workspace_artifacts_v0', 'enabled': true},
        ],
      };
      final card = artifactCardJson(
        title: 'Workspace roadmap',
        kind: 'markdown',
      );
      const filePath = '/artifacts/$artifactId/files/roadmap.md?version=1';
      fixture.overrides['GET /artifacts/dashboard/all?sort=opened'] = (_) => {
        'counts': {'total': 116, 'filtered': 116, 'relevant': 0},
        'rows': [
          {'card': card},
        ],
      };
      fixture.overrides['GET /artifacts/$artifactId'] = (_) =>
          artifactViewerJson(
            card: card,
            frame: false,
            files: [
              {'path': 'roadmap.md', 'kind': 'markdown', 'entry': true},
            ],
          );
      fixture.overrides['GET $filePath'] = (_) => ResponseBody.fromString(
        '# Launch plan\n\nReview the release.',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/markdown; charset=utf-8'],
        },
      );
      await fixture.mount(tester, 'light', 1280, uri: Uri.parse('/s/alpha'));
      await tester.tap(find.byKey(const Key('rail-artifacts')));
      await fixture.flush(tester);
      await tester.pumpAndSettle();
      expect(find.text('Artifacts'), findsOneWidget);
      expect(find.text('116 Artifacts'), findsOneWidget);
      expect(find.byKey(const Key('artifact-grid')), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('artifact-dashboard-open-$artifactId')),
      );
      await fixture.flush(tester);
      await tester.pumpAndSettle();
      expect(find.byType(ArtifactWorkspaceViewer), findsOneWidget);
      expect(
        find.byKey(const Key('rail-artifacts')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byKey(const Key('artifact-viewer-markdown')), findsOneWidget);
      expect(find.text('Launch plan', findRichText: true), findsOneWidget);
      expect(
        find.text('Review the release.', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(ArtifactOpenInBrowser), findsNothing);
      expect(
        fixture.adapter.calls.where(
          (call) => call.method == 'GET' && call.path == filePath,
        ),
        hasLength(1),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await fixture.flush(tester);
      await tester.pumpAndSettle();
      expect(find.byType(ArtifactWorkspaceViewer), findsNothing);
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('artifact-table')), findsOneWidget);
      expect(find.text('Workspace roadmap'), findsOneWidget);
      await tester.tap(find.byKey(const Key('rail-chat')));
      await tester.pumpAndSettle();
      expect(find.byType(ArtifactDashboard), findsNothing);
      await fixture.close(tester);
    },
  );

  testWidgets('Artifacts returns to the originating tab and restores focus', (
    tester,
  ) async {
    final fixture = RootFixture();
    fixture.overrides['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'workspace_artifacts_v0', 'enabled': true},
      ],
    };
    fixture.overrides['GET /artifacts/dashboard/all?sort=opened'] = (_) => {
      'counts': {'total': 116, 'filtered': 116, 'relevant': 0},
      'rows': [
        {'card': artifactCardJson(title: 'Workspace roadmap')},
      ],
    };
    await fixture.mount(tester, 'light', 390, uri: Uri.parse('/s/alpha/tasks'));
    final workspace = fixture.workspace(tester);
    final serverTab = find.byKey(serverTabKey);
    final focus = tester.widget<RaftMobileNavServerTab>(serverTab).focusNode!;
    await openServerPopover(tester, flush: fixture.flush);
    final destination = find.byKey(serverPageKey('artifacts'));
    expect(destination.hitTestable(), findsOneWidget);
    await tester.tap(destination);
    await fixture.flush(tester);
    await tester.pumpAndSettle();
    expect(find.text('Artifacts'), findsOneWidget);
    expect(find.text('116 Artifacts'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byType(ArtifactDashboard), findsOneWidget);
    expect(find.byKey(const Key('artifact-grid')), findsOneWidget);
    expect(find.text('Workspace roadmap'), findsOneWidget);
    expect(find.byKey(serverPopoverKey), findsNothing);
    expect(serverTab, findsNothing);
    expect(workspace.location.route, RaftRoute.artifacts);
    await tester.tap(
      find.descendant(
        of: find.byType(ArtifactDashboard),
        matching: find.byTooltip('Back'),
      ),
    );
    await fixture.flush(tester);
    await tester.pumpAndSettle();
    expect(find.byType(ArtifactDashboard), findsNothing);
    expect(workspace.location.route, RaftRoute.tasks);
    expect(serverTab, findsOneWidget);
    expect(focus.hasFocus, isTrue);
    await openServerPopover(tester, flush: fixture.flush);
    for (final page in ['artifacts', 'members', 'computers', 'settings']) {
      expect(find.byKey(serverPageKey(page)).hitTestable(), findsOneWidget);
    }
    expect(
      fixture.adapter.calls
          .where((call) => call.path.startsWith('/artifacts/'))
          .map((call) => call.method),
      everyElement('GET'),
    );
    await fixture.close(tester);
  });

  testWidgets('an unresolved flag hides Artifacts until a guest is allowed', (
    tester,
  ) async {
    final fixture = RootFixture();
    fixture.servers[0] = {...fixture.servers[0], 'role': 'guest'};
    final flag = Completer<Object>();
    fixture.holds['POST /feature-flags/evaluate'] = flag;
    await fixture.mount(tester, 'light', 390, uri: Uri.parse('/s/alpha'));
    await openServerPopover(tester, flush: fixture.flush);
    final artifacts = find.byKey(serverPageKey('artifacts'));
    expect(artifacts, findsNothing);
    expect(find.byKey(serverPageKey('settings')), findsOneWidget);
    flag.complete({
      'evaluations': [
        {'key': 'workspace_artifacts_v0', 'enabled': true},
      ],
    });
    await fixture.flush(tester);
    await tester.pumpAndSettle();
    expect(artifacts.hitTestable(), findsOneWidget);
    for (final page in ['members', 'computers', 'apps']) {
      expect(find.byKey(serverPageKey(page)), findsNothing, reason: page);
    }
    await fixture.close(tester);
  });

  testWidgets('an evaluation denied by the server keeps Artifacts absent', (
    tester,
  ) async {
    final fixture = RootFixture();
    const evaluate = 'POST /feature-flags/evaluate';
    fixture.overrides[evaluate] = (_) => {'error': 'Forbidden'};
    fixture.adapter.statuses[evaluate] = 403;
    await fixture.mount(tester, 'light', 390, uri: Uri.parse('/s/alpha'));
    await openServerPopover(tester, flush: fixture.flush);
    expect(find.byKey(serverPageKey('artifacts')), findsNothing);
    for (final page in ['members', 'computers', 'settings']) {
      expect(find.byKey(serverPageKey(page)).hitTestable(), findsOneWidget);
    }
    expect(
      fixture.adapter.calls.where(
        (call) => call.path.startsWith('/artifacts/'),
      ),
      isEmpty,
    );
    await fixture.close(tester);
  });
}
