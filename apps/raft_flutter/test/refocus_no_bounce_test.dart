import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show contextRows, paintedMessage;
import 'message_presentation_test.dart' show fixture;
import '../integration_test/message_scroll_performance_test.dart'
    show longMessage;

/// Activity → open a message's context, scroll far away, open the same
/// message again: the list repositions to it without ever leaving its
/// scroll range (no overscroll spring / blank gap) on any frame.
void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
  ]) {
    testWidgets('$family/$dark refocusing the same message never overscrolls', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (w, api) = (await tester.runAsync(() => fixture('member')))!;
      addTearDown(w.dispose);
      w.ledger.switchServer('s1');
      final rows = [
        for (final r in contextRows('t', count: 200))
          {
            ...r,
            'content': int.parse((r['id'] as String).substring(2)) % 3 == 0
                ? longMessage(int.parse((r['id'] as String).substring(2)))
                : r['content'],
          },
      ];
      // The context window is 50 rows around the target; scrolling back
      // pages older rows in, so the second open replaces a larger window.
      api.routes['GET /messages/context/t-150'] = (_) => {
        'messages': rows.sublist(125, 176),
        'hasOlder': true,
        'hasNewer': true,
      };
      api.routes['GET /messages/channel/c1'] = (request) {
        final before = int.tryParse('${request.queryParameters['before']}');
        final end = before == null ? rows.length : before - 1;
        final start = (end - 50).clamp(0, end);
        return {'messages': rows.sublist(start, end), 'historyLimited': false};
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Scaffold(body: RaftChatView(controller: w)),
        ),
      );
      Future<void> open() async {
        await tester.runAsync(() async {
          unawaited(w.jumpToMessage('c1', 't-150'));
          for (var i = 0; i < 60 && (w.channelLoading || i < 4); i++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        });
      }

      await open();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(paintedMessage(tester, 't-150'), isNotNull);
      final dynamic state = tester.state(find.byType(RaftChatView));
      // Scroll far back with real drags; older pages load on the way.
      for (var k = 0; k < 25; k++) {
        await tester.timedDrag(
          find.byType(RaftChatView),
          const Offset(0, 700),
          const Duration(milliseconds: 120),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      expect(w.messages.length, greaterThan(60));
      expect(paintedMessage(tester, 't-150'), isNull);

      await open();
      final log = <String>[];
      var bad = 0;
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final ScrollController now = state.viewport;
        if (!now.hasClients) {
          log.add('$i detached');
          continue;
        }
        final q = now.position;
        final rect = paintedMessage(tester, 't-150');
        log.add(
          '$i px=${q.pixels.toStringAsFixed(0)} '
          'range=${q.minScrollExtent.toStringAsFixed(0)}..'
          '${q.maxScrollExtent.toStringAsFixed(0)} '
          'out=${q.outOfRange} target=${rect?.top.toStringAsFixed(0)}',
        );
        if (q.outOfRange) bad++;
      }
      expect(bad, 0, reason: log.join('\n'));
      expect(
        paintedMessage(tester, 't-150'),
        isNotNull,
        reason: log.join('\n'),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }

  for (final family in [RaftFamily.brutal, RaftFamily.elegant]) {
    testWidgets('$family thread: reopening the same reply never overscrolls', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (w, api) = (await tester.runAsync(() => fixture('member')))!;
      addTearDown(w.dispose);
      w.ledger.switchServer('s1');
      final replies = [
        for (final r in contextRows('r', count: 200)) {...r, 'channelId': 'th'},
      ];
      api.routes['GET /messages/context/parent'] = (_) => {
        'messages': [
          {
            'id': 'parent',
            'channelId': 'c1',
            'seq': '1',
            'senderId': 'alice',
            'content': 'parent',
          },
        ],
      };
      api.routes['GET /messages/context/r-150'] = (_) => {
        'messages': replies.sublist(125, 176),
        'hasOlder': true,
        'hasNewer': true,
      };
      api.routes['GET /messages/channel/th'] = (request) {
        final before = int.tryParse('${request.queryParameters['before']}');
        final after = int.tryParse('${request.queryParameters['after']}');
        if (after != null) {
          return {
            'messages': replies.sublist(after, (after + 50).clamp(0, 200)),
          };
        }
        final end = before == null ? replies.length : before - 1;
        final start = (end - 50).clamp(0, end);
        return {'messages': replies.sublist(start, end)};
      };
      Future<void> open() => tester.runAsync(() async {
        unawaited(
          w.openThreadIdentity(
            parentChannelId: 'c1',
            parentMessageId: 'parent',
            initialThreadChannelId: 'th',
            focusedMessageId: 'r-150',
            navigate: false,
          ),
        );
        for (var i = 0; i < 60 && (w.threadLoading || i < 4); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await open();
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(family),
          home: Scaffold(body: RaftChatView(controller: w, thread: true)),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(paintedMessage(tester, 'r-150'), isNotNull);
      for (var k = 0; k < 25; k++) {
        await tester.timedDrag(
          find.byType(RaftChatView),
          const Offset(0, 700),
          const Duration(milliseconds: 120),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      expect(paintedMessage(tester, 'r-150'), isNull);
      final dynamic state = tester.state(find.byType(RaftChatView));
      await open();
      final log = <String>[];
      var bad = 0;
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final ScrollController now = state.viewport;
        if (!now.hasClients) {
          log.add('$i detached');
          continue;
        }
        final q = now.position;
        final rect = paintedMessage(tester, 'r-150');
        log.add(
          '$i px=${q.pixels.toStringAsFixed(0)} '
          'range=${q.minScrollExtent.toStringAsFixed(0)}..'
          '${q.maxScrollExtent.toStringAsFixed(0)} '
          'out=${q.outOfRange} target=${rect?.top.toStringAsFixed(0)}',
        );
        if (q.outOfRange) bad++;
      }
      expect(bad, 0, reason: log.join('\n'));
      expect(
        paintedMessage(tester, 'r-150'),
        isNotNull,
        reason: log.join('\n'),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('thread: own reply while scrolled to the top jumps to the end, '
      'no animated or inertial travel', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (w, api) = (await tester.runAsync(() => fixture('member')))!;
    addTearDown(w.dispose);
    w.ledger.switchServer('s1');
    final replies = [
      for (final r in contextRows('r', count: 120)) {...r, 'channelId': 'th'},
    ];
    api.routes['GET /messages/context/parent'] = (_) => {
      'messages': [
        {
          'id': 'parent',
          'channelId': 'c1',
          'seq': '1',
          'senderId': 'bob',
          'content': 'parent',
        },
      ],
    };
    api.routes['GET /messages/channel/th'] = (_) => {'messages': replies};
    api.routes['POST /channels/th/read'] = (_) => {};
    await tester.runAsync(
      () => w.openThreadIdentity(
        parentChannelId: 'c1',
        parentMessageId: 'parent',
        initialThreadChannelId: 'th',
        navigate: false,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(body: RaftChatView(controller: w, thread: true)),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final dynamic state = tester.state(find.byType(RaftChatView));
    final ScrollController scroll = state.viewport;
    // Scroll to the very top (oldest) with real drags.
    for (
      var k = 0;
      k < 30 && scroll.offset > scroll.position.minScrollExtent;
      k++
    ) {
      await tester.timedDrag(
        find.byType(RaftChatView),
        const Offset(0, 900),
        const Duration(milliseconds: 100),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(scroll.offset, scroll.position.minScrollExtent);
    final own = {
      'id': 'mine',
      'channelId': 'th',
      'seq': '500',
      'senderId': w.client.user!.id,
      'senderType': 'user',
      'content': 'my reply',
    };
    w.ledger.ingest([own], expectedGeneration: w.ledger.generation);
    w.visibleIds['th']!.add('mine');
    w.notifyListeners();
    final log = <String>[];
    var bad = 0, framesToEnd = -1;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final q = scroll.position;
      log.add(
        '$i px=${q.pixels.toStringAsFixed(0)} max=${q.maxScrollExtent.toStringAsFixed(0)} act=${q.activity.runtimeType}',
      );
      if (q.outOfRange) bad++;
      if (framesToEnd < 0 &&
          paintedMessage(tester, 'mine') != null &&
          (q.pixels - q.maxScrollExtent).abs() < .5) {
        framesToEnd = i;
      }
    }
    expect(bad, 0, reason: log.join('\n'));
    expect(framesToEnd, inInclusiveRange(0, 3), reason: log.join('\n'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
