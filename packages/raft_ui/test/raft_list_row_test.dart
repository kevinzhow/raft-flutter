import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// Published raft-ui 0.7.0 `ListRow`: variants default / plain / entry, unread tone, selected, interactive false, parts.
Widget _app(bool dark, Widget child) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 358, child: child),
    ),
  ),
);

RaftListRow _conversation({
  Key? key,
  RaftListRowTone tone = RaftListRowTone.normal,
  bool selected = false,
  VoidCallback? onPressed,
  bool topRule = false,
}) => RaftListRow(
  key: key,
  tone: tone,
  selected: selected,
  onPressed: onPressed,
  topRule: topRule,
  children: const [
    SizedBox.square(dimension: 35),
    RaftListRowBody(
      children: [
        RaftListRowTop(
          children: [RaftListRowTitle('Wug'), RaftListRowMeta('10:40')],
        ),
        RaftListRowBottom(
          children: [RaftListRowDescription('Draft is in #launch-week.')],
        ),
      ],
    ),
  ],
);

Color? _fill(WidgetTester tester, Finder row) {
  final box = find
      .descendant(of: row, matching: find.byType(DecoratedBox))
      .first;
  final decoration = tester.widget<DecoratedBox>(box).decoration;
  return switch (decoration) {
    RaftLayeredDecoration(:final base) => base.color,
    BoxDecoration(:final color) => color,
    _ => throw StateError(
      'Unexpected row decoration ${decoration.runtimeType}',
    ),
  };
}

TextStyle _style(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    final ui = RaftUiColors.of(dark);

    testWidgets(
      '$mode a conversation row is 70px: py-3 around a 24 + 2 + 20 body',
      (tester) async {
        await tester.pumpWidget(
          _app(dark, _conversation(key: const ValueKey('r'))),
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('r'))),
          const Size(358, 70),
        );
      },
    );

    testWidgets(
      '$mode default rows are at least 64px, plain and entry rows 48px',
      (tester) async {
        Future<double> height(RaftListRowVariant variant) async {
          await tester.pumpWidget(
            _app(
              dark,
              RaftListRow(
                key: const ValueKey('r'),
                variant: variant,
                children: const [
                  RaftListRowIcon(RaftGlyph.search),
                  RaftListRowBody(children: [RaftListRowTitle('Search')]),
                ],
              ),
            ),
          );
          return tester.getSize(find.byKey(const ValueKey('r'))).height;
        }

        expect(await height(RaftListRowVariant.standard), 64);
        expect(await height(RaftListRowVariant.plain), 48);
        expect(await height(RaftListRowVariant.entry), 48);
      },
    );

    testWidgets(
      '$mode selected fills info-soft; unread bolds the title and inks the description',
      (tester) async {
        await tester.pumpWidget(
          _app(
            dark,
            _conversation(
              key: const ValueKey('r'),
              tone: RaftListRowTone.unread,
              selected: true,
            ),
          ),
        );
        expect(_fill(tester, find.byKey(const ValueKey('r'))), ui['info-soft']);
        expect(_style(tester, 'Wug').fontWeight, FontWeight.w700);
        expect(_style(tester, 'Wug').color, ui.foreground);
        expect(
          _style(tester, 'Draft is in #launch-week.').color,
          ui.foreground,
        );
        expect(_style(tester, '10:40').color, ui.foregroundHint);
      },
    );

    testWidgets(
      '$mode a normal row reads foreground-muted descriptions and semibold titles',
      (tester) async {
        await tester.pumpWidget(_app(dark, _conversation()));
        expect(_style(tester, 'Wug').fontWeight, FontWeight.w600);
        expect(
          _style(tester, 'Draft is in #launch-week.').color,
          ui.foregroundMuted,
        );
      },
    );

    testWidgets('$mode a disabled row greys every ink', (tester) async {
      await tester.pumpWidget(
        _app(
          dark,
          RaftListRow(
            disabled: true,
            onPressed: () {},
            children: const [
              RaftListRowBody(children: [RaftListRowTitle('Wug')]),
              RaftListRowMeta('7'),
            ],
          ),
        ),
      );
      expect(_style(tester, 'Wug').color, ui.foregroundDisabled);
      expect(_style(tester, '7').color, ui.foregroundDisabled);
    });

    testWidgets(
      '$mode tap and Enter activate; hover lays fill-pressed unless selected',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _app(
            dark,
            _conversation(key: const ValueKey('r'), onPressed: () => taps++),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('r')));
        expect(taps, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(taps, 2);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('r'))));
        await tester.pump();
        expect(_fill(tester, find.byKey(const ValueKey('r'))), ui.fillPressed);
        await tester.pumpWidget(
          _app(
            dark,
            _conversation(
              key: const ValueKey('r'),
              selected: true,
              onPressed: () {},
            ),
          ),
        );
        await tester.pump();
        expect(_fill(tester, find.byKey(const ValueKey('r'))), ui['info-soft']);
        await mouse.removePointer();
      },
    );

    testWidgets('$mode interactive false hosts a control and ignores taps', (
      tester,
    ) async {
      var row = 0;
      var toggled = false;
      await tester.pumpWidget(
        _app(
          dark,
          RaftListRow(
            variant: RaftListRowVariant.plain,
            interactive: false,
            onPressed: () => row++,
            children: [
              const RaftListRowIcon(RaftGlyph.bell),
              const RaftListRowBody(
                children: [
                  RaftListRowTitle('Agents can merge to main'),
                  RaftListRowDescription(
                    'Off: a person approves every merge.',
                    wrap: true,
                  ),
                ],
              ),
              RaftSwitch(value: toggled, onChanged: (v) => toggled = v),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Agents can merge to main'));
      expect(row, 0);
      await tester.tap(find.byType(RaftSwitch));
      expect(toggled, isTrue);
    });

    testWidgets(
      '$mode a group is a hairline card with rules from 16px (plain) between rows',
      (tester) async {
        await tester.pumpWidget(
          _app(
            dark,
            RaftListRowGroup(
              children: [
                for (final key in ['a', 'b'])
                  RaftListRow(
                    key: ValueKey(key),
                    variant: RaftListRowVariant.plain,
                    onPressed: () {},
                    children: const [
                      RaftListRowBody(
                        children: [RaftListRowTitle('Appearance')],
                      ),
                      RaftListRowValue('System'),
                      RaftListRowChevron(),
                    ],
                  ),
              ],
            ),
          ),
        );
        // 2px border + two 48px rows; the rows are 356px wide.
        expect(
          tester.getSize(find.byType(RaftListRowGroup)),
          const Size(358, 98),
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('a'))),
          const Size(356, 48),
        );
        final rule = find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == ui.lineHairline,
        );
        expect(rule, findsOneWidget);
        final b = tester.getRect(find.byKey(const ValueKey('b')));
        final r = tester.getRect(rule);
        expect(r.top, b.top);
        expect(r.left - b.left, 16);
        expect(r.height, 1);
      },
    );

    testWidgets(
      '$mode default rows rule off at 63px and entry rows have no rule',
      (tester) async {
        await tester.pumpWidget(
          _app(
            dark,
            RaftListRowList(
              children: [
                _conversation(key: const ValueKey('a')),
                _conversation(key: const ValueKey('b')),
              ],
            ),
          ),
        );
        final rule = find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == ui.lineHairline,
        );
        expect(rule, findsOneWidget);
        expect(
          tester.getRect(rule).left -
              tester.getRect(find.byKey(const ValueKey('b'))).left,
          63,
        );
        await tester.pumpWidget(
          _app(
            dark,
            RaftListRowList(
              children: [
                for (final key in ['a', 'b'])
                  RaftListRow(
                    key: ValueKey(key),
                    variant: RaftListRowVariant.entry,
                    children: const [
                      RaftListRowBody(children: [RaftListRowTitle('Search')]),
                    ],
                  ),
              ],
            ),
          ),
        );
        expect(rule, findsNothing);
      },
    );

    testWidgets('$mode the value takes at most 45% of the row', (tester) async {
      await tester.pumpWidget(
        _app(
          dark,
          const RaftListRow(
            variant: RaftListRowVariant.plain,
            children: [
              RaftListRowBody(children: [RaftListRowTitle('Appearance')]),
              RaftListRowValue(
                'A very long value that keeps going and going and going',
              ),
            ],
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(RaftListRowValue)).width,
        lessThanOrEqualTo((358 - 32) * .45 + .01),
      );
    });

    testWidgets('$mode meta is Space Mono 12 and the description may wrap', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dark,
          const RaftListRow(
            children: [
              RaftListRowBody(
                children: [
                  RaftListRowTop(
                    children: [
                      RaftListRowTitle('Wug'),
                      RaftListRowMeta('10:40'),
                    ],
                  ),
                  RaftListRowDescription(
                    'Off: a person approves every merge and then some more words to wrap around.',
                    wrap: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      final meta = _style(tester, '10:40');
      expect(meta.fontSize, 12);
      expect(meta.fontFamily, contains('SpaceMono'));
      expect(
        tester.getSize(find.byType(RaftListRowDescription)).height,
        greaterThan(20),
      );
    });
  }
}
