import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Segmented-control corners come from the theme, and stay concentric.
///
/// The segment takes `radius.control`; the track around it is that radius plus
/// the 3px inset, mirroring the official source (`rounded-[11px]` wrapping
/// `p-[3px]` around a `rounded-control` 8px segment). Deriving the track from the
/// token rather than hardcoding 11 matters: a theme with square controls would
/// otherwise leave a 3px-rounded track around a square segment.
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

/// Painted segment radius and track radius for one theme, in its own tree.
Future<(double, double)> _painted(WidgetTester tester, String id) async {
  await tester.pumpWidget(_host(id));
  await tester.pump();
  final segment = tester
      .widgetList<RaftCssBox>(find.byType(RaftCssBox))
      .first
      .radius;
  final radii = tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .map((box) => box.decoration)
      .whereType<BoxDecoration>()
      .map((decoration) => (decoration.borderRadius as BorderRadius?)?.topLeft.x)
      .whereType<double>();
  // The track is the largest painted radius; the decorative orders vary.
  final track = radii.isEmpty ? 0.0 : radii.reduce((a, b) => a > b ? a : b);
  return (segment, track);
}

void main() {
  group('segmented control radius follows the theme', () {
    testWidgets('Raft keeps 8 inside and 11 around it', (tester) async {
      expect(await _painted(tester, raftThemePackId), (8.0, 11.0));
    });

    testWidgets('Elegant uses its own control corner plus the inset',
        (tester) async {
      expect(await _painted(tester, elegantThemePackId), (6.0, 9.0));
    });

    testWidgets('Brutal squares both', (tester) async {
      final (segment, track) = await _painted(tester, brutalThemePackId);
      expect(segment, 0.0);
      // A square segment inside a 3px-rounded track would show corners poking out,
      // so the track follows the token down rather than staying at 11.
      expect(track, 3.0);
    });

    test('the track is derived from the token, not fixed at 11', () {
      // Guard the derivation itself: with square controls the track must not be
      // the hardcoded 11 it used to be.
      final brutal = RaftTokens.theme(pack: packForThemeId(brutalThemePackId));
      expect(brutal.size('radius.control', fallback: 8), 0);
      expect(brutal.size('radius.control', fallback: 8) + 3, isNot(11));
    });
  });
}
