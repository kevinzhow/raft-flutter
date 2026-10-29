import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'mobile_focus_outline_test.dart' show navItems;

typedef Shot = ({int width, Uint8List pixels});

Future<Shot> capture(WidgetTester tester, Finder finder) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final result = (
      width: image.width,
      pixels: Uint8List.fromList(data.buffer.asUint8List()),
    );
    image.dispose();
    return result;
  }))!;
}

int pixel(Shot shot, int x, int y) {
  final i = (y * shot.width + x) * 4, p = shot.pixels;
  return p[i + 3] << 24 | p[i] << 16 | p[i + 1] << 8 | p[i + 2];
}

void main() {
  // Modality and theme differences are the contract: never sample these away.
  for (final dark in [false, true]) {
    for (final density in RaftDensity.values) {
      testWidgets('docked focus paints 2px outside a 2px gap; selected shadow '
          'survives: dark=$dark/$density', (tester) async {
        const captureKey = ValueKey('docked-focus-capture');
        final captureFinder = find.byKey(captureKey);
        var selected = 'home', activations = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: captureKey,
                  child: SizedBox(
                    width: 412,
                    height: 200,
                    child: Center(
                      child: RaftDensityScope(
                        density: density,
                        child: StatefulBuilder(
                          builder: (context, setState) => RaftMobileNav(
                            items: navItems,
                            selectedId: selected,
                            viewportHeight: 915,
                            bottomInset: 0,
                            onSelected: (id) => setState(() {
                              selected = id;
                              activations++;
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final tasks = find.byKey(const ValueKey('focus-tab-tasks'));
        final gesture = await tester.startGesture(
          tester.getCenter(tasks),
          kind: density == RaftDensity.desktop
              ? PointerDeviceKind.mouse
              : PointerDeviceKind.touch,
        );
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 200));
        expect(selected, 'tasks');
        expect(activations, 1);
        final detector = tester.widget<FocusableActionDetector>(
          find.descendant(
            of: tasks,
            matching: find.byType(FocusableActionDetector),
          ),
        );
        expect(detector.focusNode!.hasFocus, isTrue);
        final outline = find.descendant(
          of: tasks,
          matching: find.byWidgetPredicate(
            (w) =>
                w is CustomPaint && w.foregroundPainter is RaftCssFocusOutline,
          ),
        );
        RaftCssFocusOutline painter() =>
            tester.widget<CustomPaint>(outline).foregroundPainter!
                as RaftCssFocusOutline;
        expect(painter().enabled, isFalse);
        final sticker = find.byKey(const ValueKey('mobile-nav-sticker-tasks'));
        BoxDecoration decoration() =>
            tester.widget<Container>(sticker).decoration! as BoxDecoration;
        final pointerShadows = decoration().boxShadow;
        expect(pointerShadows, isNotEmpty);
        final pointer = await capture(tester, captureFinder);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump(const Duration(milliseconds: 200));
        expect(selected, 'tasks');
        expect(activations, 2);
        expect(detector.focusNode!.hasFocus, isTrue);
        expect(painter().enabled, isTrue);
        expect(decoration().boxShadow, pointerShadows);
        final keyboard = await capture(tester, captureFinder);
        final origin = tester.getTopLeft(captureFinder);
        final face = tester.getRect(outline).shift(-origin);
        final left = face.left.round(), y = face.center.dy.floor();
        final colour = painter().color.toARGB32();
        // At a straight edge CSS outline occupies [-4,-2): 2px ink, then a
        // 2px untouched gap before the face. Check rendered output directly.
        for (final dx in [-4, -3]) {
          expect(pixel(pointer, left + dx, y), isNot(colour));
          expect(pixel(keyboard, left + dx, y), colour);
        }
        for (final dx in [-5, -2, -1, 0]) {
          expect(pixel(keyboard, left + dx, y), pixel(pointer, left + dx, y));
        }
        // Selection pixels inside the item, including the lateral shadow/ring,
        // stay identical. Outside the item the new outline intentionally paints
        // over the backdrop, so those pixels belong to the outline assertion.
        final selectedArea = tester
            .getRect(sticker)
            .shift(-origin)
            .inflate(4)
            .intersect(face);
        for (
          var yy = selectedArea.top.floor();
          yy < selectedArea.bottom.ceil();
          yy++
        ) {
          for (
            var xx = selectedArea.left.floor();
            xx < selectedArea.right.ceil();
            xx++
          ) {
            expect(
              pixel(keyboard, xx, yy),
              pixel(pointer, xx, yy),
              reason: 'Selection paint changed at ($xx,$yy).',
            );
          }
        }
        await tester.tap(find.byKey(const ValueKey('focus-tab-home')));
        await tester.pump(const Duration(milliseconds: 200));
        expect(selected, 'home');
        expect(activations, 3);
        expect(detector.focusNode!.hasFocus, isFalse);
        expect(painter().enabled, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }
}
