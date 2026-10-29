import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/tap_slop.dart';

void main() {
  for (final scenario in [
    (platform: TargetPlatform.android, width: 856.0, mode: null),
    (platform: TargetPlatform.linux, width: 390.0, mode: null),
    (
      platform: TargetPlatform.android,
      width: 856.0,
      mode: RaftInteraction.pointerMode,
    ),
    (
      platform: TargetPlatform.linux,
      width: 390.0,
      mode: RaftInteraction.touchMode,
    ),
  ]) {
    final platform = scenario.platform;
    final touch =
        (scenario.mode ?? RaftInteraction.forPlatform(platform)).touch;
    testWidgets(
      '$platform/${scenario.mode?.mode} search hint follows input and keeps its tap target',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(scenario.width, 844);
        addTearDown(t.view.reset);
        var opened = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(
              body: RaftInteractionScope(
                interaction:
                    scenario.mode ?? RaftInteraction.forPlatform(platform),
                child: RaftTapSlopHost(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 360,
                      height: 48,
                      child: Center(
                        child: RaftWorkspaceSearchTrigger(
                          onPressed: () => opened++,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final hint = find.text(globalSearchShortcutLabel());
        expect(hint, touch ? findsNothing : findsOneWidget);
        await t.tapAt(const Offset(180, 1));
        expect(opened, touch ? 1 : 0);
        await t.tap(find.byKey(const Key('topbar-search')));
        expect(opened, touch ? 2 : 1);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
}
