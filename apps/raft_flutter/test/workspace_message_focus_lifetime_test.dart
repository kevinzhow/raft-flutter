import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'chat_focus_receipt_test.dart' show contextRows, paintedMessage;
import 'message_presentation_test.dart' show MessageAdapter;
import 'workspace_source_location_contract_test.dart'
    show pageFixture, mountPage;

class _SearchFocusPage {
  _SearchFocusPage(this.workspace, this.api);
  final WorkspaceController workspace;
  final MessageAdapter api;

  static Future<_SearchFocusPage> mount(
    WidgetTester tester,
    RaftFamily family,
    bool dark, {
    bool otherChannel = false,
  }) async {
    final (w, api) = await pageFixture(tester, section: 'search');
    final rows = contextRows('cache');
    api.routes['GET /messages/channel/c1'] = (_) => {
      'messages': rows,
      'historyLimited': true,
      'threadSummariesByParentMessageId': {
        'cache-20': {'replyCount': 2},
      },
    };
    // Establish accepted window ownership through the real tail endpoint.
    // historyLimited is tail metadata; Source context acceptance sets it false
    // (messageStore2433–2457), irrespective of an unsupported response field.
    await tester.runAsync(() => w.selectChannel(w.channel!, navigate: false));
    if (otherChannel) {
      w.channels.add(
        RaftChannel({'id': 'c2', 'name': 'Other channel', 'joined': true}),
      );
      api.routes['POST /channels/c2/read'] = (_) => {};
    }
    api.routes['GET /messages/search'] = (_) => {
      'results': [
        {
          ...rows[20],
          'channelType': 'channel',
          'channelName': 'test',
          'content': 'Actual first cached result',
        },
        {
          ...rows[55],
          if (otherChannel) 'id': 'next-40',
          if (otherChannel) 'channelId': 'c2',
          'channelType': 'channel',
          'channelName': otherChannel ? 'Other channel' : 'test',
          'content': 'Actual second result',
        },
      ],
      'hasMore': false,
    };
    await mountPage(tester, w, family, dark);
    await tester.enterText(find.byType(TextField).first, 'Actual');
    await tester.pump(const Duration(milliseconds: 210));
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byType(RaftSearchResultSurface), findsNWidgets(2));
    return _SearchFocusPage(w, api);
  }

  int get contextRequests => api.calls
      .where((request) => request.path.startsWith('/messages/context/'))
      .length;

  dynamic getState(WidgetTester tester) =>
      tester.state(find.byType(RaftChatView));

  void assertHighlighted(WidgetTester tester, String id, bool highlighted) {
    expect(
      tester
          .widget<RaftMessageTile>(find.byKey(ValueKey('message-$id')))
          .highlighted,
      highlighted,
    );
  }

  Rect assertCentered(WidgetTester tester, String id) {
    final bounds = paintedMessage(tester, id);
    expect(bounds, isNotNull);
    final dynamic state = getState(tester);
    final anchor =
        state.focusAnchors[id].currentContext.findRenderObject() as RenderBox;
    final view = RenderAbstractViewport.of(anchor) as RenderBox;
    final clip = view.localToGlobal(Offset.zero) & view.size;
    expect(bounds!.center.dy, closeTo(clip.center.dy, .5));
    return bounds;
  }

  Future<Rect> waitForCentered(WidgetTester tester, String id) async {
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (paintedMessage(tester, id) != null) {
        // Assert the first painted target, rather than waiting for a later
        // settled viewport that could conceal an intermediate jump.
        return assertCentered(tester, id);
      }
    }
    fail('The actual target did not paint within 40 frames: $id');
  }

  Future<Rect> clickFirst(WidgetTester tester) async {
    await tester.tap(find.byType(RaftSearchResultSurface).first);
    return waitForCentered(tester, 'cache-20');
  }
}

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '[L01] $family/$dark actual cached Search result centers without another context GET or metadata reset',
      (tester) async {
        final page = await _SearchFocusPage.mount(tester, family, dark);
        final w = page.workspace;
        final before = (
          page.contextRequests,
          w.hasMore,
          w.hasNewer,
          w.historyLimited,
          jsonEncode(w.threadSummaries),
          w.messages.map((row) => row.id).toList(),
        );
        expect(before.$1, 0);
        expect((before.$2, before.$3, before.$4), (false, false, true));
        expect(w.threadSummaries['cache-20']['replyCount'], 2);
        final first = await page.clickFirst(tester);
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(page.assertCentered(tester, 'cache-20'), first);
          page.assertHighlighted(tester, 'cache-20', true);
          expect(w.channelLoading, false);
          expect(page.contextRequests, before.$1);
          expect(
            (w.hasMore, w.hasNewer, w.historyLimited),
            (before.$2, before.$3, before.$4),
          );
          expect(jsonEncode(w.threadSummaries), before.$5);
          expect(w.messages.map((row) => row.id), before.$6);
        }
        expect(w.location.content?.id, 'c1');
        expect(w.location.messageId, 'cache-20');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      '[L03] $family/$dark actual second cached Search target owns its full highlight lifetime after the old timer deadline',
      (tester) async {
        final page = await _SearchFocusPage.mount(tester, family, dark);
        final w = page.workspace;
        await page.clickFirst(tester);
        final Timer oldTimer = page.getState(tester).highlightTimer;
        expect(oldTimer.isActive, true);
        await tester.pump(const Duration(milliseconds: 1000));
        page.assertHighlighted(tester, 'cache-20', true);
        await tester.tap(find.byType(RaftSearchResultSurface).last);
        final second = await page.waitForCentered(tester, 'cache-55');
        expect(oldTimer.isActive, false);
        expect(w.highlightedMessageId, 'cache-55');
        page.assertHighlighted(tester, 'cache-55', true);
        // Cross the first target's old expiry while the second owns its timer.
        await tester.pump(const Duration(milliseconds: 1100));
        expect(w.highlightedMessageId, 'cache-55');
        page.assertHighlighted(tester, 'cache-55', true);
        expect(page.assertCentered(tester, 'cache-55'), second);
        await tester.pump(const Duration(milliseconds: 600));
        expect(w.highlightedMessageId, 'cache-55');
        await tester.pump(const Duration(milliseconds: 400));
        expect(w.highlightedMessageId, isNull);
        page.assertHighlighted(tester, 'cache-55', false);
        expect(page.assertCentered(tester, 'cache-55'), second);
        expect(page.contextRequests, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      '[L03] $family/$dark actual cross-channel Search target survives the old expiry while its context is held',
      (tester) async {
        final page = await _SearchFocusPage.mount(
          tester,
          family,
          dark,
          otherChannel: true,
        );
        final w = page.workspace;
        final response = Completer<Map<String, dynamic>>.sync();
        page.api.routes['GET /messages/context/next-40'] = (_) =>
            response.future;
        await page.clickFirst(tester);
        await tester.pump(const Duration(milliseconds: 1000));
        await tester.tap(find.byType(RaftSearchResultSurface).last);
        // Real input changed the presented channel but the new response waits.
        // Every frame crosses the old timer deadline without clearing the new
        // pending target or painting the old private window in this channel.
        for (var frame = 0; frame < 80; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(w.channel?.id, 'c2');
          expect(w.location.content?.id, 'c2');
          expect(w.highlightedMessageId, 'next-40');
          expect(w.channelLoading, true);
          expect(paintedMessage(tester, 'cache-20'), isNull);
          expect(paintedMessage(tester, 'next-40'), isNull);
        }
        final request = page.api.calls
            .where((r) => r.path == '/messages/context/next-40')
            .single;
        expect(request.queryParameters['channelId'], 'c2');
        response.complete({
          'messages': [
            for (final row in contextRows('next')) {...row, 'channelId': 'c2'},
          ],
          'hasOlder': true,
          'hasNewer': true,
        });
        final next = await page.waitForCentered(tester, 'next-40');
        expect(w.channelLoading, false);
        page.assertHighlighted(tester, 'next-40', true);
        await tester.pump(const Duration(milliseconds: 1700));
        expect(w.highlightedMessageId, 'next-40');
        page.assertHighlighted(tester, 'next-40', true);
        await tester.pump(const Duration(milliseconds: 400));
        expect(w.highlightedMessageId, isNull);
        page.assertHighlighted(tester, 'next-40', false);
        expect(page.assertCentered(tester, 'next-40'), next);
        expect(page.contextRequests, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
