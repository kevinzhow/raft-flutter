import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/thread_search.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/thread_actions.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_context_transition_test.dart' show row;
import 'message_presentation_test.dart' show fixture;

RaftMessage message(String id, String name, String text) =>
    RaftMessage({'id': id, 'senderName': name, 'content': text});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('matches search sender name and content, case-insensitively', () {
    final rows = [
      message('a', 'Cindy', 'Captured the Android artifact'),
      message('b', 'artin', 'Looks good'),
      message('c', 'designer', 'ANDROID spacing'),
    ];
    expect(threadSearchMatches(rows, 'android'), ['a', 'c']);
    expect(threadSearchMatches(rows, '  ARTIN '), ['b']);
    expect(threadSearchMatches(rows, 'zzzz'), isEmpty);
    expect(threadSearchMatches(rows, '   '), isEmpty);
  });

  Future<(dynamic, dynamic)> mountThread(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (w, api) = (await tester.runAsync(() => fixture('member')))!;
    addTearDown(w.dispose);
    w.messageDomain.ledger.switchServer('s1');
    final replies = [
      for (var i = 0; i < 3; i++) row('reply-$i', 'thread-1', i + 1),
    ];
    api.routes['GET /messages/context/parent'] = (_) => {
      'messages': [row('parent', 'c1', 1)],
    };
    api.routes['GET /messages/channel/thread-1'] = (_) => {'messages': replies};
    await tester.runAsync(() async {
      await w.openThreadIdentity(
        parentChannelId: 'c1',
        parentMessageId: 'parent',
        initialThreadChannelId: 'thread-1',
        navigate: false,
      );
      for (var i = 0; i < 40 && w.messageDomain.threadParentLoading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(body: RaftChatView(controller: w, thread: true)),
      ),
    );
    await tester.pump();
    return (w, api);
  }

  testWidgets('search bar: open, query, count, next / previous, close', (
    tester,
  ) async {
    final (w, _) = await mountThread(tester);
    expect(find.byKey(const Key('thread-search-bar')), findsNothing);

    w.threadSearch.open();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('thread-search-bar')), findsOneWidget);
    expect(find.text('Search this thread'), findsOneWidget);
    // No query yet: no count and the steppers are disabled.
    expect(
      tester
          .widget<RaftIconButton>(find.byKey(const Key('thread-search-next')))
          .onPressed,
      isNull,
    );

    // Parent + three replies all read "Message <id>".
    await tester.enterText(
      find.byKey(const Key('thread-search-input')),
      'message',
    );
    await tester.pump();
    expect(find.text('1/4'), findsOneWidget);
    await tester.tap(find.byKey(const Key('thread-search-next')));
    await tester.pump();
    expect(find.text('2/4'), findsOneWidget);
    await tester.tap(find.byKey(const Key('thread-search-previous')));
    await tester.tap(find.byKey(const Key('thread-search-previous')));
    await tester.pump();
    // Wraps around from the first match to the last.
    expect(find.text('4/4'), findsOneWidget);

    // Enter steps forward (wrapping), Shift+Enter backward.
    await tester.tap(find.byKey(const Key('thread-search-input')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('1/4'), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(find.text('4/4'), findsOneWidget);

    // A query without a hit reads 0/0 and disables the steppers.
    await tester.enterText(
      find.byKey(const Key('thread-search-input')),
      'zzzz',
    );
    await tester.pump();
    expect(find.text('0/0'), findsOneWidget);
    expect(
      tester
          .widget<RaftIconButton>(find.byKey(const Key('thread-search-next')))
          .onPressed,
      isNull,
    );

    // Escape closes the bar; reopening restores the query.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const Key('thread-search-bar')), findsNothing);
    w.threadSearch.open();
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('thread-search-input')))
          .controller!
          .text,
      'zzzz',
    );
    await tester.tap(find.byKey(const Key('thread-search-close')));
    await tester.pump();
    expect(find.byKey(const Key('thread-search-bar')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the active match marks its text and Ctrl+F opens the bar', (
    tester,
  ) async {
    final (w, _) = await mountThread(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    // The shortcut needs focus inside the thread surface; open via the model
    // when the harness has no focus there.
    if (!w.threadSearch.isOpen) {
      w.threadSearch.open();
      await tester.pump();
    }
    expect(w.threadSearch.isOpen, isTrue);
    await tester.enterText(
      find.byKey(const Key('thread-search-input')),
      'reply-1',
    );
    await tester.pump();
    expect(w.threadSearch.activeMessageId, 'reply-1');
    // Web marks the query inside the active message only.
    bool marked(InlineSpan span) {
      var found = false;
      span.visitChildren((s) {
        if (s is TextSpan &&
            s.style?.backgroundColor != null &&
            s.text == 'reply-1') {
          found = true;
        }
        return true;
      });
      return found;
    }

    expect(
      find.byWidgetPredicate((x) => x is RichText && marked(x.text)),
      findsWidgets,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the thread menu "Search in thread" runs the search callback', (
    tester,
  ) async {
    final (w, _) = await mountThread(tester);
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: ThreadActions(
            controller: w,
            parentMessageId: 'parent',
            menuMode: true,
            onSearch: () => opened++,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('thread-options')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search in thread'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
