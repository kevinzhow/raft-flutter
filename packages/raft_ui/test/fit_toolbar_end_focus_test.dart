import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// A scroll group's `end` (Search's Clear All) appears after the first filter
// is picked. The chips must keep their elements, so the chip that had focus
// (the one whose menu just closed) keeps it and Enter still reaches the page.
bool _focusedInside(String key) {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return false;
  var found = false;
  ctx.visitAncestorElements((e) {
    if (e.widget.key == Key(key)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

void main() {
  testWidgets('a scroll group keeps the focused chip when its end appears', (
    t,
  ) async {
    late StateSetter setEnd;
    var showEnd = false;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: StatefulBuilder(
              builder: (context, setState) {
                setEnd = setState;
                return RaftFitToolbar(
                  children: [
                    RaftFitGroup(
                      firstLine: true,
                      scroll: true,
                      end: showEnd
                          ? RaftButton(label: 'Clear All', onPressed: () {})
                          : null,
                      items: [
                        for (final id in ['a', 'b'])
                          RaftFitChild(
                            child: RaftButton(
                              key: Key(id),
                              label: id.toUpperCase(),
                              onPressed: () {},
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    // A toolbar is one Tab stop; the arrows move between its items.
    for (var i = 0; i < 4 && !_focusedInside('a'); i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
    }
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    expect(_focusedInside('b'), isTrue);
    final scrollers = find.byType(SingleChildScrollView);
    final scroller = t.element(scrollers.first);

    setEnd(() => showEnd = true);
    await t.pump();
    await t.pump();

    expect(find.text('Clear All'), findsOneWidget);
    expect(_focusedInside('b'), isTrue, reason: 'focus stays on the chip');
    expect(
      identical(t.element(scrollers.first), scroller),
      isTrue,
      reason: 'the scroller is not re-parented',
    );
  });
}
