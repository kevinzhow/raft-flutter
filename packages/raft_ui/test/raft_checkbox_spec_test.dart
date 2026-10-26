import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// raft-ui 0.7.1 `Checkbox` / `CheckboxIndicator`: a 20px ink-bordered sticker square (4px corners) or circle, a lucide
// check / minus on a `foreground` fill, `layer-card` when unchecked, `fill-muted` / `foreground-disabled` disabled.
Widget _app(bool dark, Widget child) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

RaftCssBox _graphic(WidgetTester tester) => tester.widget<RaftCssBox>(
  find.descendant(
    of: find.byType(RaftCheckboxIndicator),
    matching: find.byType(RaftCssBox),
  ),
);

Finder _glyph(RaftGlyph g) =>
    find.byWidgetPredicate((w) => w is RaftIcon && w.glyph == g);

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    final ui = RaftUiColors.of(dark);

    testWidgets('$mode is a 20px square with 4px corners, or a circle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(dark, RaftCheckbox(value: false, onChanged: (_) {})),
      );
      expect(tester.getSize(find.byType(RaftCheckbox)), const Size(20, 20));
      expect(_graphic(tester).radius, 4);
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
      expect(tester.getSize(find.byType(RaftCheckbox)), const Size(20, 20));
      expect(_graphic(tester).radius, 10);
      // The legacy sizes and the yellow variant collapse onto the single 0.7.1 look.
      await tester.pumpWidget(
        _app(dark, RaftCheckbox(value: true, onChanged: (_) {})),
      );
      expect(tester.getSize(find.byType(RaftCheckbox)), const Size(20, 20));
    });

    testWidgets('$mode unchecked, checked and indeterminate marks and fills', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(dark, RaftCheckbox(value: false, onChanged: (_) {})),
      );
      expect(_graphic(tester).fill, ui.layerCard);
      expect(_graphic(tester).borderColor, ui.lineStrong);
      expect(_glyph(RaftGlyph.check), findsNothing);
      expect(_glyph(RaftGlyph.minus), findsNothing);

      await tester.pumpWidget(
        _app(dark, RaftCheckbox(value: true, onChanged: (_) {})),
      );
      expect(_graphic(tester).fill, ui.foreground);
      expect(_graphic(tester).borderColor, ui.foreground);
      expect(_glyph(RaftGlyph.check), findsOneWidget);
      expect(
        tester.widget<RaftIcon>(_glyph(RaftGlyph.check)).color,
        ui['foreground-inverse'],
      );
      expect(tester.widget<RaftIcon>(_glyph(RaftGlyph.check)).size, 14);

      await tester.pumpWidget(
        _app(
          dark,
          RaftCheckbox(value: false, indeterminate: true, onChanged: (_) {}),
        ),
      );
      expect(_graphic(tester).fill, ui.foreground);
      expect(_glyph(RaftGlyph.minus), findsOneWidget);
      expect(_glyph(RaftGlyph.check), findsNothing);
    });

    testWidgets(
      '$mode disabled reads fill-muted / foreground-disabled, not opacity',
      (tester) async {
        await tester.pumpWidget(_app(dark, const RaftCheckbox(value: false)));
        expect(_graphic(tester).fill, ui.fillMuted);
        expect(
          _graphic(tester).borderColor,
          raftChromeBlend(ui.foregroundDisabled, ui.fillMuted),
        );
        expect(find.byType(Opacity), findsNothing);

        await tester.pumpWidget(_app(dark, const RaftCheckbox(value: true)));
        final fill = raftChromeBlend(ui.foregroundDisabled, ui.layerCanvas);
        expect(_graphic(tester).fill, fill);
        expect(
          _graphic(tester).borderColor,
          raftChromeBlend(ui.foregroundDisabled, fill),
        );
        expect(
          tester.widget<RaftIcon>(_glyph(RaftGlyph.check)).color,
          ui.layerCard,
        );
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

    testWidgets('$mode keyboard focus draws the focus ring on the 20px root', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(dark, RaftCheckbox(value: true, onChanged: (_) {})),
      );
      RaftCssBox root() =>
          tester.widget<RaftCssBox>(find.byType(RaftCssBox).first);
      expect(root().rings, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(root().rings, [
        for (final layer in ui.focusRing.layers)
          RaftRing(layer.spread, layer.color),
      ]);
    });

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
      expect(
        tester.widget<RaftIcon>(_glyph(RaftGlyph.check)).color!.a,
        closeTo(ui.foreground.a * .2, .01),
      );
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
  }
}
