import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

/// Phone channel history long enough to leave the bottom.
List<Map<String, dynamic>> channelHistory(int count) => [
  for (var i = 1; i <= count; i++)
    {
      'id': 'm$i',
      'channelId': 'ca',
      'seq': '$i',
      'senderId': 'alice',
      'senderName': 'Alice',
      'content': 'Row $i',
      'createdAt': '2026-10-10T00:00:00Z',
    },
];

Map<String, dynamic> channelPage({
  required List<Map<String, dynamic>> messages,
  bool hasMore = false,
}) => {'messages': messages, 'hasMore': hasMore, 'hasNewer': false};

void useChannelHistory(
  RootFixture f, {
  required int count,
  bool hasMore = false,
}) {
  f.overrides['GET /messages/channel/ca'] = (o) {
    if (o.queryParameters['before'] != null) {
      return channelPage(
        messages: [
          {
            'id': 'older-1',
            'channelId': 'ca',
            'seq': '0',
            'senderId': 'alice',
            'senderName': 'Alice',
            'content': 'Older row',
            'createdAt': '2026-10-09T00:00:00Z',
          },
        ],
      );
    }
    return channelPage(messages: channelHistory(count), hasMore: hasMore);
  };
}

Finder channelChat({bool skipOffstage = true}) => find.byWidgetPredicate(
  (widget) => widget is RaftChatView && !widget.thread,
  skipOffstage: skipOffstage,
);

ScrollController channelViewport(WidgetTester t) {
  expect(channelChat(), findsOneWidget);
  final dynamic state = t.state(channelChat());
  return state.viewport as ScrollController;
}

/// A painted message row and its global rect, after the reader has left the tail.
(String, Rect) visibleAnchor(WidgetTester t) {
  for (var i = 1; i <= 40; i++) {
    final found = find.byKey(ValueKey('message-m$i'));
    if (found.evaluate().isEmpty) continue;
    final render = t.renderObject(found.first);
    if (render is! RenderBox || !render.attached || !render.hasSize) continue;
    final bounds = render.localToGlobal(Offset.zero) & render.size;
    if (bounds.top > 80 && bounds.bottom < 820) return ('m$i', bounds);
  }
  fail('no channel row was painted away from the edges');
}

int messageReads(RootFixture f, bool Function(RequestOptions) match) =>
    f.adapter.calls.where(match).length;

String requestPath(RequestOptions call) {
  final resolved = call.uri.path;
  return resolved.isEmpty ? call.path : resolved;
}

bool channelMessageGet(RequestOptions call, {required bool older}) {
  if (call.method != 'GET' ||
      !requestPath(call).endsWith('/messages/channel/ca')) {
    return false;
  }
  final before =
      call.queryParameters['before'] ?? call.uri.queryParameters['before'];
  return older ? before != null : before == null;
}

void main() {
  testWidgets('phone channel scroll and first frame stay put', (t) async {
    final f = RootFixture();
    useChannelHistory(f, count: 40);
    await f.mount(t, 'light', 390, uri: Uri.parse('/s/alpha/channel/ca'));
    final tail = find.text('Row 40');
    expect(tail, findsOneWidget);
    final settled = t.getRect(tail);
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 16));
      expect(
        t.getRect(find.text('Row 40')),
        settled,
        reason: 'the accepted tail moved after the first settled frame',
      );
    }
    final scopes = t.widgetList<MobileChatDirectRead>(
      find.byType(MobileChatDirectRead),
    );
    expect(scopes.where((scope) => scope.channel && !scope.thread), isNotEmpty);
    final page = t.widget<RaftChatView>(channelChat()).controller;
    expect(
      identical(page.messageWindows, f.workspace(t).messageWindows),
      isTrue,
    );

    final viewport = channelViewport(t);
    expect(viewport.position.maxScrollExtent, greaterThan(20));
    final origin = viewport.offset;
    final moved = (origin - 500).clamp(0.0, viewport.position.maxScrollExtent);
    viewport.jumpTo(moved == origin ? origin + 200 : moved);
    await t.pump();
    expect((viewport.offset - origin).abs(), greaterThan(20));
    final pixels = viewport.position.pixels;
    final (anchor, rect) = visibleAnchor(t);

    await t.tap(find.byTooltip('Channel Details and Settings'));
    await f.flush(t);
    expect(await t.binding.handlePopRoute(), isTrue);
    await f.flush(t);

    final restored = channelViewport(t);
    expect(restored.position.pixels, closeTo(pixels, 0.5));
    final back = t.renderObject(find.byKey(ValueKey('message-$anchor')));
    expect(back, isA<RenderBox>());
    final backRect = (back as RenderBox).localToGlobal(Offset.zero) & back.size;
    expect(backRect.top, closeTo(rect.top, 1));
    expect(backRect.left, closeTo(rect.left, 1));
    expect(t.takeException(), isNull);
    await f.close(t);
  });

  testWidgets('a covered direct chat does not read, focus, or tick', (t) async {
    final f = RootFixture();
    await f.mount(t, 'light', 390, uri: Uri.parse('/s/alpha/channel/ca'));
    expect(find.text('Accepted a'), findsOneWidget);
    final page = t.widget<RaftChatView>(channelChat()).controller;
    expect(
      identical(page.messageWindows, f.workspace(t).messageWindows),
      isTrue,
    );
    expect(
      identical(
        page.messageDomain.messageWindow,
        f.workspace(t).messageDomain.messageWindow,
      ),
      isTrue,
    );

    final field = find.descendant(
      of: channelChat(),
      matching: find.byType(EditableText),
    );
    await t.tap(field);
    await f.flush(t);
    expect(t.widget<EditableText>(field).focusNode.hasFocus, isTrue);

    await t.tap(find.byTooltip('Channel Details and Settings'));
    await f.flush(t);
    final coveredChat = channelChat(skipOffstage: false);
    final covered = t.widget<RaftChatView>(coveredChat);
    final dynamic coveredState = t.state(coveredChat);
    expect(identical(covered.controller, f.workspace(t)), isTrue);
    expect(coveredState.presentationActive, isFalse);
    expect(TickerMode.valuesOf(t.element(coveredChat)).enabled, isFalse);
    expect(
      t
          .widget<EditableText>(
            find.descendant(
              of: coveredChat,
              matching: find.byType(EditableText, skipOffstage: false),
              skipOffstage: false,
            ),
          )
          .focusNode
          .hasFocus,
      isFalse,
    );

    // The owner may still receipt the open channel. The covered view must not
    // paint the row that arrived while it was underneath.
    f.client.event('message:new', {
      'id': 'fresh-covered',
      'channelId': 'ca',
      'seq': '2',
      'senderId': 'bob',
      'senderName': 'Bob',
      'content': 'Fresh while covered',
      'createdAt': '2026-10-15T00:00:00Z',
    });
    await f.flush(t);
    expect(
      find.descendant(
        of: channelChat(skipOffstage: false),
        matching: find.text('Fresh while covered', skipOffstage: false),
        skipOffstage: false,
      ),
      findsNothing,
    );

    expect(await t.binding.handlePopRoute(), isTrue);
    await f.flush(t);
    // The revealed page applies what arrived once the route transition ends.
    await t.pumpAndSettle();
    expect(find.text('Fresh while covered'), findsOneWidget);
    expect(TickerMode.valuesOf(t.element(channelChat())).enabled, isTrue);
    expect(t.takeException(), isNull);
    await f.close(t);
  });

  testWidgets('phone history uses one open, one older page, and one jump', (
    t,
  ) async {
    Future<({int open, int page, int jump, List<String> seen})>
    exercise() async {
      final f = RootFixture();
      // A fresh tail reports another page only when it holds at least 50 rows.
      useChannelHistory(f, count: 50, hasMore: true);
      f.overrides['GET /messages/context/missing-jump'] = (_) => {
        'messages': [
          {
            'id': 'missing-jump',
            'channelId': 'ca',
            'seq': '100',
            'senderId': 'alice',
            'senderName': 'Alice',
            'content': 'Jumped row',
            'createdAt': '2026-10-11T00:00:00Z',
          },
        ],
        'targetMessageId': 'missing-jump',
        'hasOlder': false,
        'hasNewer': false,
      };
      await f.mount(t, 'light', 390, uri: Uri.parse('/s/alpha/channel/ca'));
      expect(find.text('Row 50'), findsWidgets);
      final outer = f.workspace(t);
      final paging = outer.messageDomain.older();
      await f.flush(t);
      final jumping = outer.jumpToMessage('ca', 'missing-jump');
      await f.flush(t);
      await t.runAsync(() async {
        await paging.timeout(const Duration(seconds: 2));
        await jumping.timeout(const Duration(seconds: 2));
      });
      final seen = [
        for (final call in f.adapter.calls)
          if (call.path.contains('message') ||
              call.uri.path.contains('message'))
            '${call.method} ${requestPath(call)} before=${call.queryParameters['before']}',
      ];
      final counts = (
        open: messageReads(f, (call) => channelMessageGet(call, older: false)),
        page: messageReads(f, (call) => channelMessageGet(call, older: true)),
        jump: messageReads(
          f,
          (call) =>
              call.method == 'GET' &&
              requestPath(call).contains('/messages/context/'),
        ),
        seen: seen,
      );
      expect(t.takeException(), isNull);
      await f.close(t);
      return counts;
    }

    final counts = await exercise();
    expect(counts.open, greaterThan(0), reason: '$counts');
    expect(counts.page, greaterThan(0), reason: '$counts');
    expect(counts.jump, greaterThan(0), reason: '$counts');
  });

  testWidgets(
    'the phone thread opened from the channel uses the shared window',
    (t) async {
      final f = RootFixture();
      f.overrides['GET /messages/context/ma'] = (_) => {
        'messages': [
          {
            'id': 'ma',
            'channelId': 'ca',
            'seq': '1',
            'senderId': 'alice',
            'senderName': 'Alice',
            'content': 'Accepted a',
            'createdAt': '2026-10-10T00:00:00Z',
          },
        ],
        'hasOlder': false,
        'hasNewer': false,
      };
      await f.mount(
        t,
        'light',
        390,
        uri: Uri.parse('/s/alpha/channel/ca?thread=ca:ma'),
      );
      final threadChat = find.byWidgetPredicate(
        (widget) => widget is RaftChatView && widget.thread,
      );
      expect(threadChat, findsOneWidget);
      final scopes = t.widgetList<MobileChatDirectRead>(
        find.byType(MobileChatDirectRead),
      );
      expect(
        scopes.where((scope) => scope.thread && !scope.channel),
        isNotEmpty,
      );
      final page = t.widget<RaftChatView>(threadChat).controller;
      expect(
        identical(page.messageWindows, f.workspace(t).messageWindows),
        isTrue,
      );
      expect(t.takeException(), isNull);
      await f.close(t);
    },
  );

  testWidgets('a wide channel keeps the classic timeline', (t) async {
    final f = RootFixture();
    await f.mount(t, 'light', 1280, uri: Uri.parse('/s/alpha/channel/ca'));
    expect(find.byType(RaftChatView), findsWidgets);
    expect(find.byType(MobileChatDirectRead), findsNothing);
    expect(t.takeException(), isNull);
    await f.close(t);
  });
}
