import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/message_timeline.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'history_load_once_test.dart' show historyFixture, idle;

/// A tap on the timeline must move focus onto the list so Page Up loads one
/// older page. Pointer down and a drag must not. Jump and landing must not
/// load another page.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a touch tap with the soft keyboard hidden loads one older page',
    (tester) async {
      final older = await _openFirstPage(tester);
      await _focusComposer(tester);
      tester.testTextInput.hide();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(_composer(tester).focusNode.hasPrimaryFocus, isTrue);

      await tester.tap(find.byType(RaftMessageTimeline));
      await tester.pump();

      expect(_timeline(tester).hasPrimaryFocus, isTrue);
      await _pageUp(tester);
      expect(older, hasLength(1), reason: 'Page Up stayed on h-25');
      await _landWithoutAnother(tester, older);
      await _jump(tester);
      expect(older, hasLength(1), reason: 'a jump requested more');
    },
  );

  testWidgets('a mouse click on the timeline loads one older page', (
    tester,
  ) async {
    final older = await _openFirstPage(tester);
    await _focusComposer(tester);
    tester.testTextInput.hide();

    await tester.tap(
      find.byType(RaftMessageTimeline),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();

    expect(_timeline(tester).hasPrimaryFocus, isTrue);
    await _pageUp(tester);
    expect(older, hasLength(1), reason: 'Page Up stayed on h-25');
  });

  testWidgets('pointer down keeps the soft keyboard, and a tap dismisses it', (
    tester,
  ) async {
    final older = await _openFirstPage(tester);
    await _focusComposer(tester);
    await tester.enterText(find.byType(RaftComposer), 'half-written');
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    expect(_composer(tester).controller.text, 'half-written');

    final center = tester.getCenter(find.byType(RaftMessageTimeline));
    final drag = await tester.startGesture(center);
    await tester.pump();
    expect(_composer(tester).focusNode.hasPrimaryFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(_timeline(tester).hasFocus, isFalse);

    await drag.moveBy(const Offset(0, -40));
    await tester.pump();
    await drag.up();
    await tester.pump();
    expect(_timeline(tester).hasPrimaryFocus, isFalse);
    expect(_composer(tester).controller.text, 'half-written');

    await tester.tap(find.byType(RaftMessageTimeline));
    await tester.pump();
    expect(_timeline(tester).hasPrimaryFocus, isTrue);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(_composer(tester).controller.text, 'half-written');
    await _pageUp(tester);
    expect(older, hasLength(1), reason: 'Page Up stayed on h-25');
    await _landWithoutAnother(tester, older);
  });

  testWidgets('a right-click menu keeps focus off the timeline', (
    tester,
  ) async {
    await _openFirstPage(tester);
    await _focusComposer(tester);
    await tester.tap(
      find.text('Row h-50'),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Copy Link'), findsOneWidget);
    expect(_timeline(tester).hasFocus, isFalse);
    final menuRoute = ModalRoute.of(tester.element(find.text('Copy Link')));
    expect(menuRoute?.isCurrent, isTrue);
  });

  testWidgets('a long-press message menu keeps focus off the timeline', (
    tester,
  ) async {
    await _openFirstPage(tester);
    await _focusComposer(tester);
    final row = find.byKey(const ValueKey('message-h-40'));
    final rect = tester.getRect(row);
    await tester.longPressAt(Offset(rect.left + 2, rect.center.dy));
    await tester.pump();
    await tester.pump();

    expect(find.text('Copy Link'), findsOneWidget);
    expect(_timeline(tester).hasFocus, isFalse);
    expect(_timeline(tester).hasPrimaryFocus, isFalse);
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

Future<void> _focusComposer(WidgetTester tester) async {
  await tester.showKeyboard(find.byType(RaftComposer));
  await tester.pump();
  expect(_composer(tester).focusNode.hasPrimaryFocus, isTrue);
}

EditableText _composer(WidgetTester tester) {
  return tester.widget<EditableText>(
    find.descendant(
      of: find.byType(RaftComposer),
      matching: find.byType(EditableText),
    ),
  );
}

FocusNode _timeline(WidgetTester tester) {
  return tester
      .widget<Focus>(find.byKey(const ValueKey('timeline-focus')))
      .focusNode!;
}

Future<void> _pageUp(WidgetTester tester) async {
  final handled = await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
  expect(handled, isTrue, reason: 'Page Up was not handled');
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
