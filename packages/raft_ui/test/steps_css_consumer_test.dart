import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// Contracts read from the pinned published Steps CSS, not a real-entry visual
// acceptance. Slack's real progress has no descriptions; that capability is
// exercised here only at component level.
Widget _app(bool dark, Widget child) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: MediaQuery(
    data: const MediaQueryData(size: Size(390, 844)),
    child: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);
const _steps = [
  RaftStep(title: 'Connect', description: 'Configure access'),
  RaftStep(title: 'Channels'),
  RaftStep(title: 'Health'),
];
void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets('Steps number consumes published line-height1 dark=$dark', (
      t,
    ) async {
      await t.pumpWidget(
        _app(dark, const RaftSteps(steps: _steps, current: 0)),
      );
      final label = find.text('1');
      final own = t.widget<Text>(label).style;
      final style = DefaultTextStyle.of(t.element(label)).style.merge(own);
      expect(style.height, 1);
    });
    testWidgets(
      'Narrow content consumes source6px top and end padding dark=$dark',
      (t) async {
        addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
        await t.pumpWidget(
          _app(dark, const RaftSteps(steps: _steps, current: 0)),
        );
        final pads = t.widgetList<Padding>(
          find.ancestor(
            of: find.text('Connect'),
            matching: find.byType(Padding),
          ),
        );
        expect(
          pads.any(
            (p) =>
                p.padding.resolve(TextDirection.ltr) ==
                const EdgeInsets.only(top: 6, right: 6),
          ),
          isTrue,
        );
      },
    );
    testWidgets(
      'Narrow title and description retain source2px margin dark=$dark',
      (t) async {
        addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
        await t.pumpWidget(
          _app(dark, const RaftSteps(steps: _steps, current: 0)),
        );
        expect(
          t.getTopLeft(find.text('Configure access')).dy -
              t.getBottomLeft(find.text('Connect')).dy,
          closeTo(2, 0.001),
        );
      },
    );
  }
}
