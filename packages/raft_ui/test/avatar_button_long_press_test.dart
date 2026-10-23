// Web SenderAvatar long press: 500ms of touch runs onLongPress and swallows
// the tap; a quick touch and any mouse click still press.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('touch long press, touch tap and mouse click', (t) async {
    var pressed = 0, held = 0;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: Center(
            child: RaftAvatarButton(
              semanticLabel: 'avatar',
              onPressed: () => pressed++,
              onLongPress: () => held++,
              child: const SizedBox(width: 32, height: 32),
            ),
          ),
        ),
      ),
    );
    final at = t.getCenter(find.byType(RaftAvatarButton));
    final hold = await t.startGesture(at, kind: PointerDeviceKind.touch);
    await t.pump(const Duration(milliseconds: 600));
    await hold.up();
    await t.pump();
    expect((pressed, held), (0, 1));

    final quick = await t.startGesture(at, kind: PointerDeviceKind.touch);
    await t.pump(const Duration(milliseconds: 100));
    await quick.up();
    await t.pump();
    expect((pressed, held), (1, 1));

    final slow = await t.startGesture(at, kind: PointerDeviceKind.mouse);
    await t.pump(const Duration(milliseconds: 700));
    await slow.up();
    await t.pump();
    expect((pressed, held), (2, 1));

    // Dragging further than the touch slop before 500ms cancels the hold.
    final drift = await t.startGesture(at, kind: PointerDeviceKind.touch);
    await drift.moveBy(const Offset(24, 0));
    await t.pump(const Duration(milliseconds: 600));
    await drift.up();
    await t.pump();
    expect(held, 1);
  });
}
