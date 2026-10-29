@Tags(['look-elegant'])
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '[K09e] ${dark ? 'dark' : 'light'} frozen Elegant attention paints Source indicator/mask, suppresses active',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        var selected = 'search';
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(
              pack: packForThemeId(elegantThemePackId),
              dark: dark,
            ),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, update) => Align(
                  alignment: Alignment.topLeft,
                  child: RepaintBoundary(
                    key: boundary,
                    child: SizedBox(
                      width: 64,
                      child: RaftDensityScope(
                        density: RaftDensity.desktop,
                        child: RaftWorkspaceRail(
                          destinations: const [
                            RaftRailDestination(
                              id: 'search',
                              label: 'Search',
                              glyph: RaftGlyph.search,
                            ),
                            RaftRailDestination(
                              id: 'chat',
                              label: 'Chat',
                              glyph: RaftGlyph.messageSquare,
                              attention: true,
                            ),
                          ],
                          selected: selected,
                          onSelected: (value) => update(() => selected = value),
                          workspaceName: 'Visual',
                          onWorkspace: () {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final attention = find.byType(RaftRailAttention);
        expect(attention, findsOneWidget);
        final indicator = find.byKey(
          const ValueKey('rail-attention-indicator'),
        );
        expect(tester.getSize(indicator), const Size.square(8));
        final mask = find.byKey(const ValueKey('rail-attention-mask'));
        expect(mask, findsOneWidget);
        final glyphBounds = tester.getRect(attention);
        final indicatorBounds = tester.getRect(indicator);
        expect(indicatorBounds.top, glyphBounds.top - 2);
        expect(indicatorBounds.right, glyphBounds.right + 4);
        final box = tester.widget<RaftRecipeBox>(indicator);
        final tokens = RaftTokens.of(tester.element(indicator));
        final expected = RaftStatusRecipe.resolve(
          theme: tokens.recipeTheme,
          size: RaftStatusRecipeSize.sm,
          attention: true,
          variant: RaftStatusRecipeVariant.primary,
          states: tokens.recipeStates(),
          tokens: tokens.recipeTokens,
        ).root;
        expect(
          box.style.decoration(tokens.recipeTokens).border,
          expected.decoration(tokens.recipeTokens).border,
        );
        // Observe real paint: the dot centre is the exact resolved fill; masks
        // are rasterized rather than accepted only because a ShaderMask exists.
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final point =
            indicatorBounds.center - tester.getTopLeft(find.byKey(boundary));
        await tester.runAsync(() async {
          final image = await render.toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final offset =
              (point.dy.floor() * image.width + point.dx.floor()) * 4;
          final color = box.style.backgroundColor!
              .resolve(tokens.recipeTokens)
              .toARGB32();
          expect(bytes.getUint8(offset), color >> 16 & 255);
          expect(bytes.getUint8(offset + 1), color >> 8 & 255);
          expect(bytes.getUint8(offset + 2), color & 255);
          // Pinned Chromium147 painted the actual Source recipe expression:
          // light [239,199,61], dark [254,218,116].
          // Theme token bytes are already quantized before this local mix;
          // Chrome mixes the original float colours. Retain the one-byte
          // light-green quantization difference, with no colour patch.
          final source = dark ? [254, 218, 116] : [239, 199, 61];
          for (var channel = 0; channel < 3; channel++) {
            expect(
              bytes.getUint8(offset + channel),
              closeTo(source[channel], 1),
            );
          }
          // Below the upper-right dot, the real SVG stroke must also gain
          // the recipe's warm attention tint through the radial mask.
          final origin =
              glyphBounds.topLeft - tester.getTopLeft(find.byKey(boundary));
          var tinted = 0;
          for (var y = 7; y < glyphBounds.height.floor(); y++) {
            for (var x = 0; x < glyphBounds.width.floor(); x++) {
              final pixel =
                  ((origin.dy.floor() + y) * image.width +
                      origin.dx.floor() +
                      x) *
                  4;
              if (bytes.getUint8(pixel) - bytes.getUint8(pixel + 2) > 40)
                tinted++;
            }
          }
          expect(tinted, greaterThan(0));
          expect(find.byType(ImageFiltered), findsOneWidget);
          image.dispose();
        });
        await tester.tap(find.byKey(const ValueKey('rail-chat')));
        await tester.pumpAndSettle();
        expect(selected, 'chat');
        expect(find.byType(RaftRailAttention), findsNothing);
        expect(find.byType(RaftRailUnreadCount), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
