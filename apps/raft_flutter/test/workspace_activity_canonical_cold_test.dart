import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;
import 'workspace_activity_activation_test.dart'
    show threadRow, channelRow, message;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final outcome in ['accepted', 'back', 'denied']) {
      final backBeforeMetadata = outcome == 'back';
      final metadataDenied = outcome == 'denied';
      testWidgets(
        '[N24e] $family/$dark uncached-parent double ${backBeforeMetadata
            ? 'Back fences metadata'
            : metadataDenied
            ? 'rejects unavailable metadata without fake channel'
            : 'loads independent thread and outer tail'}',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = const Size(1440, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
          addTearDown(w.dispose);
          w.loading = false;
          w.ledger.switchServer('s1');
          w.ledger.ingest([
            message('old-main', 'c1'),
          ], expectedGeneration: w.ledger.generation);
          w.visibleIds['c1'] = {'old-main'};
          w.section = 'activity';
          final parentChannel = Completer<Map<String, dynamic>>(),
              parentMessage = Completer<Map<String, dynamic>>(),
              resolution = Completer<Map<String, dynamic>>(),
              reply = Completer<Map<String, dynamic>>(),
              tail = Completer<Map<String, dynamic>>();
          api.routes['GET /channels/inbox'] = (_) => {
            'items': [
              {...threadRow, 'parentChannelId': 'c2', 'threadChannelId': 't2'},
            ],
          };
          api.routes['GET /channels/c2'] = (_) => parentChannel.future;
          api.routes['GET /messages/context/parent'] = (_) =>
              parentMessage.future;
          api.routes['GET /channels/c2/threads/parent'] = (_) =>
              resolution.future;
          api.routes['GET /messages/context/mention-reply'] = (_) =>
              reply.future;
          api.routes['GET /messages/channel/c2'] = (_) => tail.future;
          api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
          api.routes['POST /feature-flags/evaluate'] = (_) => {
            'evaluations': [],
          };
          api.routes['POST /channels/c2/read'] = (_) => {};
          api.routes['POST /channels/t2/read'] = (_) => {};
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
          final before = w.navigation.entries.length;
          final locations = <RaftLocation>[];
          void observe() => locations.add(w.location);
          w.addListener(observe);
          addTearDown(() => w.removeListener(observe));
          final card = find.byKey(const ValueKey('activity-thread-t2'));
          await tester.tap(card);
          await tester.pump(const Duration(milliseconds: 80));
          await tester.tap(card);
          for (var frame = 0; frame < 6; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(w.location.route, RaftRoute.channel);
            expect(w.location.entityId, 'c2');
            expect(w.location.thread?.itemId, 'parent');
            expect(w.location.messageId, 'mention-reply');
            expect(w.location.content, isNull);
            expect(w.threadIdentity?.parentChannelId, 'c2');
            expect(find.byType(RaftThreadHeader), findsOneWidget);
            expect(
              tester
                  .widget<RaftThreadHeader>(find.byType(RaftThreadHeader))
                  .parentLabel,
              isNull,
            );
            expect(find.byType(RaftChannelResolutionBody), findsOneWidget);
            expect(find.byType(RaftConversationTabs), findsNothing);
            expect(
              find.byKey(const Key('workspace-channel-header')),
              findsNothing,
            );
          }
          expect(w.navigation.entries.length, before + 1);
          expect(
            api.calls.where((r) => r.path == '/channels/c2'),
            hasLength(1),
          );
          expect(
            api.calls.where((r) => r.path == '/channels/c2/threads/parent'),
            hasLength(1),
          );
          expect(
            api.calls
                .where((r) => r.path == '/messages/context/parent')
                .single
                .queryParameters['channelId'],
            'c2',
          );
          await tester.runAsync(() async {
            resolution.complete({'threadChannelId': 't2'});
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          for (var frame = 0; frame < 6; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(
            api.calls
                .where((r) => r.path == '/messages/context/mention-reply')
                .single
                .queryParameters['channelId'],
            't2',
          );
          await tester.runAsync(() async {
            reply.complete({
              'messages': [message('mention-reply', 't2')],
            });
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          for (var frame = 0; frame < 6; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(w.replies.map((row) => row.id), ['mention-reply']);
          expect(w.presentedThreadParent, isNull);
          expect(find.byType(RaftChannelResolutionBody), findsOneWidget);
          expect(
            tester
                .widgetList<RaftChatView>(find.byType(RaftChatView))
                .every((view) => view.thread),
            isTrue,
          );
          expect(
            locations.every(
              (uri) =>
                  uri.route == RaftRoute.channel &&
                  uri.entityId == 'c2' &&
                  uri.content == null &&
                  uri.thread?.itemId == 'parent',
            ),
            isTrue,
          );
          if (backBeforeMetadata) {
            await tester.binding.handlePopRoute();
            await tester.pump();
            expect(w.location.route, RaftRoute.activity);
            expect(w.threadIdentity, isNull);
            expect(find.byType(RaftThreadHeader), findsNothing);
          }
          final identity = w.threadIdentity;
          final threadGeneration = w.threadGeneration;
          await tester.runAsync(() async {
            parentChannel.complete({
              'id': metadataDenied ? 'wrong-channel' : 'c2',
              'serverId': 's1',
              'name': 'Real hydrated parent',
              'joined': true,
            });
            parentMessage.complete({
              'messages': [message('parent', 'c2')],
            });
            await Future<void>.delayed(const Duration(milliseconds: 30));
          });
          for (var frame = 0; frame < 6; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          if (backBeforeMetadata) {
            expect(w.channel?.id, 'c1');
            expect(w.channels.any((row) => row.id == 'c2'), isFalse);
            expect(w.threadIdentity, isNull);
          } else if (metadataDenied) {
            expect(w.channel?.id, 'c1');
            expect(w.channels.any((row) => row.id == 'c2'), isFalse);
            expect(w.missingConversationChannelId, 'c2');
            expect(w.threadGeneration, threadGeneration);
            expect(w.threadIdentity, same(identity));
            expect(w.replies.map((row) => row.id), ['mention-reply']);
            expect(find.text('SELECT A CHANNEL'), findsOneWidget);
            expect(
              find.byKey(const Key('workspace-channel-header')),
              findsNothing,
            );
            expect(find.byType(RaftConversationTabs), findsNothing);
            expect(
              api.calls.where((r) => r.path == '/messages/channel/c2'),
              isEmpty,
            );
          } else {
            expect(w.channel?.id, 'c2');
            expect(
              w.channels.where((row) => row.id == 'c2').single.name,
              'Real hydrated parent',
            );
            expect(w.threadGeneration, threadGeneration);
            expect(w.threadIdentity, same(identity));
            expect(w.presentedThreadParent?.id, 'parent');
            expect(w.replies.map((row) => row.id), ['mention-reply']);
            expect(w.messages, isEmpty);
            expect(w.highlightedMessageId, 'mention-reply');
            expect(find.byType(RaftChannelResolutionBody), findsNothing);
            expect(
              find.byKey(const Key('workspace-channel-header')),
              findsOneWidget,
            );
            expect(find.byType(RaftConversationTabs), findsOneWidget);
          }
          await tester.runAsync(() async {
            tail.complete({
              'messages': [message('real-tail', 'c2')],
            });
            await Future<void>.delayed(const Duration(milliseconds: 25));
          });
          await tester.pumpAndSettle();
          expect(w.navigation.entries.length, before + 1);
          if (!backBeforeMetadata && !metadataDenied) {
            expect(w.messages.map((row) => row.id), ['real-tail']);
            expect(w.replies.map((row) => row.id), ['mention-reply']);
            expect(
              api.calls.where(
                (r) => r.method == 'POST' && r.path == '/channels/c2/read',
              ),
              isNotEmpty,
              reason: 'the genuinely visible desktop outer channel remains admitted',
            );
          }
          expect(
            api.calls.where(
              (r) =>
                  r.path == '/messages/context/mention-reply' &&
                  r.queryParameters['channelId'] == 'c2',
            ),
            isEmpty,
          );
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
    for (final thread in [true, false]) {
      testWidgets(
        '${thread ? '[N25a]' : '[N25b]'} $family/$dark actual narrow Activity ${thread ? 'thread' : 'channel'} uses Source single focus and Back',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = const Size(390, 844);
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
          api.routes['GET /messages/channel/c1'] = (_) => {
            'messages': [message('outer-tail', 'c1')],
          };
          api.routes['GET /messages/context/parent'] = (_) => parent.future;
          api.routes['GET /channels/c1/threads/parent'] = (_) =>
              resolution.future;
          api.routes['GET /messages/context/reply'] = (_) => target.future;
          api.routes['GET /messages/context/mention-channel'] = (_) =>
              target.future;
          api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
          api.routes['POST /feature-flags/evaluate'] = (_) => {
            'evaluations': [],
          };
          api.routes['POST /channels/c1/read'] = (_) => {};
          api.routes['POST /channels/thread-1/read'] = (_) => {};
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
          final original = w.location.toString(),
              before = w.navigation.entries.length;
          await tester.tap(
            find.byKey(
              ValueKey(
                thread ? 'activity-thread-thread-1' : 'activity-channel-c1',
              ),
            ),
          );
          for (var frame = 0; frame < 5; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(
              api.calls.where(
                (r) => r.method == 'POST' && r.path == '/channels/c1/read',
              ),
              isEmpty,
              reason:
                  'hidden parent must not acknowledge during pending frame $frame',
            );
            expect(w.location.route, RaftRoute.channel);
            expect(w.location.entityId, 'c1');
            expect(w.location.content, isNull);
            expect(w.location.messageId, thread ? 'reply' : 'mention-channel');
            expect(w.location.thread?.itemId, thread ? 'parent' : null);
            expect(find.byKey(const Key('mobile-detail-back')), findsOneWidget);
            expect(
              find.byType(RaftThreadHeader),
              thread ? findsOneWidget : findsNothing,
            );
            expect(
              find.byKey(const Key('workspace-mobile-navigation')),
              findsNothing,
            );
          }
          expect(w.navigation.entries.length, before + 1);
          await tester.tap(find.byKey(const Key('mobile-detail-back')));
          await tester.pump();
          expect(w.location.toString(), original);
          expect(w.threadIdentity, isNull);
          expect(
            find.byKey(const Key('workspace-mobile-navigation')),
            findsNothing,
          );
          // Activity is an auxiliary Source page; its own Back reaches Home.
          expect(find.byType(RaftPanelBackAction), findsOneWidget);
          await tester.tap(find.byType(RaftPanelBackAction));
          await tester.pump();
          expect(w.location.route, RaftRoute.home);
          expect(
            find.byKey(const Key('workspace-mobile-navigation')),
            findsOneWidget,
          );
          final afterBack = w.location.toString();
          await tester.runAsync(() async {
            resolution.complete({'threadChannelId': 'thread-1'});
            parent.complete({
              'messages': [message('parent', 'c1')],
            });
            target.complete({
              'messages': [
                message(
                  thread ? 'reply' : 'mention-channel',
                  thread ? 'thread-1' : 'c1',
                ),
              ],
            });
            await Future<void>.delayed(const Duration(milliseconds: 30));
          });
          await tester.pumpAndSettle();
          expect(w.location.toString(), afterBack);
          expect(w.threadIdentity, isNull);
          expect(w.navigation.entries.length, before + 1);
          expect(
            api.calls.where(
              (r) => r.method == 'POST' && r.path == '/channels/c1/read',
            ),
            isEmpty,
          );
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
