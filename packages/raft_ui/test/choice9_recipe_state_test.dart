import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// Published @botiverse/raft-ui 0.7.0, used by Web db5e399:
// disabled picker/combobox use foreground-disabled; selected combobox rows
// are bold and carry an indicator; Tabs reads its generated tab/list slots.
// These component checks do not stand in for paired real-screen acceptance.
Widget _host(bool dark, Widget child) => MaterialApp(
  theme: raftTheme(dark: dark).copyWith(platform: TargetPlatform.linux),
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

Finder _action(String label) => find.byWidgetPredicate(
  (widget) => widget is RaftInteractive && widget.semanticLabel == label,
);

RaftRecipeBox _box(WidgetTester tester, Finder parent) =>
    tester.widget<RaftRecipeBox>(
      find.descendant(of: parent, matching: find.byType(RaftRecipeBox)).first,
    );

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('$mode Tabs uses the published recipe for its selected tab', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          dark,
          RaftTabButton(label: 'Members', selected: true, onPressed: () {}),
        ),
      );
      final box = _box(tester, find.byType(RaftTabButton));
      expect(box.style.height, 32);
      expect(
        box.style.backgroundColor?.resolve(box.tokens),
        RaftUiColors.of(dark).brand,
      );
      expect(box.style.text(box.tokens).fontWeight, FontWeight.w700);
    });

    testWidgets('$mode a picker with no action paints disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(dark, const RaftPickerTriggerButton(label: 'Status')),
      );
      final box = _box(tester, find.byType(RaftPickerTriggerButton));
      expect(
        box.style.color?.resolve(box.tokens),
        RaftUiColors.of(dark).foregroundDisabled,
      );
    });

    testWidgets('$mode combobox disabled rows use the published disabled ink', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          dark,
          SizedBox(
            width: 260,
            child: RaftComboboxPanel.items(
              label: 'Model',
              items: const [RaftComboboxItem('a', 'Disabled', enabled: false)],
              onSelected: (_) {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      final box = _box(tester, _action('Disabled'));
      expect(
        box.style.color?.resolve(box.tokens),
        RaftUiColors.of(dark).foregroundDisabled,
      );
      expect(
        find.descendant(
          of: _action('Disabled'),
          matching: find.byWidgetPredicate(
            (widget) => widget is Opacity && widget.opacity < 1,
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('$mode combobox selected rows are bold and show the check', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          dark,
          SizedBox(
            width: 260,
            child: RaftComboboxPanel.items(
              label: 'Model',
              currentId: 'a',
              items: const [RaftComboboxItem('a', 'Selected')],
              onSelected: (_) {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      final action = _action('Selected');
      final box = _box(tester, action);
      expect(box.style.text(box.tokens).fontWeight, FontWeight.w700);
      expect(
        find.descendant(
          of: action,
          matching: find.byWidgetPredicate(
            (widget) => widget is RaftIcon && widget.glyph == RaftGlyph.check,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      '$mode disabling a mounted radio group disables constant rows',
      (tester) async {
        Widget group(ValueChanged<String>? change) => RaftRadioGroup<String>(
          value: 'a',
          onChanged: change,
          children: const [
            RaftRadioGroupItem<String>(
              value: 'a',
              semanticLabel: 'Alpha',
              child: Text('Alpha'),
            ),
          ],
        );
        final values = <String>[];
        await tester.pumpWidget(_host(dark, group(values.add)));
        await tester.pumpWidget(_host(dark, group(null)));
        expect(
          tester.widget<RaftInteractive>(_action('Alpha')).onPressed,
          isNull,
        );
        final style = DefaultTextStyle.of(tester.element(find.text('Alpha')))
            .style;
        expect(style.fontWeight, FontWeight.w600);
        expect(style.color, RaftUiColors.of(dark).foregroundDisabled);
        await tester.tap(find.text('Alpha'));
        expect(values, isEmpty);
      },
    );

    testWidgets('$mode checkbox row forwards keyboard focus to its graphic', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          dark,
          RaftCheckboxRow(title: 'Accept', value: false, onChanged: (_) {}),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final boxes = tester.widgetList<RaftRecipeBox>(
        find.descendant(
          of: find.byType(RaftCheckboxRow),
          matching: find.byType(RaftRecipeBox),
        ),
      );
      expect(
        boxes.any((box) => box.style.cssShadows(box.tokens).isNotEmpty),
        isTrue,
      );
    });

    testWidgets('$mode an open Select closes when its action is revoked', (
      tester,
    ) async {
      Widget select(ValueChanged<String?>? change) => SizedBox(
        width: 240,
        child: RaftSelectField<String>(
          value: 'a',
          onChanged: change,
          items: const [
            RaftSelectItem(value: 'a', label: 'Alpha'),
            RaftSelectItem(value: 'b', label: 'Beta'),
          ],
        ),
      );
      await tester.pumpWidget(_host(dark, select((_) {})));
      await tester.tap(find.byType(RaftSelectField<String>));
      await tester.pump();
      expect(find.byKey(const ValueKey('raft-select-popup')), findsOneWidget);
      await tester.pumpWidget(_host(dark, select(null)));
      await tester.pump();
      expect(find.byKey(const ValueKey('raft-select-popup')), findsNothing);
      expect(find.text('Beta'), findsNothing);
    });

    testWidgets('$mode toggle arrows move focus without changing selection', (
      tester,
    ) async {
      final values = <Set<String>>[];
      await tester.pumpWidget(
        _host(
          dark,
          RaftToggleGroup<String>(
            value: const {'a'},
            onChanged: values.add,
            items: const [
              RaftToggleGroupItem(value: 'a', label: 'Alpha'),
              RaftToggleGroupItem(
                value: 'x',
                label: 'Unavailable',
                enabled: false,
              ),
              RaftToggleGroupItem(value: 'b', label: 'Beta'),
            ],
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(values, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(values, [
        {'b'},
      ]);
    });
  }
}
