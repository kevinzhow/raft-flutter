import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'workspace_activity_activation_test.dart' show message;
import 'workspace_source_location_contract_test.dart'
    show pageFixture, mountPage, frames, waitForPainted;

// Source MainLayout756–784 uses the same Search ThreadPanel at both widths.
// Its explicit close-slot owner replaces the Search URI. It does not supply
// Activity's onFocusedMessageConsumed callback (899–910), so expiry is visual.
void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final width in [390.0, 1440.0]) {
      testWidgets(
        '[N02c] $family/$dark ${width == 390 ? 'mobile' : 'desktop'} Search direct thread preserves URI through focus expiry and owned close',
        (tester) async {
          final (w, api) = await pageFixture(tester, section: 'search');
          w.navigation.navigate(
            RaftLocation.parse('/s/demo'),
            kind: RaftNavigationKind.replace,
          );
          w.navigation.navigate(
            RaftLocation.parse('/s/demo/search?q=needle%20words&keep=accepted'),
          );
          final parent = Completer<Map<String, dynamic>>(),
              reply = Completer<Map<String, dynamic>>();
          addTearDown(() {
            if (!parent.isCompleted) parent.complete({'messages': []});
            if (!reply.isCompleted) reply.complete({'messages': []});
          });
          api.routes['GET /messages/search'] = (_) => {
            'results': [
              {
                ...message('reply', 't1'),
                'channelType': 'thread',
                'parentChannelId': 'c1',
                'parentMessageId': 'parent',
                'parentChannelName': 'test',
                'content': 'Needle words in an accepted reply',
              },
            ],
            'hasMore': false,
          };
          api.routes['GET /messages/context/parent'] = (_) => parent.future;
          api.routes['GET /messages/context/reply'] = (_) => reply.future;
          await mountPage(tester, w, family, dark, width: width);
          final searchElement = tester.element(find.byType(ResourceView)),
              index = w.navigation.index,
              count = w.navigation.entries.length;
          expect(
            tester
                .widget<TextField>(find.byType(TextField).first)
                .controller!
                .text,
            'needle words',
          );
          await tester.tap(find.byType(RaftSearchResultSurface).first);
          await frames(tester, () {
            expect(w.location.route, RaftRoute.search);
            expect(w.location.content?.kind, RaftContentKind.thread);
            expect(w.location.content?.id, 't1');
            expect(w.location.thread?.channelId, 'c1');
            expect(w.location.thread?.itemId, 'parent');
            expect(w.location.messageId, 'reply');
            expect(w.location.query('q'), 'needle words');
            expect(w.location.query('keep'), 'accepted');
            expect(w.navigation.index, index + 1);
            expect(w.navigation.entries.length, count + 1);
            expect(w.threadIdentity?.parentChannelId, 'c1');
            expect(w.threadIdentity?.parentMessageId, 'parent');
            expect(w.threadIdentity?.focusedMessageId, 'reply');
            expect(w.threadChannelId, 't1');
            expect(w.channel?.id, 'c1');
            expect(w.presentedThreadParent, isNull);
            expect(find.byType(RaftThreadHeader), findsOneWidget);
            expect(find.byType(RaftChannelHeader), findsNothing);
            expect(find.byType(RaftChatView), findsOneWidget);
            expect(
              find.byKey(const Key('workspace-mobile-navigation')),
              findsNothing,
            );
            if (width == 390) {
              expect(find.byType(ResourceView), findsNothing);
              expect(find.byKey(const Key('thread-back')), findsOneWidget);
              expect(
                find.byKey(const Key('desktop-master-resize-handle')),
                findsNothing,
              );
            }
          });
          expect(
            api.calls.where((r) => r.path == '/channels/c1/threads/parent'),
            isEmpty,
          );
          expect(api.calls.where((r) => r.path == '/channels/t1'), isEmpty);
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
            't1',
          );
          await tester.runAsync(() async {
            reply.complete({
              'messages': [message('reply', 't1')],
            });
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          await waitForPainted(tester, 'reply');
          final focus = find.byKey(const ValueKey('message-reply')),
              revision = w.navigationRevision,
              before = Map<String, String>.from(w.location.uri.queryParameters);
          expect(tester.widget<RaftMessageTile>(focus).highlighted, isTrue);
          expect(w.threadParentLoading, isTrue);
          await tester.pump(const Duration(milliseconds: 2100));
          await frames(tester, () {
            expect(w.highlightedMessageId, isNull);
            expect(
              tester
                  .widgetList<RaftMessageTile>(focus)
                  .every((tile) => !tile.highlighted),
              isTrue,
            );
            expect(w.location.uri.queryParameters, before);
            expect(w.navigationRevision, revision);
            expect(w.threadParentLoading, isTrue);
          });
          await tester.runAsync(() async {
            parent.complete({
              'messages': [message('parent', 'c1')],
            });
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          await frames(tester, () {
            expect(w.presentedThreadParent?.id, 'parent');
            expect(w.threadParentLoading, isFalse);
            expect(w.location.messageId, 'reply');
            expect(
              tester
                  .widgetList<RaftMessageTile>(focus)
                  .every((tile) => !tile.highlighted),
              isTrue,
            );
          });
          await tester.tap(
            find.byKey(Key(width == 390 ? 'thread-back' : 'thread-close')),
          );
          await frames(tester, () {
            expect(
              w.location.toString(),
              '/s/demo/search?q=needle+words&keep=accepted',
            );
            expect(w.navigation.index, index + 1);
            expect(w.navigation.entries.length, count + 1);
            expect(w.threadIdentity, isNull);
            expect(find.byType(RaftThreadHeader), findsNothing);
            expect(find.byType(ResourceView), findsOneWidget);
            expect(
              tester.element(find.byType(ResourceView)),
              same(searchElement),
            );
            expect(
              tester
                  .widget<TextField>(find.byType(TextField).first)
                  .controller!
                  .text,
              'needle words',
            );
          });
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      '[N02c] $family/$dark desktop Search first thread PUSH and reply/thread retarget/Close REPLACE',
      (tester) async {
        final (w, api) = await pageFixture(tester, section: 'search');
        w.navigation.navigate(
          RaftLocation.parse('/s/demo/search?q=needle&keep=accepted'),
          kind: RaftNavigationKind.replace,
        );
        final held = Completer<Map<String, dynamic>>();
        addTearDown(() {
          if (!held.isCompleted) held.complete({'messages': []});
        });
        final rows = [
          for (final (id, thread, parent) in [
            ('first', 't1', 'parent'),
            ('same-thread', 't1', 'parent'),
            ('other-thread', 't2', 'other-parent'),
          ])
            {
              ...message(id, thread),
              'channelType': 'thread',
              'parentChannelId': 'c1',
              'parentMessageId': parent,
              'parentChannelName': 'test',
              'content': 'Needle reply $id',
            },
        ];
        api.routes['GET /messages/search'] = (_) => {
          'results': rows,
          'hasMore': false,
        };
        for (final id in [
          'parent',
          'other-parent',
          'first',
          'same-thread',
          'other-thread',
        ]) {
          api.routes['GET /messages/context/$id'] = (_) => held.future;
        }
        await mountPage(tester, w, family, dark);
        final index = w.navigation.index, count = w.navigation.entries.length;
        expect(find.byType(RaftSearchResultSurface), findsNWidgets(3));
        for (var row = 0; row < rows.length; row++) {
          await tester.tap(find.byType(RaftSearchResultSurface).at(row));
          await frames(tester, () {
            expect(w.navigation.index, index + 1);
            expect(w.navigation.entries.length, count + 1);
            expect(w.location.route, RaftRoute.search);
            expect(w.location.content?.id, rows[row]['channelId']);
            expect(w.location.messageId, rows[row]['id']);
            expect(w.location.thread?.itemId, rows[row]['parentMessageId']);
            expect(w.location.query('q'), 'needle');
            expect(w.location.query('keep'), 'accepted');
            expect(
              w.threadIdentity?.parentMessageId,
              rows[row]['parentMessageId'],
            );
            expect(w.threadIdentity?.focusedMessageId, rows[row]['id']);
            expect(find.byType(RaftThreadHeader), findsOneWidget);
            expect(find.byType(RaftChannelHeader), findsNothing);
            expect(find.byType(ResourceView), findsOneWidget);
          });
        }
        await tester.tap(find.byKey(const Key('thread-close')));
        await frames(tester, () {
          expect(
            w.location.toString(),
            '/s/demo/search?q=needle&keep=accepted',
          );
          expect(w.navigation.index, index + 1);
          expect(w.navigation.entries.length, count + 1);
          expect(w.threadIdentity, isNull);
          expect(find.byType(RaftThreadHeader), findsNothing);
          expect(find.byType(ResourceView), findsOneWidget);
        });
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
