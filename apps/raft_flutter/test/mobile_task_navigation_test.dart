import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/features/mobile_workspace_pages.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/features/workspace_task_host.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'task_surface_test.dart' show modernTask, taskRoutes, flush;
import 'workspace_source_location_contract_test.dart' show pageFixture;
import 'support/app_services_fixture.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final section in ['tasks', 'chat']) {
      for (final legacy in [false, true]) {
        testWidgets(
          'Repeated $section ${legacy ? 'legacy' : 'modern'} task open/close/system Back retains its page ${dark ? 'dark' : 'light'}',
          (t) async {
            t.view.physicalSize = const Size(390, 844);
            t.view.devicePixelRatio = 1;
            addTearDown(t.view.reset);
            final (w, api) = await pageFixture(t, section: section);
            final task = {...modernTask, if (legacy) 'isLegacy': true};
            taskRoutes(api, task);
            api.routes['GET /tasks/channel/c1'] = (_) => {
              'tasks': [task],
            };
            if (section == 'chat') {
              w.navigation.navigate(
                w.location.withQuery({'chatTab': 'tasks'}),
                kind: RaftNavigationKind.replace,
              );
            }
            await t.pumpWidget(
              MaterialApp(
                theme: raftTheme(dark: dark),
                home: withAppServices(
                  WorkspaceView(
                    controller: w,
                    appearance: RaftAppearance(),
                    onAppearance: (_) async {},
                    onLogout: () async {},
                  ),
                ),
              ),
            );
            await flush(t);
            final base = w.location;
            final pages = mobilePageEntries(w.navigation);
            final hostState = t.state(find.byType(WorkspaceTaskHost));
            final listState = t.state(find.byType(ResourceView));
            for (var cycle = 0; cycle < 6; cycle++) {
              await t.tap(find.text('Scoped actual task'));
              await flush(t);
              await t.pumpAndSettle();
              expect(find.byType(SourceTaskSurface), findsOneWidget);
              expect(
                mobilePageEntries(w.navigation),
                hasLength(pages.length + 1),
              );
              // Web's phone TaskModalBar (`px-4 py-2`; legacy: the 62/56px
              // panel header), not the shared 56px page header.
              expect(find.byType(RaftMobilePageHeader), findsNothing);
              expect(
                t.getSize(find.byKey(const ValueKey('task-modal-bar'))).height,
                legacy ? (56) : (53),
              );
              final owner = t
                  .widget<SourceTaskSurface>(find.byType(SourceTaskSurface))
                  .owner;
              if (cycle.isEven) {
                await t.tap(find.byTooltip('Close Task'));
              } else {
                await t.binding.handlePopRoute();
              }
              await flush(t);
              await t.pumpAndSettle();
              expect(w.location.uri, base.uri);
              expect(find.byType(SourceTaskSurface), findsNothing);
              expect(find.text('Scoped actual task'), findsOneWidget);
              expect(owner.closed, isTrue);
              expect(t.state(find.byType(WorkspaceTaskHost)), same(hostState));
              expect(t.state(find.byType(ResourceView)), same(listState));
              expect(mobilePageEntries(w.navigation), pages);
              expect(t.takeException(), isNull);
            }
            await t.pumpWidget(const SizedBox.shrink());
            await t.pump(const Duration(milliseconds: 300));
          },
        );
      }
    }
  }
}
