import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family dark=$dark selected result remains keyboard actionable',
      (t) async {
        final semantics = t.ensureSemantics();
        var opened = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 300,
                  child: RaftSearchResultSurface(
                    selected: true,
                    onPressed: () => opened++,
                    child: const Text('Result'),
                  ),
                ),
              ),
            ),
          ),
        );
        final node = t.getSemantics(find.byType(RaftInteractive));
        expect(
          node,
          matchesSemantics(
            isSelected: true,
            hasSelectedState: true,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
            hasFocusAction: true,
            isFocusable: true,
            label: 'Result',
          ),
        );
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pump();
        expect(opened, 1);
        await t.tap(find.text('Result'));
        expect(opened, 2);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        semantics.dispose();
      },
    );
    testWidgets('$family dark=$dark task views support keyboard selection', (
      t,
    ) async {
      var value = 'board';
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => RaftSegmentedControl<String>(
                label: 'Task view',
                value: value,
                style: RaftSegmentedStyle.taskViews,
                items: const [
                  RaftSegmentedOption(
                    value: 'board',
                    label: 'Board',
                    glyph: RaftGlyph.columns3,
                  ),
                  RaftSegmentedOption(
                    value: 'list',
                    label: 'List',
                    glyph: RaftGlyph.list,
                  ),
                ],
                onChanged: (next) => update(() => value = next),
              ),
            ),
          ),
        ),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      expect(value, 'list');
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pump();
      expect(value, 'board');
      await t.tap(find.text('List'));
      await t.pump();
      expect(value, 'list');
      expect(t.takeException(), isNull);
    });
    testWidgets(
      '$family dark=$dark task filter keeps fixed visual box and intrinsic width',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: RaftTaskFilterButton(
                  onPressed: () {},
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      RaftIcon(RaftGlyph.hash, size: 14),
                      Text('Channel'),
                      RaftIcon(RaftGlyph.chevronDown, size: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        final face = find.byType(RaftRecipeBox);
        expect(t.getSize(face).height, 32);
        expect(t.getSize(face).width, lessThan(200));
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        expect(t.takeException(), isNull);
      },
    );
  }
}
