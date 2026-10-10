
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration_test/message_scroll_performance_test.dart'
    show longMessage;
import 'chat_focus_receipt_test.dart' show contextRows, paintedMessage;
import 'message_presentation_test.dart' show fixture;

/// Desktop Activity: open a channel message, scroll far back (older pages
/// load), activate the same Activity row again. The re-positioning must never
/// overscroll (no spring-back with an empty gap) on any frame.
void main() {
  for (final (family, dark, fling, last, thread) in [
    (RaftFamily.brutal, false, false, false, false),
    (RaftFamily.elegant, false, false, false, false),
    (RaftFamily.brutal, false, true, false, false),
    (RaftFamily.elegant, false, true, false, false),
    (RaftFamily.brutal, false, false, true, false),
    (RaftFamily.elegant, false, true, true, false),
    (RaftFamily.brutal, false, false, true, true),
    (RaftFamily.elegant, false, true, true, true),
    (RaftFamily.brutal, false, false, false, true),
  ]) {
    final target = last ? 't-199' : 't-150';
    testWidgets(
      '$family/$dark fling=$fling target=$target thread=$thread Activity re-activation never overscrolls',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        w.loading = false;
        w.ledger.switchServer('s1');
        final other = RaftChannel({'id': 'o', 'name': 'other', 'joined': true});
        w.channels = [w.channel!, other];
        w.channel = other;
        w.section = 'activity';
        final rows = [
          for (final r in contextRows('t', count: 200))
            {
              ...r,
              'channelId': thread ? 'th' : 'c1',
              'senderType': 'user',
              'content': int.parse((r['id'] as String).substring(2)) % 3 == 0
                  ? longMessage(int.parse((r['id'] as String).substring(2)))
                  : r['content'],
            },
        ];
        api.routes['GET /channels/inbox'] = (_) => {
          'items': [
            if (thread)
              {
                'kind': 'thread',
                'threadChannelId': 'th',
                'parentChannelId': 'c1',
                'parentMessageId': 'parent',
                'parentMessagePreview': 'Open accepted channel',
                'latestActivityPreview': 'A real reply',
                'unreadCount': 2,
                'firstUnreadMessageId': target,
                'latestActivityMessageId': 't-199',
              }
            else
              {
                'kind': 'channel',
                'channelId': 'c1',
                'channelName': 'test',
                'lastMessagePreview': 'Open accepted channel',
                'unreadCount': 2,
                'firstUnreadMessageId': target,
                'lastMessageId': 't-199',
              },
          ],
        };
        api.routes['GET /messages/context/$target'] = (_) => {
          'messages': last ? rows.sublist(150) : rows.sublist(125, 176),
          'hasOlder': true,
          'hasNewer': !last,
        };
        api.routes['GET /messages/context/parent'] = (_) => {
          'messages': [
            {
              'id': 'parent',
              'channelId': 'c1',
              'seq': '1',
              'senderId': 'alice',
              'senderType': 'user',
              'content': 'parent',
            },
          ],
        };
        api.routes['POST /channels/th/read'] = (_) => {};
        api.routes['GET /messages/channel/${thread ? 'th' : 'c1'}'] =
            (request) {
              final before = int.tryParse(
                '${request.queryParameters['before']}',
              );
              final after = int.tryParse('${request.queryParameters['after']}');
              if (after != null) {
                return {
                  'messages': rows.sublist(after, (after + 50).clamp(0, 200)),
                };
              }
              final end = before == null ? rows.length : before - 1;
              final start = (end - 50).clamp(0, end);
              return {'messages': rows.sublist(start, end)};
            };
        api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
        api.routes['POST /channels/c1/read'] = (_) => {};
        api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
        api.routes['GET /servers/s1/setup-projection'] = (_) => {
          'phase': 'complete',
          'surface': 'complete',
          'blocksChat': false,
        };
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: WorkspaceView(
              controller: w,
              appearance: RaftAppearance(light: family),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final row = find.textContaining('Open accepted channel');
        expect(row, findsWidgets);
        Future<void> activate() async {
          await tester.tap(row.first);
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 16));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 5)),
            );
          }
        }

        await activate();
        await tester.pumpAndSettle();
        String diag() {
          final parts = <String>[
            'threadLoading=${w.threadLoading} replies=${w.replies.length} '
                'threadChannel=${w.threadChannelId} hl=${w.highlightedMessageId} '
                'calls=${api.calls.map((c) => c.path).toList()}',
          ];
          for (final scrollable
              in find
                  .descendant(
                    of: find.byType(RaftChatView),
                    matching: find.byType(Scrollable),
                  )
                  .evaluate()) {
            final q = ((scrollable as StatefulElement).state as ScrollableState)
                .position;
            if (!q.hasPixels || !q.hasContentDimensions) continue;
            parts.add(
              'px=${q.pixels} ${q.minScrollExtent}..${q.maxScrollExtent} '
              'vp=${q.viewportDimension} axis=${q.axisDirection}',
            );
          }
          return parts.join('\n');
        }

        expect(paintedMessage(tester, target), isNotNull, reason: diag());
        final chat = find.byType(RaftChatView).last;
        for (var k = 0; k < 25; k++) {
          await tester.timedDrag(
            chat,
            const Offset(0, 700),
            const Duration(milliseconds: 120),
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();
        expect(paintedMessage(tester, target), isNull);
        final log = <String>['messages=${w.messages.length}'];
        var bad = 0;
        if (fling) {
          // Trackpad-style flick back, then activate while it still coasts.
          await tester.fling(chat, const Offset(0, 900), 6000);
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.tap(row.first);
        for (var i = 0; i < 80; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          if (i % 4 == 0) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 5)),
            );
          }
          for (final scrollable
              in find
                  .descendant(
                    of: find.byType(RaftChatView),
                    matching: find.byType(Scrollable),
                  )
                  .evaluate()) {
            final q = (scrollable as StatefulElement).state is ScrollableState
                ? (scrollable.state as ScrollableState).position
                : null;
            if (q == null || !q.hasPixels || !q.hasContentDimensions) continue;
            if (q.axis != Axis.vertical) continue;
            final rect = paintedMessage(tester, target);
            log.add(
              '$i px=${q.pixels.toStringAsFixed(0)} '
              'range=${q.minScrollExtent.toStringAsFixed(0)}..'
              '${q.maxScrollExtent.toStringAsFixed(0)} '
              'out=${q.outOfRange} act=${q.activity.runtimeType} '
              'target=${rect?.top.toStringAsFixed(0)}',
            );
            if (q.outOfRange) bad++;
            // Repositioning is never an animated scroll.
            if (q.activity is DrivenScrollActivity) bad++;
          }
        }
        expect(bad, 0, reason: log.join('\n'));
        // Once the target is painted it stays put: no visible second jump.
        final painted = <String>[
          for (final line in log.skip(1))
            if (!line.endsWith('target=null'))
              RegExp(r'target=(-?\d+)').firstMatch(line)!.group(1)!,
        ];
        expect(painted.toSet().length, 1, reason: log.join('\n'));
        expect(
          paintedMessage(tester, target),
          isNotNull,
          reason: log.join('\n'),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }
}
