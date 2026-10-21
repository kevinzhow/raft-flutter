import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// The segmented control's two structures, chosen by the theme.
///
/// raft-ui 0.7.1 wraps the segments in a rounded, padded track. The pre-theme app
/// (`a57b9dab`) drew a flat row of separate segments with a gap and no container
/// at all -- measured by resolving `RaftSegmentedControlRecipe` there: the root
/// carried no `rounded`, no padding and no background in either family, while the
/// items were `rounded-sm` (4px) for Elegant and square for Brutal.
///
/// Replicating Elegant and Brutal pixel for pixel means not drawing a track for
/// them, so this is a structural option (`segmented.frame`) rather than a radius
/// that happens to look close.
Widget _host(String id) => MaterialApp(
  theme: raftTheme(pack: packForThemeId(id)),
  home: Scaffold(
    body: RaftSegmentedControl<String>(
      value: 'a',
      onChanged: (_) {},
      items: const [
        RaftSegmentedOption(value: 'a', label: 'A'),
        RaftSegmentedOption(value: 'b', label: 'B'),
      ],
    ),
  ),
);

/// The rounded boxes belonging to the control itself.
///
/// Scoped to the control: the surrounding Scaffold also paints decorated boxes,
/// and counting those makes the "no track" assertion meaningless.
int _roundedBoxes(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(RaftSegmentedControl<String>),
        matching: find.byType(DecoratedBox),
      ),
    )
    .map((box) => box.decoration)
    .whereType<BoxDecoration>()
    .where((decoration) => decoration.borderRadius != null)
    .length;

double _segmentRadius(WidgetTester tester) =>
    tester.widgetList<RaftCssBox>(find.byType(RaftCssBox)).first.radius;

double _gap(WidgetTester tester) =>
    tester.widgetList<Wrap>(find.byType(Wrap)).first.spacing;

Future<void> _pump(WidgetTester tester, String id) async {
  await tester.pumpWidget(_host(id));
  await tester.pump();
}

void main() {
  group('segmented control structure follows the theme', () {
    testWidgets('Raft frames its segments in a track', (tester) async {
      await _pump(tester, raftThemePackId);
      // Track plus two segments.
      expect(_roundedBoxes(tester), 3);
      expect(_segmentRadius(tester), 8);
    });

    testWidgets('Elegant draws separate segments with no track', (tester) async {
      await _pump(tester, elegantThemePackId);
      // Two segments only: no third rounded box means no track.
      expect(_roundedBoxes(tester), 2);
      // a57b9dab's `rounded-sm`, which the contract carries as radius.chip.
      expect(_segmentRadius(tester), 4);
      // `gap-1.5` at --spacing 0.25rem.
      expect(_gap(tester), 6);
    });

    testWidgets('Brutal draws square separate segments with no track',
        (tester) async {
      await _pump(tester, brutalThemePackId);
      expect(_roundedBoxes(tester), 2);
      expect(_segmentRadius(tester), 0);
      // `gap-1`.
      expect(_gap(tester), 4);
    });

    test('the frame is a structural option, not a radius coincidence', () {
      // A theme that kept the track would give Elegant three rounded boxes; the
      // option is what removes it, so pin the option values themselves.
      expect(packForThemeId(raftThemePackId).light.options['segmented.frame'],
          'framed');
      for (final id in [elegantThemePackId, brutalThemePackId]) {
        expect(packForThemeId(id).light.options['segmented.frame'], 'separate',
            reason: id);
      }
    });
  });
}
