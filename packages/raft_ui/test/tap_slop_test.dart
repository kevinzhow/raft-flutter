import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/tap_slop.dart';

void main() {
  for (final offset in [
    Offset.zero,
    const Offset(.142857142857, .095238095238),
  ]) {
    testWidgets('nearby action preserves editable input at $offset', (t) async {
      final focus = FocusNode();
      var actions = 0;
      try {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(platform: TargetPlatform.android),
            home: Scaffold(
              body: RaftTapSlopHost(
                child: SizedBox(
                  width: 200,
                  height: 150,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 32 + offset.dx,
                        top: 20 + offset.dy,
                        width: 120,
                        height: 24,
                        child: TextField(
                          focusNode: focus,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 32 + offset.dx,
                        top: 48 + offset.dy,
                        width: 32,
                        height: 32,
                        child: RaftTapSlopAnchor(
                          minSize: const Size.square(48),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => actions++,
                            child: const ColoredBox(color: Colors.blue),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pump();
        // This point is on the real editable field, even though the action's
        // expanded box overlaps the last two pixels of that field.
        await t.tapAt(Offset(48 + offset.dx, 42 + offset.dy));
        await t.pump();
        expect(actions, 0);
        expect(focus.hasFocus, isTrue);
        // The empty gap below the field still belongs to the nearby action.
        await t.tapAt(Offset(48 + offset.dx, 46 + offset.dy));
        await t.pump();
        expect(actions, 1);
        expect(focus.hasFocus, isTrue);
      } finally {
        await t.pumpWidget(const SizedBox());
        focus.dispose();
      }
    });
  }
}
