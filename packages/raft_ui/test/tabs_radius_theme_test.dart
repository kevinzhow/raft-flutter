import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

/// Tab corners come from the theme.
///
/// Values measured per look rather than copied from the 0.7.1 class:
///   Raft     official `rounded-control` = 8
///   Elegant  a57b9dab tab `rounded-md` (--radius-md: 0.375rem) = 6
///   Brutal   a57b9dab tab, no rounding = 0
///
/// `radius.control` happens to carry exactly 8 / 6 / 0. `radius.chip` would also
/// give 6 for Raft but only 4 for Elegant, so it would miss the measurement on one
/// look while looking correct on another -- which is why the token choice is
/// pinned here rather than left implicit.
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

    testWidgets('Elegant uses the measured 6px tab corner', (tester) async {
      expect(await _painted(tester, elegantThemePackId), 6);
    }, skip: raftLookSkip(raftLookElegant));

    testWidgets('Brutal squares it', (tester) async {
      expect(await _painted(tester, brutalThemePackId), 0);
    }, skip: raftLookSkip(raftLookBrutal));

    test(
      'radius.control carries the measured triple, radius.chip does not',
      () {
        // Guards the token choice: if a future edit switches to radius.chip,
        // Elegant silently becomes 4 and this fails.
        for (final (id, expected) in raftThemeMatrix([
          (raftThemePackId, 8.0),
          (elegantThemePackId, 6.0),
          (brutalThemePackId, 0.0),
        ], look: (v) => raftLookOf(v.$1))) {
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
