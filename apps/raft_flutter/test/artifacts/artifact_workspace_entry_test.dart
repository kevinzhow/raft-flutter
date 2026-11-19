import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/artifacts/artifact_dashboard.dart';

import '../app_global_server_selector_test.dart' show RootFixture;
import '../support/server_tab.dart';
import '../support/artifact_fake_client.dart';

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

  testWidgets('Artifacts opens from the desktop rail and switches layouts', (
    tester,
  ) async {
    final fixture = RootFixture();
    fixture.overrides['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'workspace_artifacts_v0', 'enabled': true},
      ],
    };
    fixture.overrides['GET /artifacts/dashboard/all?sort=opened'] = (_) => {
      'rows': [
        {'card': artifactCardJson(title: 'Workspace roadmap')},
      ],
    };
    await fixture.mount(tester, 'light', 1280, uri: Uri.parse('/s/alpha'));
    await tester.tap(find.byKey(const Key('rail-artifacts')));
    await fixture.flush(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('artifact-grid')), findsOneWidget);
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('artifact-table')), findsOneWidget);
    expect(find.text('Workspace roadmap'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rail-chat')));
    await tester.pumpAndSettle();
    expect(find.byType(ArtifactDashboard), findsNothing);
    await fixture.close(tester);
  });

  testWidgets('Artifacts opens from the phone server tab and returns home', (
    tester,
  ) async {
    final fixture = RootFixture();
    fixture.overrides['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'workspace_artifacts_v0', 'enabled': true},
      ],
    };
    fixture.overrides['GET /artifacts/dashboard/all?sort=opened'] = (_) => {
      'rows': [
        {'card': artifactCardJson(title: 'Workspace roadmap')},
      ],
    };
    await fixture.mount(tester, 'light', 390, uri: Uri.parse('/s/alpha'));
    await openServerPopover(tester, flush: fixture.flush);
    final destination = find.descendant(
      of: find.byKey(serverPopoverKey),
      matching: find.text('Artifacts'),
    );
    expect(destination, findsOneWidget);
    await tester.tap(destination);
    await fixture.flush(tester);
    await tester.pumpAndSettle();
    expect(find.byType(ArtifactDashboard), findsOneWidget);
    expect(find.byKey(const Key('artifact-list')), findsOneWidget);
    expect(find.text('Workspace roadmap'), findsOneWidget);
    expect(find.byKey(serverPopoverKey), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(ArtifactDashboard),
        matching: find.byTooltip('Back'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ArtifactDashboard), findsNothing);
    await fixture.close(tester);
  });
}
