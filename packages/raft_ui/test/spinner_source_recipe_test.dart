import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  // Exact published root custom properties, not a Flutter baseline.
  for (final spec in [
    (size: RaftSpinnerRecipeSize.xs, extent: 9.5, pixel: 4.0, gap: 1.5),
    (size: RaftSpinnerRecipeSize.sm, extent: 12.0, pixel: 5.0, gap: 2.0),
    (size: RaftSpinnerRecipeSize.md, extent: 14.0, pixel: 6.0, gap: 2.0),
    (size: RaftSpinnerRecipeSize.lg, extent: 19.0, pixel: 8.0, gap: 3.0),
  ]) {
    testWidgets('published pixel grid and reduced-motion alpha ${spec.size}', (
      tester,
    ) async {
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: packForThemeId(raftThemePackId)),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: DefaultTextStyle(
              // Make the current-color input explicitly opaque so the source
              // 20% dim state can be measured independently of its parent.
              style: const TextStyle(color: Colors.blue),
              child: Center(child: RaftSpinner(recipeSize: spec.size)),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(RaftSpinner)),
        Size.square(spec.extent),
      );
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.descendant(
          of: find.byType(RaftSpinner),
          matching: find.byType(RepaintBoundary),
        ),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          int alpha(double x, double y) => bytes.getUint8(
            ((y * 2).floor() * image.width + (x * 2).floor()) * 4 + 3,
          );
          expect(alpha(spec.pixel / 2, spec.pixel / 2), 255);
          expect(alpha(spec.pixel * 1.5 + spec.gap, spec.pixel / 2), 51);
        } finally {
          image.dispose();
        }
      });
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
    });
  }
  for (final dark in [false, true]) {
    testWidgets(
      'inverse spinner follows the source foreground role dark=$dark',
      (tester) async {
        addTearDown(() => tester.pumpWidget(const SizedBox()));
        const customInverse = Color(0xff176b42);
        final mode = const RaftModeValues(
          colors: {'foreground-inverse': customInverse},
        ).mergedWith(dark ? builtInRaftTheme.dark : builtInRaftTheme.light);
        final pack = RaftThemePack(
          id: 'source-spinner-role',
          name: {'en': 'Source spinner role'},
          version: '1.0.0',
          light: mode,
          dark: mode,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: pack, dark: dark),
            home: const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: Center(child: RaftSpinner(inverse: true)),
            ),
          ),
        );
        // Published Spinner uses text-foreground-inverse, never literal white.
        expect(
          tester.widget<RaftPixelSpinner>(find.byType(RaftPixelSpinner)).color,
          customInverse,
        );
      },
    );
  }
}
