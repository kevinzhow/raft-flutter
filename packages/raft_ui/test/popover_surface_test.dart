import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/popover_surface.dart';
import 'package:raft_ui/src/theme.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark keeps source content layout and paint-only shadows',
      (t) async {
        var calls = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
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
        final expected = family == RaftFamily.brutal
            ? const Size(224, 40)
            : const Size(220, 36);
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
  test('light Popover is source XL, not menu LG and not a real border', () {
    final r = RaftPopoverSurfaceRecipe(
      raftTheme(RaftFamily.elegant).extension<RaftTokens>()!,
    );
    expect(r.borderWidth, 0);
    expect(r.radius, 6);
    expect(r.cssShadows.length, 5);
    expect(r.cssShadows[0].offset, const Offset(0, .5));
    expect(r.cssShadows[1].spread, 1);
    expect(r.cssShadows[2].offset, const Offset(0, 18));
    expect(r.cssShadows[2].blur, 24);
    expect(r.cssShadows[2].sigma, 12);
    expect(r.cssShadows[2].spread, -12);
    expect(r.innerRing, isNull);
  });
  test('dark XL preserves separate top inset and inner ring without layout padding', () {
    final r = RaftPopoverSurfaceRecipe(
      raftTheme(RaftFamily.elegant, dark: true).extension<RaftTokens>()!,
    );
    expect(r.borderWidth, 0);
    expect(r.topInset!.a, closeTo(.06, .0001));
    expect(r.innerRing!.a, closeTo(.04, .0001));
    expect(r.cssShadows.map((s) => s.offset.dy), [0, 24, 10, 4]);
    expect(r.cssShadows.map((s) => s.blur), [0, 44, 16, 6]);
    expect(r.cssShadows.map((s) => s.spread), [1, -12, -6, -3]);
  });
  testWidgets('theme replacement changes paint while keeping Elegant extent', (
    t,
  ) async {
    Widget host(bool dark) => MaterialApp(
      theme: raftTheme(RaftFamily.elegant, dark: dark),
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
    'dark inset chrome really paints above fill without becoming a border',
    (t) async {
      const captureKey = ValueKey('popover-paint-receipt');
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant, dark: true),
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
          expect(top, greaterThan(center));
        } finally {
          image.dispose();
        }
      });
    },
  );
}
