// Web v1.24 TaskConversationDialog: off a phone the head is pinned above the
// conversation (at most 45%); on a phone it is the conversation's first row,
// the bar names the task's state once it has scrolled away and pulls it down.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _surface(Size size) => MaterialApp(
  theme: raftTheme(),
  home: MediaQuery(
    data: MediaQueryData(size: size),
    child: RaftDensityScope(
      density: size.width < 768 ? RaftDensity.touch : RaftDensity.desktop,
      child: Scaffold(
        body: SizedBox(
          width: size.width,
          height: size.height,
          child: RaftTaskSurface(
            conversation: RaftTaskConversation(
              ref: '#general:#8',
              onViewInChannel: () {},
            ),
            task: const {
              'id': 't1',
              'taskNumber': 8,
              'channelName': 'general',
              'title': 'Review the release',
              'status': 'in_progress',
              'claimedByType': 'user',
              'claimedById': 'u1',
              'createdByName': 'Alice',
            },
            history: const [],
            assignees: const [],
            legacy: false,
            loading: false,
            historyLoading: false,
            busy: false,
            canStatus: true,
            canAssign: false,
            canCleanupDelete: false,
            statusOptions: raftTaskStatuses,
            displayNameFor: (_, _) => 'Dana',
            onClose: () {},
            onRetry: () async {},
            onLoadAssignees: () async {},
            onUpdate: (field, value) async {},
            formatTime: (_) => 'Oct 10, 2026, 09:00',
            discussionBuilder: (slot) => CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: slot),
                SliverList.builder(
                  itemCount: 60,
                  itemBuilder: (_, i) =>
                      SizedBox(height: 48, child: Text('reply $i')),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('wide: the head stays pinned above the conversation, no '
      'summary in the bar', (t) async {
    t.view.physicalSize = const Size(1280, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_surface(const Size(1280, 900)));
    await t.pump();
    expect(
      find.byKey(const ValueKey('task-conversation-head')),
      findsOneWidget,
    );
    await t.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await t.pump();
    expect(find.byKey(const ValueKey('task-modal-bar-summary')), findsNothing);
    expect(find.text('Review the release'), findsOneWidget);
  });

  testWidgets('phone: the head scrolls away, the bar names the task and '
      'pulls the head down; a scroll closes it', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_surface(const Size(390, 844)));
    await t.pump();
    await t.pump();
    expect(find.byKey(const ValueKey('task-conversation-head')), findsNothing);
    expect(find.byKey(const ValueKey('task-modal-bar-summary')), findsNothing);
    expect(find.text('Review the release'), findsOneWidget);

    await t.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await t.pump();
    await t.pump();
    expect(
      find.byKey(const ValueKey('task-modal-bar-summary')),
      findsOneWidget,
    );
    // The bar here is narrower than 22rem: the avatar only, no name.
    expect(
      find.byKey(const ValueKey('task-modal-bar-assignee-name')),
      findsNothing,
    );
    expect(find.text('Review the release'), findsNothing);

    await t.tap(find.byKey(const ValueKey('task-modal-bar-summary')));
    await t.pump();
    await t.pump();
    expect(find.byKey(const ValueKey('task-head-pull-down')), findsOneWidget);
    expect(find.text('Review the release'), findsOneWidget);

    // The messages below the panel (the panel covers the middle).
    await t.dragFrom(const Offset(200, 820), const Offset(0, -100));
    await t.pump();
    expect(find.byKey(const ValueKey('task-head-pull-down')), findsNothing);

    await t.tap(find.byKey(const ValueKey('task-modal-bar-summary')));
    await t.pump();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(find.byKey(const ValueKey('task-head-pull-down')), findsNothing);
    expect(
      find.byKey(const ValueKey('task-modal-bar-summary')),
      findsOneWidget,
    );

    // Back at the top: the head is a row again, the bar just its label.
    await t.drag(find.byType(CustomScrollView), const Offset(0, 2000));
    await t.pump();
    await t.pump();
    expect(find.byKey(const ValueKey('task-modal-bar-summary')), findsNothing);
  });

  // Web TaskModalHead: `text-headline font-semibold` (600). raft-ui 0.95.3
  // dist/styles.css:181-185, `@media (width >= 48rem) and (pointer: fine)`
  // sets --text-headline 16px / 24px line height; a phone keeps 17/22
  // (styles.css:103-105). The surface picks touch density below 768.
  for (final (name, size, fontSize, line) in [
    ('a desktop window with a mouse', const Size(1280, 900), 16.0, 24.0),
    ('a phone', const Size(390, 844), 17.0, 22.0),
  ]) {
    testWidgets('the title is the Web headline, semibold: $name', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(_surface(size));
      await t.pump();
      final style = t
          .widget<Text>(find.byKey(const ValueKey('task-modal-title')))
          .style!;
      expect(style.fontSize, fontSize);
      expect(style.height! * style.fontSize!, closeTo(line, .01));
      expect(style.fontWeight, FontWeight.w600);
    });
  }
}
