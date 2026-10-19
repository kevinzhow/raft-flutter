import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/message_timeline.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'history_load_once_test.dart' show historyFixture, idle;

/// Page Up and the modified arrow keys both dispatch a [ScrollIntent] on the
/// timeline. The first page of 75 rows is h-25..h-74. At that top, the key
/// must request one older page. A jump and the page landing must not.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Page Up at the first page requests one older page', (
    tester,
  ) async {
    final older = await _openFirstPage(tester);
    await _invokeOlder(
      tester,
      const ScrollIntent(
        direction: AxisDirection.up,
        type: ScrollIncrementType.page,
      ),
    );
    expect(older, hasLength(1), reason: 'Page Up stayed on h-25');
    await _landWithoutAnother(tester, older);
    await _jump(tester);
    expect(older, hasLength(1), reason: 'a jump requested more');
  });

  testWidgets('modified arrow up at the first page requests one older page', (
    tester,
  ) async {
    final older = await _openFirstPage(tester);
    // Ctrl+Up, and Cmd+Up on iOS and macOS, are a line ScrollIntent upward.
    await _invokeOlder(tester, const ScrollIntent(direction: AxisDirection.up));
    expect(older, hasLength(1), reason: 'arrow up stayed on h-25');
    await _landWithoutAnother(tester, older);
  });

  testWidgets('jumping to the top of the first page requests nothing', (
    tester,
  ) async {
    final older = await _openFirstPage(tester);
    await _jump(tester);
    expect(older, isEmpty, reason: 'a jump requested more');
  });
}

Future<List<Completer<void>>> _openFirstPage(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1280, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final (w, older) = await historyFixture(
    tester,
    thread: false,
    total: 75,
    first: 50,
    short: true,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(body: RaftChatView(controller: w, thread: false)),
    ),
  );
  await idle(tester, 30);
  expect(older, isEmpty);
  final ids = w.messageDomain.messages.map((m) => m.id).toList();
  expect(ids, containsAll(['h-25', 'h-74']));
  expect(ids, isNot(contains('h-0')));
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
  return older;
}

Future<void> _invokeOlder(WidgetTester tester, ScrollIntent intent) async {
  // The scrollable's own context does not see itself. The key arrives on a
  // descendant, which is what Page Up and the modified arrows use.
  final viewport = find.descendant(
    of: find.byType(RaftMessageTimeline),
    matching: find.byWidgetPredicate((widget) => widget is Viewport),
  );
  Actions.invoke(tester.element(viewport), intent);
  await idle(tester, 20);
}

Future<void> _jump(WidgetTester tester) async {
  final scrollable = tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .firstWhere((state) => state.position is RaftTimelinePosition);
  scrollable.position.jumpTo(scrollable.position.minScrollExtent);
  await idle(tester, 20);
}

Future<void> _landWithoutAnother(
  WidgetTester tester,
  List<Completer<void>> older,
) async {
  older.firstWhere((c) => !c.isCompleted).complete();
  await idle(tester, 40);
  expect(older, hasLength(1), reason: 'a landed page requested more');
}
