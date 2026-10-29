import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// raft-ui 0.7.0 `Input`: 44px, `px-3`, 16/24 field text, `rounded-control border-[1.5px] border-line-strong
// bg-layer-card`, invalid `border-danger-strong`, `focus:shadow-focus`, disabled `fill-muted` / `line-hairline`.
Widget _app(bool dark, Widget child, {double width = 358}) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, child: child),
    ),
  ),
);

/// The painted box of the input: its decoration, its content padding and the outer (focus ring) shadows.
Container _container(WidgetTester tester) => tester.widget<Container>(
  find
      .descendant(
        of: find.byType(RaftTextInput),
        matching: find.byType(Container),
      )
      .first,
);

BoxDecoration _decoration(WidgetTester tester) =>
    _container(tester).decoration! as BoxDecoration;

List<BoxShadow> _rings(WidgetTester tester) => [
  for (final paint in tester.widgetList<CustomPaint>(
    find.descendant(
      of: find.byType(RaftTextInput),
      matching: find.byType(CustomPaint),
    ),
  ))
    if (paint.painter is RaftOuterShadowPainter)
      ...(paint.painter! as RaftOuterShadowPainter).shadows,
];

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    final ui = RaftUiColors.of(dark);

    testWidgets(
      '$mode is 44px tall, full width, with 12px sides and 8px corners',
      (tester) async {
        await tester.pumpWidget(
          _app(dark, const RaftTextInput(hintText: 'you@example.com')),
        );
        expect(tester.getSize(find.byType(RaftTextInput)), const Size(358, 44));
        final decoration = _decoration(tester);
        expect(decoration.borderRadius, BorderRadius.circular(8));
        expect(
          _container(tester).padding,
          const EdgeInsets.symmetric(horizontal: 12),
        );
        expect(decoration.color, ui.layerCard);
        final border = decoration.border! as Border;
        expect(border.top.color, ui.lineStrong);
        // `border-[1.5px]` floors to whole device pixels like the other controls.
        expect(
          border.top.width,
          raftControlBorderPx(tester.element(find.byType(RaftTextInput)), 1.5),
        );
        expect(_rings(tester), isEmpty);
        expect(find.byType(Opacity), findsNothing);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.style!.fontSize, 16);
        expect(field.style!.height, 24 / 16);
        expect(field.style!.fontWeight, FontWeight.w400);
        expect(field.style!.color, ui.foreground);
        expect(field.decoration!.hintStyle!.color, ui.foregroundHint);
        // The 24px line sits centred in the 44px box.
        final line = tester.getRect(find.byType(EditableText));
        expect((line.center.dy - 22).abs(), lessThan(1));
      },
    );

    testWidgets('$mode a padding override lets the height follow the content', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dark,
          const RaftTextInput(padding: EdgeInsets.all(8), initialValue: 'x'),
        ),
      );
      expect(tester.getSize(find.byType(RaftTextInput)).height, lessThan(44));
      expect(
        tester.getSize(find.byType(RaftTextInput)).height,
        greaterThanOrEqualTo(24 + 16),
      );
    });

    testWidgets('$mode invalid swaps the border to danger-strong', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dark,
          const RaftTextInput(initialValue: 'not-an-email', invalid: true),
        ),
      );
      expect(
        (_decoration(tester).border! as Border).top.color,
        ui['danger-strong'],
      );
      expect(_decoration(tester).color, ui.layerCard);
    });

    testWidgets(
      '$mode disabled reads fill-muted / line-hairline / foreground-disabled',
      (tester) async {
        await tester.pumpWidget(
          _app(
            dark,
            const RaftTextInput(
              initialValue: 'mia@botiverse.build',
              hintText: 'h',
              enabled: false,
            ),
          ),
        );
        final box = _decoration(tester);
        expect(box.color, ui.fillMuted);
        expect((box.border! as Border).top.color, ui.lineHairline);
        final ink = ui.foregroundDisabled;
        expect(
          tester.widget<TextField>(find.byType(TextField)).style!.color,
          ink,
        );
        expect(
          tester
              .widget<TextField>(find.byType(TextField))
              .decoration!
              .hintStyle!
              .color,
          ink,
        );
        expect(find.byType(Opacity), findsNothing);
        await tester.enterText(find.byType(TextField), 'nope');
        expect(find.text('mia@botiverse.build'), findsOneWidget);
      },
    );

    testWidgets(
      '$mode focus draws the focus ring and keeps the field mounted',
      (tester) async {
        final changes = <String>[];
        await tester.pumpWidget(
          _app(dark, RaftTextInput(onChanged: changes.add)),
        );
        expect(_rings(tester), isEmpty);
        await tester.tap(find.byType(TextField));
        await tester.pump();
        expect(
          [for (final ring in _rings(tester)) (ring.spreadRadius, ring.color)],
          [
            // CSS lists the top layer first; Flutter paints the first shadow underneath.
            for (final layer in ui.focusRing.layers.reversed)
              (layer.spread, layer.color),
          ],
        );
        await tester.enterText(find.byType(TextField), 'hello');
        expect(changes, ['hello']);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isTrue,
        );
        expect(tester.getSize(find.byType(RaftTextInput)).height, 44);
      },
    );

    testWidgets(
      '$mode the Material-hosted field keeps its border on focus and draws the ring outside',
      (tester) async {
        await tester.pumpWidget(
          _app(
            dark,
            const RaftFieldSurface(
              child: TextField(decoration: InputDecoration(hintText: 'Name')),
            ),
          ),
        );
        final theme = Theme.of(tester.element(find.byType(TextField)));
        final border =
            theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
        expect(border.borderRadius, BorderRadius.circular(8));
        expect(border.borderSide.color, ui.lineStrong);
        expect(border.borderSide.width, 1.5);
        expect(
          (theme.inputDecorationTheme.disabledBorder! as OutlineInputBorder)
              .borderSide
              .color,
          ui.lineHairline,
        );
        expect(
          (theme.inputDecorationTheme.errorBorder! as OutlineInputBorder)
              .borderSide
              .color,
          ui['danger-strong'],
        );
        expect(theme.inputDecorationTheme.fillColor, isNotNull);
        await tester.tap(find.byType(TextField));
        await tester.pump();
        final rings = tester.widget<RaftOuterRings>(
          find.byType(RaftOuterRings),
        );
        expect(rings.rings.length, ui.focusRing.layers.length);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isTrue,
        );
      },
    );
  }
}
