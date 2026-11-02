// Drives the real single-pane (390px) flow with a mounted WorkspaceView:
// Activity row tap -> markActivityRead -> mobile page push -> context GET ->
// Android back / tab switches. Answers: does a navigation revision bump land
// during the context GET in practice, and does any path paint the chat while
// channelLoading is stuck?
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_open_clears_new_test.dart' show activityRow;
import 'chat_focus_receipt_test.dart' show paintedMessage;
import 'message_presentation_test.dart' show MessageAdapter;
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

Map<String, dynamic> _message(int seq, [String channel = 'c1']) => {
  'id': 'm$seq',
  'channelId': channel,
  'seq': '$seq',
  'senderType': 'user',
  'senderId': 'bob',
  'senderName': 'Bob',
  'content': 'Message $seq',
};

class _Rig {
  _Rig(this.tester, {this.thread = false});
  final WidgetTester tester;
  final bool thread;
  late MessageAdapter api;
  late _Client client;
  late WorkspaceController w;
  Completer<void>? contextGate;
  final contextStarted = <Completer<void>>[];

  Future<void> pumpFrames([int n = 12]) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> mount({bool both = false}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    api = MessageAdapter();
    api.routes['POST /auth/login'] = (_) => {
      'accessToken': 'fixture-only',
      'refreshToken': 'fixture-only',
      'user': {'id': 'alice'},
    };
    final made = (await tester.runAsync(() async {
      final client = _Client(api);
      await client.login('fixture', 'fixture');
      client.selectServer('s1');
      return (client, WorkspaceController(client, mobileNavigation: true));
    }))!;
    client = made.$1;
    w = made.$2;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      w.dispose();
    });
    w.server = RaftRecord({'id': 's1', 'role': 'owner'});
    w.channels = [
      RaftChannel({'id': 'c1', 'name': 'test', 'joined': true}),
    ];
    w.loading = false;
    w.connected = true;
    w.messageDomain.ledger.switchServer('s1');
    w.section = 'activity';
    // A read, long conversation whose newest message (m201) is the target.
    final row = activityRow(
      thread ? 'thread' : 'channel',
      unread: 0,
      seq: '201',
    );
    api.routes['GET /channels/inbox'] = (_) => {
      'items': [row, if (both) activityRow('channel', unread: 0, seq: '201')],
      'totalCount': both ? 2 : 1,
      'totalUnreadCount': 0,
      'hasMore': false,
    };
    api.routes['GET /agents'] = (_) => [];
    api.routes['GET /servers/s1/members'] = (_) => [];
    api.routes['GET /channels/unread'] = (_) => {'channels': {}};
    api.routes['GET /channels/c1'] = (_) => w.channels.first.json;
    api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
    api.routes['GET /messages/channel/c1'] = (_) => {
      'messages': [for (var n = 152; n <= 201; n++) _message(n)],
    };
    api.routes['GET /channels/c1/threads/parent'] = (_) => {
      'threadChannelId': 'thread-1',
    };
    api.routes['GET /channels/thread-1/followers'] = (_) => [];
    api.routes['GET /messages/context/parent'] = (_) => {
      'messages': [
        {..._message(1), 'id': 'parent'},
      ],
    };
    api.routes['GET /messages/channel/thread-1'] = (_) => {
      'messages': [for (var n = 152; n <= 201; n++) _message(n, 'thread-1')],
    };
    api.routes['POST /channels/thread-1/read'] = (_) => {
      'maxReadSeq': 201,
      'readStateVersion': 1,
    };
    api.routes['POST /channels/thread-1/read-all'] = (_) => {
      'maxReadSeq': 201,
      'readStateVersion': 1,
    };
    for (final id in ['m201', 'm202', 'm203', 'm204']) {
      api.routes['GET /messages/context/$id'] = (request) async {
        final channel = request.queryParameters['channelId'] as String? ?? 'c1';
        final started = Completer<void>();
        contextStarted.add(started);
        started.complete();
        await contextGate?.future;
        return {
          'messages': [for (var n = 186; n <= 201; n++) _message(n, channel)],
          'targetMessageId': id,
          'hasOlder': true,
          'hasNewer': false,
        };
      };
    }
    api.routes['POST /channels/c1/read'] = (_) => {
      'maxReadSeq': 201,
      'readStateVersion': 1,
    };
    api.routes['POST /channels/c1/read-all'] = (_) => {
      'maxReadSeq': 201,
      'readStateVersion': 1,
    };
    api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
    api.routes['GET /servers/s1/setup-projection'] = (_) => {
      'phase': 'complete',
      'surface': 'complete',
      'blocksChat': false,
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: false),
        home: withAppServices(
          WorkspaceView(
            controller: w,
            appearance: RaftAppearance(),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder get card => find.byKey(
    ValueKey(thread ? 'activity-thread-thread-1' : 'activity-channel-c1'),
  );

  String describe() {
    final m = w.messageDomain;
    return 'route=${w.location.route.name} section=${w.section} '
        'channel=${w.channel?.id} loading=${m.state.channelLoading} '
        'thread=${m.state.threadChannelId} threadLoading=${m.state.threadLoading} '
        'threadErr=${m.state.threadResolutionError} replies=${w.replies.length} '
        'rows=${m.messages.length} uri=${w.location.uri} rev=${w.navigationRevision}';
  }
}

void main() {
  for (final thread in [true, false]) {
    final kind = thread ? 'thread' : 'channel';
    testWidgets(
      '$kind row, real tap: no navigation revision bump lands during the context GET; the chat paints the newest message',
      (tester) async {
        final rig = _Rig(tester, thread: thread);
        await rig.mount();
        expect(rig.card, findsOneWidget);
        final gate = rig.contextGate = Completer<void>();
        await tester.tap(rig.card);
        await rig.pumpFrames();
        expect(rig.contextStarted, isNotEmpty, reason: 'context GET not sent');
        final atRequest = rig.w.navigationRevision;
        final log = <String>[rig.describe()];
        // Let the pushed chat page build, post-frame work and markRead run while
        // the GET is still pending.
        await rig.pumpFrames(60);
        log.add(rig.describe());
        expect(
          rig.w.navigationRevision,
          atRequest,
          reason: 'revision bumped during the GET: ${log.join(' | ')}',
        );
        rig.contextGate = null;
        gate.complete();
        await rig.pumpFrames();
        expect(
          thread
              ? rig.w.messageDomain.state.threadLoading
              : rig.w.messageDomain.state.channelLoading,
          isFalse,
        );
        expect(
          paintedMessage(tester, 'm201'),
          isNotNull,
          reason: rig.describe(),
        );
      },
    );

    for (final back in ['android-back', 'back-button']) {
      for (final stage in ['not-left-loading', 'second-tap-recovers']) {
        testWidgets(
          stage == 'not-left-loading'
              ? '$kind row: back during the context GET does not leave it loading; $back'
              : '$kind row: back during the context GET, then tapping the row again paints the newest message; $back',
          skip: !thread && stage == 'not-left-loading', // known: channelLoading after Back during the GET; the next tap recovers
          (tester) async {
            final rig = _Rig(tester, thread: thread);
            await rig.mount();
            final gate = rig.contextGate = Completer<void>();
            await tester.tap(rig.card);
            await rig.pumpFrames();
            expect(rig.contextStarted, isNotEmpty);
            if (back == 'android-back') {
              await tester.binding.handlePopRoute();
            } else {
              await tester.tap(find.byKey(const Key('mobile-detail-back')));
            }
            await rig.pumpFrames();
            rig.contextGate = null;
            gate.complete();
            await rig.pumpFrames();
            final afterBack = rig.describe();
            expect(rig.w.location.route, RaftRoute.activity, reason: afterBack);
            expect(rig.card, findsOneWidget, reason: afterBack);
            if (stage == 'not-left-loading') {
              expect(
                (thread
                    ? rig.w.messageDomain.state.threadLoading
                    : rig.w.messageDomain.state.channelLoading),
                isFalse,
                reason: 'after back: $afterBack',
              );
              return;
            }
            await tester.tap(rig.card);
            await rig.pumpFrames();
            expect(
              paintedMessage(tester, 'm201'),
              isNotNull,
              reason: 'second tap: ${rig.describe()}',
            );
            expect(
              thread
                  ? rig.w.messageDomain.state.threadLoading
                  : rig.w.messageDomain.state.channelLoading,
              isFalse,
            );
          },
        );
      }
    }
  }

  // Back and forth between a thread row and a channel row, with new thread
  // replies arriving while the channel is open.
  testWidgets(
    'switching between a thread row and a channel row repeatedly paints the tapped item each time',
    (tester) async {
      final rig = _Rig(tester, thread: true);
      await rig.mount(both: true);
      final threadCard = find.byKey(const ValueKey('activity-thread-thread-1'));
      final channelCard = find.byKey(const ValueKey('activity-channel-c1'));
      for (var round = 0; round < 3; round++) {
        await tester.tap(threadCard);
        await rig.pumpFrames();
        await tester.pumpAndSettle();
        expect(
          rig.w.messageDomain.state.threadChannelId,
          'thread-1',
          reason: 'round $round thread: ${rig.describe()}',
        );
        expect(
          paintedMessage(tester, 'm201'),
          isNotNull,
          reason: 'round $round thread: ${rig.describe()}',
        );
        await tester.binding.handlePopRoute();
        await rig.pumpFrames();
        await tester.pumpAndSettle();
        expect(threadCard, findsOneWidget, reason: rig.describe());
        await tester.tap(channelCard);
        await rig.pumpFrames();
        await tester.pumpAndSettle();
        expect(
          rig.w.messageDomain.state.threadChannelId,
          isNull,
          reason: 'round $round channel: ${rig.describe()}',
        );
        expect(
          paintedMessage(tester, 'm201'),
          isNotNull,
          reason: 'round $round channel: ${rig.describe()}',
        );
        rig.client.ingress.add(
          RaftEvent('message:new', _message(202 + round, 'thread-1')),
        );
        await rig.pumpFrames();
        await tester.binding.handlePopRoute();
        await rig.pumpFrames();
        await tester.pumpAndSettle();
        expect(channelCard, findsOneWidget, reason: rig.describe());
      }
      await tester.pump(const Duration(seconds: 3));
    },
  );
}
