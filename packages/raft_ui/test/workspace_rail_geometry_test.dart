import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final height in [800.0, 560.0]) {
      for (final onRight in [false, true]) {
        for (final density in RaftDensity.values) {
          for (final bounded in [false, true]) {
            testWidgets(
              '${dark ? 'dark' : 'light'} $height right=$onRight $density bounded=$bounded navigation keeps rail geometry',
              (tester) async {
                tester.view.physicalSize = Size(1100, height);
                tester.view.devicePixelRatio = 1;
                addTearDown(tester.view.reset);
                var selected = 'chat';
                await tester.pumpWidget(
                  MaterialApp(
                    theme: raftTheme(dark: dark),
                    home: Scaffold(
                      body: RaftDensityScope(
                        density: density,
                        child: StatefulBuilder(
                          builder: (context, setState) {
                            final component = RaftRailEdgeScope(
                              onRight: onRight,
                              child: RaftWorkspaceRail(
                                phone: density == RaftDensity.touch,
                                thinDivider: selected == 'activity',
                                selected: selected,
                                destinations: const [
                                  RaftRailDestination(
                                    id: 'search',
                                    label: 'Search',
                                    glyph: RaftGlyph.search,
                                  ),
                                  RaftRailDestination(
                                    id: 'chat',
                                    label: 'Chat',
                                    glyph: RaftGlyph.messageSquare,
                                  ),
                                  RaftRailDestination(
                                    id: 'activity',
                                    label: 'Activity',
                                    glyph: RaftGlyph.activity,
                                  ),
                                  RaftRailDestination(
                                    id: 'tasks',
                                    label: 'Tasks',
                                    glyph: RaftGlyph.checkSquare,
                                  ),
                                ],
                                onSelected: (id) =>
                                    setState(() => selected = id),
                                workspaceName: 'M',
                                onWorkspace: () {},
                                footer: RaftWorkspaceRailFooter(
                                  children: [
                                    RaftWorkspaceRailAction(
                                      key: const Key('geometry-footer'),
                                      label: 'Settings',
                                      glyph: RaftGlyph.settings,
                                      selected: selected == 'settings',
                                      onPressed: () =>
                                          setState(() => selected = 'settings'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            final rail = bounded
                                ? SizedBox(
                                    width: RaftLayoutMetrics.railWidth(
                                      RaftTokens.of(context),
                                      height,
                                    ),
                                    child: component,
                                  )
                                : component;
                            // Both constrained and loose hosts keep stable geometry.
                            return Row(
                              children: [
                                if (!onRight) rail,
                                const Expanded(child: SizedBox.expand()),
                                if (onRight) rail,
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                final rail = find.byType(RaftWorkspaceRail);
                final initial = tester.getRect(rail);
                expect(
                  initial.width,
                  RaftRailRecipe(
                    raftTheme(dark: dark).extension<RaftTokens>()!,
                    viewportHeight: height,
                  ).width,
                );
                final slots = <Finder>[
                  find.byKey(const Key('rail-workspace')),
                  for (final id in ['search', 'chat', 'activity', 'tasks'])
                    find.byKey(Key('rail-$id')),
                  find.byKey(const Key('geometry-footer')),
                ];
                final original = [
                  for (final slot in slots) tester.getRect(slot),
                ];
                for (final id in [
                  'activity',
                  'tasks',
                  'search',
                  'chat',
                  'settings',
                  'activity',
                  'chat',
                ]) {
                  await tester.tap(
                    id == 'settings' ? slots.last : find.byKey(Key('rail-$id')),
                  );
                  await tester.pumpAndSettle();
                  expect(
                    tester.getRect(rail),
                    initial,
                    reason: 'rail boundary changed on $id',
                  );
                  for (var i = 0; i < slots.length; i++) {
                    expect(
                      tester.getRect(slots[i]),
                      original[i],
                      reason: 'slot $i moved on $id',
                    );
                  }
                  expect(tester.takeException(), isNull);
                }
              },
              variant: TargetPlatformVariant({TargetPlatform.macOS}),
            );
          }
        }
      }
    }
  }
}
