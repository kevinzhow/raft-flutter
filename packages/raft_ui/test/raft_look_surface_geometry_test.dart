// Pins the geometry of the Raft-look surfaces and fields after the raft-ui
// 0.7.0 recipes (#493): inputs keep the recipe's `h-11 rounded-control
// border-[1.5px]` box, and every ring, focus ring and `overflow-hidden` clip
// follows the rounded corner concentrically instead of being cut at the arc.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart'
    show
        RaftCardRecipe,
        RaftRecipeDecoration,
        RaftSegmentedControlRecipe,
        RaftSidebarItemRecipe;
import 'package:raft_ui/test_themes.dart';

const _paint = ValueKey('paint');

Future<ui.Image> _capture(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_paint),
  );
  return (await tester.runAsync(() => boundary.toImage()))!;
}

Future<Color Function(double, double)> _sampler(WidgetTester tester) async {
  final image = await _capture(tester);
  final data = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  final width = image.width;
  image.dispose();
  return (x, y) {
    final i = (y.floor() * width + x.floor()) * 4;
    return Color.fromARGB(
      data.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
  };
}

/// The pixel on the 45 degree diagonal of the top-left corner arc whose
/// centre is [center], [radius] away from it.

Color _diag(Color Function(double, double) at, Offset center, double radius) {
  final d = radius / math.sqrt2;
  return at(center.dx - d, center.dy - d);
}

Widget _host(ThemeData theme, Widget child, {Color? canvas}) => MaterialApp(
  theme: theme,
  home: Material(
    color: Colors.transparent,
    child: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: _paint,
        child: Container(
          color: canvas ?? Colors.white,
          padding: const EdgeInsets.all(24),
          child: child,
        ),
      ),
    ),
  ),
);

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    final theme = raftTheme(dark: dark);
    final t = theme.extension<RaftTokens>()!;

    group('[$mode] input fields', () {
      testWidgets(
        'RaftRecipeInput is the recipe box: 44px, 8px, 1.5px line-strong',
        (tester) async {
          await tester.pumpWidget(
            _host(
              theme,
              const SizedBox(
                width: 320,
                child: RaftRecipeInput(fieldKey: Key('field')),
              ),
            ),
          );
          final box = find
              .ancestor(
                of: find.byKey(const Key('field')),
                matching: find.byType(Container),
              )
              .first;
          expect(
            tester.getSize(box).height,
            44,
            reason: '`h-11`, not a bare line',
          );
          final d = tester.widget<Container>(box).decoration! as BoxDecoration;
          expect(d.borderRadius, BorderRadius.circular(8));
          final border = d.border! as Border;
          // `border-[1.5px]`, floored to whole device pixels like every other control.
          expect(
            border.top.width,
            raftControlBorderPx(
              tester.element(find.byKey(const Key('field'))),
              1.5,
            ),
          );
          expect(border.top.color, t.ui.lineStrong);
        },
      );

      testWidgets('read-only prefixed input keeps the same 44px box', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            theme,
            const SizedBox(
              width: 320,
              child: RaftSettingsPrefixedInput(
                prefix: '@',
                value: 'name',
                readOnly: true,
              ),
            ),
          ),
        );
        final boxes = find.descendant(
          of: find.byType(RaftSettingsPrefixedInput),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is RaftRecipeDecoration,
          ),
        );
        final heights = [
          for (final e in boxes.evaluate())
            tester.getSize(find.byWidget(e.widget)).height,
        ];
        expect(heights.reduce(math.max), 44);
      });

      testWidgets(
        'a disabled input dims through its fill, not through opacity',
        (tester) async {
          await tester.pumpWidget(
            _host(
              theme,
              const SizedBox(
                width: 320,
                child: RaftRecipeInput(fieldKey: Key('field'), enabled: false),
              ),
            ),
          );
          final dimmed = find.descendant(
            of: find.byType(RaftRecipeInput),
            matching: find.byWidgetPredicate(
              (w) => w is Opacity && w.opacity < 1,
            ),
          );
          expect(dimmed, findsNothing);
        },
      );
    });

    group('[$mode] corners', () {
      testWidgets('focus ring is concentric with the composer corner', (
        tester,
      ) async {
        final recipe = RaftComposerRecipe(t, desktop: true);
        final radius = recipe.shellRadius;
        await tester.pumpWidget(
          _host(
            theme,
            Container(
              width: 140,
              height: 80,
              decoration: recipe.shellDecoration(focused: true),
            ),
            canvas: Colors.grey.shade400,
          ),
        );
        final at = await _sampler(tester);
        final centre = Offset(24 + radius, 24 + radius);
        // `0 0 0 2px gap, 0 0 0 4px ring`: gap in (r, r+2), ring in (r+2, r+4).
        final gap = _diag(at, centre, radius + 1);
        final ring = _diag(at, centre, radius + 3);
        expect(
          gap.computeLuminance(),
          isNot(closeTo(ring.computeLuminance(), .2)),
        );
        // The gap is the focus ring's surface colour and the ring its ink.
        final layers = t.shadowLayers('shadow.composerFocus');
        expect(gap.toARGB32(), isNot(Colors.grey.shade400.toARGB32()));
        expect(
          (gap.r - layers.first.color.r).abs() +
              (gap.g - layers.first.color.g).abs(),
          lessThan(.25),
          reason: 'gap ${gap.toARGB32().toRadixString(16)} on the diagonal',
        );
        expect(
          (ring.r - layers.last.color.r).abs() +
              (ring.g - layers.last.color.g).abs(),
          lessThan(.25),
          reason: 'ring ${ring.toARGB32().toRadixString(16)} on the diagonal',
        );
      });

      testWidgets('the notification centre ring is not cut at the corner arc', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            theme,
            const RaftNotificationCenter(width: 300, height: 200, entries: []),
            canvas: dark ? const Color(0xff1b1b19) : Colors.white,
          ),
        );
        final at = await _sampler(tester);
        final canvas = at(2, 2);
        // `rounded-container` is 10px: the 1px ring sits at 10..11 from the arc centre.
        final onArc = _diag(at, const Offset(34, 34), 10.5);
        final onEdge = at(24 - 0.5, 150);
        expect(
          (onEdge.r - canvas.r).abs() +
              (onEdge.g - canvas.g).abs() +
              (onEdge.b - canvas.b).abs(),
          greaterThan(.08),
          reason: 'the ring is visible on the straight edge',
        );
        expect(
          (onArc.r - canvas.r).abs() +
              (onArc.g - canvas.g).abs() +
              (onArc.b - canvas.b).abs(),
          greaterThan(.04),
          reason: 'and still there on the corner arc',
        );
      });

      testWidgets(
        'overflow clip follows the padding box, so a fill never covers the border',
        (tester) async {
          final rt = t.recipeTokens;
          final card = RaftCardRecipe.resolve(
            theme: t.recipeTheme,
            states: t.recipeStates(),
            tokens: rt,
          ).root;
          await tester.pumpWidget(
            _host(
              theme,
              RaftRecipeBox(
                style: card,
                tokens: rt,
                applyText: false,
                clip: true,
                width: 80,
                height: 60,
                child: const ColoredBox(color: Color(0xffff0000)),
              ),
            ),
          );
          final at = await _sampler(tester);
          // `rounded-container` is 10px with a 1px border: the border ring is
          // 9..10 from the arc centre. The card's header fill is red here.
          final onBorder = _diag(at, const Offset(34, 34), 9.5);
          expect(
            onBorder.g,
            greaterThan(.1),
            reason:
                'the hairline border shows, not the fill (${onBorder.toARGB32().toRadixString(16)})',
          );
          // The padding box itself is the child's.
          expect(at(60, 54).r, greaterThan(.9));
          expect(at(60, 54).g, lessThan(.1));
        },
      );
    });

    testWidgets(
      '[$mode] settings navigation follows the raft-ui SidebarItem rows',
      (tester) async {
        final rt = t.recipeTokens;
        RaftSettingsNavEntry entry(String id, RaftGlyph glyph) =>
            RaftSettingsNavEntry(id: id, label: id, glyph: glyph, onTap: () {});
        await tester.pumpWidget(
          _host(
            theme,
            SizedBox(
              width: 224,
              child: RaftSettingsSidebarList(
                activeId: 'account',
                groups: [
                  RaftSettingsNavGroup('Personal', [
                    entry('account', RaftGlyph.user),
                    entry('appearance', RaftGlyph.type),
                  ]),
                  RaftSettingsNavGroup('Server', [
                    entry('profile', RaftGlyph.user),
                  ]),
                ],
              ),
            ),
          ),
        );
        Rect rect(String id) =>
            tester.getRect(find.byKey(ValueKey('workspace-settings-nav-$id')));
        // `h-9` rows, `my-px` margins that collapse to a 37px pitch.
        expect(rect('account').height, 36);
        expect(rect('account').width, 224);
        expect(rect('appearance').top - rect('account').top, 37);
        // `SidebarGroupLabel`: `px-2 pt-4 pb-1.5`, 13/18 bold hint.
        final label = tester.widget<RaftCssText>(
          find.widgetWithText(RaftCssText, 'Personal'),
        );
        expect(label.style!.fontSize, 13);
        expect(label.style!.fontWeight, FontWeight.w700);
        final labelRect = tester.getRect(
          find.widgetWithText(RaftCssText, 'Workspace'),
        );
        expect(labelRect.left - 24, 8, reason: 'px-2');
        // The yellow sticker: ink border 1.5px, brand fill, 8px radius; rest rows have none.
        final active = tester.widget<Container>(
          find
              .descendant(
                of: find.byKey(
                  const ValueKey('workspace-settings-nav-account'),
                ),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = active.decoration! as BoxDecoration;
        final item = RaftSidebarItemRecipe.resolve(
          theme: t.recipeTheme,
          states: t.recipeStates(extra: ['data-active']),
          tokens: rt,
        ).sidebarItem;
        expect(decoration.color, item.backgroundColor!.resolve(rt));
        expect(decoration.borderRadius, BorderRadius.circular(8));
        expect((decoration.border! as Border).top.width, 1.5);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('workspace-settings-nav-account')),
            matching: find.byWidgetPredicate(
              (w) => w is RaftIcon && w.size == 16,
            ),
          ),
          findsOneWidget,
        );
        // Row text is `text-subhead`: 15/20, bold when active, medium otherwise.
        TextStyle titleStyle(String id) => tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(ValueKey('workspace-settings-nav-$id')),
                matching: find.byType(Text),
              ),
            )
            .style!;
        expect(titleStyle('account').fontSize, 15);
        expect(titleStyle('account').fontWeight, FontWeight.w700);
        expect(titleStyle('appearance').fontWeight, FontWeight.w500);
      },
    );

    testWidgets('[$mode] segmented control items sit in the muted track', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          theme,
          RaftSegmentedControl<String>(
            value: 'a',
            items: const [
              RaftSegmentedOption(value: 'a', label: 'One'),
              RaftSegmentedOption(value: 'b', label: 'Two'),
            ],
            onChanged: (_) {},
          ),
        ),
      );
      final track = RaftSegmentedControlRecipe.resolve(
        theme: t.recipeTheme,
        states: t.recipeStates(),
        tokens: t.recipeTokens,
      ).root;
      final at = await _sampler(tester);
      // The left strip of the track (`p-[3px]`) is the track fill, not the canvas.
      expect(at(24 + 1.5, 24 + 16).toARGB32(), isNot(Colors.white.toARGB32()));
      expect(
        at(24 + 1.5, 24 + 16).computeLuminance(),
        closeTo(at(24 + 1.5, 24 + 10).computeLuminance(), .05),
      );
      expect(track.backgroundColor, isNotNull);
    });
  }
}
