import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:raft_theme/raft_theme.dart';

import 'dart:convert';
import 'dart:ui' show Tristate;
import 'dart:ui' as ui;

import 'package:raft_ui/raft_ui.dart';

// Independent source expectations: raft-ui 0.7.1 switchRecipe, and
// a57b9dab lib/src/switch.dart:65-81. Brutal dark uses all Elegant values.
void main() {
  for (final id in [raftThemePackId, elegantThemePackId, brutalThemePackId]) {
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
          final expected = id == raftThemePackId
              ? const Size(50, 30)
              : size == RaftSwitchSize.sm
              ? const Size(28, 16)
              : const Size(36, 20);
          expect(t.getSize(find.byType(RaftSwitch)), expected, reason: '$size');
          final recipe = RaftSwitchRecipe(
            tokens: RaftTokens.theme(pack: packForThemeId(id), dark: dark),
            size: size,
          );
          final square = id == brutalThemePackId && !dark;
          expect(
            recipe.thumbSize,
            id == raftThemePackId
                ? 22
                : size == RaftSwitchSize.sm
                ? (square ? 10 : 12)
                : (square ? 14 : 16),
          );
          expect(
            recipe.thumbInset,
            id == raftThemePackId
                ? 4
                : square
                ? 3
                : 2,
          );
          expect(
            recipe.travel,
            id == raftThemePackId
                ? 20
                : size == RaftSwitchSize.sm
                ? 12
                : 16,
          );
          expect(
            recipe.slideDuration,
            Duration(milliseconds: id == raftThemePackId ? 220 : 180),
          );
          expect(
            recipe.colorDuration,
            Duration(milliseconds: id == raftThemePackId ? 150 : 180),
          );
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
  testWidgets(
    'user geometry reaches the mounted switch without a pack-id branch',
    (t) async {
      final pack = RaftThemePack.parse(
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
                'space.switchInset': 6,
                'motion.switchSlideMs': 0,
                'motion.switchColorMs': 0,
              },
            },
            'dark': {},
          },
        }),
      );
      final tokens = RaftTokens.theme(pack: pack);
      final recipe = RaftSwitchRecipe(tokens: tokens, size: RaftSwitchSize.sm);
      expect(recipe.travel, 32);
      expect(recipe.thumbSize, 20);
      expect(recipe.thumbInset, 6);
      await t.pumpWidget(
        MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: raftTheme(pack: pack),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RaftSwitch(value: false, onChanged: (_) {}),
            ),
          ),
        ),
      );
      expect(t.getSize(find.byType(RaftSwitch)), const Size(64, 32));
      final off = t.getTopLeft(find.byType(RaftCssBox).last);
      await t.pumpWidget(
        MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: raftTheme(pack: pack),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RaftSwitch(value: true, onChanged: (_) {}),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.getTopLeft(find.byType(RaftCssBox).last).dx - off.dx, 32);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  test('dark switch bottom shadow retains source float colour precision', () {
    for (final id in [elegantThemePackId, brutalThemePackId]) {
      final source = const Color.from(
        alpha: .039203,
        red: .954685,
        green: .954685,
        blue: .969524,
      );
      final actual = RaftTokens.theme(
        pack: packForThemeId(id),
        dark: true,
      ).components.switchShadowBottom;
      expect(actual.a, closeTo(source.a, 1e-12));
      expect(actual.r, closeTo(source.r, 1e-12));
      expect(actual.g, closeTo(source.g, 1e-12));
      expect(actual.b, closeTo(source.b, 1e-12));
    }
  });
  testWidgets(
    'touch highlight mode suppresses source hover until mouse highlights resume',
    (t) async {
      final original = FocusManager.instance.highlightStrategy;
      final key = GlobalKey();
      final mouse = await t.createGesture(kind: ui.PointerDeviceKind.mouse);
      bool hoverPaint() {
        final painted = t
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .singleWhere(
              (paint) =>
                  paint.painter.runtimeType.toString() == '_SwitchPainter',
            );
        return (painted.painter as dynamic).hovered as bool;
      }

      try {
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTouch;
        final specimen = RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: Colors.white,
            child: SizedBox(
              width: 100,
              height: 60,
              child: Align(
                alignment: Alignment.topLeft,
                child: RaftDensityScope(
                  density: RaftDensity.desktop,
                  child: RaftSwitch(value: false, onChanged: (_) {}),
                ),
              ),
            ),
          ),
        );
        await t.pumpWidget(
          MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: raftTheme(pack: packForThemeId(brutalThemePackId)),
            home: Scaffold(
              body: Align(alignment: Alignment.topLeft, child: specimen),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(hoverPaint(), isFalse);
        await mouse.addPointer(location: const Offset(300, 300));
        await mouse.moveTo(t.getCenter(find.byType(RaftSwitch)));
        await t.pumpAndSettle();
        expect(hoverPaint(), isFalse);
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        await t.pumpAndSettle();
        expect(hoverPaint(), isTrue);
      } finally {
        await mouse.removePointer();
        await t.pumpWidget(const SizedBox.shrink());
        FocusManager.instance.highlightStrategy = original;
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
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
      for (final id in [
        raftThemePackId,
        elegantThemePackId,
        brutalThemePackId,
      ]) {
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
        for (final id in [
          raftThemePackId,
          elegantThemePackId,
          brutalThemePackId,
        ]) {
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
