// RaftTaskCard `selected` / `current` (Web TaskCard.tsx:100-110): selected is
// the cell-selected fill plus a 2px `info` inset ring; current is the fill only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Future<void> _mount(
  WidgetTester t, {
  bool dark = false,
  bool selected = false,
  bool current = false,
}) async {
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            child: RaftTaskCard(
              title: 'Write the notes',
              number: '11',
              status: 'todo',
              selected: selected,
              current: current,
              onTap: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await t.pump();
}

BoxDecoration _surface(WidgetTester t) =>
    t
            .widget<Container>(find.byKey(const ValueKey('task-card-surface')))
            .decoration!
        as BoxDecoration;

Finder get _ring => find.byKey(const ValueKey('task-card-selected-ring'));

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    final tokens = raftTheme(dark: dark).extension<RaftTokens>()!;

    testWidgets('$mode: an ordinary card keeps the card fill and no ring', (
      t,
    ) async {
      await _mount(t, dark: dark);
      expect(_surface(t).color, isNot(tokens.colors['fill-cell-selected']));
      expect(_ring, findsNothing);
    });

    testWidgets('$mode: current is the cell-selected fill and no ring', (
      t,
    ) async {
      await _mount(t, dark: dark, current: true);
      expect(_surface(t).color, tokens.colors['fill-cell-selected']);
      expect(_ring, findsNothing);
    });

    testWidgets('$mode: selected is the fill and a 2px info ring inside the '
        'border', (t) async {
      await _mount(t, dark: dark, selected: true);
      expect(_surface(t).color, tokens.colors['fill-cell-selected']);
      expect(_ring, findsOneWidget);
      final ring =
          (t.widget<DecoratedBox>(_ring).decoration as BoxDecoration).border!
              as Border;
      expect(ring.top.color, tokens.colors['info']);
      expect(ring.top.width, 2);
      // Inside the card's own border, not over it.
      final card = t.getRect(find.byKey(const ValueKey('task-card-surface')));
      final inner = t.getRect(_ring);
      final border = (_surface(t).border! as Border).top.width;
      expect(inner.left - card.left, border);
      expect(card.right - inner.right, border);
    });
  }

  testWidgets('the card still opens and says it is selected', (t) async {
    final handle = t.ensureSemantics();
    var opened = 0;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: RaftTaskCard(
            title: 'Write the notes',
            number: '11',
            status: 'todo',
            selected: true,
            onTap: () => opened++,
          ),
        ),
      ),
    );
    await t.tap(find.text('Write the notes'));
    expect(opened, 1);
    final node = t.getSemantics(find.bySemanticsLabel(RegExp('Open task #11')));
    expect(node.flagsCollection.isSelected.name, 'isTrue');
    handle.dispose();
  });
}
