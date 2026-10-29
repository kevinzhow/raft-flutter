import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/popover_surface.dart';
import 'package:raft_ui/src/theme.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} keeps source content layout and paint-only shadows',
      (t) async {
        var calls = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Center(
                child: RaftPopoverSurface(
                  child: SizedBox(
                    width: 220,
                    height: 36,
                    child: GestureDetector(
                      key: const ValueKey('surface-action'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => calls++,
                      child: const Text('Public action'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final surface = find.byType(RaftPopoverSurface);
        final expected = const Size(220, 36);
        expect(t.getSize(surface), expected);
        expect(
          t.getSize(find.byKey(const ValueKey('surface-action'))),
          const Size(220, 36),
        );
        await t.tap(find.text('Public action'));
        expect(calls, 1);
        final rect = t.getRect(surface);
        // Painted outer shadow must never become an additional action target.
        await t.tapAt(rect.bottomRight + const Offset(2, 2));
        expect(calls, 1);
        expect(t.takeException(), isNull);
      },
    );
  }
  test(
    'light Popover is elevation-float, not menu LG and not a real border',
    () {
      final r = RaftPopoverSurfaceRecipe(raftTheme().extension<RaftTokens>()!);
      expect(r.borderWidth, 0);
      // `rounded-container ring-1 ring-line-seam` (raft-ui 0.7 popover).
      expect(r.radius, 10);
      expect(r.ringWidth, 1);
      expect(r.cssShadows.length, 2);
      expect(r.cssShadows[0].offset, const Offset(0, 1));
      expect(r.cssShadows[0].blur, 0);
      expect(r.cssShadows[0].spread, 0);
      expect(r.cssShadows[1].offset, const Offset(0, 12));
      expect(r.cssShadows[1].blur, 32);
      expect(r.cssShadows[1].sigma, 16);
      expect(r.cssShadows[1].spread, -12);
      expect(r.topInset, isNull);
      expect(r.innerRing, isNull);
    },
  );
  test(
    'dark elevation-float is a 1px outer ring plus drop, with no inset layers',
    () {
      final r = RaftPopoverSurfaceRecipe(
        raftTheme(dark: true).extension<RaftTokens>()!,
      );
      expect(r.borderWidth, 0);
      expect(r.topInset, isNull);
      expect(r.innerRing, isNull);
      expect(r.cssShadows.map((s) => s.offset.dy), [0, 16]);
      expect(r.cssShadows.map((s) => s.blur), [0, 40]);
      expect(r.cssShadows.map((s) => s.spread), [1, -12]);
    },
  );
  testWidgets('theme replacement changes paint while keeping Elegant extent', (
    t,
  ) async {
    Widget host(bool dark) => MaterialApp(
      theme: raftTheme(dark: dark),
      home: const Center(
        child: RaftPopoverSurface(child: SizedBox(width: 220, height: 36)),
      ),
    );
    await t.pumpWidget(host(false));
    final before = t.getSize(find.byType(RaftPopoverSurface));
    await t.pumpWidget(host(true));
    await t.pumpAndSettle();
    expect(t.getSize(find.byType(RaftPopoverSurface)), before);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'dark popover paints no inset chrome: the edge is the plain fill',
    (t) async {
      const captureKey = ValueKey('popover-paint-receipt');
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: true),
          home: const Center(
            child: RepaintBoundary(
              key: captureKey,
              child: RaftPopoverSurface(
                child: SizedBox(width: 220, height: 36),
              ),
            ),
          ),
        ),
      );
      expect(t.getSize(find.byKey(captureKey)), const Size(220, 36));
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(captureKey),
      );
      await t.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final top = bytes.getUint8((110 * 4));
          final center = bytes.getUint8((18 * 220 + 110) * 4);
          expect(top, center);
        } finally {
          image.dispose();
        }
      });
    },
  );
}
