// Web v1.24 TaskHandoffCard and the reason popover: the card names who handed
// the task to whom with the reason as its body and fades once it came back;
// the Backlog reason is a popover under the chip that waits while it writes.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Future<void> _mount(WidgetTester t, Widget child) async {
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: RaftDensityScope(
          density: RaftDensity.desktop,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 480, child: child),
          ),
        ),
      ),
    ),
  );
  await t.pump();
}

RaftTaskHandoffCard _card({String? returned}) => RaftTaskHandoffCard(
  from: '@Otter',
  to: '@xxchan',
  fromAvatar: const SizedBox.square(dimension: 16),
  toAvatar: const SizedBox.square(dimension: 16),
  reason: 'Please review the copy',
  time: '10:42',
  semanticLabel: '@Otter handed #7 to @xxchan',
  returnedLabel: returned,
);

void main() {
  testWidgets('a hand-off is a card: from, to, the time and the reason', (
    t,
  ) async {
    await _mount(t, _card());
    expect(find.text('@Otter'), findsOneWidget);
    expect(find.text('→'), findsOneWidget);
    expect(find.text('@xxchan'), findsOneWidget);
    expect(find.text('10:42'), findsOneWidget);
    expect(find.text('Please review the copy'), findsOneWidget);
    expect(find.byKey(const ValueKey('task-handoff-card')), findsOneWidget);
    expect(t.widget<Opacity>(find.byType(Opacity)).opacity, 1);
  });

  testWidgets('once it came back the card fades and says who took it', (
    t,
  ) async {
    await _mount(t, _card(returned: 'Otter took it back · 10:51'));
    expect(
      find.byKey(const ValueKey('task-handoff-card-returned')),
      findsOneWidget,
    );
    expect(find.text('Otter took it back · 10:51'), findsOneWidget);
    expect(find.text('10:42'), findsNothing);
    expect(t.widget<Opacity>(find.byType(Opacity)).opacity, lessThan(1));
  });

  testWidgets('the Backlog reason hangs under the chip and does not dismiss '
      'while the write runs', (t) async {
    final anchor = GlobalKey();
    final panel = GlobalKey<RaftTaskReasonPanelState>();
    final write = Completer<bool>();
    var open = true, dismissed = 0;
    final reasons = <String>[];
    late StateSetter set;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return Padding(
                padding: const EdgeInsets.all(40),
                child: RaftTaskReasonPopover(
                  open: open,
                  anchorKey: anchor,
                  panelKey: panel,
                  onSubmit: (reason) {
                    reasons.add(reason);
                    return write.future;
                  },
                  onDismiss: () {
                    dismissed++;
                    set(() => open = false);
                  },
                  child: KeyedSubtree(key: anchor, child: const Text('chip')),
                ),
              );
            },
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump();
    final popover = find.byKey(const ValueKey('task-backlog-reason'));
    expect(popover, findsOneWidget);
    expect(
      t.getTopLeft(popover).dy,
      greaterThanOrEqualTo(t.getBottomLeft(find.text('chip')).dy),
    );
    await t.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('task-backlog-reason-input')),
        matching: find.byType(EditableText),
      ),
      '  later  ',
    );
    await t.tap(find.byKey(const ValueKey('task-backlog-reason-confirm')));
    await t.pump();
    expect(reasons, ['later']);
    // A press outside and Escape wait for the write.
    await t.tapAt(const Offset(2, 2));
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(dismissed, 0);
    expect(popover, findsOneWidget);
    write.complete(false);
    await t.pump();
    expect(
      find.text("Couldn't move the task. Try again."),
      findsOneWidget,
      reason: 'a refused move stays with its failure',
    );
    await t.tapAt(const Offset(2, 2));
    await t.pump();
    expect(dismissed, 1);
    expect(popover, findsNothing);
  });
}
