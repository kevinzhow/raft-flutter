import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show paintedMessage;
import 'message_context_transition_test.dart' show row;
import 'message_presentation_test.dart' show fixture, MessageAdapter;
import 'workspace_activity_activation_test.dart' show channelRow;

// The held transport returns a real HTTP 404 response. Completing an error
// future across WidgetTester's real/FakeAsync error zones is not an HTTP test.
class HeldMissingContext implements HttpClientAdapter {
  HeldMissingContext(this.delegate, this.release);
  final MessageAdapter delegate;
  final Future<void> release;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    if (request.path != '/messages/context/second') {
      return delegate.fetch(request, stream, cancel);
    }
    delegate.calls.add(request);
    await release;
    return ResponseBody.fromString(
      '{"error":"Missing context"}',
      404,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) => delegate.close(force: force);
}

Future<(WorkspaceController, MessageAdapter)> pageFixture(
  WidgetTester tester,
) async {
  SharedPreferences.setMockInitialValues({});
  final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
  w.loading = false;
  w.ledger.switchServer('s1');
  w.section = 'chat';
  api.routes['GET /servers/s1/setup-projection'] = (_) => {
    'phase': 'complete',
    'surface': 'complete',
    'blocksChat': false,
  };
  api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
  api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
  api.routes['POST /channels/c1/read'] = (_) => {};
  api.routes['POST /channels/c2/read'] = (_) => {};
  api.routes['POST /channels/t1/read'] = (_) => {};
  api.routes['POST /channels/t2/read'] = (_) => {};
  addTearDown(w.dispose);
  return (w, api);
}

Future<void> mountPage(
  WidgetTester tester,
  WorkspaceController w,
  RaftFamily family,
  bool dark, {
  double width = 1440,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
}

Future<void> pageFrames(
  WidgetTester tester,
  void Function() check, {
  int count = 6,
}) async {
  for (var frame = 0; frame < count; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
    check();
  }
}

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final switchThread in [false, true]) {
      testWidgets(
        '${switchThread ? '[N07b]' : '[N07a]'} $family/$dark actual side-thread ${switchThread ? 'retarget' : 'close'} replaces only its slot',
        (tester) async {
          final (w, api) = await pageFixture(tester);
          final p1 = row('p1', 'c1', 1), p2 = row('p2', 'c1', 2);
          w.ledger.ingest([p1, p2], expectedGeneration: w.ledger.generation);
          w.visibleIds['c1'] = {'p1', 'p2'};
          w.threadSummaries = {
            'p1': {'replyCount': 1},
            'p2': {'replyCount': 1},
          };
          w.navigation.navigate(
            w.location.withQuery({
              'msg': 'unrelated-focus',
              'profile': 'human:alice',
              'task': 'c2:independent-task',
              'keep': 'encoded value:1',
            }),
          );
          final independent = Map<String, String>.from(
            w.location.uri.queryParameters,
          );
          final pending = Completer<Map<String, dynamic>>.sync();
          api.routes['GET /channels/c1/threads/p1'] = (_) => {
            'threadChannelId': 't1',
          };
          api.routes['GET /channels/c1/threads/p2'] = (_) => {
            'threadChannelId': 't2',
          };
          api.routes['GET /messages/channel/t1'] = (_) => {
            'messages': [row('r1', 't1', 1)],
          };
          api.routes['GET /messages/channel/t2'] = (_) => pending.future;
          await mountPage(tester, w, family, dark);
          await tester.tap(
            find.byKey(const ValueKey('thread-replies-badge-p1')),
          );
          await tester.runAsync(() async {
            for (var i = 0; i < 40 && w.threadLoading; i++) {
              await Future<void>.delayed(const Duration(milliseconds: 5));
            }
          });
          await pageFrames(tester, () {});
          expect(paintedMessage(tester, 'r1'), isNotNull);
          final entries = w.navigation.entries.length,
              index = w.navigation.index;
          if (switchThread) {
            await tester.tap(
              find.byKey(const ValueKey('thread-replies-badge-p2')),
            );
            await tester.runAsync(() async {
              for (
                var i = 0;
                i < 40 &&
                    !api.calls.any((c) => c.path == '/messages/channel/t2');
                i++
              ) {
                await Future<void>.delayed(const Duration(milliseconds: 5));
              }
            });
            await pageFrames(tester, () {
              expect(w.location.thread?.itemId, 'p2');
              expect(w.navigation.entries.length, entries);
              expect(w.navigation.index, index);
              expect(paintedMessage(tester, 'r1'), isNull);
              expect(paintedMessage(tester, 'r2'), isNull);
            });
            await tester.runAsync(() async {
              pending.complete({
                'messages': [row('r2', 't2', 1)],
              });
              for (var i = 0; i < 40 && w.threadLoading; i++) {
                await Future<void>.delayed(const Duration(milliseconds: 5));
              }
            });
            await pageFrames(tester, () {});
            expect(paintedMessage(tester, 'r2'), isNotNull);
            expect(paintedMessage(tester, 'r1'), isNull);
          } else {
            await tester.tap(find.byKey(const Key('thread-close')));
            await pageFrames(tester, () {
              expect(w.location.thread, isNull);
              expect(w.navigation.entries.length, entries);
              expect(w.navigation.index, index);
              expect(find.byType(RaftThreadHeader), findsNothing);
              expect(paintedMessage(tester, 'r1'), isNull);
              expect(paintedMessage(tester, 'p1'), isNotNull);
            });
          }
          for (final key in ['profile', 'task', 'keep']) {
            expect(w.location.query(key), independent[key]);
          }
          // rightPanelUrlSync preserves the independent existing msg slot.
          expect(w.location.messageId, independent['msg']);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }

    for (final back in [true, false]) {
      testWidgets(
        '[N09] $family/$dark mounted ${back ? 'Back' : 'new route'} rejects held old parent and replies',
        (tester) async {
          final (w, api) = await pageFixture(tester);
          w.ledger.ingest([
            row('main', 'c1', 1),
          ], expectedGeneration: w.ledger.generation);
          w.visibleIds['c1'] = {'main'};
          final parent = Completer<Map<String, dynamic>>.sync(),
              replies = Completer<Map<String, dynamic>>.sync();
          api.routes['GET /messages/context/parent'] = (_) => parent.future;
          api.routes['GET /messages/context/reply'] = (_) => replies.future;
          api.routes['GET /channels/inbox'] = (_) => {'items': []};
          await mountPage(tester, w, family, dark, width: back ? 390 : 1440);
          late Future<void> opening;
          await tester.runAsync(() async {
            opening = w.openThreadIdentity(
              parentChannelId: 'c1',
              parentMessageId: 'parent',
              initialThreadChannelId: 't1',
              focusedMessageId: 'reply',
            );
            for (
              var i = 0;
              i < 40 &&
                  !api.calls.any((c) => c.path == '/messages/context/reply');
              i++
            ) {
              await Future<void>.delayed(const Duration(milliseconds: 5));
            }
          });
          await pageFrames(tester, () {
            expect(find.byType(RaftThreadHeader), findsOneWidget);
            expect(paintedMessage(tester, 'reply'), isNull);
            expect(find.text('Message parent'), findsNothing);
          });
          await tester.runAsync(() async {
            replies.complete({
              'messages': [row('reply', 't1', 1)],
            });
            await opening;
          });
          await pageFrames(tester, () {
            expect(w.presentedThreadParent, isNull);
            expect(find.text('Message parent'), findsNothing);
          });
          expect(paintedMessage(tester, 'reply'), isNotNull);
          if (back) {
            await tester.tap(find.byKey(const Key('mobile-detail-back')));
          } else {
            await tester.tap(find.byTooltip('Activity').first);
          }
          await pageFrames(tester, () {
            expect(find.byType(RaftThreadHeader), findsNothing);
            expect(paintedMessage(tester, 'reply'), isNull);
            expect(find.text('Message parent'), findsNothing);
          });
          final accepted = w.location.toString(),
              acceptedIndex = w.navigation.index;
          await tester.runAsync(() async {
            parent.complete({
              'messages': [row('parent', 'c1', 2)],
            });
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          await pageFrames(tester, () {
            expect(w.location.toString(), accepted);
            expect(w.navigation.index, acceptedIndex);
            expect(find.byType(RaftThreadHeader), findsNothing);
            expect(find.text('Message parent'), findsNothing);
            expect(paintedMessage(tester, 'reply'), isNull);
            expect(w.presentedThreadParent, isNull);
            expect(
              w.ledger.messages('c1').any((m) => m['id'] == 'parent'),
              false,
            );
            if (back) expect(paintedMessage(tester, 'main'), isNotNull);
          });
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }

    for (final failLast in [false, true]) {
      testWidgets(
        '[L04] $family/$dark actual Activity last click ${failLast ? 'fails without reviving old context' : 'wins over late old context'}',
        (tester) async {
          final (w, api) = await pageFixture(tester);
          w.channels.add(
            RaftChannel({'id': 'c2', 'name': 'second', 'joined': true}),
          );
          w.ledger.ingest([
            row('old', 'c1', 1),
          ], expectedGeneration: w.ledger.generation);
          w.visibleIds['c1'] = {'old'};
          w.section = 'activity';
          final (first, second, latest) = (await tester.runAsync(
            () async => (
              Completer<Map<String, dynamic>>.sync(),
              Completer<Map<String, dynamic>>.sync(),
              Completer<Map<String, dynamic>>.sync(),
            ),
          ))!;
          api.routes['GET /channels/inbox'] = (_) => {
            'items': [
              {...channelRow, 'firstUnreadMessageId': 'first'},
              {
                ...channelRow,
                'channelId': 'c2',
                'channelName': 'second',
                'firstUnreadMessageId': 'second',
              },
            ],
          };
          final missing = Completer<void>.sync();
          if (failLast) {
            w.client.http.httpClientAdapter = HeldMissingContext(
              api,
              missing.future,
            );
          }
          api.routes['GET /messages/context/first'] = (_) => first.future;
          api.routes['GET /messages/context/second'] = (_) => second.future;
          api.routes['GET /messages/channel/c2'] = (_) => latest.future;
          await mountPage(tester, w, family, dark);
          await tester.tap(find.byKey(const ValueKey('activity-channel-c1')));
          await tester.pump(const Duration(milliseconds: 220));
          await tester.runAsync(() async {
            for (
              var i = 0;
              i < 40 &&
                  !api.calls.any((c) => c.path == '/messages/context/first');
              i++
            ) {
              await Future<void>.delayed(const Duration(milliseconds: 5));
            }
          });
          expect(
            api.calls.any((c) => c.path == '/messages/context/first'),
            true,
          );
          await tester.tap(find.byKey(const ValueKey('activity-channel-c2')));
          await tester.pump(const Duration(milliseconds: 220));
          await tester.runAsync(() async {
            for (
              var i = 0;
              i < 40 &&
                  !api.calls.any((c) => c.path == '/messages/context/second');
              i++
            ) {
              await Future<void>.delayed(const Duration(milliseconds: 5));
            }
          });
          expect(
            api.calls.any((c) => c.path == '/messages/context/second'),
            true,
          );
          await pageFrames(tester, () {
            expect(w.location.route, RaftRoute.activity);
            expect(w.location.content?.id, 'c2');
            expect(paintedMessage(tester, 'old'), isNull);
            expect(paintedMessage(tester, 'first'), isNull);
          });
          if (failLast) {
            await tester.runAsync(() async {
              missing.complete();
            });
            // HTTP status validation completes in the actual tap's FakeAsync
            // zone; observe these frames instead of awaiting that zone inside
            // runAsync, which cannot advance its queued error continuation.
            await pageFrames(tester, () {
              expect(paintedMessage(tester, 'first'), isNull);
              expect(paintedMessage(tester, 'old'), isNull);
              expect(w.location.content?.id, 'c2');
            });
            expect(
              api.calls.any((c) => c.path == '/messages/channel/c2'),
              true,
            );
          } else {
            await tester.runAsync(() async {
              second.complete({
                'messages': [row('second', 'c2', 20)],
              });
              for (var i = 0; i < 40 && w.channelLoading; i++) {
                await Future<void>.delayed(const Duration(milliseconds: 5));
              }
            });
          }
          await tester.runAsync(() async {
            first.complete({
              'messages': [row('first', 'c1', 10)],
            });
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          await pageFrames(tester, () {
            expect(w.location.route, RaftRoute.activity);
            expect(w.location.content?.id, 'c2');
            expect(paintedMessage(tester, 'first'), isNull);
            expect(paintedMessage(tester, 'old'), isNull);
          });
          if (failLast) {
            await tester.runAsync(() async {
              latest.complete({
                'messages': [row('latest', 'c2', 30)],
              });
              for (var i = 0; i < 40 && w.channelLoading; i++) {
                await Future<void>.delayed(const Duration(milliseconds: 5));
              }
            });
            await pageFrames(tester, () {});
            expect(paintedMessage(tester, 'latest'), isNotNull);
            expect(w.highlightedMessageId, isNull);
            expect(find.byType(MaterialBanner), findsOneWidget);
          } else {
            expect(paintedMessage(tester, 'second'), isNotNull);
          }
          expect(w.location.content?.id, 'c2');
          expect(paintedMessage(tester, 'first'), isNull);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
