import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

/// Tab corners come from the theme: Raft `rounded-control` = 8.
Widget _host(String id) => MaterialApp(
  theme: raftTheme(pack: packForThemeId(id)),
  home: Scaffold(
    body: RaftTabsList<String>(
      tabs: const [
        RaftTabItem(value: 'a', label: 'A'),
        RaftTabItem(value: 'b', label: 'B'),
      ],
      value: 'a',
      onChanged: (_) {},
    ),
  ),
);

Future<double> _painted(WidgetTester tester, String id) async {
  await tester.pumpWidget(_host(id));
  await tester.pump();
  if (id == raftThemePackId) {
    return tester
        .widgetList<RaftRecipeBox>(find.byType(RaftRecipeBox))
        .first
        .style
        .borderRadius!
        .topLeft
        .x;
  }
  return tester.widgetList<RaftCssBox>(find.byType(RaftCssBox)).first.radius;
}

void main() {
  group('tab radius follows the theme', () {
    testWidgets('Raft keeps the official 8px control corner', (tester) async {
      expect(await _painted(tester, raftThemePackId), 8);
    });

    test(
      'radius.control carries the measured triple, radius.chip does not',
      () {
        // Guards the token choice: if a future edit switches to radius.chip,
        // the corner silently changes and this fails.
        for (final (id, expected) in raftThemeMatrix([
          (raftThemePackId, 8.0),
        ])) {
          final tokens = RaftTokens.theme(pack: packForThemeId(id));
          expect(
            tokens.size('radius.control', fallback: 8),
            expected,
            reason: id,
          );
        }
      },
    );
  });
}
