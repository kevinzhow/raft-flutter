import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/recipes/button_variants.g.dart';
import 'package:raft_ui/src/recipes/search_trigger.g.dart';
import 'package:raft_ui/test_themes.dart';

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
  // Published raft-ui 0.7.0 SearchTrigger: bg-layer-card and
  // hover/active:press-overlay. Both states use the same single background
  // image, whose two color stops are --fill-pressed.
  for (final dark in [false, true]) {
    for (final flags in [
      <String>{},
      {'hover'},
      {'active'},
      {'hover', 'active'},
    ]) {
      testWidgets('generated search $dark/$flags paints one source overlay', (
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
                    expected = flags.isEmpty
                        ? paper
                        : Color.alphaBlend(
                            tokens.colors['fill-pressed']!,
                            paper,
                          );
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

  // The frozen looks keep their existing renderer. Record exact images for
  // before/after review when explicitly requested; normal test runs write none.
  for (final (id, dark) in raftThemeMatrix(
    [
      (elegantThemePackId, false),
      (elegantThemePackId, true),
      (brutalThemePackId, false),
    ],
    look: (v) => raftLookOf(v.$1),
    dark: (v) => v.$2,
  )) {
    for (final hover in [false, true]) {
      testWidgets('frozen $id/$dark/$hover retains recipe paint', (t) async {
        const key = Key('legacy-paint');
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(id), dark: dark),
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: key,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Builder(
                      builder: (context) {
                        final tokens = RaftTokens.of(context);
                        final rt = tokens.recipeTokens;
                        final root = RaftButtonRecipe.resolve(
                          theme: tokens.recipeTheme,
                          tokens: rt,
                          variant: RaftButtonRecipeVariant.default_,
                          size: RaftButtonRecipeSize.md,
                          states: tokens.recipeStates(hovered: hover),
                        ).root;
                        return RaftRecipeBox(
                          style: root,
                          tokens: rt,
                          width: 160,
                          child: const Text('Frozen control'),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        addTearDown(() async {
          await t.pumpWidget(const SizedBox());
        });
        await t.pumpAndSettle();
        final out = Platform.environment['RAFT_BACKGROUND_IMAGE_CAPTURE'];
        if (out != null) {
          await t.runAsync(() async {
            final image = await t
                .renderObject<RenderRepaintBoundary>(find.byKey(key))
                .toImage(pixelRatio: 1);
            try {
              final data = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              final dir = Directory(out)..createSync(recursive: true);
              File('${dir.path}/$id-$dark-$hover.png')
                  .writeAsBytesSync(data.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }
        expect(t.takeException(), isNull);
      });
    }
  }
}
