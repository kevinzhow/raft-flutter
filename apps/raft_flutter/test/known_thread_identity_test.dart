import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show contextRows, paintedMessage;
import 'message_context_transition_test.dart' show row;
import 'message_presentation_test.dart' show fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final sparse in [false, true]) {
      testWidgets(
        '[N24a] $family/$dark sparse=$sparse accepted inbox thread starts replies while parent is held',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final (w, api) = (await tester.runAsync(() => fixture('member')))!;
          addTearDown(w.dispose);
          final main = RaftChannel({
            'id': 'c0',
            'name': 'old main',
            'joined': true,
            'channelCapabilities': {'viewChannel': false},
          });
          w.channels.add(main);
          w.channel = main;
          w.ledger.switchServer('s1');
          w.ledger.ingest([
            row('old-main', 'c0', 1),
          ], expectedGeneration: w.ledger.generation);
          w.visibleIds['c0'] = {'old-main'};
          w.setSection('activity');
          final focusId = sparse ? 'reply' : 'reply-40';
          final target = w.location.withQuery({
            'open': 'thread:thread-1',
            'thread': 'c1:parent',
            'msg': focusId,
          });
          w.navigation.navigate(target);
          final parent = Completer<Map<String, dynamic>>.sync(),
              reply = Completer<Map<String, dynamic>>.sync(),
              parentStarted = Completer<void>.sync(),
              replyStarted = Completer<void>.sync();
          api.routes['GET /messages/context/parent'] = (_) {
            parentStarted.complete();
            return parent.future;
          };
          api.routes['GET /messages/context/$focusId'] = (request) {
            expect(request.queryParameters['channelId'], 'thread-1');
            replyStarted.complete();
            return reply.future;
          };
          late Future<void> opening;
          await tester.runAsync(() async {
            opening = w.openThreadIdentity(
              parentChannelId: 'c1',
              parentMessageId: 'parent',
              initialThreadChannelId: 'thread-1',
              focusedMessageId: focusId,
              navigate: false,
            );
            // These are synchronous projections of the accepted inbox DTO.
            expect(w.threadChannelId, 'thread-1');
            expect(w.threadResolutionLoading, false);
            expect(w.threadParentLoading, true);
            expect(w.threadSourceChannel?.id, 'c1');
            expect(w.channel?.id, 'c0');
            expect(w.location.toString(), target.toString());
            await Future.wait([parentStarted.future, replyStarted.future]);
          });
          expect(
            api.calls.where((c) => c.path == '/channels/c1/threads/parent'),
            isEmpty,
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: Scaffold(body: RaftChatView(controller: w, thread: true)),
            ),
          );
          for (var frame = 0; frame < 4; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(w.channel?.id, 'c0');
            expect(w.threadIdentity?.parentMessageId, 'parent');
            expect(find.text('Message old-main'), findsNothing);
            expect(find.text('Loading...'), findsOneWidget);
            expect(
              tester.widget<RaftComposer>(find.byType(RaftComposer)).enabled,
              true,
            );
          }
          await tester.runAsync(() async {
            reply.complete({
              'messages': [
                if (sparse)
                  row(focusId, 'thread-1', 1)
                else
                  for (final message in contextRows('reply'))
                    {...message, 'channelId': 'thread-1'},
              ],
              'hasOlder': true,
              'hasNewer': true,
            });
            await opening;
          });
          Rect? first;
          for (var frame = 0; frame < 12; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            final rect = paintedMessage(tester, focusId);
            if (rect != null) {
              first ??= rect;
              expect(rect, first);
            }
            expect(w.presentedThreadParent, isNull);
            expect(w.threadParentLoading, true);
            expect(w.location.toString(), target.toString());
            expect(find.text('Message old-main'), findsNothing);
          }
          expect(first, isNotNull);
          await tester.runAsync(() async {
            parent.complete({
              'messages': [row('parent', 'c1', 1)],
            });
            for (var i = 0; i < 40 && w.threadParentLoading; i++) {
              await Future<void>.delayed(const Duration(milliseconds: 5));
            }
          });
          Rect? afterParent;
          for (var frame = 0; frame < 6; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            final rect = paintedMessage(tester, focusId);
            expect(rect, isNotNull);
            if (!sparse) {
              expect(rect, first);
            } else if (rect != first || afterParent != null) {
              afterParent ??= rect;
              expect(
                rect,
                afterParent,
                reason: 'Only the real parent insertion may change a clamped short window',
              );
              final focus = find.byKey(ValueKey('message-$focusId')).last;
              final scroll = tester
                  .state<ScrollableState>(
                    find
                        .ancestor(of: focus, matching: find.byType(Scrollable))
                        .first,
                  )
                  .position;
              expect(scroll.maxScrollExtent, 0);
              expect(scroll.pixels, 0);
            }
            expect(w.presentedThreadParent?.id, 'parent');
          }
          if (sparse) expect(afterParent, isNotNull);
          expect(w.messages.map((m) => m.id), ['old-main']);
          expect(w.ledger.messages('c1'), isEmpty);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  for (final invalidation in [
    'back',
    'server',
    'parent-capability',
    'parent-revoked',
  ]) {
    test(
      '[N24a] known thread late replies and parent cannot accept after $invalidation',
      () async {
        final (w, api) = await fixture('member');
        addTearDown(w.dispose);
        w.ledger.switchServer('s1');
        w.setSection('activity');
        w.navigation.navigate(
          w.location.withQuery({
            'open': 'thread:thread-1',
            'thread': 'c1:parent',
            'msg': 'reply',
          }),
        );
        final parent = Completer<Map<String, dynamic>>(),
            reply = Completer<Map<String, dynamic>>(),
            started = Completer<void>();
        api.routes['GET /messages/context/parent'] = (_) => parent.future;
        api.routes['GET /messages/context/reply'] = (_) {
          started.complete();
          return reply.future;
        };
        final opening = w.openThreadIdentity(
          parentChannelId: 'c1',
          parentMessageId: 'parent',
          initialThreadChannelId: 'thread-1',
          focusedMessageId: 'reply',
          navigate: false,
        );
        await started.future;
        switch (invalidation) {
          case 'back':
            w.navigation.back();
          case 'server':
            w.revokeServer('s1');
          case 'parent-capability':
            w.channels[0] = RaftChannel({
              ...w.channels.first.json,
              'channelCapabilities': {'viewChannel': false},
            });
            w.channel = w.channels[0];
          case 'parent-revoked':
            api.routes['GET /channels'] = (_) => [];
            api.routes['GET /channels/dm'] = (_) => [];
            await w.refreshChannels();
        }
        reply.complete({
          'messages': [row('late-reply', 'thread-1', 1)],
        });
        parent.complete({
          'messages': [row('parent', 'c1', 1)],
        });
        await opening;
        await Future<void>.delayed(Duration.zero);
        expect(w.threadIdentity, isNull);
        expect(w.presentedThreadParent, isNull);
        expect(w.ledger.messages('thread-1'), isEmpty);
      },
    );
  }

  test(
    '[N24a] invalid identity and denied authority do not navigate or request',
    () async {
      final (w, api) = await fixture('member');
      addTearDown(w.dispose);
      w.setSection('activity');
      final uri = w.location.toString(), calls = api.calls.length;
      await w.openThreadIdentity(
        parentChannelId: '',
        parentMessageId: 'parent',
      );
      expect(w.location.toString(), uri);
      w.server = RaftRecord({'id': 's1', 'role': 'guest'});
      final deniedUri = w.location.toString();
      await w.openThreadIdentity(
        parentChannelId: 'c1',
        parentMessageId: 'parent',
        initialThreadChannelId: 'thread-1',
      );
      expect(w.location.toString(), deniedUri);
      expect(w.threadIdentity, isNull);
      expect(api.calls.length, calls);
    },
  );
}
