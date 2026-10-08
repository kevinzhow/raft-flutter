import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark mobile add uses source flow and real bounded hit; permission/count/desktop gates',
      (t) async {
        var opens = 0;
        Widget host({
          double width = 390,
          bool permitted = true,
          int count = 2,
        }) => MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: MediaQuery(
            data: MediaQueryData(size: Size(width, 720)),
            child: Scaffold(
              body: RaftDensityScope(
                density: RaftDensity.touch,
                child: SizedBox(
                  width: width,
                  child: RaftMessageTile(
                    author: 'Cindy',
                    content: 'Public body',
                    timestamp: '10:30',
                    reactions: [
                      {'emoji': '👍', 'count': count},
                    ],
                    onReaction: permitted ? (_) {} : null,
                    onReactionAdd: permitted ? (_) => opens++ : null,
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpWidget(host());
        final add = find.byKey(const ValueKey('message-reaction-add'));
        expect(t.getSize(add), const Size(25, 20));
        final chip = t.getRect(find.byType(RaftMountedReaction));
        final box = t.getRect(add);
        expect(box.left - chip.right, 6);
        final icon = t.widget<RaftIcon>(
          find.descendant(of: add, matching: find.byType(RaftIcon)),
        );
        expect(icon.glyph, RaftGlyph.plus);
        expect(icon.size, 13);
        expect(icon.strokeWidth, 2.5);
        await t.tapAt(Offset(box.center.dx, box.top + 1));
        await t.pump();
        expect(opens, 1);
        await t.tapAt(Offset(box.center.dx, box.bottom + 2));
        await t.pump();
        expect(opens, 1);
        await t.pumpWidget(host(permitted: false));
        expect(add, findsNothing);
        await t.pumpWidget(host(count: 0));
        expect(add, findsNothing);
        await t.pumpWidget(host(width: 900));
        expect(add, findsNothing);
        expect(t.takeException(), isNull);
      },
    );
  }
}
