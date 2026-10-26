import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// raft-ui 0.7.1 `SegmentedControl`: fill-muted track (r11, p3, gap 2), 32px items, yellow sticker checked item.
Widget _app(bool dark, Widget child) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

const _items = [
  RaftSegmentedOption(
    value: 'all',
    label: 'All',
    glyph: RaftGlyph.inbox,
    count: '12',
    itemKey: ValueKey('all'),
  ),
  RaftSegmentedOption(
    value: 'unread',
    label: 'Unread',
    itemKey: ValueKey('unread'),
  ),
  RaftSegmentedOption(
    value: 'off',
    label: 'Off',
    enabled: false,
    itemKey: ValueKey('off'),
  ),
];

BoxDecoration _decoration(WidgetTester tester, String key) {
  final box = find
      .descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(DecoratedBox),
      )
      .first;
  return tester.widget<DecoratedBox>(box).decoration as BoxDecoration;
}

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    final ui = RaftUiColors.of(dark);

    testWidgets(
      '$mode expand fills the row and the segments share it equally',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: RaftSegmentedControl<String>(
                  value: 'all',
                  expand: true,
                  items: const [
                    RaftSegmentedOption(
                      value: 'all',
                      label: 'All',
                      itemKey: ValueKey('all'),
                    ),
                    RaftSegmentedOption(
                      value: 'unread',
                      label: 'Unread',
                      itemKey: ValueKey('unread'),
                    ),
                  ],
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        expect(tester.getSize(find.byType(RaftSegmentedTrack)).width, 400);
        expect(
          tester.getSize(find.byKey(const ValueKey('all'))).width,
          tester.getSize(find.byKey(const ValueKey('unread'))).width,
        );
      },
    );

    testWidgets(
      '$mode the track is 38px: 3px padding around 32px items, 2px apart',
      (tester) async {
        await tester.pumpWidget(
          _app(
            dark,
            RaftSegmentedControl<String>(
              value: 'all',
              items: _items,
              onChanged: (_) {},
            ),
          ),
        );
        final all = tester.getRect(find.byKey(const ValueKey('all')));
        final unread = tester.getRect(find.byKey(const ValueKey('unread')));
        expect(all.height, 32);
        expect(unread.left - all.right, 2);
        final track = tester.getRect(find.byType(RaftSegmentedTrack));
        expect(track.height, 38);
        expect(all.left - track.left, 3);
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: find.byType(RaftSegmentedTrack),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        expect(decoration.color, ui.fillMuted);
        expect(decoration.borderRadius, BorderRadius.circular(11));
      },
    );

    testWidgets(
      '$mode the checked item is a yellow sticker with an ink border',
      (tester) async {
        await tester.pumpWidget(
          _app(
            dark,
            RaftSegmentedControl<String>(
              value: 'all',
              items: _items,
              onChanged: (_) {},
            ),
          ),
        );
        final checked = _decoration(tester, 'all');
        expect(checked.color, ui.brand);
        expect((checked.border! as Border).top.color, ui.stickerInk);
        final other = _decoration(tester, 'unread');
        expect(other.color, const Color(0x00000000));
      },
    );

    testWidgets('$mode tapping selects; a disabled item does not', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          dark,
          RaftSegmentedControl<String>(
            value: 'all',
            items: _items,
            onChanged: taps.add,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('unread')));
      await tester.tap(find.byKey(const ValueKey('off')));
      expect(taps, ['unread']);
    });

    testWidgets('$mode a disabled group keeps the sticker and greys the ink', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          dark,
          RaftSegmentedControl<String>(
            disabled: true,
            value: 'all',
            items: _items,
            onChanged: taps.add,
          ),
        ),
      );
      expect(_decoration(tester, 'all').color, ui.brand);
      final label = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('all')),
          matching: find.text('All'),
        ),
      );
      expect(label.style!.color, ui.foregroundDisabled);
      await tester.tap(find.byKey(const ValueKey('unread')));
      expect(taps, isEmpty);
    });

    testWidgets('$mode the count is Space Mono 12 and the checked label bold', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dark,
          RaftSegmentedControl<String>(
            value: 'all',
            items: _items,
            onChanged: (_) {},
          ),
        ),
      );
      final count = tester.widget<Text>(find.text('12'));
      expect(count.style!.fontSize, 12);
      expect(count.style!.fontFamily, contains('SpaceMono'));
      final label = tester.widget<Text>(find.text('All'));
      expect(label.style!.fontWeight, FontWeight.w700);
      final other = tester.widget<Text>(find.text('Unread'));
      expect(other.style!.fontWeight, FontWeight.w600);
    });

    testWidgets('$mode arrow keys select the next item', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          dark,
          RaftSegmentedControl<String>(
            value: 'all',
            items: _items,
            onChanged: taps.add,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('all')));
      await tester.pump();
      taps.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(taps, ['unread']);
    });
  }
}
