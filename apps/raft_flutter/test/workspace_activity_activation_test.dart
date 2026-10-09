import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;

const threadRow = <String, dynamic>{
  'kind': 'thread',
  'threadChannelId': 'thread-1',
  'parentChannelId': 'c1',
  'parentMessageId': 'parent',
  'parentMessagePreview': 'Open accepted thread directly',
  'latestActivityPreview': 'A real reply',
  'unreadCount': 2,
  'firstMentionMessageId': 'mention-reply',
  'firstUnreadMessageId': 'reply',
  'latestActivityMessageId': 'latest-reply',
};
const channelRow = <String, dynamic>{
  'kind': 'channel',
  'channelId': 'c1',
  'channelName': 'test',
  'lastMessagePreview': 'Open accepted channel',
  'unreadCount': 2,
  'firstMentionMessageId': 'mention-channel',
  'firstUnreadMessageId': 'first-channel',
  'lastMessageId': 'latest-channel',
};
Map<String, dynamic> message(String id, String channel) => {
  'id': id,
  'channelId': channel,
  'seq': '1',
  'senderId': 'alice',
  'senderType': 'user',
  'content': 'Accepted $id',
};

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final scenario in ['thread', 'channel', 'dm']) {
      final channelAfterThread = scenario != 'thread';
      final dm = scenario == 'dm';
      final destination = dm ? 'd1' : 'c1';
      final channelTarget = dm ? 'first-dm' : 'first-channel';
      testWidgets(
        '${dm
            ? '[N24c] DM-single'
            : channelAfterThread
            ? '[N24b] channel-after-thread'
            : '[N24a] thread-single'} $family/$dark actual Activity slot has no channel detour',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = const Size(1440, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
          addTearDown(w.dispose);
          w.loading = false;
          w.ledger.switchServer('s1');
          final unrelated = RaftChannel({
            'id': 'unrelated',
            'name': 'retained main channel',
            'joined': true,
          });
          w.channels = [w.channel!, unrelated];
          w.channel = unrelated;
          w.dms = [
            RaftChannel({
              'id': 'd1',
              'name': 'Alice',
              'type': 'dm',
              'joined': true,
            }),
          ];
          w.ledger.ingest([
            message('old-main', 'unrelated'),
          ], expectedGeneration: w.ledger.generation);
          w.visibleIds['unrelated'] = {'old-main'};
          w.section = 'activity';
          final parent = Completer<Map<String, dynamic>>();
          final replies = Completer<Map<String, dynamic>>();
          api.routes['GET /channels/inbox'] = (_) => {
            'items': [
              threadRow,
              channelRow,
              {
                ...channelRow,
                'kind': 'dm',
                'channelId': 'd1',
                'channelName': 'Alice',
                'firstUnreadMessageId': 'first-dm',
              },
            ],
          };
          api.routes['GET /messages/context/parent'] = (_) => parent.future;
          api.routes['GET /messages/context/reply'] = (_) => replies.future;
          api.routes['GET /channels/c1/threads/parent'] = (_) => {
            'threadChannelId': 'thread-1',
          };
          api.routes['GET /messages/context/$channelTarget'] = (_) => {
            'messages': [message(channelTarget, destination)],
          };
          api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
          api.routes['POST /channels/thread-1/read'] = (_) => {};
          api.routes['POST /channels/c1/read'] = (_) => {};
          api.routes['POST /channels/d1/read'] = (_) => {};
          api.routes['POST /feature-flags/evaluate'] = (_) => {
            'evaluations': [],
          };
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
          expect(w.section, 'activity');
          expect(
            find.byKey(const ValueKey('activity-thread-thread-1')),
            findsOneWidget,
            reason:
                'route=${w.location} calls=${api.calls.map((r) => r.path).toList()} texts=${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList()}',
          );
          final observed = <RaftLocation>[];
          void observe() => observed.add(w.location);
          w.addListener(observe);
          addTearDown(() => w.removeListener(observe));
          final entries = w.navigation.entries.length;
          await tester.tap(
            find.byKey(const ValueKey('activity-thread-thread-1')),
          );
          // The first activation is delivered immediately by the SDK; the
          // actual mounted Activity consumer alone owns Source's 220 ms wait.
          await tester.pump(const Duration(milliseconds: 219));
          expect(w.location.content, isNull);
          expect(w.threadIdentity, isNull);
          expect(
            api.calls.where((r) => r.path == '/messages/context/parent'),
            isEmpty,
          );
          await tester.pump(const Duration(milliseconds: 1));
          for (var frame = 0; frame < 5; ++frame) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(w.location.route, RaftRoute.activity);
            expect(w.location.content?.kind, RaftContentKind.thread);
            expect(w.location.content?.id, 'thread-1');
            expect(w.location.thread?.channelId, 'c1');
            expect(w.location.thread?.itemId, 'parent');
            expect(w.location.messageId, 'reply');
            expect(w.channel?.id, 'unrelated');
            expect(w.messages.map((row) => row.id), ['old-main']);
            expect(w.presentedThreadParent, isNull);
            expect(find.byType(RaftThreadHeader), findsOneWidget);
            expect(
              tester
                  .widget<RaftThreadHeader>(find.byType(RaftThreadHeader))
                  .parentLabel,
              '#test',
            );
            expect(find.byType(RaftChatView), findsOneWidget);
            expect(
              tester.widget<RaftChatView>(find.byType(RaftChatView)).thread,
              isTrue,
            );
          }
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          expect(
            api.calls.where((r) => r.path == '/channels/c1/threads/parent'),
            isEmpty,
          );
          expect(
            api.calls
                .where((r) => r.path == '/messages/context/parent')
                .single
                .queryParameters['channelId'],
            'c1',
          );
          expect(
            api.calls
                .where((r) => r.path == '/messages/context/reply')
                .single
                .queryParameters['channelId'],
            'thread-1',
          );
          expect(
            observed.every(
              (uri) => uri.content?.kind == RaftContentKind.thread,
            ),
            isTrue,
          );
          expect(w.navigation.entries.length, entries);
          if (channelAfterThread) {
            observed.clear();
            await tester.tap(
              find.byKey(
                ValueKey(dm ? 'activity-dm-d1' : 'activity-channel-c1'),
              ),
            );
            await tester.pump(const Duration(milliseconds: 220));
            for (var frame = 0; frame < 4; ++frame) {
              await tester.pump(const Duration(milliseconds: 16));
              expect(w.location.route, RaftRoute.activity);
              expect(
                w.location.content?.kind,
                dm ? RaftContentKind.dm : RaftContentKind.channel,
              );
              expect(w.location.content?.id, destination);
              expect(w.location.messageId, channelTarget);
              expect(w.location.thread, isNull);
              expect(w.threadIdentity, isNull);
              expect(find.byType(RaftThreadHeader), findsNothing);
            }
            expect(
              observed.every((uri) => uri.content?.id == destination),
              isTrue,
            );
            expect(w.navigation.entries.length, entries);
          }
          await tester.runAsync(() async {
            replies.complete({
              'messages': [message('reply', 'thread-1')],
            });
            parent.complete({
              'messages': [message('parent', 'c1')],
            });
            await Future<void>.delayed(const Duration(milliseconds: 35));
          });
          await tester.pumpAndSettle();
          if (channelAfterThread) {
            expect(w.threadIdentity, isNull);
            expect(
              w.location.content?.kind,
              dm ? RaftContentKind.dm : RaftContentKind.channel,
            );
            expect(w.messages.map((row) => row.id), [channelTarget]);
          } else {
            expect(w.presentedThreadParent?.id, 'parent');
            expect(w.messages.map((row) => row.id), ['old-main']);
          }
          for (var frame = 0; frame < 5; ++frame) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
    for (final thread in [true, false]) {
      testWidgets(
        '[N24d] double-${thread ? 'thread' : 'channel'} $family/$dark actual Activity cancels 220ms slot and pushes one canonical route',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = const Size(1440, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
          addTearDown(w.dispose);
          w.loading = false;
          w.ledger.switchServer('s1');
          w.section = 'activity';
          final parent = Completer<Map<String, dynamic>>(),
              resolution = Completer<Map<String, dynamic>>(),
              target = Completer<Map<String, dynamic>>();
          api.routes['GET /channels/inbox'] = (_) => {
            'items': [threadRow, channelRow],
          };
          api.routes['GET /messages/context/parent'] = (_) => parent.future;
          api.routes['GET /channels/c1/threads/parent'] = (_) =>
              resolution.future;
          api.routes['GET /messages/context/mention-reply'] = (_) =>
              target.future;
          api.routes['GET /messages/context/first-channel'] = (_) =>
              target.future;
          api.routes['GET /messages/channel/c1'] = (_) => {
            'messages': [message('outer-tail', 'c1')],
          };
          api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
          api.routes['POST /feature-flags/evaluate'] = (_) => {
            'evaluations': [],
          };
          api.routes['POST /channels/thread-1/read'] = (_) => {};
          api.routes['POST /channels/c1/read'] = (_) => {};
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
          expect(w.section, 'activity');
          expect(
            find.byKey(const ValueKey('activity-thread-thread-1')),
            findsOneWidget,
            reason:
                'route=${w.location} calls=${api.calls.map((r) => r.path).toList()} texts=${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList()}',
          );
          final observed = <RaftLocation>[];
          void observe() => observed.add(w.location);
          w.addListener(observe);
          addTearDown(() => w.removeListener(observe));
          final before = w.navigation.entries.length;
          final card = find.byKey(
            ValueKey(
              thread ? 'activity-thread-thread-1' : 'activity-channel-c1',
            ),
          );
          await tester.tap(card);
          await tester.pump(const Duration(milliseconds: 80));
          expect(w.location.route, RaftRoute.activity);
          expect(w.location.content, isNull);
          await tester.tap(card);
          for (var frame = 0; frame < 20; ++frame) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(w.location.route, RaftRoute.channel);
            expect(w.location.entityId, 'c1');
            expect(w.location.content, isNull);
            expect(
              w.location.messageId,
              thread ? 'mention-reply' : 'first-channel',
            );
            expect(w.location.thread?.itemId, thread ? 'parent' : null);
            expect(
              find.byType(RaftThreadHeader),
              thread ? findsOneWidget : findsNothing,
            );
          }
          expect(w.navigation.entries.length, before + 1);
          expect(observed, isNotEmpty);
          expect(
            observed.every(
              (uri) => uri.route == RaftRoute.channel && uri.content == null,
            ),
            isTrue,
          );
          await tester.runAsync(() async {
            if (thread) {
              resolution.complete({'threadChannelId': 'thread-1'});
              await Future<void>.delayed(const Duration(milliseconds: 20));
            }
            target.complete({
              'messages': [
                message(
                  thread ? 'mention-reply' : 'first-channel',
                  thread ? 'thread-1' : 'c1',
                ),
              ],
            });
            parent.complete({
              'messages': [message('parent', 'c1')],
            });
            await Future<void>.delayed(const Duration(milliseconds: 35));
          });
          for (var frame = 0; frame < 6; ++frame) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(w.navigation.entries.length, before + 1);
          expect(w.location.content, isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
