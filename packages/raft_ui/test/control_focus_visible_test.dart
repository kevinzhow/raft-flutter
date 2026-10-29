import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    testWidgets(
      '$kind focus keeps semantic focus but never paints keyboard outline; keyboard restores it',
      (t) async {
        final node = FocusNode();
        addTearDown(node.dispose);
        var count = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(
              body: RaftControl(
                key: const Key('control'),
                focusNode: node,
                onPressed: () => count++,
                child: const Text('Action'),
              ),
            ),
          ),
        );
        final pointer = await t.startGesture(
          t.getCenter(find.byKey(const Key('control'))),
          kind: kind,
        );
        await pointer.up();
        await t.pumpAndSettle();
        expect(node.hasFocus, true);
        expect(count, 1);
        List<BoxShadow> shadows() => t
            .widgetList<CustomPaint>(
              find.descendant(
                of: find.byKey(const Key('control')),
                matching: find.byType(CustomPaint),
              ),
            )
            .map((w) => w.painter)
            .whereType<RaftOuterShadowPainter>()
            .expand((p) => p.shadows)
            .toList();
        final before = shadows();
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        expect(count, 2);
        expect(shadows().length, greaterThan(before.length));
        // A subsequent real pointer interaction removes only focus-visible paint.
        final again = await t.startGesture(
          t.getCenter(find.byKey(const Key('control'))),
          kind: kind,
        );
        await again.up();
        await t.pumpAndSettle();
        expect(count, 3);
        expect(node.hasFocus, true);
        expect(shadows(), before);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
