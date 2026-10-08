import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Future<Color> sample(WidgetTester t) async {
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('paint')),
  );
  return (await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final index = (28 * image.width + 292) * 4;
    final color = Color.fromARGB(
      bytes.getUint8(index + 3),
      bytes.getUint8(index),
      bytes.getUint8(index + 1),
      bytes.getUint8(index + 2),
    );
    image.dispose();
    return color;
  }))!;
}

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final kind in RaftConversationNavKind.values) {
      testWidgets('$family/$dark/$kind selected hover has mounted paint', (
        t,
      ) async {
        final tokens = raftTheme(family, dark: dark).extension<RaftTokens>()!;
        var selected = true;
        var activations = 0;
        late StateSetter update;
        const row = ValueKey('conversation');
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Align(
                    alignment: Alignment.topLeft,
                    child: RepaintBoundary(
                      key: const ValueKey('paint'),
                      child: ColoredBox(
                        color: tokens.colors['layer-canvas-muted']!,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 300,
                            child: RaftNavItem(
                              key: row,
                              label: 'Owned conversation',
                              glyph: kind == RaftConversationNavKind.channel
                                  ? RaftGlyph.hash
                                  : RaftGlyph.user,
                              conversationKind: kind,
                              selected: selected,
                              onTap: () => activations++,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(t.getCenter(find.byKey(row)));
        await t.pumpAndSettle();
        final selectedFill = tokens.brutal
            ? tokens.colors['color-brutal-pink']!
            : tokens.colors['fill-muted']!;
        // The blank interior raster catches actual opaque hover/gradient paint.
        expect(await sample(t), selectedFill);
        AnimatedContainer face() => t.widget<AnimatedContainer>(
          find.descendant(
            of: find.byKey(row),
            matching: find.byType(AnimatedContainer),
          ),
        );
        final decoration = face().decoration! as BoxDecoration;
        expect(decoration.color, selectedFill);
        expect(
          decoration.borderRadius,
          BorderRadius.circular(tokens.brutal ? 0 : 6),
        );
        expect(
          t.widget<Text>(find.text('Owned conversation')).style!.color,
          tokens.colors['foreground-strong'],
        );
        final overlays = t.widgetList<DecoratedBox>(
          find.descendant(
            of: find.byKey(row),
            matching: find.byType(DecoratedBox),
          ),
        );
        expect(
          overlays.any(
            (w) =>
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).gradient != null,
          ),
          isFalse,
        );
        if (!tokens.brutal) {
          expect(decoration.boxShadow, isEmpty);
        }
        final bounds = t.getRect(find.byKey(row));
        await mouse.down(t.getCenter(find.byKey(row)));
        await t.pumpAndSettle();
        expect(t.getRect(find.byKey(row)), bounds);
        expect(await sample(t), selectedFill);
        await mouse.cancel();
        await t.pumpAndSettle();
        expect(activations, 0);
        update(() => selected = false);
        await t.pumpAndSettle();
        final hoverFill = tokens.brutal
            ? Colors.white
            : tokens.dark
            ? tokens.colors['ink-6']!
            : tokens.colors['fill-strong']!.withValues(alpha: .8);
        expect((face().decoration! as BoxDecoration).color, hoverFill);
        await mouse.moveTo(const Offset(600, 500));
        await t.pumpAndSettle();
        update(() => selected = true);
        await t.pumpAndSettle();
        expect(await sample(t), selectedFill);
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pumpAndSettle();
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        expect(activations, 1);
        await mouse.removePointer();
      });
    }
  }
}
