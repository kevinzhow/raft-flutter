import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/recipes/combobox.g.dart';

void main() {
  testWidgets('the Combobox shadow uses Chromium mask coverage at DPR 3', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1170, 1110);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final capture = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: packForThemeId(raftThemePackId)),
        home: RepaintBoundary(
          key: capture,
          child: ColoredBox(
            color: Colors.white,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 235 / 3,
                  top: 100,
                  width: 220,
                  height: 149,
                  child: Builder(
                    builder: (context) {
                      final tokens = RaftTokens.of(context);
                      final recipe = RaftComboboxRecipe.resolve(
                        inputOwner: RaftComboboxRecipeInputOwner.group,
                        states: tokens.recipeStates(responsive: true),
                        tokens: tokens.recipeTokens,
                      );
                      return RaftRecipeBox(
                        style: recipe.content,
                        tokens: tokens.recipeTokens,
                        clip: true,
                        snapShadowToDevicePixels: true,
                        child: const SizedBox.expand(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(capture),
    );
    await tester.pumpAndSettle();
    final samples = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3);
      try {
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        return [
          for (final (x, y) in [(500, 766), (500, 797), (220, 500)])
            bytes.getUint32((y * image.width + x) * 4),
        ];
      } finally {
        image.dispose();
      }
    });

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(samples, [0xe4e3e3ff, 0xf2f2f2ff, 0xf2f2f2ff]);
  });
}
