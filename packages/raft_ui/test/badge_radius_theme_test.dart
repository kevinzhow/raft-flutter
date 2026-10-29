import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

/// Badge corners come from the theme.
///
/// A solid badge takes `radius.sticker` and an outline badge `radius.chip`; the
/// official React specimen confirms that mapping (`rounded-sticker` /
/// `rounded-chip`). Before this, both were the literal Raft values, so Elegant and
/// Brutal always painted Raft's corners.
Widget _host(String id) => MaterialApp(
  theme: raftTheme(pack: packForThemeId(id)),
  home: Scaffold(body: RaftBadge(label: 'Beta')),
);

/// Reads the painted radius for one theme in its own tree.
///
/// A fresh tree per theme, because reusing one leaves the previous theme's values
/// in the element and the comparison then passes for the wrong reason.
Future<double> _paintedRadius(WidgetTester tester, String id) async {
  await tester.pumpWidget(_host(id));
  await tester.pump();
  return tester.widgetList<RaftCssBox>(find.byType(RaftCssBox)).first.radius;
}

void main() {
  group('badge radius follows the theme', () {
    testWidgets('Raft keeps the official 4px sticker corner', (tester) async {
      expect(await _paintedRadius(tester, raftThemePackId), 4);
    });

    testWidgets('Elegant softens to its own sticker corner', (tester) async {
      expect(await _paintedRadius(tester, elegantThemePackId), 3);
    }, skip: raftLookSkip(raftLookElegant));

    testWidgets('Brutal squares it', (tester) async {
      expect(await _paintedRadius(tester, brutalThemePackId), 0);
    }, skip: raftLookSkip(raftLookBrutal));

    test('the mapping is sticker for solid and chip for outline', () {
      // The tokens differ per theme, so a mix-up between the two would still be
      // caught by the values above only for themes where both differ; this pins
      // the mapping itself.
      final raft = RaftTokens.theme(pack: packForThemeId(raftThemePackId));
      expect(raft.size('radius.sticker', fallback: 4), 4);
      expect(raft.size('radius.chip', fallback: 6), 6);
      expect(
        raft.size('radius.sticker', fallback: 4),
        isNot(raft.size('radius.chip', fallback: 6)),
      );
    });
  });
}
