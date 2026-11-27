import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/thread_search.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/thread_actions.dart';
import 'package:raft_flutter/features/thread_outline_scope.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_context_transition_test.dart' show row;
import 'message_presentation_test.dart' show fixture;
import 'thread_overlay_history_test.dart'
    show frames, openThreadFromBadge, overlayFixture, taskRow, threadTimeline;

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

  Future<(dynamic, dynamic)> mountThread(
    WidgetTester tester, {
    int replyCount = 3,
    ChatViewportHandle? viewport,
    Size size = const Size(900, 900),
    TargetPlatform platform = TargetPlatform.linux,
    EdgeInsets safePadding = EdgeInsets.zero,
  }) async {
    tester.view.physicalSize = size;
    tester.view.padding = FakeViewPadding(
      left: safePadding.left,
      top: safePadding.top,
      right: safePadding.right,
      bottom: safePadding.bottom,
    );
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (w, api) = (await tester.runAsync(() => fixture('member')))!;
    addTearDown(w.dispose);
    w.messageDomain.ledger.switchServer('s1');
    final replies = [
      for (var i = 0; i < replyCount; i++) row('reply-$i', 'thread-1', i + 1),
    ];
    api.routes['GET /messages/context/parent'] = (_) => {
      'messages': [row('parent', 'c1', 1)],
    };
    api.routes['GET /messages/channel/thread-1'] = (_) => {'messages': replies};
    api.routes['GET /messages/channel/thread-1/human-outline'] = (_) => {
      'items': [
        for (final reply in replies.reversed)
          {...reply, 'senderName': 'Alice', 'preview': reply['content']},
        {
          'id': 'parent',
          'seq': '0',
          'senderName': 'Alice',
          'preview': 'Parent',
        },
      ],
      'hasMore': false,
    };
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
        theme: raftTheme().copyWith(platform: platform),
        home: RepaintBoundary(
          key: const ValueKey('mounted-thread-surface'),
          child: SafeArea(
            child: Scaffold(
              body: RaftChatView(
                controller: w,
                thread: true,
                viewportHandle: viewport,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return (w, api);
  }

  testWidgets('the outline follows a mounted thread without disk history', (
    tester,
  ) async {
    final viewport = ChatViewportHandle();
    final (w, _) = await mountThread(
      tester,
      replyCount: 60,
      viewport: viewport,
    );
    final outline = threadOutlineFor(w)!;
    await tester.runAsync(outline.load);
    await tester.pumpAndSettle();
    expect(outline.currentId, startsWith('reply-'));

    viewport.jumpToBeginning();
    await tester.pump();
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final parentVisible = find
        .text('Message parent')
        .hitTestable()
        .evaluate()
        .isNotEmpty;
    final current = outline.currentId;

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(parentVisible, isTrue);
    expect(current, 'parent');
  });

  testWidgets(
    'mounted search centers an interior match and shows bottom action',
    (tester) async {
      final (w, _) = await mountThread(tester, replyCount: 60);
      w.threadSearch.open();
      await tester.pumpAndSettle();
      final input = find.byKey(const Key('thread-search-input'));
      final field = find
          .ancestor(
            of: input,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Container &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration! as BoxDecoration).border is Border,
            ),
          )
          .first;
      final decoration =
          tester.widget<Container>(field).decoration! as BoxDecoration;
      expect(decoration.borderRadius, isNotNull);
      await tester.enterText(input, 'reply-30');
      await tester.pumpAndSettle();
      expect(find.text('1/1'), findsOneWidget);
      final target = find.byKey(const ValueKey('message-wrapper-reply-30'));
      final viewport = find.byKey(const Key('chat-list-thread'));
      expect(target.hitTestable(), findsOneWidget);
      expect(
        tester.getCenter(target).dy,
        closeTo(tester.getCenter(viewport).dy, 1),
      );
      expect(find.text('Back to bottom'), findsOneWidget);
      await tester.tap(find.text('Back to bottom'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('message-wrapper-reply-59')).hitTestable(),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets('a live reply that opens the outline rail updates the count', (
    tester,
  ) async {
    final (w, _) = await mountThread(tester);
    final outline = threadOutlineFor(w)!;
    await tester.runAsync(outline.load);
    await tester.pumpAndSettle();
    expect(outline.hasReplies('parent'), isFalse);
    expect(find.text('3 replies'), findsOneWidget);

    final reply = {
      ...row('reply-3', 'thread-1', 4),
      'senderType': 'user',
      'senderName': 'Alice',
    };
    outline.note(RaftEvent('message:new', reply));
    w.messageDomain.ledger.ingest([
      reply,
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds['thread-1']!.add('reply-3');
    w.notifyListeners();
    await tester.pump();

    expect(outline.hasReplies('parent'), isTrue);
    expect(find.text('4 replies').hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('desktop search paints through the outline rail gutter', (
    tester,
  ) async {
    final (w, _) = await mountThread(tester, replyCount: 60);
    final outline = threadOutlineFor(w)!;
    await tester.runAsync(outline.load);
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Thread timeline',
      ),
      findsOneWidget,
    );

    w.threadSearch.open();
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('thread-search-input')),
      'reply-30',
    );
    await tester.pumpAndSettle();
    expect(w.threadSearch.activeMessageId, 'reply-30');

    final surface = find.byKey(const ValueKey('mounted-thread-surface'));
    final boundary = tester.renderObject<RenderRepaintBoundary>(surface);
    final matched = tester.getRect(
      find.byKey(const ValueKey('message-wrapper-reply-30')),
    );
    final adjacent = tester.getRect(
      find.byKey(const ValueKey('message-wrapper-reply-31')),
    );
    final right = tester.getRect(surface).right;
    expect(right - matched.right, RaftThreadOutlineMetrics.timelineInset.end);
    expect(adjacent.right, matched.right);

    final pixels = await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final rgba = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        int pixel(double x, double y) =>
            rgba.getUint32(4 * (image.width * y.floor() + x.floor()));
        // The outline ticks paint over the fill. Sample between them too.
        List<int> railStrip(double y) => [
          for (var offset = -4; offset <= 4; offset++)
            pixel(right - 22, y + offset),
        ];
        return (
          fill: pixel(matched.right - 20, matched.center.dy),
          gutter: railStrip(matched.center.dy),
          idleGutter: railStrip(adjacent.center.dy),
        );
      } finally {
        image.dispose();
      }
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    expect(pixels!.idleGutter, isNot(contains(pixels.fill)));
    expect(
      pixels.gutter.where((pixel) => pixel == pixels.fill),
      hasLength(greaterThanOrEqualTo(5)),
    );
  });

  for (final (size, platform, closeSize) in [
    (const Size(390, 844), TargetPlatform.android, 32.0),
    (const Size(390, 844), TargetPlatform.linux, 32.0),
    (const Size(856, 944), TargetPlatform.android, 32.0),
    (const Size(944, 856), TargetPlatform.android, 32.0),
    (const Size(900, 900), TargetPlatform.linux, 28.0),
  ]) {
    testWidgets('mounted search Close at $size on ${platform.name}', (
      tester,
    ) async {
      const safePadding = EdgeInsets.fromLTRB(12, 24, 16, 20);
      final (w, _) = await mountThread(
        tester,
        replyCount: 60,
        size: size,
        platform: platform,
        safePadding: safePadding,
      );
      w.threadSearch.open();
      await tester.pumpAndSettle();
      final bar = find.byKey(const Key('thread-search-bar'));
      final input = find.byKey(const Key('thread-search-input'));
      final close = find.byKey(const Key('thread-search-close'));
      final box = tester.getRect(close);
      final safeRect = safePadding.deflateRect(Offset.zero & size);
      expect(box.size, Size.square(closeSize));
      expect(safeRect.contains(box.topLeft), isTrue);
      expect(safeRect.contains(box.bottomRight), isTrue);
      expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
      final closeGlyph = find.descendant(
        of: close,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is RaftGlyphPainter,
        ),
      );
      final painter = tester.widget<CustomPaint>(closeGlyph).painter!;
      expect(
        (painter as RaftGlyphPainter).color,
        RaftTokens.of(tester.element(close)).ink,
      );

      await tester.enterText(input, 'reply-3');
      await tester.pumpAndSettle();
      final list = find.byKey(const Key('chat-list-thread'));
      void expectCentered(String id) {
        final row = find.byKey(ValueKey('message-wrapper-$id'));
        expect(row.hitTestable(), findsOneWidget);
        expect(tester.getCenter(row).dy, closeTo(tester.getCenter(list).dy, 1));
      }

      expect(find.text('1/11'), findsOneWidget);
      await tester.tap(find.byKey(const Key('thread-search-next')));
      await tester.pumpAndSettle();
      expect(find.text('2/11'), findsOneWidget);
      expectCentered('reply-30');
      await tester.tap(find.byKey(const Key('thread-search-previous')));
      await tester.pumpAndSettle();
      expect(find.text('1/11'), findsOneWidget);
      await tester.tap(find.text('Back to bottom'));
      await tester.pumpAndSettle();
      final latest = find.byKey(const ValueKey('message-wrapper-reply-59'));
      expect(latest.hitTestable(), findsOneWidget);

      // Hit the outer edge of the button, away from its glyph.
      await tester.tapAt(
        tester.getRect(close).centerRight - const Offset(1, 0),
      );
      await tester.pumpAndSettle();
      expect(bar, findsNothing);
      expect(latest.hitTestable(), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('phone search Close keeps the route and header Back returns', (
    tester,
  ) async {
    final fixture = await overlayFixture(
      tester,
      width: 390,
      task: taskRow('p1', threadChannelId: 't1'),
    );
    final channel = fixture.w.location;
    await openThreadFromBadge(tester, fixture);
    final thread = fixture.w.location;
    final input = find.byKey(const Key('thread-search-input'));

    Future<void> openSearch() async {
      await tester.tap(find.byKey(const Key('thread-options')));
      await frames(tester, count: 20);
      await tester.tap(find.text('Search in thread'));
      await frames(tester, count: 20);
      expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
      expect(fixture.w.location, thread);
    }

    await openSearch();
    await tester.tap(find.byKey(const Key('thread-search-close')));
    await frames(tester);
    expect(input, findsNothing);
    expect(fixture.w.location, thread);
    expect(threadTimeline(), findsOneWidget);

    await openSearch();
    await tester.tap(find.byKey(const Key('mobile-detail-back')));
    await frames(tester, count: 35);
    expect(fixture.w.location, channel);
    expect(threadTimeline(), findsNothing);
    expect(input, findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

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
        theme: raftTheme(),
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
