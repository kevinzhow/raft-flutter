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
      '$family/$dark mounted touch message controls preserve source flow and disjoint hits',
      (t) async {
        var first = 0, second = 0, toggles = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: RaftDensityScope(
                density: RaftDensity.touch,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RaftMountedReaction(
                            key: const Key('first'),
                            label: 'First reaction',
                            glyph: const RaftReactionGlyph('👍'),
                            count: 2,
                            onPressed: () => first++,
                          ),
                          const SizedBox(width: 6),
                          RaftMountedReaction(
                            key: const Key('second'),
                            label: 'Second reaction',
                            glyph: const RaftReactionGlyph('❤️'),
                            count: 1,
                            onPressed: () => second++,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      RaftComposerTaskToggle(
                        checked: false,
                        label: 'As Task',
                        onChanged: (_) => toggles++,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pump(const Duration(milliseconds: 250));
        final a = t.getRect(find.byKey(const Key('first')));
        final b = t.getRect(find.byKey(const Key('second')));
        expect(a.height, 20);
        expect(b.height, 20);
        expect(b.left - a.right, 6);
        expect(a.overlaps(b), false);
        final toggle = find.byKey(const ValueKey('composer-as-task-toggle'));
        expect(t.getSize(toggle).height, 16);
        await t.tapAt(Offset(a.center.dx, a.top + 1));
        await t.pump();
        await t.tapAt(Offset(b.center.dx, b.bottom - 1));
        await t.pump();
        expect(first, 1);
        expect(second, 1);
        await t.tapAt(Offset(a.right + 3, a.center.dy));
        await t.pump();
        await t.tapAt(Offset(a.center.dx, a.bottom + 3));
        await t.pump();
        expect(first, 1);
        expect(second, 1);
        expect(toggles, 0);
        await t.tap(toggle);
        await t.pump();
        expect(toggles, 1);
        expect(t.takeException(), null);
      },
    );
  }
}
