import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show paintedMessage;
import 'message_context_transition_test.dart' show row;
import 'message_presentation_test.dart' show fixture;
import 'mounted_message_navigation_test.dart'
    show pageFixture, mountPage, pageFrames;
import 'workspace_activity_activation_test.dart' show channelRow, threadRow;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final invalidate in [
    null,
    'principal',
    'client-generation',
    'capability',
  ]) {
    test('[N24g] accepted memory bucket ownership: $invalidate', () async {
      final (w, api) = await fixture('owner');
      addTearDown(w.dispose);
      w.ledger.switchServer('s1');
      final c2 = RaftChannel({'id': 'c2', 'name': 'other', 'joined': true});
      w.channels.add(c2);
      api.routes['POST /channels/c1/read'] = (_) => {};
      api.routes['POST /channels/c2/read'] = (_) => {};
      api.routes['GET /messages/context/accepted'] = (_) => {
        'messages': [row('accepted', 'c1', 40)],
        'hasOlder': true,
        'hasNewer': true,
      };
      await w.jumpToMessage('c1', 'accepted');
      api.routes['GET /messages/channel/c2'] = (_) => {
        'messages': [row('other-private', 'c2', 1)],
      };
      await w.selectChannel(c2);
      switch (invalidate) {
        case 'principal':
          w.client.user = RaftRecord({'id': 'another-user'});
        case 'client-generation':
          w.client.selectServer('another-server');
          w.client.selectServer('s1');
        case 'capability':
          w.server = RaftRecord({'id': 's1', 'role': 'member'});
      }
      final started = Completer<void>(),
          response = Completer<Map<String, dynamic>>();
      api.routes['GET /messages/context/target'] = (_) {
        started.complete();
        return response.future;
      };
      final opening = w.jumpToMessage('c1', 'target');
      await started.future;
      expect(w.pendingMessageContextChannelId, 'c1');
      expect(
        w.messages.map((m) => m.id),
        invalidate == null ? ['accepted'] : isEmpty,
      );
      expect(w.messages.any((m) => m.id == 'other-private'), false);
      if (invalidate == null) {
        expect(w.hasMore, true);
        expect(w.hasNewer, true);
        expect(w.historyLimited, false);
      }
      response.complete({
        'messages': [row('target', 'c1', 10)],
        'hasOlder': false,
        'hasNewer': false,
      });
      await opening;
      expect(w.messages.map((m) => m.id), ['target']);
      expect(w.hasMore, false);
      expect(w.hasNewer, false);
    });
  }

  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '[N24g] $family/$dark canonical thread Back then channel double-click retains accepted destination every pending frame',
      (tester) async {
        final (w, api) = await pageFixture(tester);
        w.channels.add(
          RaftChannel({'id': 'c2', 'name': 'other', 'joined': true}),
        );
        api.routes['GET /messages/channel/c1'] = (_) => {
          'messages': [row('accepted-tail', 'c1', 49)],
          'historyLimited': true,
        };
        api.routes['GET /messages/channel/c2'] = (_) => {
          'messages': [row('parent-other', 'c2', 1)],
        };
        api.routes['GET /channels/c2/threads/parent-other'] = (_) => {
          'threadChannelId': 't2',
        };
        api.routes['GET /messages/context/parent-other'] = (_) => {
          'messages': [row('parent-other', 'c2', 1)],
        };
        api.routes['GET /messages/context/reply-other'] = (_) => {
          'messages': [row('reply-other', 't2', 1)],
        };
        api.routes['GET /channels/inbox'] = (_) => {
          'items': [
            {
              ...threadRow,
              'threadChannelId': 't2',
              'parentChannelId': 'c2',
              'parentMessageId': 'parent-other',
              'firstUnreadMessageId': 'reply-other',
              'firstMentionMessageId': 'reply-other',
            },
            {
              ...channelRow,
              'firstUnreadMessageId': 'target',
              'firstMentionMessageId': 'target',
            },
          ],
        };
        await tester.runAsync(() => w.selectChannel(w.channel!));
        w.section = 'activity';
        await mountPage(tester, w, family, dark);
        final thread = find.byKey(const ValueKey('activity-thread-t2'));
        await tester.tap(thread);
        await tester.pump(const Duration(milliseconds: 80));
        await tester.tap(thread);
        await tester.runAsync(() async {
          for (
            var i = 0;
            i < 60 && (w.threadLoading || w.channelLoading);
            i++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        });
        await tester.pumpAndSettle();
        expect(w.location.route, RaftRoute.channel);
        expect(w.location.entityId, 'c2');
        expect(w.location.thread?.itemId, 'parent-other');
        expect(paintedMessage(tester, 'reply-other'), isNotNull);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(w.location.route, RaftRoute.activity);
        expect(w.location.thread, isNull);
        final entries = w.navigation.entries.length, index = w.navigation.index;
        final response = Completer<Map<String, dynamic>>.sync();
        api.routes['GET /messages/context/target'] = (_) => response.future;
        final channel = find.byKey(const ValueKey('activity-channel-c1'));
        await tester.tap(channel);
        await tester.pump(const Duration(milliseconds: 80));
        await tester.tap(channel);
        for (var frame = 0; frame < 12; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(w.channelLoading, true);
          expect(w.location.route, RaftRoute.channel);
          expect(w.location.entityId, 'c1');
          expect(w.location.messageId, 'target');
          expect(w.location.thread, isNull);
          expect(w.messages.map((m) => m.id), ['accepted-tail']);
          expect(w.hasMore, false);
          expect(w.hasNewer, false);
          expect(w.historyLimited, true);
          expect(
            paintedMessage(tester, 'accepted-tail'),
            isNotNull,
            reason: 'pending frame $frame',
          );
          expect(paintedMessage(tester, 'parent-other'), isNull);
          expect(paintedMessage(tester, 'reply-other'), isNull);
          expect(paintedMessage(tester, 'target'), isNull);
          expect(w.navigation.index, index + 1);
          expect(w.navigation.entries.length, entries);
        }
        expect(
          api.calls.where((c) => c.path == '/messages/channel/c1').length,
          1,
        );
        await tester.runAsync(() async {
          response.complete({
            'messages': [row('target', 'c1', 10)],
            'hasOlder': false,
            'hasNewer': true,
          });
          for (var i = 0; i < 40 && w.channelLoading; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        });
        await pageFrames(tester, () {}, count: 8);
        expect(w.messages.map((m) => m.id), ['target']);
        expect(paintedMessage(tester, 'target'), isNotNull);
        expect(paintedMessage(tester, 'accepted-tail'), isNull);
        expect(w.hasMore, false);
        expect(w.hasNewer, true);
        expect(w.historyLimited, false);
        expect(w.navigation.index, index + 1);
        expect(w.navigation.entries.length, entries);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
