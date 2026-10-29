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
import 'support/app_services_fixture.dart';
import 'workspace_activity_activation_test.dart'
    show channelRow, threadRow, message;

// The user already has a loaded Activity conversation in a desktop column.
// Resizing that same mounted workspace must show the accepted conversation on
// the phone, rather than an empty timeline selected from the retained list.
void main() {
  for (final kind in [
    'channel',
    'dm',
    'thread',
    'thread-loading',
    'thread-loading-back',
  ]) {
    testWidgets('Activity $kind keeps its loaded messages across width changes', (
      t,
    ) async {
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = const Size(1440, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final (w, api) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      addTearDown(() async {
        await t.pumpWidget(const SizedBox());
        await t.pump();
      });
      w.loading = false;
      w.messageDomain.ledger.switchServer('s1');
      w.dms = [
        RaftChannel({
          'id': 'd1',
          'name': 'Alice',
          'type': 'dm',
          'joined': true,
        }),
      ];
      w.section = 'activity';
      final pending = kind.contains('loading');
      final isThread = kind.startsWith('thread');
      final parentWait = Completer<Map<String, dynamic>>();
      final repliesWait = Completer<Map<String, dynamic>>();
      api.routes['GET /channels/inbox'] = (_) => {
        'items': [
          channelRow,
          {
            ...channelRow,
            'kind': 'dm',
            'channelId': 'd1',
            'channelName': 'Alice',
            'firstUnreadMessageId': 'first-dm',
          },
          threadRow,
        ],
      };
      api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
      api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
      api.routes['GET /servers/s1/setup-projection'] = (_) => {
        'phase': 'complete',
        'surface': 'complete',
        'blocksChat': false,
      };
      for (final (id, channel) in [
        ('first-channel', 'c1'),
        ('first-dm', 'd1'),
        ('parent', 'c1'),
        ('reply', 'thread-1'),
      ]) {
        api.routes['GET /messages/context/$id'] = (_) => {
          'messages': [message(id, channel)],
        };
      }
      api.routes['GET /channels/c1/threads/parent'] = (_) => {
        'threadChannelId': 'thread-1',
      };
      if (pending) {
        api.routes['GET /messages/context/parent'] = (_) => parentWait.future;
        api.routes['GET /messages/context/reply'] = (_) => repliesWait.future;
      }
      for (final id in ['c1', 'd1', 'thread-1']) {
        api.routes['POST /channels/$id/read'] = (_) => {
          'maxReadSeq': '1',
          'readStateVersion': '1',
        };
        api.routes['GET /channels/$id'] = (_) => {
          'id': id,
          'name': id == 'd1' ? 'Alice' : 'test',
          'type': id == 'd1' ? 'dm' : 'channel',
          'joined': true,
        };
        api.routes['GET /messages/channel/$id'] = (_) => {
          'messages': <Map<String, dynamic>>[],
        };
      }
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: withAppServices(
            WorkspaceView(
              controller: w,
              appearance: const RaftAppearance(),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final rowId = isThread
          ? 'thread-thread-1'
          : kind == 'dm'
          ? 'dm-d1'
          : 'channel-c1';
      await t.tap(find.byKey(ValueKey('activity-$rowId')));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await t.pumpAndSettle();
      final id = isThread
          ? 'reply'
          : kind == 'dm'
          ? 'first-dm'
          : 'first-channel';
      final accepted = find.byKey(ValueKey('message-$id'));
      expect(w.location.route, RaftRoute.activity);
      expect(w.location.content, isNotNull);
      expect(
        accepted,
        pending ? findsNothing : findsOneWidget,
        reason: pending
            ? 'desktop replies are still pending'
            : 'desktop preview already loaded',
      );
      if (isThread) {
        expect(find.byType(RaftThreadHeader), findsOneWidget);
        expect(w.threadIdentity?.parentMessageId, 'parent');
      }

      for (final size in [
        const Size(390, 844),
        const Size(1440, 900),
        const Size(767, 900),
      ]) {
        t.view.physicalSize = size;
        await t.pumpAndSettle();
        if (pending && !repliesWait.isCompleted) {
          if (kind.endsWith('-back')) {
            await t.tap(find.byKey(const Key('mobile-detail-back')));
            await t.pumpAndSettle();
            expect(w.location.thread, isNull);
          }
          await t.runAsync(() async {
            parentWait.complete({
              'messages': [message('parent', 'c1')],
            });
            repliesWait.complete({
              'messages': [message('reply', 'thread-1')],
            });
            await Future<void>.delayed(const Duration(milliseconds: 30));
          });
          await t.pumpAndSettle();
          if (kind.endsWith('-back')) {
            expect(w.location.thread, isNull);
            expect(w.threadIdentity, isNull);
            expect(
              accepted,
              findsNothing,
              reason: 'Back must reject the late old thread result',
            );
            expect(t.takeException(), isNull);
            return;
          }
        }
        expect(
          accepted,
          findsOneWidget,
          reason:
              'loaded $kind at $size: location=${w.location}; '
              'currentThread=${w.threadIdentity?.parentMessageId}; '
              'rawThread=${w.messageDomain.state.threadIdentity?.parentMessageId}; '
              'replyRows=${w.messageDomain.visibleIds['thread-1']}',
        );
        expect(
          t.getRect(accepted).overlaps(Offset.zero & size),
          isTrue,
          reason: 'the accepted message must be painted in the new viewport',
        );
        expect(
          t
              .widgetList<RaftChatView>(find.byType(RaftChatView))
              .any((view) => view.thread == isThread),
          isTrue,
        );
        if (isThread) {
          expect(w.threadIdentity?.parentMessageId, 'parent');
          expect(w.threadChannelId, 'thread-1');
        } else {
          expect(w.channel?.id, kind == 'dm' ? 'd1' : 'c1');
        }
        expect(t.takeException(), isNull);
      }
      await t.pumpWidget(const SizedBox());
      await t.pump();
    });
  }
}
