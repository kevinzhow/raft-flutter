// Web v1.24 TaskHeadPullDown: a swipe up at the end closes the panel, and
// focus returns to the bar unless a tap outside closed it.
// Web v1.24 TaskConversationDialog: off a phone the head is pinned above the
// conversation (at most 45%); on a phone it is the conversation's first row,
// the bar names the task's state once it has scrolled away and pulls it down.
import 'package:flutter/gestures.dart';
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

Future<void> _open(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(_surface(size));
  await t.pump();
  await t.pump();
  await t.drag(find.byType(CustomScrollView), const Offset(0, -700));
  await t.pump();
  await t.pump();
  await t.tap(find.byKey(const ValueKey('task-modal-bar-summary')));
  await t.pump();
  await t.pump();
  expect(find.byKey(const ValueKey('task-head-pull-down')), findsOneWidget);
}

final _panel = find.byKey(const ValueKey('task-head-pull-down'));

Future<void> _swipe(WidgetTester t, Offset from, Offset by) async {
  final g = await t.startGesture(from, kind: PointerDeviceKind.touch);
  await g.moveBy(Offset(by.dx / 2, by.dy / 2));
  await g.moveBy(Offset(by.dx / 2, by.dy / 2));
  await g.up();
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

/// The primary focus is the bar's toggle (the node the host owns).
bool _barFocused() =>
    FocusManager.instance.primaryFocus?.debugLabel == 'task bar summary';

void main() {
  const phone = Size(390, 844);

  testWidgets('swipe up 40+ px from the panel at its end closes it and '
      'focus returns to the bar', (t) async {
    await _open(t, phone);
    await _swipe(t, t.getCenter(_panel), const Offset(0, -60));
    expect(_panel, findsNothing);
    expect(_barFocused(), isTrue);
  });

  testWidgets('a shorter swipe or a mostly horizontal one does not close', (
    t,
  ) async {
    await _open(t, phone);
    await _swipe(t, t.getCenter(_panel), const Offset(0, -30));
    expect(_panel, findsOneWidget);
    await _swipe(t, t.getCenter(_panel), const Offset(-120, -50));
    expect(_panel, findsOneWidget);
  });

  testWidgets('content not at its end: the up drag scrolls the panel, '
      'it stays open', (t) async {
    await _open(t, const Size(390, 150));
    final scroll = find.descendant(
      of: _panel,
      matching: find.byType(Scrollable),
    );
    final position = t.state<ScrollableState>(scroll.first).position;
    expect(position.maxScrollExtent, greaterThan(70));
    await _swipe(t, t.getCenter(_panel), const Offset(0, -60));
    expect(_panel, findsOneWidget);
    expect(position.pixels, greaterThan(0));
  });

  testWidgets('Escape returns focus to the bar', (t) async {
    await _open(t, phone);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    await t.pump();
    expect(_panel, findsNothing);
    expect(_barFocused(), isTrue);
  });

  testWidgets('a tap on the messages closes it and does not focus the bar', (
    t,
  ) async {
    await _open(t, phone);
    await t.tapAt(const Offset(200, 830));
    await t.pump();
    await t.pump();
    expect(_panel, findsNothing);
    expect(_barFocused(), isFalse);
  });
}
