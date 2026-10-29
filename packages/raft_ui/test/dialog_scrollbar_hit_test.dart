import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('packages/raft_ui/SpaceGrotesk')
      ..addFont(
        rootBundle.load('packages/raft_ui/assets/fonts/SpaceGrotesk.ttf'),
      );
    await loader.load();
  });
  for (final width in [390.0, 1280.0]) {
    for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
      for (final style in [
        'default',
        'thick',
        'hover',
        'inset',
        'thick-inset',
        'hover-inset',
      ]) {
        testWidgets(
          'scrollbar leaves $direction action edge clickable at width $width, style=$style',
          (t) async {
            t.view.physicalSize = Size(width, 844);
            t.view.devicePixelRatio = 1;
            t.platformDispatcher.textScaleFactorTestValue = 3.1;
            addTearDown(t.view.reset);
            addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
            addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
            var hits = 0;
            await t.pumpWidget(
              MaterialApp(
                theme: raftTheme(platform: TargetPlatform.linux).copyWith(
                  platform: TargetPlatform.linux,
                  scrollbarTheme: switch (style) {
                    'thick' || 'thick-inset' => const ScrollbarThemeData(
                      thickness: WidgetStatePropertyAll(28),
                      crossAxisMargin: 4,
                    ),
                    'hover' || 'hover-inset' => ScrollbarThemeData(
                      thickness: WidgetStateProperty.resolveWith<double?>(
                        (states) =>
                            states.contains(WidgetState.hovered) ? 28 : 8,
                      ),
                      crossAxisMargin: 4,
                    ),
                    _ => null,
                  },
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    padding: style.endsWith('inset')
                        ? const EdgeInsets.only(left: 17, right: 24)
                        : MediaQuery.paddingOf(context),
                  ),
                  child: RaftTextScaling(
                    child: Directionality(
                      textDirection: direction,
                      child: child!,
                    ),
                  ),
                ),
                home: Scaffold(
                  body: RaftModalBackdrop(
                    child: RaftDialog.card(
                      title: 'Details',
                      onClose: () {},
                      child: const SizedBox(
                        height: 1100,
                        child: Text('Long content'),
                      ),
                      footer: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: RaftButton(
                          key: const ValueKey('edge-action'),
                          label: 'Save',
                          onPressed: () => hits++,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            final action = find.byKey(const ValueKey('edge-action'));
            await t.ensureVisible(action);
            await t.pumpAndSettle();
            expect(Directionality.of(t.element(action)), direction);
            final rect = t.getRect(action);
            final leading = direction == TextDirection.ltr
                ? rect.left + 2
                : rect.right - 2;
            final trailing = direction == TextDirection.ltr
                ? rect.right - 2
                : rect.left + 2;
            await t.tapAt(Offset(leading, rect.center.dy));
            await t.pump();
            expect(hits, 1, reason: 'the leading edge must receive the tap');
            await t.tapAt(Offset(trailing, rect.center.dy));
            await t.pump();
            expect(
              hits,
              2,
              reason: 'the visible action edge must receive the tap',
            );
            if (style.endsWith('inset')) {
              final inside = direction == TextDirection.ltr
                  ? rect.right - 18
                  : rect.left + 8;
              await t.tapAt(Offset(inside, rect.center.dy));
              await t.pump();
              expect(
                hits,
                3,
                reason: 'the inset scrollbar must not steal action taps',
              );
            }
            final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
            await mouse.addPointer(location: rect.center);
            await mouse.moveTo(Offset(trailing, rect.center.dy));
            await t.pump();
            await t.pump(const Duration(milliseconds: 200));
            await mouse.down(Offset(trailing, rect.center.dy));
            await mouse.up();
            await t.pump();
            expect(
              hits,
              style.endsWith('inset') ? 4 : 3,
              reason: 'hovering near the scrollbar must not steal the action',
            );
            await mouse.removePointer();
            expect(t.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('desktop scrollbar remains draggable at large text size', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 3.1;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        builder: (context, child) => RaftTextScaling(child: child!),
        home: Scaffold(
          body: RaftModalBackdrop(
            child: RaftDialog.card(
              key: const ValueKey('scrolling-card'),
              title: 'Details',
              onClose: () {},
              child: const SizedBox(height: 1600, child: Text('Long content')),
              footer: RaftButton(
                key: const ValueKey('bottom-action'),
                label: 'Save',
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final action = find.byKey(const ValueKey('bottom-action'));
    final position = Scrollable.of(t.element(action)).position;
    await t.dragFrom(const Offset(195, 400), const Offset(0, -120));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    final before = position.pixels;
    expect(before, greaterThan(0));
    final paint = find.descendant(
      of: find.byKey(const ValueKey('scrolling-card')),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.foregroundPainter is ScrollbarPainter,
      ),
    );
    expect(paint, findsOneWidget);
    final painter =
        t.widget<CustomPaint>(paint).foregroundPainter! as ScrollbarPainter;
    final box = t.renderObject<RenderBox>(paint);
    final bounds = t.getRect(paint);
    Offset? point;
    for (double dx = 1; dx < 24 && point == null; dx += 1) {
      for (double y = bounds.top + 1; y < bounds.bottom - 1; y += 2) {
        final candidate = Offset(bounds.right - dx, y);
        if (painter.hitTestOnlyThumbInteractive(
          box.globalToLocal(candidate),
          PointerDeviceKind.mouse,
        )) {
          point = candidate;
          break;
        }
      }
    }
    expect(
      point,
      isNotNull,
      reason: 'the visible scrollbar thumb can be located',
    );
    final drag = await t.startGesture(point!, kind: PointerDeviceKind.mouse);
    await drag.moveBy(const Offset(0, 80));
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    expect(
      position.pixels,
      greaterThan(before),
      reason: 'dragging the thumb must scroll the dialog',
    );
    expect(t.takeException(), isNull);
  });
}
