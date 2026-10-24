import 'package:raft_ui/raft_ui.dart' show packForThemeId, elegantThemePackId;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/message_row_recipe.dart';
import 'package:raft_ui/src/message_toolbar_glyphs.dart';
import 'package:raft_ui/src/theme.dart';

// The Raft toolbar sits inside the row (toolbarTop 4); the old Brutal toolbar
// overhung the row by 14 px, so a pointer could land above the visual row.
// The actual pointer still has to travel from the body onto the toolbar and
// activate the reaction.
void main() {
  testWidgets(
    'actual pointer can move from the body onto the toolbar and activate reaction',
    (tester) async {
      var activated = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: packForThemeId(elegantThemePackId)),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: RaftMessageRow(
                author: 'Public',
                timestamp: '14:30',
                content: const Text('Public body'),
                toolbar: RaftMessageToolbar(
                  children: [
                    RaftMessageToolbarAction(
                      key: const Key('reaction-action'),
                      label: 'Add Reaction',
                      icon: const RaftMessageAddReactionGlyph(),
                      onPressed: () => activated++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 300));
      await mouse.moveTo(tester.getCenter(find.text('Public body')));
      await tester.pump();
      final action = tester.getRect(find.byKey(const Key('reaction-action')));
      final point = Offset(action.center.dx, action.top + 2);
      // Inside the row (which starts at the 40 px padding), not above it.
      expect(point.dy, greaterThanOrEqualTo(40));
      await mouse.moveTo(point);
      await tester.pump();
      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byType(RaftMessageToolbar),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 1);
      await mouse.down(point);
      await mouse.up();
      await tester.pump();
      expect(activated, 1);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    },
  );
}
