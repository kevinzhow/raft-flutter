import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// raft-ui 0.7.0 `Tabs`: h-8 sticker tabs / h-11 underline tabs, yellow sticker selection, callbacks, keyboard.
Widget _app(bool dark, Widget child) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

const _items = [
  RaftTabItem(value: 'a', label: 'General', itemKey: ValueKey('tab-a')),
  RaftTabItem(value: 'b', label: 'Members', itemKey: ValueKey('tab-b')),
  RaftTabItem(
    value: 'c',
    label: 'Activity',
    itemKey: ValueKey('tab-c'),
    enabled: false,
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
      '$mode sticker tabs are 32px, 2px apart; underline tabs 44px, 20px apart',
      (tester) async {
        await tester.pumpWidget(
          _app(
            dark,
            RaftTabsList<String>(tabs: _items, value: 'a', onChanged: (_) {}),
          ),
        );
        final a = tester.getRect(find.byKey(const ValueKey('tab-a')));
        final b = tester.getRect(find.byKey(const ValueKey('tab-b')));
        expect(a.height, 32);
        expect(b.left - a.right, 2);
        await tester.pumpWidget(
          _app(
            dark,
            RaftTabsList<String>(
              tabs: _items,
              value: 'a',
              onChanged: (_) {},
              variant: RaftTabsVariant.underline,
            ),
          ),
        );
        final ua = tester.getRect(find.byKey(const ValueKey('tab-a')));
        final ub = tester.getRect(find.byKey(const ValueKey('tab-b')));
        expect(ua.height, 44);
        expect(ub.left - ua.right, 20);
      },
    );

    testWidgets(
      '$mode the selected sticker tab is brand yellow with an ink border',
      (tester) async {
        await tester.pumpWidget(
          _app(
            dark,
            RaftTabsList<String>(tabs: _items, value: 'a', onChanged: (_) {}),
          ),
        );
        final selected = _decoration(tester, 'tab-a');
        expect(selected.color, ui.brand);
        expect((selected.border! as Border).top.color, ui.stickerInk);
        expect(selected.borderRadius, BorderRadius.circular(8));
        final other = _decoration(tester, 'tab-b');
        expect(other.color ?? Colors.transparent, Colors.transparent);
        expect(other.border != null, isTrue);
      },
    );

    testWidgets('$mode underline selection is a 2px foreground bar, no fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dark,
          RaftTabsList<String>(
            tabs: _items,
            value: 'a',
            onChanged: (_) {},
            variant: RaftTabsVariant.underline,
          ),
        ),
      );
      // Web draws this as an inset shadow, not a second positioned box.
      RaftRecipeBox tab(String key) => tester.widget<RaftRecipeBox>(
        find
            .descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(RaftRecipeBox),
            )
            .first,
      );
      final selected = tab('tab-a');
      final bars = selected.style
          .cssShadows(selected.tokens)
          .where((shadow) => shadow.inset)
          .toList();
      expect(bars, hasLength(1));
      expect(bars.single.offset, const Offset(0, -2));
      expect(bars.single.blur, 0);
      expect(bars.single.spread, 0);
      expect(bars.single.color, ui.foreground);
      final resting = tab('tab-b');
      expect(
        resting.style
            .cssShadows(resting.tokens)
            .where((shadow) => shadow.inset),
        isEmpty,
      );
    });

    testWidgets('$mode tapping selects, a disabled tab does not', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          dark,
          RaftTabsList<String>(tabs: _items, value: 'a', onChanged: taps.add),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('tab-b')));
      await tester.tap(find.byKey(const ValueKey('tab-c')));
      expect(taps, ['b']);
    });

    testWidgets('$mode arrow keys move selection among enabled tabs', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(
          dark,
          RaftTabsList<String>(tabs: _items, value: 'a', onChanged: taps.add),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('tab-a')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      expect(taps, ['a', 'b', 'b']);
    });

    testWidgets('$mode a disabled tab reads foreground-disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dark,
          RaftTabsList<String>(tabs: _items, value: 'a', onChanged: (_) {}),
        ),
      );
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('tab-c')),
          matching: find.text('Activity'),
        ),
      );
      expect(text.style!.color, ui.foregroundDisabled);
    });

    testWidgets('$mode RaftTabs shows the selected panel under the list', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dark,
          SizedBox(
            width: 358,
            child: RaftTabs<String>(
              tabs: _items,
              value: 'b',
              onChanged: (_) {},
              panels: const {
                'a': Text('panel-a'),
                'b': RaftTabsPanelText('12 members, 3 agents.'),
              },
            ),
          ),
        ),
      );
      expect(find.text('panel-a'), findsNothing);
      expect(find.text('12 members, 3 agents.'), findsOneWidget);
      // p-3 text-xs: 12 + 16 + 12 under the 32px list.
      expect(
        tester.getSize(find.byType(RaftTabsPanelText)),
        const Size(358, 40),
      );
    });

    testWidgets(
      '$mode hovering a resting sticker tab lays the fill-pressed wash',
      (tester) async {
        await tester.pumpWidget(
          _app(
            dark,
            RaftTabsList<String>(tabs: _items, value: 'a', onChanged: (_) {}),
          ),
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(
          tester.getCenter(find.byKey(const ValueKey('tab-b'))),
        );
        await tester.pump();
        expect(_decoration(tester, 'tab-b').color, ui.fillPressed);
        await mouse.removePointer();
      },
    );
  }
}
