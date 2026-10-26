import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// raft-ui 0.7.0 `RadioGroup`: a grid with `gap-2`; each item is a 20px circle (border 1.5, `bg-layer-card`) holding an
// 8px dot when chosen, inside a row that selects on tap; arrow keys move the choice.
Widget _app(bool dark, Widget child) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

Widget _group(String value, ValueChanged<String>? onChanged) =>
    RaftRadioGroup<String>(
      value: value,
      onChanged: onChanged,
      children: const [
        RaftRadioGroupItem<String>(
          key: ValueKey('a'),
          value: 'a',
          child: Text('Alpha'),
        ),
        RaftRadioGroupItem<String>(
          key: ValueKey('b'),
          value: 'b',
          enabled: false,
          child: Text('Beta'),
        ),
        RaftRadioGroupItem<String>(
          key: ValueKey('c'),
          value: 'c',
          child: Text('Gamma'),
        ),
      ],
    );

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    final ui = RaftUiColors.of(dark);

    testWidgets('$mode the circle is 20px, the chosen one has an 8px dot', (
      t,
    ) async {
      await t.pumpWidget(_app(dark, _group('a', (_) {})));
      expect(t.getSize(find.byType(RaftRadioMark).first), const Size(20, 20));
      final dots = find.descendant(
        of: find.byType(RaftRadioMark),
        matching: find.byType(RaftRecipeBox),
      );
      // Three marks, three boxes, and one dot box inside the chosen mark.
      expect(dots, findsNWidgets(4));
      expect(
        t.getSize(
          find
              .descendant(
                of: find.descendant(
                  of: find.byKey(const ValueKey('a')),
                  matching: find.byType(RaftRadioMark),
                ),
                matching: find.byType(RaftRecipeBox),
              )
              .last,
        ),
        const Size(8, 8),
      );
    });

    testWidgets('$mode a tap on the label row chooses the item', (t) async {
      final taps = <String>[];
      await t.pumpWidget(_app(dark, _group('a', taps.add)));
      await t.tap(find.text('Gamma'));
      expect(taps, ['c']);
      await t.tap(find.text('Beta'));
      expect(taps, ['c'], reason: 'a disabled item never fires');
    });

    testWidgets('$mode arrow keys move the choice past disabled items', (
      t,
    ) async {
      final taps = <String>[];
      await t.pumpWidget(_app(dark, _group('a', taps.add)));
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(taps, ['c']);
    });

    testWidgets('$mode a group without onChanged is disabled', (t) async {
      await t.pumpWidget(_app(dark, _group('a', null)));
      await t.tap(find.text('Gamma'));
      final mark = find.descendant(
        of: find.byKey(const ValueKey('c')),
        matching: find.byType(RaftRadioMark),
      );
      final box = t.widget<RaftRecipeBox>(
        find.descendant(of: mark, matching: find.byType(RaftRecipeBox)).first,
      );
      expect(box.style.backgroundColor?.resolve(box.tokens), ui.fillMuted);
    });
  }
}
