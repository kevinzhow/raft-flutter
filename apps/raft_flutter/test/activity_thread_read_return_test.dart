import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_open_clears_new_test.dart' show activityRow;
import 'chat_focus_receipt_test.dart' show paintedMessage;
import 'message_presentation_test.dart' show MessageAdapter, fixture;
import 'support/app_services_fixture.dart';

class _Client extends RaftClient {
  _Client(MessageAdapter api)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = api,
      );
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => ingress.stream;
  @override
  Future<void> dispose() async {
    await ingress.close();
    await super.dispose();
  }
}

Map<String, dynamic> _reply(int seq) => {
  'id': 'm$seq',
  'channelId': 'thread-1',
  'seq': '$seq',
  'senderType': 'user',
  'senderId': 'bob',
  'senderName': 'Bob',
  'content': 'Visible reply $seq',
};

Future<void> _dispatch(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 25)),
  );
  for (var turn = 0; turn < 20; turn++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  for (final (family, dark) in raftThemeMatrix([
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ])) {
    for (final width in [390.0]) {
      for (final outcome in ['success', 'failure', 'after return']) {
        testWidgets(
          '$family/$dark ${width.toInt()}px Activity thread receipt $outcome updates the first return',
          (tester) async {
            SharedPreferences.setMockInitialValues({});
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final api = MessageAdapter();
            api.routes['POST /auth/login'] = (_) => {
              'accessToken': 'fixture-only',
              'refreshToken': 'fixture-only',
              'user': {'id': 'alice'},
            };
            final (client, w) = (await tester.runAsync(() async {
              final client = _Client(api);
              await client.login('fixture', 'fixture');
              client.selectServer('s1');
              return (client, WorkspaceController(client));
            }))!;
            addTearDown(w.dispose);
            w.server = RaftRecord({'id': 's1', 'role': 'owner'});
            w.channels = [
              RaftChannel({'id': 'c1', 'name': 'test', 'joined': true}),
            ];
            w.loading = false;
            w.connected = true;
            w.ledger.switchServer('s1');
            w.section = 'activity';
            var row = activityRow('thread');
            row['firstUnreadMessageId'] = 'm5';
            final heldInbox = Completer<dynamic>();
            var holdInbox = false;
            api.routes['GET /channels/inbox'] = (_) => holdInbox
                ? heldInbox.future
                : {
                    'items': [row],
                    'totalCount': 1,
                    'totalUnreadCount': row['unreadCount'],
                    'hasMore': false,
                  };
            api.routes['GET /agents'] = (_) => [];
            api.routes['GET /servers/s1/members'] = (_) => [];
            api.routes['GET /channels/unread'] = (_) => {'channels': {}};
            api.routes['GET /channels/c1'] = (_) => w.channels.first.json;
            api.routes['GET /channels/threads/followed'] = (_) => {
              'threads': [],
            };
            api.routes['GET /channels/thread-1/followers'] = (_) => [];
            api.routes['GET /channels/c1/threads/parent'] = (_) => {
              'threadChannelId': 'thread-1',
            };
            api.routes['GET /messages/context/parent'] = (_) => {
              'messages': [
                {..._reply(1), 'id': 'parent', 'channelId': 'c1'},
              ],
            };
            api.routes['GET /messages/context/m5'] = (_) => {
              'messages': [_reply(5)],
              'hasOlder': false,
              'hasNewer': false,
            };
            api.routes['GET /messages/channel/c1'] = (_) => {'messages': []};
            api.routes['GET /messages/channel/thread-1'] = (_) => {
              'messages': [_reply(5)],
            };
            api.routes['POST /channels/thread-1/read-all'] = (_) => {
              'maxReadSeq': 5,
              'readStateVersion': 1,
            };
            final receipt = Completer<dynamic>();
            api.routes['POST /channels/thread-1/read'] = (request) =>
                int.parse('${(request.data as Map)['seq']}') < 6
                ? {'maxReadSeq': 5, 'readStateVersion': 1}
                : receipt.future;
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
                home: withAppServices(
                  WorkspaceView(
                    controller: w,
                    appearance: RaftAppearance(light: family),
                    onAppearance: (_) async {},
                    onLogout: () async {},
                  ),
                ),
              ),
            );
            try {
              await tester.pumpAndSettle();
              final card = find.byKey(
                const ValueKey('activity-thread-thread-1'),
              );
              expect(card, findsOneWidget);
              await tester.tap(card);
              await tester.pumpAndSettle();
              expect(w.threadChannelId, 'thread-1');
              expect(paintedMessage(tester, 'm5'), isNotNull);
              row = activityRow('thread', unread: 1, seq: '6');
              holdInbox = true;
              client.ingress.add(RaftEvent('message:new', _reply(6)));
              await _dispatch(tester);
              expect(paintedMessage(tester, 'm6'), isNotNull);
              expect(
                api.calls.where(
                  (r) =>
                      r.path == '/channels/thread-1/read' &&
                      '${(r.data as Map)['seq']}' == '6',
                ),
                isNotEmpty,
                reason: 'The real thread timeline must have sent a receipt for the painted arrival.',
              );
              // A canonical window reaches the arrival while its receipt is held.
              final attention = w.activityUnread;
              attention.acceptWindow(
                {
                  'items': [row],
                  'totalCount': 1,
                  'totalUnreadCount': 1,
                  'hasMore': false,
                },
                scope: attention.scope,
                firstPage: true,
              );
              await _dispatch(tester);
              if (outcome == 'success') {
                receipt.complete({'maxReadSeq': 6, 'readStateVersion': 2});
              } else if (outcome == 'failure') {
                receipt.completeError(
                  const RaftApiException('Fixture read failure'),
                );
              }
              await _dispatch(tester);
              expect(
                w.readState.state('s1', 'alice', 'thread-1')?['maxReadSeq'],
                outcome == 'success' ? 6 : 5,
              );
              expect(attention.totalUnreadCount, outcome == 'success' ? 0 : 1);
              await tester.tap(
                find.byKey(
                  Key(width < 1000 ? 'mobile-detail-back' : 'thread-close'),
                ),
              );
              await tester.pump();
              for (var frame = 0; frame < 6; frame++) {
                expect(w.location.route, RaftRoute.activity);
                expect(w.location.content, isNull);
                expect(w.location.thread, isNull);
                expect(card, findsOneWidget);
                expect(
                  find.descendant(of: card, matching: find.text('1 new')),
                  outcome == 'success' ? findsNothing : findsOneWidget,
                  reason:
                      'Read ACK must update Activity before a second visit or inbox response; frame $frame.',
                );
                final dynamic state = tester.state(find.byType(ResourceView));
                expect(
                  state.rows.single['unreadCount'],
                  outcome == 'success' ? 0 : 1,
                );
                await tester.pump(const Duration(milliseconds: 16));
              }
              if (outcome == 'after return') {
                receipt.complete({'maxReadSeq': 6, 'readStateVersion': 2});
                await _dispatch(tester);
                expect(
                  find.descendant(of: card, matching: find.text('1 new')),
                  findsNothing,
                );
                expect(
                  w.readState.state('s1', 'alice', 'thread-1')?['maxReadSeq'],
                  6,
                );
              }
              if (outcome != 'failure') {
                // A later reply arrives after leaving the thread. Its new unread
                // indicator cannot be suppressed by the completed read of seq 6.
                client.ingress.add(RaftEvent('message:new', _reply(7)));
                heldInbox.complete({
                  'items': [activityRow('thread', unread: 1, seq: '7')],
                  'totalCount': 1,
                  'totalUnreadCount': 1,
                  'hasMore': false,
                });
                await _dispatch(tester);
                expect(
                  find.descendant(of: card, matching: find.text('1 new')),
                  findsOneWidget,
                );
                expect(
                  api.calls.where(
                    (r) =>
                        r.path == '/channels/thread-1/read' &&
                        '${(r.data as Map)['seq']}' == '7',
                  ),
                  isEmpty,
                );
              }
            } finally {
              await tester.pumpWidget(const SizedBox());
              await tester.pumpAndSettle();
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  testWidgets(
    'cached Activity projects a read accepted while the page was absent before its first frame',
    (tester) async {
      final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      final row = activityRow('thread', unread: 1, seq: '6');
      final pending = Completer<dynamic>();
      var hold = false;
      api.routes['GET /agents'] = (_) => [];
      api.routes['GET /servers/s1/members'] = (_) => [];
      api.routes['GET /channels/inbox'] = (_) => hold
          ? pending.future
          : {
              'items': [row],
              'totalCount': 1,
              'totalUnreadCount': 1,
              'hasMore': false,
            };
      api.routes['POST /channels/thread-1/read-all'] = (_) => {
        'maxReadSeq': 6,
        'readStateVersion': 2,
      };
      Widget page() => MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: ResourceView(
            controller: w,
            section: 'activity',
            onMessage: (_, _) async {},
          ),
        ),
      );
      try {
        await tester.pumpWidget(page());
        await tester.pumpAndSettle();
        expect(find.text('1 new'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        final write = w.conversationReads.markAllRead('thread-1');
        await _dispatch(tester);
        await write;
        expect(w.readState.state('s1', 'alice', 'thread-1')?['maxReadSeq'], 6);
        hold = true;
        await tester.pumpWidget(page());
        // The returning page cannot paint the old badge while waiting for GET.
        expect(find.text('1 new'), findsNothing);
        final dynamic state = tester.state(find.byType(ResourceView));
        expect(state.rows.single['unreadCount'], 0);
        expect(state.totalUnreadCount, 0);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );
}
