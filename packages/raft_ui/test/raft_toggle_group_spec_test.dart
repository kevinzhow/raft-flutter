import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// raft-ui 0.7.0 `ToggleGroup`: a fill-muted track (r11, p3, gap 2) of 32px items; a pressed item is the yellow
// sticker. The frozen looks have no track.
Widget _app(bool dark, Widget child) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

Widget _group(Set<String> value, ValueChanged<Set<String>>? onChanged) =>
    RaftToggleGroup<String>(
      value: value,
      onChanged: onChanged,
      items: const [
        RaftToggleGroupItem(
          value: 'grid',
          glyph: RaftGlyph.layoutGrid,
          tooltip: 'Grid',
          itemKey: ValueKey('grid'),
        ),
        RaftToggleGroupItem(
          value: 'list',
          glyph: RaftGlyph.list,
          tooltip: 'List',
          itemKey: ValueKey('list'),
        ),
      ],
    );

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    final ui = RaftUiColors.of(dark);

    testWidgets('$mode the track is 38px high with 32px square items', (
      t,
    ) async {
      await t.pumpWidget(_app(dark, _group({'grid'}, (_) {})));
      expect(t.getSize(find.byKey(const ValueKey('grid'))), const Size(32, 32));
      final track = t.getRect(find.byType(RaftToggleGroup<String>));
      expect(track.height, 38);
      expect(track.width, 3 + 32 + 2 + 32 + 3);
    });

    testWidgets('$mode the pressed item is the brand sticker', (t) async {
      await t.pumpWidget(_app(dark, _group({'grid'}, (_) {})));
      RaftRecipeBox box(String key) => t.widget<RaftRecipeBox>(
        find
            .descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(RaftRecipeBox),
            )
            .first,
      );
      final pressed = box('grid');
      expect(pressed.style.backgroundColor?.resolve(pressed.tokens), ui.brand);
      final idle = box('list');
      expect(idle.style.backgroundColor?.resolve(idle.tokens), isNot(ui.brand));
    });

    testWidgets('$mode single mode: a tap presses, a second tap clears', (
      t,
    ) async {
      final changes = <Set<String>>[];
      await t.pumpWidget(_app(dark, _group({'grid'}, changes.add)));
      await t.tap(find.byKey(const ValueKey('list')));
      await t.tap(find.byKey(const ValueKey('grid')));
      expect(changes, [
        {'list'},
        <String>{},
      ]);
    });

    testWidgets('$mode a group without onChanged is inert', (t) async {
      await t.pumpWidget(_app(dark, _group({'grid'}, null)));
      await t.tap(find.byKey(const ValueKey('list')));
      expect(t.takeException(), isNull);
    });
  }
}
