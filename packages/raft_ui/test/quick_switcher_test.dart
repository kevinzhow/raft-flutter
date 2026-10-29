import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

/// Owned by the running test: disposed when it ends.
T _own<T extends ChangeNotifier>(T value) {
  addTearDown(value.dispose);
  return value;
}

Widget frame(bool dark, {bool selected = true, VoidCallback? onTap}) =>
    MaterialApp(
      theme: raftTheme(dark: dark),
      home: RaftQuickSwitcherLayer(
        child: Align(
          child: SizedBox(
            width: 720,
            height: 480,
            child: RaftQuickSwitcherFrame(
              semanticLabel: 'Search',
              selectLabel: 'Select',
              openLabel: 'Open',
              field: RaftQuickSwitcherField(
                controller: _own(TextEditingController()),
                focusNode: _own(FocusNode()),
                hint: 'Channels, people, messages…',
                clearLabel: 'Clear Search',
                onClear: () {},
              ),
              body: RaftQuickSwitcherList(
                controller: _own(ScrollController()),
                children: [
                  RaftQuickSwitcherHead(
                    children: [
                      RaftQuickSwitcherActionRow(
                        glyph: RaftGlyph.search,
                        title: 'Search for “x”',
                        subtitle: 'Open the full results page',
                        selected: false,
                        onPressed: () {},
                      ),
                    ],
                  ),
                  RaftQuickSwitcherSection(
                    heading: 'Server entities',
                    children: [
                      RaftQuickSwitcherRow(
                        leading: const RaftQuickSwitcherIconBox(RaftGlyph.hash),
                        title: 'design',
                        subtitle: 'Channel',
                        badges: const ['Channel', '!Archived'],
                        selected: selected,
                        returnHint: true,
                        onPressed: onTap ?? () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'quick switcher frame renders field, rows and footer in ${dark ? 'dark' : 'light'}',
      (t) async {
        await t.pumpWidget(frame(dark));
        expect(find.byKey(const Key('quick-switcher-input')), findsOneWidget);
        expect(find.byKey(const Key('quick-switcher-footer')), findsOneWidget);
        expect(find.text('Select'), findsOneWidget);
        expect(find.text('Open'), findsOneWidget);
        // Return hints: footer, "Search for" row, cursor row.
        expect(find.text('↵'), findsNWidgets(3));
        expect(
          find.byWidgetPredicate(
            (w) => w is Text && w.data?.toLowerCase() == 'archived',
          ),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'only the cursor row shows the Return hint and rows are pressable',
    (t) async {
      var taps = 0;
      await t.pumpWidget(frame(false, selected: false, onTap: () => taps++));
      expect(find.text('↵'), findsNWidgets(2));
      await t.tap(find.text('design'));
      expect(taps, 1);
    },
  );

  testWidgets('frame exposes a named route scope', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(frame(false));
    expect(find.bySemanticsLabel('Search'), findsWidgets);
    handle.dispose();
  });

  test('card geometry follows the Web fallback placement', () {
    final wide = RaftQuickSwitcherMetrics.cardRect(const Size(1280, 1000));
    expect((wide.width, wide.height, wide.top), (720, 680, 160));
    final small = RaftQuickSwitcherMetrics.cardRect(const Size(500, 700));
    expect(small.width, closeTo(460, .01));
    expect(small.top, closeTo(72, .01));
    expect(small.bottom, lessThanOrEqualTo(700 - 24));
  });
}
