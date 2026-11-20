import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/popover_shadow.dart';
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

  for (final (name, shadow, profiles) in [
    (
      'light',
      const BoxShadow(
        color: Color(0xff141111),
        offset: Offset(0, 12),
        blurRadius: (16 - .5) / .57735,
        spreadRadius: -12,
      ),
      {
        44: [67, 30, 11, 8],
        116: [74, 31, 11, 21],
        119: [74, 31, 11, 21],
        120: [74, 31, 11, 21],
        121: [77, 35, 14, 25],
        124: [77, 35, 14, 25],
        217: [77, 35, 14, 25],
      },
    ),
    (
      'dark',
      const BoxShadow(
        color: Colors.black,
        offset: Offset(0, 16),
        blurRadius: (20 - .5) / .57735,
        spreadRadius: -12,
      ),
      {
        145: [105, 64, 36, 38],
        148: [105, 64, 36, 38],
        217: [105, 64, 36, 38],
      },
    ),
  ]) {
    for (final MapEntry(key: height, value: expected) in profiles.entries) {
      test('$name Chromium shadow profile at 302×$height and DPR 3', () async {
        const origin = Offset(80, 80);
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)
          ..scale(3)
          ..translate(origin.dx, origin.dy);
        RaftPopoverShadowPainter(
          [shadow],
          BorderRadius.circular(10),
          devicePixelRatio: 3,
          origin: () => origin,
        ).paint(canvas, Size(302, height.toDouble()));
        final picture = recorder.endRecording();
        final image = await picture.toImage(1386, 1230);
        try {
          final pixels = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final bottom = (80 + height) * 3;
          final center = (80 + height ~/ 2) * 3;
          expect([
            for (final (x, y) in [
              (600, bottom + 26),
              (600, bottom + 54),
              (600, bottom + 78),
              (211, center),
            ])
              pixels.getUint8((y * image.width + x) * 4 + 3),
          ], expected);
        } finally {
          image.dispose();
          picture.dispose();
        }
      });
    }
  }
}
