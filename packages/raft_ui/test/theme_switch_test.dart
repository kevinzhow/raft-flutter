import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:raft_theme/raft_theme.dart';

import 'dart:convert';
import 'dart:ui' show Tristate;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// Independent source expectations: raft-ui 0.7.1 switchRecipe.
void main() {
  for (final id in raftThemeMatrix([raftThemePackId])) {
    for (final dark in [false, true]) {
      testWidgets('$id dark=$dark preserves both source switch sizes', (
        t,
      ) async {
        addTearDown(() async {
          await t.pumpWidget(const SizedBox.shrink());
        });
        for (final size in RaftSwitchSize.values) {
          await t.pumpWidget(
            MaterialApp(
              themeAnimationDuration: Duration.zero,
              theme: raftTheme(pack: packForThemeId(id), dark: dark),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: RaftDensityScope(
                    density: RaftDensity.desktop,
                    child: RaftSwitch(
                      value: false,
                      size: size,
                      onChanged: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          );
          // raft-ui 0.95.3 `md:pointer-fine` switch: 38x22 with a mouse from 768px.
          const expected = Size(38, 22);
          expect(t.getSize(find.byType(RaftSwitch)), expected, reason: '$size');
        }
      });
      testWidgets(
        '$id dark=$dark pointer keyboard disabled and touch semantics',
        (t) async {
          final handle = t.ensureSemantics();
          try {
            addTearDown(() async {
              await t.pumpWidget(const SizedBox.shrink());
            });
            var value = false;
            var enabled = true;
            final calls = <bool>[];
            late StateSetter change;
            await t.pumpWidget(
              MaterialApp(
                themeAnimationDuration: Duration.zero,
                theme: raftTheme(pack: packForThemeId(id), dark: dark),
                home: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, rebuild) {
                      change = rebuild;
                      return MediaQuery(
                        data: const MediaQueryData(disableAnimations: true),
                        child: RaftDensityScope(
                          density: RaftDensity.touch,
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: RaftSwitch(
                              value: value,
                              enabled: enabled,
                              semanticLabel: 'Setting',
                              onChanged: (next) {
                                calls.add(next);
                                rebuild(() => value = next);
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
            final control = find.byType(RaftSwitch);
            expect(t.getSemantics(control).rect.size.shortestSide, 48);
            await t.tap(control);
            await t.pump();
            expect(calls, [true]);
            expect(
              t.getSemantics(control).flagsCollection.isToggled,
              Tristate.isTrue,
            );
            await t.sendKeyEvent(LogicalKeyboardKey.space);
            await t.pump();
            await t.sendKeyEvent(LogicalKeyboardKey.enter);
            await t.pump();
            expect(calls, [true, false, true]);
            change(() => enabled = false);
            await t.pump();
            expect(
              t.getSemantics(control).flagsCollection.isEnabled,
              Tristate.isFalse,
            );
            await t.tap(control, warnIfMissed: false);
            await t.sendKeyEvent(LogicalKeyboardKey.space);
            await t.pump();
            expect(calls, [true, false, true]);
          } finally {
            handle.dispose();
          }
        },
      );
    }
  }
  RaftThemePack userSwitchPack({
    String? shape,
    String? edge,
    double? stroke,
    double inset = 6,
  }) => RaftThemePack.parse(
    jsonEncode({
      'format': raftThemePackFormat,
      'id': 'user:switch',
      'name': {'en': 'Custom'},
      'version': '1',
      'extends': 'raft',
      'modes': {
        'light': {
          'geometry': {
            'size.switch.width.sm': 64,
            'size.switch.height.sm': 32,
            'size.switch.thumb.sm': 20,
            'space.switchInset': inset,
            'motion.switchSlideMs': 0,
            'motion.switchColorMs': 0,
            if (stroke != null) 'stroke.control': stroke,
          },
          if (shape != null || edge != null)
            'options': {
              if (shape != null) 'switch.shape': shape,
              if (edge != null) 'control.edge': edge,
            },
        },
        'dark': {},
      },
    }),
  );
  Widget userSwitch(
    RaftThemePack pack,
    bool value, {
    RaftSwitchSize size = RaftSwitchSize.sm,
  }) => MaterialApp(
    themeAnimationDuration: Duration.zero,
    theme: raftTheme(pack: pack),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: const Key('user-switch-paint'),
          child: RaftSwitch(value: value, size: size, onChanged: (_) {}),
        ),
      ),
    ),
  );
  for (final mode in ['ring', 'square']) {
    testWidgets('custom $mode switch keeps interaction and semantics', (
      t,
    ) async {
      final semantics = t.ensureSemantics();
      addTearDown(() async => t.pumpWidget(const SizedBox.shrink()));
      try {
        var value = false;
        var enabled = true;
        final calls = <bool>[];
        late StateSetter change;
        final pack = mode == 'ring'
            ? userSwitchPack(edge: 'ring')
            : userSwitchPack(shape: 'square');
        await t.pumpWidget(
          MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: raftTheme(pack: pack),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, rebuild) {
                  change = rebuild;
                  return Align(
                    alignment: Alignment.topLeft,
                    child: RaftSwitch(
                      value: value,
                      enabled: enabled,
                      semanticLabel: 'Custom switch',
                      onChanged: (next) {
                        calls.add(next);
                        rebuild(() => value = next);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        );
        final control = find.byType(RaftSwitch);
        await t.tap(control);
        await t.pump();
        expect(calls, [true]);
        expect(
          t.getSemantics(control).flagsCollection.isToggled,
          Tristate.isTrue,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pump();
        expect(calls, [true, false]);
        change(() => enabled = false);
        await t.pump();
        expect(
          t.getSemantics(control).flagsCollection.isEnabled,
          Tristate.isFalse,
        );
        await t.tap(control, warnIfMissed: false);
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pump();
        expect(calls, [true, false]);
      } finally {
        semantics.dispose();
      }
    });
  }
  testWidgets(
    'explicit user geometry and zero motion reach the mounted Raft switch',
    (t) async {
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      addTearDown(() async => t.pumpWidget(const SizedBox.shrink()));
      final pack = userSwitchPack();
      await t.pumpWidget(userSwitch(pack, false));
      expect(t.getSize(find.byType(RaftSwitch)), const Size(64, 32));
      expect(t.getSize(find.byType(RaftCssBox).last), const Size(20, 20));
      final off = t.getTopLeft(find.byType(RaftCssBox).last);
      expect(off.dx - t.getTopLeft(find.byType(RaftSwitch)).dx, 6);
      await t.pumpWidget(userSwitch(pack, true));
      await t.pump();
      expect(t.getTopLeft(find.byType(RaftCssBox).last).dx - off.dx, 32);
    },
  );
  testWidgets('a thumb-only override retains recipe track and inset', (
    t,
  ) async {
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    addTearDown(() async => t.pumpWidget(const SizedBox.shrink()));
    final pack = RaftThemePack.parse(
      jsonEncode({
        'format': raftThemePackFormat,
        'id': 'user:thumb-only',
        'name': {'en': 'Custom'},
        'version': '1',
        'extends': 'raft',
        'modes': {
          'light': {
            'geometry': {'size.switch.thumb.sm': 18},
          },
          'dark': {},
        },
      }),
    );
    await t.pumpWidget(userSwitch(pack, false));
    expect(t.getSize(find.byType(RaftSwitch)), const Size(50, 30));
    expect(t.getSize(find.byType(RaftCssBox).last), const Size(18, 18));
    final off = t.getTopLeft(find.byType(RaftCssBox).last);
    expect(off.dx - t.getTopLeft(find.byType(RaftSwitch)).dx, 4);
    await t.pumpWidget(userSwitch(pack, true));
    await t.pumpAndSettle();
    expect(t.getTopLeft(find.byType(RaftCssBox).last).dx - off.dx, 24);
  });
  testWidgets('a size-specific override does not alter another size', (
    t,
  ) async {
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    addTearDown(() async => t.pumpWidget(const SizedBox.shrink()));
    // Six pixels on both edges leaves only 18px of height for a 22px thumb
    // in the 30px md track. Use a compatible shared inset to isolate size.
    final pack = userSwitchPack(inset: 4);
    await t.pumpWidget(userSwitch(pack, false, size: RaftSwitchSize.md));
    expect(t.getSize(find.byType(RaftSwitch)), const Size(50, 30));
    expect(t.getSize(find.byType(RaftCssBox).last), const Size(22, 22));
    final off = t.getTopLeft(find.byType(RaftCssBox).last);
    expect(off.dx - t.getTopLeft(find.byType(RaftSwitch)).dx, 4);
    await t.pumpWidget(userSwitch(pack, true, size: RaftSwitchSize.md));
    await t.pump();
    expect(t.getTopLeft(find.byType(RaftCssBox).last).dx - off.dx, 20);
  });
  testWidgets('a shared inset still applies to the other switch size', (
    t,
  ) async {
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    addTearDown(() async => t.pumpWidget(const SizedBox.shrink()));
    final pack = userSwitchPack();
    await t.pumpWidget(userSwitch(pack, false, size: RaftSwitchSize.md));
    expect(t.getSize(find.byType(RaftSwitch)), const Size(50, 30));
    // The original widget also constrained the 22px thumb to 18px high when
    // a 6px inset was applied on both sides of a 30px track.
    expect(t.getSize(find.byType(RaftCssBox).last), const Size(22, 18));
    final off = t.getTopLeft(find.byType(RaftCssBox).last);
    expect(off.dx - t.getTopLeft(find.byType(RaftSwitch)).dx, 6);
    await t.pumpWidget(userSwitch(pack, true, size: RaftSwitchSize.md));
    await t.pump();
    expect(t.getTopLeft(find.byType(RaftCssBox).last).dx - off.dx, 16);
  });
  testWidgets('an explicit square switch shape applies to track and thumb', (
    t,
  ) async {
    addTearDown(() async => t.pumpWidget(const SizedBox.shrink()));
    Future<Uint8List> pixels(bool value) async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpWidget(userSwitch(userSwitchPack(shape: 'square'), value));
      await t.pumpAndSettle();
      expect(t.getSize(find.byType(RaftSwitch)), const Size(64, 32));
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('user-switch-paint')),
      );
      return (await t.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return Uint8List.fromList(data!.buffer.asUint8List());
      }))!;
    }

    final off = await pixels(false);
    final on = await pixels(true);
    int pixel(Uint8List bytes, int x, int y) =>
        bytes.buffer.asByteData().getUint32((y * 64 + x) * 4);
    // The square track covers its top-left corner. The square thumb moves
    // from the left to the right when checked.
    expect(off[3], 255);
    expect(pixel(off, 10, 16), pixel(on, 48, 16));
    expect(pixel(off, 10, 16), isNot(pixel(off, 48, 16)));
    expect(pixel(on, 10, 16), isNot(pixel(on, 48, 16)));
  });
  testWidgets('an explicit control stroke preserves the thumb inset', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    addTearDown(() async => t.pumpWidget(const SizedBox.shrink()));
    await t.pumpWidget(userSwitch(userSwitchPack(stroke: 3), false));
    final boxes = t
        .widgetList<RaftCssBox>(
          find.descendant(
            of: find.byType(RaftSwitch),
            matching: find.byType(RaftCssBox),
          ),
        )
        .toList();
    expect(boxes, hasLength(2));
    expect(boxes.first.borderWidth, 3);
    final offset =
        t.getTopLeft(find.byType(RaftCssBox).last).dx -
        t.getTopLeft(find.byType(RaftSwitch)).dx;
    expect(offset, 6);
  });
  testWidgets('an explicit ring edge changes the switch paint', (t) async {
    addTearDown(() async => t.pumpWidget(const SizedBox.shrink()));
    Future<Uint8List> pixels(String edge) async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpWidget(userSwitch(userSwitchPack(edge: edge), false));
      await t.pumpAndSettle();
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('user-switch-paint')),
      );
      return (await t.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return Uint8List.fromList(data!.buffer.asUint8List());
      }))!;
    }

    final ink = await pixels('inkBorder');
    final ring = await pixels('ring');
    expect(listEquals(ink, ring), isFalse);
  });
  testWidgets(
    'Raft keeps the source thumb origin after device border quantization',
    (t) async {
      final snap = RaftBorderSnap.emulatedDeviceScaleFactor;
      addTearDown(t.view.reset);
      try {
        for (final emulated in [false, true]) {
          for (final entry in [(1.0, 3.5), (2.0, 4.0), (3.0, 23 / 6)]) {
            t.view.devicePixelRatio = entry.$1;
            RaftBorderSnap.emulatedDeviceScaleFactor = emulated;
            await t.pumpWidget(
              MaterialApp(
                themeAnimationDuration: Duration.zero,
                theme: raftTheme(),
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: RaftDensityScope(
                      density: RaftDensity.desktop,
                      child: RaftSwitch(value: false, onChanged: (_) {}),
                    ),
                  ),
                ),
              ),
            );
            final boxes = find.descendant(
              of: find.byType(RaftSwitch),
              matching: find.byType(RaftCssBox),
            );
            final left =
                t.getTopLeft(boxes.last).dx - t.getTopLeft(boxes.first).dx;
            expect(
              left,
              closeTo(emulated ? 4 : entry.$2, 1e-9),
              reason: 'dpr=${entry.$1} emulated=$emulated',
            );
          }
        }
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        RaftBorderSnap.emulatedDeviceScaleFactor = snap;
      }
    },
  );
  testWidgets('touch layout keeps the source minimum box at both sizes', (
    t,
  ) async {
    try {
      for (final id in raftThemeMatrix([raftThemePackId])) {
        for (final dark in [false, true]) {
          for (final size in RaftSwitchSize.values) {
            await t.pumpWidget(
              MaterialApp(
                themeAnimationDuration: Duration.zero,
                theme: raftTheme(
                  pack: packForThemeId(id),
                  dark: dark,
                  platform: TargetPlatform.android,
                ),
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: RaftDensityScope(
                      density: RaftDensity.touch,
                      child: RaftSwitch(
                        value: false,
                        size: size,
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            );
            expect(
              t.getSize(find.byType(RaftSwitch)),
              id == raftThemePackId ? const Size(50, 30) : const Size(48, 48),
              reason: '$id dark=$dark $size',
            );
          }
        }
      }
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  testWidgets(
    'explicit minimum target overrides the theme touch layout minimum',
    (t) async {
      try {
        for (final id in raftThemeMatrix([raftThemePackId])) {
          for (final minimum in [0.0, 60.0]) {
            await t.pumpWidget(
              MaterialApp(
                themeAnimationDuration: Duration.zero,
                theme: raftTheme(
                  pack: packForThemeId(id),
                  platform: TargetPlatform.android,
                ),
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: RaftDensityScope(
                      density: RaftDensity.touch,
                      child: RaftSwitch(
                        value: false,
                        onChanged: (_) {},
                        minimumTargetSize: minimum,
                      ),
                    ),
                  ),
                ),
              ),
            );
            expect(
              t.getSize(find.byType(RaftSwitch)),
              minimum == 60
                  ? const Size(60, 60)
                  : id == raftThemePackId
                  ? const Size(50, 30)
                  : const Size(28, 16),
            );
          }
        }
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
