import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

/// Web `ThreadUnreadJumpPill`: the jump label and the dismiss cross are two
/// actions of one pill with the height of the "Back to bottom" button.
void main() {
  for (final (family, dark) in raftThemeMatrix([
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ])) {
    testWidgets('$family/$dark the pill jumps, dismisses and lines up with '
        'Back to bottom', (t) async {
      var jumps = 0, dismissals = 0, backs = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 300,
              child: Stack(
                children: [
                  RaftTimelineBottomControls(
                    button: RaftTimelineBottomButtonBody(
                      label: 'Back to bottom',
                      onPressed: () => backs++,
                    ),
                    pill: RaftThreadUnreadJumpPill(
                      up: false,
                      label: 'Next unread thread (3)',
                      dismissLabel: 'Dismiss',
                      onJump: () => jumps++,
                      onDismiss: () => dismissals++,
                    ),
                  ),
                  RaftTimelineTopPill(
                    child: RaftThreadUnreadJumpPill(
                      up: true,
                      label: 'Earliest unread thread (3)',
                      dismissLabel: 'Dismiss',
                      onJump: () {},
                      onDismiss: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final bottom = find.byKey(
        const ValueKey('thread-unread-jump-pill-bottom'),
      );
      final top = find.byKey(const ValueKey('thread-unread-jump-pill-top'));
      final back = find.byType(RaftTimelineBottomButtonBody);
      // Same height as Back to bottom (h-8), side by side, 8 px apart.
      expect(t.getSize(bottom).height, t.getSize(back).height);
      expect(t.getRect(bottom).left - t.getRect(back).right, 8);
      expect(t.getRect(bottom).center.dy, t.getRect(back).center.dy);
      // The top pill sits 12 px under the top edge, centred.
      expect(t.getRect(top).top - t.getTopLeft(find.byType(Stack).first).dy, 12);
      expect(t.getCenter(top).dx, 300);

      await t.tap(find.byKey(const ValueKey('thread-unread-jump')).first);
      expect((jumps, dismissals, backs), (1, 0, 0));
      await t.tap(find.byKey(const ValueKey('thread-unread-dismiss')).first);
      expect((jumps, dismissals, backs), (1, 1, 0));
      await t.tap(find.text('Back to bottom'));
      expect((jumps, dismissals, backs), (1, 1, 1));
      expect(find.bySemanticsLabel('Dismiss'), findsWidgets);
    });
  }
}
