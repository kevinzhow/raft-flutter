import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/recipes/recipe_runtime.dart' show RaftSlotStyle;
import 'package:raft_ui/src/recipes/switch_recipe.g.dart';
import 'package:raft_ui/test_themes.dart';

// raft-ui 0.7.0 `Switch` (recipe `switchRecipe`): every expectation below is read from the generated recipe, resolved
// for the state the control is in, and compared with what the mounted switch paints. The anchors at the end pin the
// recipe itself to the raft-ui source class list, so a regeneration that drifts shows up here.
Widget _app(bool dark, Widget child) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

RaftTokens _tokens(bool dark) =>
    RaftTokens.theme(pack: packForThemeId(raftThemePackId), dark: dark);

RaftSwitchRecipeStyle _recipe(
  bool dark, {
  bool on = false,
  bool disabled = false,
  bool focus = false,
}) {
  final t = _tokens(dark);
  return RaftSwitchRecipe.resolve(
    theme: t.recipeTheme,
    tokens: t.recipeTokens,
    states: t.recipeStates(
      focusVisible: focus,
      extra: [if (on) 'data-checked', if (disabled) 'data-disabled'],
    ),
  );
}

Color _fill(bool dark, RaftSlotStyle s) =>
    s.backgroundColor!.resolve(_tokens(dark).recipeTokens);

Color _border(bool dark, RaftSlotStyle s) =>
    s.borderColor!.resolve(_tokens(dark).recipeTokens);

/// The painted rings of a slot: its outer box-shadow layers that have a spread, first = on top.
List<RaftRing> _rings(bool dark, RaftSlotStyle s) => [
  for (final l in s.cssShadows(_tokens(dark).recipeTokens))
    if (!l.inset && l.spread > 0) RaftRing(l.spread, l.color),
];

List<RaftCssBox> _boxes(WidgetTester tester) => tester
    .widgetList<RaftCssBox>(
      find.descendant(
        of: find.byType(RaftSwitch),
        matching: find.byType(RaftCssBox),
      ),
    )
    .toList();

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    final ui = RaftUiColors.of(dark);

    testWidgets('$mode is 50x30 with a 22px thumb at either size', (
      tester,
    ) async {
      for (final size in RaftSwitchSize.values) {
        await tester.pumpWidget(
          _app(dark, RaftSwitch(value: false, onChanged: (_) {}, size: size)),
        );
        final r = _recipe(dark);
        expect(
          tester.getSize(find.byType(RaftSwitch)),
          Size(r.root.width!, r.root.height!),
        );
        final boxes = _boxes(tester);
        expect(boxes[0].radius, r.root.height! / 2);
        expect(boxes[1].width, r.thumb.width);
        expect(boxes[1].height, r.thumb.height);
        expect(boxes[1].radius, r.thumb.height! / 2);
      }
    });

    testWidgets('$mode off, on and disabled paint the recipe slots', (
      tester,
    ) async {
      void expectPaints(
        WidgetTester tester,
        RaftSwitchRecipeStyle r,
        String why,
      ) {
        final boxes = _boxes(tester);
        expect(boxes[0].fill, _fill(dark, r.root), reason: why);
        expect(boxes[0].borderColor, _border(dark, r.root), reason: why);
        // Blink floors the recipe's 1.5px border to whole device pixels.
        final dpr = tester.view.devicePixelRatio;
        expect(
          boxes[0].borderWidth,
          (r.root.borderWidth.top * dpr).floor() / dpr,
          reason: why,
        );
        expect(boxes[0].rings, _rings(dark, r.root), reason: why);
        expect(boxes[0].padding, r.root.padding, reason: why);
        expect(boxes[1].fill, _fill(dark, r.thumb), reason: why);
        expect(boxes[1].rings, _rings(dark, r.thumb), reason: why);
        expect(find.byType(Opacity), findsNothing, reason: why);
      }

      await tester.pumpWidget(
        _app(dark, RaftSwitch(value: false, onChanged: (_) {})),
      );
      expectPaints(tester, _recipe(dark), 'off');
      expect(_boxes(tester)[0].rings, isEmpty);
      expect(_boxes(tester)[1].rings.single.spread, 1.5);

      await tester.pumpWidget(
        _app(dark, RaftSwitch(value: true, onChanged: (_) {})),
      );
      await tester.pumpAndSettle();
      expectPaints(tester, _recipe(dark, on: true), 'on');
      // The recipe's sticker ring and ink border, in the theme's own colours.
      expect(_boxes(tester)[0].borderColor, ui.stickerInk);
      expect(_boxes(tester)[0].rings.single, RaftRing(1.5, ui.stickerEdge));
      expect(_boxes(tester)[1].fill, ui.stickerPaper);

      for (final on in [false, true]) {
        await tester.pumpWidget(_app(dark, RaftSwitch(value: on)));
        await tester.pumpAndSettle();
        expectPaints(
          tester,
          _recipe(dark, on: on, disabled: true),
          'disabled on=$on',
        );
        // Disabled reads `foreground-disabled` ink on `fill-muted` for both values.
        expect(_boxes(tester)[0].fill, ui.fillMuted);
        expect(_boxes(tester)[0].borderColor, ui.foregroundDisabled);
        expect(_boxes(tester)[1].fill, ui.fillMuted);
        expect(_boxes(tester)[1].rings.single.color, ui.foregroundDisabled);
      }
    });

    testWidgets('$mode the thumb travels 20px when on', (tester) async {
      await tester.pumpWidget(
        _app(dark, RaftSwitch(value: false, onChanged: (_) {})),
      );
      final off = tester.getTopLeft(find.byType(RaftCssBox).last).dx;
      await tester.pumpWidget(
        _app(dark, RaftSwitch(value: true, onChanged: (_) {})),
      );
      await tester.pumpAndSettle();
      final on = tester.getTopLeft(find.byType(RaftCssBox).last).dx;
      final r = _recipe(dark, on: true);
      expect(r.thumb.translate!.dx, isPositive);
      expect(on - off, closeTo(r.thumb.translate!.dx, .01));
    });

    testWidgets('$mode tap toggles, a disabled switch does not', (
      tester,
    ) async {
      final calls = <bool>[];
      await tester.pumpWidget(
        _app(dark, RaftSwitch(value: false, onChanged: calls.add)),
      );
      await tester.tap(find.byType(RaftSwitch));
      expect(calls, [true]);

      calls.clear();
      await tester.pumpWidget(
        _app(
          dark,
          RaftSwitch(value: false, enabled: false, onChanged: calls.add),
        ),
      );
      await tester.tap(find.byType(RaftSwitch), warnIfMissed: false);
      await tester.pumpWidget(_app(dark, const RaftSwitch(value: false)));
      await tester.tap(find.byType(RaftSwitch), warnIfMissed: false);
      expect(calls, isEmpty);
    });

    testWidgets('$mode semantics: toggled, labelled, disabled', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          dark,
          RaftSwitch(
            value: true,
            onChanged: (_) {},
            semanticLabel: 'Notifications',
          ),
        ),
      );
      final node = tester
          .getSemantics(find.bySemanticsLabel('Notifications'))
          .getSemanticsData();
      expect(node.flagsCollection.isToggled, Tristate.isTrue);
      expect(node.flagsCollection.isEnabled, Tristate.isTrue);
      await tester.pumpWidget(
        _app(dark, const RaftSwitch(value: false, semanticLabel: 'Off')),
      );
      final off = tester
          .getSemantics(find.bySemanticsLabel('Off'))
          .getSemanticsData();
      expect(off.flagsCollection.isEnabled, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('$mode keyboard focus adds the recipe focus ring', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(dark, RaftSwitch(value: true, onChanged: (_) {})),
      );
      await tester.pumpAndSettle();
      expect(
        _boxes(tester)[0].rings,
        _rings(dark, _recipe(dark, on: true).root),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final focused = _rings(dark, _recipe(dark, on: true, focus: true).root);
      expect(_boxes(tester)[0].rings, focused);
      // `data-checked:ring-[1.5px]` outranks `focus-visible:ring-0`: the sticker ring stays under the focus ring.
      expect(focused.first, RaftRing(1.5, ui.stickerEdge));
      expect(focused.length, 1 + ui.focusRing.layers.length);
      for (var i = 0; i < ui.focusRing.layers.length; i++) {
        expect(focused[i + 1].spread, ui.focusRing.layers[i].spread);
        expect(focused[i + 1].color, ui.focusRing.layers[i].color);
      }
    });

    testWidgets('$mode an unchecked switch gets only the focus ring', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(dark, RaftSwitch(value: false, onChanged: (_) {})),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_boxes(tester)[0].rings, [
        for (final layer in ui.focusRing.layers)
          RaftRing(layer.spread, layer.color),
      ]);
    });

    test('$mode the recipe is the raft-ui 0.7.0 switch', () {
      final r = _recipe(dark, on: true);
      expect(
        r.root.classes,
        containsAll([
          'h-[30px]',
          'w-[50px]',
          'p-[2.5px]',
          'border-[1.5px]',
          'rounded-full',
          'data-checked:bg-brand',
          'data-checked:border-sticker-ink',
          'data-checked:ring-sticker-edge',
          'focus-visible:shadow-focus',
          'duration-150',
        ]),
      );
      expect(
        r.thumb.classes,
        containsAll([
          'size-[22px]',
          'data-[checked]:translate-x-5',
          'data-checked:bg-sticker-paper',
          'duration-220',
          'ease-slide',
        ]),
      );
      expect(r.root.transitionDuration, const Duration(milliseconds: 150));
      expect(r.thumb.transitionDuration, const Duration(milliseconds: 220));
      expect((r.root.width, r.root.height), (50, 30));
      expect((r.thumb.width, r.thumb.height), (22, 22));
      expect(r.thumb.translate, const Offset(20, 0));
    });
  }
}
