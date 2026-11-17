import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// The segmented control frames its segments in a rounded, padded track
/// (raft-ui 0.7.0), a structural option (`segmented.frame`).
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

double _segmentRadius(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(RaftSegmentedItem).first,
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (box.decoration as BoxDecoration).borderRadius!
      .resolve(TextDirection.ltr)
      .topLeft
      .x;
}

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
  });
}
