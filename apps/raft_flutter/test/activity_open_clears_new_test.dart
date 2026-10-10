import 'dart:async';

import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

Map<String, dynamic> activityRow(
  String kind, {
  int unread = 2,
  String seq = '5',
}) {
  final thread = kind == 'thread';
  final dm = kind == 'dm';
  final id = thread
      ? 'thread-1'
      : dm
      ? 'd1'
      : 'c1';
  return {
    'kind': kind,
    if (thread) ...{
      'threadChannelId': id,
      'parentChannelId': 'c1',
      'parentChannelName': 'test',
      'parentMessageId': 'parent',
      'parentMessagePreview': 'Parent message',
      'latestActivityMessageId': 'm$seq',
      'latestActivityPreview': 'Reply $seq',
      'latestActivitySenderType': 'user',
      'latestActivitySenderId': 'bob',
      'latestActivitySenderName': 'Bob',
      'lastActivityAt': '2026-10-10T01:00:00Z',
      'replyCount': 3,
      'isFollowing': true,
    } else ...{
      'channelId': id,
      'channelName': dm ? 'Bob' : 'test',
      'lastMessageId': 'm$seq',
      'lastMessagePreview': 'Message $seq',
      'lastMessageSenderType': 'user',
      'lastMessageSenderId': 'bob',
      'lastMessageSenderName': 'Bob',
      'lastMessageAt': '2026-10-10T01:00:00Z',
    },
    'latestActivitySeq': seq,
    'readState': {
      'kind': 'present',
      'maxReadSeq': '0',
      'readStateVersion': 1,
      'latestActivity': {'messageId': 'm$seq', 'seq': seq},
    },
    'unreadCount': unread,
    'firstUnreadMessageId': unread > 0 ? 'first' : null,
    'hasMention': false,
  };
}

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final kind in ['channel', 'thread', 'dm']) {
      for (final canonical in [true, false]) {
        testWidgets(
          '[Activity open clears new] $family/$dark $kind ${canonical ? 'master-detail waits 220 ms like Source handleOpen' : 'single route opens at once'}',
          (tester) async {
            final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
            addTearDown(w.dispose);
            w.channels = [
              RaftChannel({'id': 'c1', 'name': 'test', 'joined': true}),
            ];
            w.dms = [
              RaftChannel({
                'id': 'd1',
                'name': 'Bob',
                'type': 'dm',
                'joined': true,
              }),
            ];
            final target = activityRow(kind);
            var served = [target];
            final scope = kind == 'thread'
                ? 'thread-1'
                : kind == 'dm'
                ? 'd1'
                : 'c1';
            final key = kind == 'thread'
                ? const ValueKey('activity-thread-thread-1')
                : ValueKey('activity-$kind-$scope');
            final opened = <Map<String, dynamic>>[];
            api.routes['GET /agents'] = (_) => [];
            api.routes['GET /servers/s1/members'] = (_) => [];
            api.routes['GET /channels/unread'] = (_) => {
              'channels': <String, int>{},
            };
            api.routes['GET /channels/inbox'] = (_) => {
              'items': served,
              'totalCount': served.length,
              'totalUnreadCount': served.fold<int>(
                0,
                (sum, row) => sum + (row['unreadCount'] as int),
              ),
              'hasMore': false,
            };
            api.routes['POST /channels/$scope/read-all'] = (_) => {
              'maxReadSeq': 5,
              'readStateVersion': 7,
            };
            Widget page() => MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: Scaffold(
                body: ResourceView(
                  controller: w,
                  section: 'activity',
                  onMessage: (_, _) async {},
                  onActivityItem: (row) async => opened.add(row),
                  onActivityCanonical: canonical ? (_) async {} : null,
                ),
              ),
            );
            Finder badge(String label) => find.descendant(
              of: find.byKey(key),
              matching: find.text(label),
            );
            List<RequestOptions> readAlls() => api.calls
                .where((r) => r.path == '/channels/$scope/read-all')
                .toList();

            await tester.pumpWidget(page());
            await tester.pumpAndSettle();
            expect(badge('2 new'), findsOneWidget);

            await tester.tap(find.byKey(key));
            if (canonical) {
              // Source handleOpen runs after the 220 ms single-click wait.
              await tester.pump(const Duration(milliseconds: 219));
              expect(badge('2 new'), findsOneWidget);
              expect(opened, isEmpty);
              await tester.pump(const Duration(milliseconds: 1));
            } else {
              await tester.pump();
            }
            // Every frame from the open moment on: no indicator.
            for (var frame = 0; frame < 6; frame++) {
              expect(badge('2 new'), findsNothing, reason: 'frame $frame');
              expect(find.text('2 new'), findsNothing);
              await tester.pump(const Duration(milliseconds: 16));
            }
            await tester.pumpAndSettle();
            expect(badge('2 new'), findsNothing);
            expect(opened, hasLength(1));
            expect(readAlls(), hasLength(1));
            expect(readAlls().single.data, isNull);
            final dynamic state = tester.state(find.byType(ResourceView));
            expect(state.totalUnreadCount, 0);
            expect(state.rows.single['unreadCount'], 0);

            // The server still serves the pre-read row (eventual consistency);
            // leaving and returning keeps the row read from the first frame.
            await tester.pumpWidget(
              MaterialApp(
                theme: raftTheme(family, dark: dark),
                home: const Scaffold(body: SizedBox.expand()),
              ),
            );
            await tester.pumpAndSettle();
            await tester.pumpWidget(page());
            expect(badge('2 new'), findsNothing);
            await tester.pump(const Duration(milliseconds: 16));
            expect(badge('2 new'), findsNothing);
            await tester.pumpAndSettle();
            expect(badge('2 new'), findsNothing);
            expect(find.byKey(key), findsOneWidget);

            // A genuinely newer message shows the indicator again.
            served = [activityRow(kind, unread: 1, seq: '6')];
            final dynamic returned = tester.state(find.byType(ResourceView));
            unawaited(returned.reconcile());
            await tester.pumpAndSettle();
            expect(badge('1 new'), findsOneWidget);
          },
        );
      }
    }
  }
}
