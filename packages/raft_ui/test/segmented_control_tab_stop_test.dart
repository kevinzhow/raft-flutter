// raft-ui SegmentedControl is one tab stop (the checked segment; the arrows
// move within it), so Tab walks past it. Before, its focus scope looped Tab
// between its own segments and nothing after it could be reached by keyboard
// (the Computers toolbar's Cards / List switch kept focus from the list).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

const _items = [
  RaftSegmentedOption(value: 'cards', label: 'Cards', itemKey: ValueKey('a')),
  RaftSegmentedOption(value: 'list', label: 'List', itemKey: ValueKey('b')),
];

void main() {
  for (final look in ['raft', 'elegant']) {
    testWidgets(
      '$look: Tab enters on the checked segment and leaves after it',
      (t) async {
        var value = 'list';
        final before = FocusNode(), after = FocusNode();
        addTearDown(before.dispose);
        addTearDown(after.dispose);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: builtInTheme(look)),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => Row(
                  children: [
                    RaftButton(
                      label: 'Before',
                      focusNode: before,
                      onPressed: () {},
                    ),
                    RaftSegmentedControl<String>(
                      label: 'View',
                      value: value,
                      items: _items,
                      onChanged: (v) => setState(() => value = v),
                    ),
                    RaftButton(
                      label: 'After',
                      focusNode: after,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        before.requestFocus();
        await t.pump();
        final visited = <String>[];
        for (var i = 0; i < 4 && !after.hasFocus; i++) {
          await t.sendKeyEvent(LogicalKeyboardKey.tab);
          await t.pump();
          final context = FocusManager.instance.primaryFocus?.context;
          String? item;
          context?.visitAncestorElements((e) {
            final key = e.widget.key;
            if (key == const ValueKey('a')) item = 'cards';
            if (key == const ValueKey('b')) item = 'list';
            return item == null;
          });
          if (item != null) visited.add(item!);
        }
        expect(after.hasFocus, isTrue, reason: 'Tab must leave the group');
        if (look == 'raft') {
          expect(visited, ['list'], reason: 'only the checked segment stops');
          // Shift+Tab comes back to it; the arrows still move and select.
          await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await t.sendKeyEvent(LogicalKeyboardKey.tab);
          await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          await t.pump();
          await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await t.pump();
          expect(value, 'cards');
        }
      },
    );
  }
}
