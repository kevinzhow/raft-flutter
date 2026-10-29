import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/recipes/checkbox.g.dart';
import 'package:raft_ui/src/recipes/checkbox_indicator.g.dart';
import 'package:raft_ui/src/recipes/recipe_runtime.dart'
    show CssNum, RaftSlotStyle;
import 'package:raft_ui/test_themes.dart';

// raft-ui 0.7.0 `Checkbox` / `CheckboxIndicator` (recipes `checkbox` and `checkboxIndicator`): every expectation is read
// from the generated recipe, resolved for the control's state, and compared with what the mounted control paints. The
// anchors at the end pin the recipes to the raft-ui source class lists, so a regeneration that drifts shows up here.
Widget _app(bool dark, Widget child) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

RaftTokens _tokens(bool dark) =>
    RaftTokens.theme(pack: packForThemeId(raftThemePackId), dark: dark);

/// The `checkboxIndicator` root slot for one state.
RaftSlotStyle _indicator(
  bool dark, {
  bool checked = false,
  bool disabled = false,
  bool circle = false,
  bool previewOnHover = false,
  bool hovered = false,
}) {
  final t = _tokens(dark);
  return RaftCheckboxIndicatorRecipe.resolve(
    theme: t.recipeTheme,
    shape: circle
        ? RaftCheckboxIndicatorRecipeShape.circle
        : RaftCheckboxIndicatorRecipeShape.square,
    checked: checked,
    disabled: disabled,
    previewOnHover: previewOnHover,
    states: t.recipeStates(extra: [if (hovered) 'group:hover']),
    tokens: t.recipeTokens,
  ).root;
}

/// What the indicator paints: the decoration of its recipe box.
BoxDecoration _graphic(WidgetTester tester) {
  final container = find
      .descendant(
        of: find.byType(RaftCheckboxIndicator),
        matching: find.byType(Container),
      )
      .first;
  return tester.widget<Container>(container).decoration! as BoxDecoration;
}

void _expectPaints(
  WidgetTester tester,
  bool dark,
  RaftSlotStyle slot, {
  String? reason,
}) {
  final rt = _tokens(dark).recipeTokens;
  final paint = _graphic(tester);
  expect(paint.color, slot.backgroundColor!.resolve(rt), reason: reason);
  final side = (paint.border! as Border).top;
  expect(side.color, slot.borderColor!.resolve(rt), reason: reason);
  // Blink floors the recipe's 1.5px border to whole device pixels.
  final dpr = tester.view.devicePixelRatio;
  expect(
    side.width,
    (slot.borderWidth.top * dpr).floor() / dpr,
    reason: reason,
  );
  expect(find.byType(Opacity), findsNothing, reason: reason);
}

Finder _glyph(RaftGlyph g) =>
    find.byWidgetPredicate((w) => w is RaftIcon && w.glyph == g);

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    final ui = RaftUiColors.of(dark);

    testWidgets('$mode is the recipe box: square corners, or a circle', (
      tester,
    ) async {
      final square = _indicator(dark);
      await tester.pumpWidget(
        _app(dark, RaftCheckbox(value: false, onChanged: (_) {})),
      );
      expect(
        tester.getSize(find.byType(RaftCheckbox)),
        Size(square.width!, square.height!),
      );
      expect(_graphic(tester).borderRadius, square.borderRadius);
      expect(
        _graphic(tester).borderRadius!.resolve(TextDirection.ltr).topLeft.x,
        _tokens(dark).size('radius.sticker', fallback: -1),
      );
      await tester.pumpWidget(
        _app(
          dark,
          RaftCheckbox(
            value: false,
            shape: RaftCheckboxShape.circle,
            onChanged: (_) {},
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(RaftCheckbox)),
        Size(square.width!, square.height!),
      );
      // `rounded-full`: the recipe radius exceeds half the box, which paints as a circle.
      final circle = _indicator(dark, circle: true);
      expect(_graphic(tester).borderRadius, circle.borderRadius);
      expect(circle.borderRadius!.topLeft.x, greaterThan(square.width! / 2));
      await tester.pumpWidget(
        _app(dark, RaftCheckbox(value: true, onChanged: (_) {})),
      );
      expect(
        tester.getSize(find.byType(RaftCheckbox)),
        Size(square.width!, square.height!),
      );
    });

    testWidgets('$mode unchecked, checked and indeterminate marks and fills', (
      tester,
    ) async {
      final rt = _tokens(dark).recipeTokens;
      await tester.pumpWidget(
        _app(dark, RaftCheckbox(value: false, onChanged: (_) {})),
      );
      _expectPaints(tester, dark, _indicator(dark), reason: 'unchecked');
      expect(_graphic(tester).color, ui.layerCard);
      expect((_graphic(tester).border! as Border).top.color, ui.lineStrong);
      expect(_glyph(RaftGlyph.check), findsNothing);
      expect(_glyph(RaftGlyph.minus), findsNothing);

      final on = _indicator(dark, checked: true);
      final mark = on.target("& svg:not([class*='size-'])")!;
      await tester.pumpWidget(
        _app(dark, RaftCheckbox(value: true, onChanged: (_) {})),
      );
      _expectPaints(tester, dark, on, reason: 'checked');
      expect(_graphic(tester).color, ui.foreground);
      expect(_glyph(RaftGlyph.check), findsOneWidget);
      final check = tester.widget<RaftIcon>(_glyph(RaftGlyph.check));
      expect(check.color, on.foreground(rt));
      expect(check.color, ui['foreground-inverse']);
      expect(check.size, mark.width);
      expect((on.target('& svg')!['stroke-width']! as CssNum).value, 2);
      expect(check.strokeWidth, 2);

      await tester.pumpWidget(
        _app(
          dark,
          RaftCheckbox(value: false, indeterminate: true, onChanged: (_) {}),
        ),
      );
      _expectPaints(tester, dark, on, reason: 'indeterminate');
      expect(_glyph(RaftGlyph.minus), findsOneWidget);
      expect(_glyph(RaftGlyph.check), findsNothing);
    });

    testWidgets(
      '$mode disabled reads the recipe disabled colours, not opacity',
      (tester) async {
        final rt = _tokens(dark).recipeTokens;
        await tester.pumpWidget(_app(dark, const RaftCheckbox(value: false)));
        _expectPaints(
          tester,
          dark,
          _indicator(dark, disabled: true),
          reason: 'disabled unchecked',
        );
        expect(_graphic(tester).color, ui.fillMuted);
        expect(
          (_graphic(tester).border! as Border).top.color,
          ui.foregroundDisabled,
        );

        await tester.pumpWidget(_app(dark, const RaftCheckbox(value: true)));
        final on = _indicator(dark, checked: true, disabled: true);
        _expectPaints(tester, dark, on, reason: 'disabled checked');
        // `bg-foreground-disabled text-layer-card`: the disabled fill and border are the translucent ink itself.
        expect(_graphic(tester).color, ui.foregroundDisabled);
        expect(
          tester.widget<RaftIcon>(_glyph(RaftGlyph.check)).color,
          on.foreground(rt),
        );
        expect(on.foreground(rt), ui.layerCard);
      },
    );

    testWidgets(
      '$mode tap toggles; indeterminate resolves to checked; disabled does nothing',
      (tester) async {
        final calls = <bool>[];
        await tester.pumpWidget(
          _app(dark, RaftCheckbox(value: false, onChanged: calls.add)),
        );
        await tester.tap(find.byType(RaftCheckbox));
        await tester.pumpWidget(
          _app(dark, RaftCheckbox(value: true, onChanged: calls.add)),
        );
        await tester.tap(find.byType(RaftCheckbox));
        await tester.pumpWidget(
          _app(
            dark,
            RaftCheckbox(
              value: false,
              indeterminate: true,
              onChanged: calls.add,
            ),
          ),
        );
        await tester.tap(find.byType(RaftCheckbox));
        expect(calls, [true, false, true]);
        calls.clear();
        await tester.pumpWidget(_app(dark, const RaftCheckbox(value: false)));
        await tester.tap(find.byType(RaftCheckbox), warnIfMissed: false);
        expect(calls, isEmpty);
      },
    );

    testWidgets('$mode semantics: checked, mixed, disabled', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          dark,
          RaftCheckbox(
            value: true,
            onChanged: (_) {},
            semanticLabel: 'Include log',
          ),
        ),
      );
      var node = tester
          .getSemantics(find.bySemanticsLabel('Include log'))
          .getSemanticsData();
      expect(node.flagsCollection.isChecked, CheckedState.isTrue);
      expect(node.flagsCollection.isEnabled, Tristate.isTrue);
      await tester.pumpWidget(
        _app(
          dark,
          RaftCheckbox(
            value: false,
            indeterminate: true,
            onChanged: (_) {},
            semanticLabel: 'Mixed',
          ),
        ),
      );
      node = tester
          .getSemantics(find.bySemanticsLabel('Mixed'))
          .getSemanticsData();
      expect(node.flagsCollection.isChecked, CheckedState.mixed);
      await tester.pumpWidget(
        _app(dark, const RaftCheckbox(value: false, semanticLabel: 'Off')),
      );
      node = tester
          .getSemantics(find.bySemanticsLabel('Off'))
          .getSemanticsData();
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets(
      '$mode keyboard focus draws the recipe focus ring on the root',
      (tester) async {
        await tester.pumpWidget(
          _app(dark, RaftCheckbox(value: true, onChanged: (_) {})),
        );
        final t = _tokens(dark);
        RaftRecipeBox root() => tester.widget<RaftRecipeBox>(
          find
              .descendant(
                of: find.byType(RaftCheckbox),
                matching: find.byType(RaftRecipeBox),
              )
              .first,
        );
        List<RaftRing> rings() => [
          for (final l in root().style.cssShadows(t.recipeTokens))
            RaftRing(l.spread, l.color),
        ];
        expect(rings(), isEmpty);
        final idle = RaftCheckboxRecipe.resolve(
          theme: t.recipeTheme,
          tokens: t.recipeTokens,
          states: t.recipeStates(),
        ).root;
        expect(root().style.classes, idle.classes);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(root().style.classes, contains('focus-visible:shadow-focus'));
        expect(rings(), [
          for (final layer in ui.focusRing.layers)
            RaftRing(layer.spread, layer.color),
        ]);
        expect(root().style.borderRadius, idle.borderRadius);
      },
    );

    testWidgets('$mode the marker graphic: minus, circle, hover preview', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dark,
          const RaftCheckboxIndicator(
            checked: true,
            mark: RaftCheckboxMark.minus,
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(RaftCheckboxIndicator)),
        const Size(20, 20),
      );
      expect(_glyph(RaftGlyph.minus), findsOneWidget);
      await tester.pumpWidget(
        _app(
          dark,
          const RaftCheckboxIndicator(
            size: 14,
            checked: false,
            previewOnHover: true,
            hovered: true,
          ),
        ),
      );
      final preview = _indicator(
        dark,
        previewOnHover: true,
        hovered: true,
      ).foreground(_tokens(dark).recipeTokens)!;
      expect(tester.widget<RaftIcon>(_glyph(RaftGlyph.check)).color, preview);
      expect(preview.a, closeTo(ui.foreground.a * .2, .01));
      await tester.pumpWidget(
        _app(
          dark,
          const RaftCheckboxIndicator(
            size: 14,
            checked: false,
            previewOnHover: true,
          ),
        ),
      );
      expect(tester.widget<RaftIcon>(_glyph(RaftGlyph.check)).color!.a, 0);
    });

    testWidgets('$mode an authored inline style overrides the recipe paint', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dark,
          const RaftCheckboxIndicator(
            checked: true,
            style: RaftCheckboxIndicatorStyle(
              fill: Color(0xFF336699),
              borderColor: Color(0xFFAA3333),
              markColor: Color(0xFFFFFFFF),
              borderWidth: 2,
              radius: 6,
              markSize: 10,
              markStrokeWidth: 3,
            ),
          ),
        ),
      );
      final paint = _graphic(tester);
      expect(paint.color, const Color(0xFF336699));
      expect((paint.border! as Border).top.color, const Color(0xFFAA3333));
      expect((paint.border! as Border).top.width, 2);
      expect(paint.borderRadius, BorderRadius.circular(6));
      final icon = tester.widget<RaftIcon>(_glyph(RaftGlyph.check));
      expect(
        (icon.color, icon.size, icon.strokeWidth),
        (const Color(0xFFFFFFFF), 10, 3),
      );
    });

    test('$mode the recipes are the raft-ui 0.7.0 checkbox', () {
      final indicator = _indicator(dark, checked: true);
      expect(
        indicator.classes,
        containsAll([
          'size-5',
          'rounded-sticker',
          'border-[1.5px]',
          'border-foreground',
          'bg-foreground',
          'text-foreground-inverse',
        ]),
      );
      expect(
        _indicator(dark, disabled: true).classes,
        containsAll(['border-foreground-disabled', 'bg-fill-muted']),
      );
      expect(
        _indicator(dark, checked: true, disabled: true).classes,
        containsAll(['bg-foreground-disabled', 'text-layer-card']),
      );
      expect(_indicator(dark, circle: true).classes, contains('rounded-full'));
      final t = _tokens(dark);
      final root = RaftCheckboxRecipe.resolve(
        theme: t.recipeTheme,
        tokens: t.recipeTokens,
      ).root;
      expect(
        root.classes,
        containsAll([
          'size-5',
          'rounded-sticker',
          'focus-visible:shadow-focus',
        ]),
      );
      expect((root.width, root.height), (20, 20));
    });
  }
}
