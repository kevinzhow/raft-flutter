import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

class _FocusRecipe extends RaftControlRecipe {
  _FocusRecipe(super.tokens);
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => focused ? const [BoxShadow(color: Colors.red, spreadRadius: 4)] : [];
}

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
            home: Scaffold(
              body: RaftControl(
                key: const Key('control'),
                focusNode: node,
                recipe: _FocusRecipe(
                  raftTheme(RaftFamily.elegant).extension<RaftTokens>()!,
                ),
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
        final surface = find.descendant(
          of: find.byKey(const Key('control')),
          matching: find.byType(AnimatedContainer),
        );
        BoxDecoration paint() =>
            t.widget<AnimatedContainer>(surface).decoration! as BoxDecoration;
        expect(paint().boxShadow, isEmpty);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        expect(count, 2);
        expect(paint().boxShadow!.single.color, Colors.red);
        // A subsequent real pointer interaction removes only focus-visible paint.
        final again = await t.startGesture(
          t.getCenter(find.byKey(const Key('control'))),
          kind: kind,
        );
        await again.up();
        await t.pumpAndSettle();
        expect(count, 3);
        expect(node.hasFocus, true);
        expect(paint().boxShadow, isEmpty);
      },
    );
  }
}
