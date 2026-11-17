import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/recipes/search_trigger.g.dart';

Future<List<int>> pixel(
  WidgetTester tester,
  Key key,
) async => (await tester.runAsync(() async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final image = await boundary.toImage(pixelRatio: 1);
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return data.buffer.asUint8List((18 * image.width + 180) * 4, 4).toList();
  } finally {
    image.dispose();
  }
}))!;

void main() {
  // Published raft-ui 0.95.3 SearchTrigger: bg-layer-card and active-only
  // overlay-medium. Hover keeps the card colour; active uses --fill-pressed.
  for (final dark in [false, true]) {
    for (final flags in [
      <String>{},
      {'hover'},
      {'active'},
      {'hover', 'active'},
    ]) {
      testWidgets('generated search $dark/$flags paints the source overlay', (
        t,
      ) async {
        const key = Key('recipe-paint');
        late Color expected;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: Builder(
                  builder: (context) {
                    final tokens = RaftTokens.of(context);
                    final rt = tokens.recipeTokens;
                    final recipe = RaftSearchTriggerRecipe.resolve(
                      tokens: rt,
                      states: tokens.recipeStates(extra: flags),
                    );
                    final paper = tokens.colors['layer-card']!;
                    expected = !flags.contains('active')
                        ? paper
                        // Chromium's 8-bit alpha (chrome-headless-shell 1234: dark fill-medium over layer-card
                        // paints 50,50,47).
                        : raftChromeBlend(tokens.colors['fill-medium']!, paper);
                    return RepaintBoundary(
                      key: key,
                      child: SizedBox(
                        width: 360,
                        child: RaftRecipeBox(
                          style: recipe.root,
                          tokens: rt,
                          child: const SizedBox(height: 12),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        addTearDown(() async {
          await t.pumpWidget(const SizedBox());
        });
        await t.pumpAndSettle();
        final argb = expected.toARGB32();
        expect(await pixel(t, key), [
          (argb >> 16) & 255,
          (argb >> 8) & 255,
          argb & 255,
          (argb >> 24) & 255,
        ]);
        expect(t.getSize(find.byKey(key)), const Size(360, 36));
        expect(t.takeException(), isNull);
      });
    }
  }
}
