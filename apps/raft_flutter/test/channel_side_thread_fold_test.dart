import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_flutter/features/chat_view.dart';

import 'message_context_transition_test.dart' show row;
import 'workspace_channel_settings_identity_test.dart' show settingsFixture;
import 'workspace_source_location_contract_test.dart' show frames, mountPage;

void main() {
  for (final width in [1100.0, 928.0]) {
    testWidgets(
      'a folded desktop thread leaves Details in its dock at $width',
      (t) async {
        final (w, api) = await settingsFixture(t);
        api.routes['GET /announcements/active'] = (_) => {'announcements': []};
        api.routes['GET /channels/c1/announcement'] = (_) => {
          'announcement': null,
        };
        api.routes['GET /channels/c1/threads/parent'] = (_) => {
          'threadChannelId': 't1',
        };
        api.routes['GET /messages/channel/t1'] = (_) => {
          'messages': [row('reply', 't1', 1)],
        };
        api.routes['GET /messages/context/parent'] = (_) => {
          'messages': [row('parent', 'c1', 1)],
        };
        w.messageDomain.ledger.ingest([
          row('parent', 'c1', 1),
        ], expectedGeneration: w.messageDomain.ledger.generation);
        w.messageDomain.visibleIds['c1'] = {'parent'};
        final details = find.byKey(const Key('channel-side-column-3'));
        final detailsClose = find.byKey(const Key('channel-details-close'));
        final sideThread = find.byKey(const Key('workspace-thread-panel'));
        final threadHeader = find.byKey(const Key('workspace-thread-header'));
        final threadBack = find.byKey(const Key('thread-back'));
        final conversation = find.byKey(const Key('channel-side-conversation'));
        final threadChat = find.byWidgetPredicate(
          (w) => w is RaftChatView && w.thread,
        );
        final channelChat = find.byWidgetPredicate(
          (w) => w is RaftChatView && !w.thread,
        );
        try {
          const splitWidth = 1380.0;
          await mountPage(t, w, false, width: splitWidth);
          await t.tap(find.byKey(const Key('channel-overflow-trigger')));
          await t.pumpAndSettle();
          expect(detailsClose.hitTestable(), findsOneWidget);
          await t.runAsync(
            () => w.openThreadIdentity(
              parentChannelId: 'c1',
              parentMessageId: 'parent',
              initialThreadChannelId: 't1',
            ),
          );
          await frames(t, () {});
          await t.pumpAndSettle();
          expect(sideThread, findsOneWidget);
          expect(detailsClose.hitTestable(), findsOneWidget);
          final available = splitWidth - t.getRect(channelChat).left;
          // 360 for chat and 400 saved for each column. The thread has 40
          // above its floor and Details has 80, so they share the deficit 1:2.
          final deficit = 1160 - available;
          expect(deficit, greaterThan(0));
          expect(t.getSize(sideThread).width, closeTo(400 - deficit / 3, .01));
          expect(t.getSize(details).width, closeTo(400 - deficit * 2 / 3, .01));
          final detailsState = t.state(find.byType(ChannelSettings));
          final threadState = t.state(threadChat);
          final chatState = t.state(channelChat);
          final location = w.location;

          t.view.physicalSize = Size(width, 800);
          await frames(t, () {});
          await t.pumpAndSettle();
          expect(sideThread, findsNothing, reason: 'the thread has folded');
          expect(threadHeader, findsOneWidget);
          expect(threadBack.hitTestable(), findsOneWidget);
          expect(detailsClose.hitTestable(), findsOneWidget);
          expect(
            t.getRect(conversation).right,
            closeTo(t.getRect(details).left, .01),
          );
          expect(t.getRect(details).right, width);
          expect(
            channelChat,
            findsNothing,
            reason: 'the folded thread owns the chat region',
          );
          expect(t.state(find.byType(ChannelSettings)), same(detailsState));
          expect(t.state(threadChat), same(threadState));
          expect(w.location, location);
          expect(t.takeException(), isNull);
          await t.tap(threadBack);
          await frames(t, () {});
          await t.pumpAndSettle();
          expect(threadHeader, findsNothing);
          expect(channelChat, findsOneWidget);
          expect(t.state(channelChat), same(chatState));
          expect(detailsClose.hitTestable(), findsOneWidget);
          expect(t.state(find.byType(ChannelSettings)), same(detailsState));
        } finally {
          await t.pumpWidget(const SizedBox.shrink());
          await t.pumpAndSettle();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  }
}
