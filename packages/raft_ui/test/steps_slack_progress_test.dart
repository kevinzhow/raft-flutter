// Actual mounted consumer's stage adapter, not a network or visual E2E.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final width in [390.0, 900.0]) {
      testWidgets(
        'Slack read-only three-step progress dark=$dark width=$width',
        (t) async {
          t.view.physicalSize = Size(width, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
          final semantics = t.ensureSemantics();
          try {
            for (final stage in RaftSlackStage.values) {
              await t.pumpWidget(
                MaterialApp(
                  theme: raftTheme(dark: dark),
                  home: MediaQuery(
                    data: MediaQueryData(size: Size(width, 844)),
                    child: Scaffold(
                      body: SingleChildScrollView(
                        child: RaftSlackWizardView(
                          stage: stage,
                          canManage: false,
                          busy: false,
                        ),
                      ),
                    ),
                  ),
                ),
              );
              final rail = find.byType(RaftSteps);
              expect(rail, findsOneWidget);
              final progress = t.widget<RaftSteps>(rail);
              expect(progress.steps.map((s) => s.title), [
                'Connect',
                'Channels',
                'Health',
              ]);
              final active = switch (stage) {
                RaftSlackStage.connect || RaftSlackStage.oauth => 0,
                RaftSlackStage.health => 2,
                _ => 1,
              };
              expect(progress.current, active);
              final steps = t
                  .widgetList<Semantics>(
                    find.descendant(of: rail, matching: find.byType(Semantics)),
                  )
                  .where((s) => s.properties.selected != null)
                  .toList();
              expect(steps.length, 3);
              expect(
                steps.where((s) => s.properties.selected == true).length,
                1,
              );
              expect(
                find.descendant(
                  of: rail,
                  matching: find.byWidgetPredicate(
                    (w) => w is Focus && w.onKeyEvent != null,
                  ),
                ),
                findsNothing,
              );
              expect(t.takeException(), isNull);
            }
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
