import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// raft-ui 0.7.1 `IconTile`: a flat sticker-radius square sized like an avatar (19 / 27 / 35 / 51) with the
// glyph at 11 / 14 / 18 / 22; default / warning / information fills.
Widget _app(bool dark, Widget child) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

/// Blink composites a translucent token with a truncated 8-bit blend; Flutter with floats: one level apart.
void _expectNear(Color actual, Color expected) {
  for (final (a, e) in [
    (actual.r, expected.r),
    (actual.g, expected.g),
    (actual.b, expected.b),
  ]) {
    expect((a - e).abs() * 255, lessThanOrEqualTo(1.01));
  }
}

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    final ui = RaftUiColors.of(dark);

    testWidgets('$mode sizes and glyph sizes', (tester) async {
      for (final (size, tile, glyph) in [
        (RaftIconTileSize.xs, 19.0, 11.0),
        (RaftIconTileSize.sm, 27.0, 14.0),
        (RaftIconTileSize.md, 35.0, 18.0),
        (RaftIconTileSize.lg, 51.0, 22.0),
      ]) {
        await tester.pumpWidget(
          _app(dark, RaftIconTile(glyph: RaftGlyph.appWindow, size: size)),
        );
        expect(tester.getSize(find.byType(RaftIconTile)), Size.square(tile));
        expect(tester.getSize(find.byType(RaftIcon)), Size.square(glyph));
        // Centred in the tile.
        expect(
          tester.getCenter(find.byType(RaftIcon)),
          tester.getCenter(find.byType(RaftIconTile)),
        );
      }
      await tester.pumpWidget(
        _app(dark, const RaftIconTile(glyph: RaftGlyph.appWindow)),
      );
      expect(tester.getSize(find.byType(RaftIconTile)), const Size.square(35));
    });

    testWidgets('$mode variants fill the tile with the soft colours', (
      tester,
    ) async {
      Color fillOf(WidgetTester tester) {
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(RaftIconTile),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final decoration = box.decoration as BoxDecoration;
        expect(decoration.borderRadius, BorderRadius.circular(4));
        expect(decoration.shape, BoxShape.rectangle);
        return decoration.color!;
      }

      Color glyphColor(WidgetTester tester) =>
          tester.widget<RaftIcon>(find.byType(RaftIcon)).color!;

      await tester.pumpWidget(
        _app(dark, const RaftIconTile(glyph: RaftGlyph.appWindow)),
      );
      expect(fillOf(tester).a, 1);
      expect(glyphColor(tester).a, 1);

      await tester.pumpWidget(
        _app(
          dark,
          const RaftIconTile(
            glyph: RaftGlyph.octagonAlert,
            variant: RaftIconTileVariant.warning,
          ),
        ),
      );
      _expectNear(
        Color.alphaBlend(fillOf(tester), ui.layerCanvas),
        Color.alphaBlend(ui['warning-soft'], ui.layerCanvas),
      );
      expect(glyphColor(tester), ui.foreground);

      await tester.pumpWidget(
        _app(
          dark,
          const RaftIconTile(
            glyph: RaftGlyph.info,
            variant: RaftIconTileVariant.information,
          ),
        ),
      );
      _expectNear(
        Color.alphaBlend(fillOf(tester), ui.layerCanvas),
        Color.alphaBlend(ui['info-soft'], ui.layerCanvas),
      );
    });

    testWidgets('$mode a labelled tile is announced, a bare one is hidden', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          dark,
          const RaftIconTile(glyph: RaftGlyph.appWindow, semanticLabel: 'App'),
        ),
      );
      expect(find.bySemanticsLabel('App'), findsOneWidget);
      await tester.pumpWidget(
        _app(dark, const RaftIconTile(glyph: RaftGlyph.appWindow)),
      );
      expect(find.bySemanticsLabel('App'), findsNothing);
    });
  }

  test('app-window and octagon-alert come from the parity host lucide', () {
    expect(RaftGlyph.appWindow.lucideName, 'app-window');
    expect(RaftGlyph.appWindow.lucideVersion, '1.59.0');
    expect(RaftGlyph.octagonAlert.lucideName, 'octagon-alert');
    expect(RaftGlyph.octagonAlert.lucideVersion, '1.59.0');
  });
}
