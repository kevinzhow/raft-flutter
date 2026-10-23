import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_permalink.dart';
import 'package:raft_flutter/features/raft_permalink_resolution.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raft_flutter/features/foreign_permalink.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;

const here = 'acme', there = 'partner';
const remoteChannel = '0a0a0a0a-0000-0000-0000-00000000000a';
const localChannel = '0a0a0a0a-0000-0000-0000-00000000000b';
const localThread = '0a0a0a0a-0000-0000-0000-00000000000c';
const targetId = '0b0b0b0b-0000-0000-0000-000000000002';
const parentId = '0b0b0b0b-0000-0000-0000-000000000001';

RaftPermalink foreign({String kind = 'channel'}) => RaftPermalink(
  routeKind: kind,
  serverSlug: there,
  channelId: remoteChannel,
  messageId: targetId,
);

Future<(WorkspaceController, MessageAdapter)> open() async {
  final (w, api) = await fixture('owner');
  w.server = RaftRecord({'id': 's1', 'role': 'owner', 'slug': here});
  return (w, api);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a link copied in the other workspace lands on the local channel',
    () async {
      final (w, api) = (await open());
      addTearDown(w.dispose);
      api.routes['GET /messages/context/$targetId'] = (_) => {
        'channelId': localChannel,
        'targetMessageId': targetId,
        'messages': [],
      };
      final out = await resolveForeignPermalink(w, foreign());
      expect(out.outcome, ForeignPermalinkOutcome.local);
      expect(out.local?.serverSlug, here);
      expect(out.local?.channelId, localChannel);
      expect(out.local?.messageId, targetId);
      expect(out.local?.threadParentMessageId, isNull);
      final call = api.calls.singleWhere((c) => c.path.startsWith('/messages'));
      expect(call.queryParameters, {'channelId': remoteChannel});
    },
  );

  test('a reply link opens the local thread of its parent', () async {
    final (w, api) = (await open());
    addTearDown(w.dispose);
    api.routes['GET /messages/context/$targetId'] = (_) => {
      'channelId': localThread,
      'targetMessageId': targetId,
      'canonicalTarget': {
        'kind': 'thread',
        'channelId': localChannel,
        'threadChannelId': localThread,
        'threadParentMessageId': parentId,
        'messageId': targetId,
      },
    };
    final out = await resolveForeignPermalink(w, foreign());
    expect(out.outcome, ForeignPermalinkOutcome.local);
    expect(out.local?.channelId, localChannel);
    expect(out.local?.threadParentMessageId, parentId);
    expect(out.local?.messageId, targetId);
  });

  test('no readable projection keeps the link where it points', () async {
    final (w, api) = (await open());
    addTearDown(w.dispose);
    // The fixture answers unknown endpoints with 404, like the server does.
    final out = await resolveForeignPermalink(w, foreign());
    expect(out.outcome, ForeignPermalinkOutcome.keep);
    expect(
      api.calls.where((c) => c.path.startsWith('/messages')),
      hasLength(1),
    );
  });

  test('any other failure is reported instead of guessed', () async {
    final (w, api) = (await open());
    addTearDown(w.dispose);
    api.routes['GET /messages/context/$targetId'] = (_) => throw DioException(
      requestOptions: RequestOptions(path: '/messages/context/$targetId'),
      type: DioExceptionType.connectionError,
    );
    final out = await resolveForeignPermalink(w, foreign());
    expect(out.outcome, ForeignPermalinkOutcome.unavailable);
  });

  test('own-workspace and DM links are not resolved', () async {
    final (w, api) = (await open());
    addTearDown(w.dispose);
    final own = RaftPermalink(
      routeKind: 'channel',
      serverSlug: here,
      channelId: localChannel,
      messageId: targetId,
    );
    expect(
      (await resolveForeignPermalink(w, own)).outcome,
      ForeignPermalinkOutcome.keep,
    );
    expect(
      (await resolveForeignPermalink(w, foreign(kind: 'dm'))).outcome,
      ForeignPermalinkOutcome.keep,
    );
    expect(api.calls.where((c) => c.path.startsWith('/messages')), isEmpty);
  });

  testWidgets('an unreadable answer toasts and does not open a browser', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (w, api) = (await tester.runAsync(open))!;
    addTearDown(w.dispose);
    api.routes['GET /messages/context/$targetId'] = (_) => {'oops': true};
    late bool handled;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: RaftToastHost(
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    handled = await openPermalinkInApp(context, w, foreign()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 100));
    expect(handled, isTrue);
    expect(
      find.text('Could not resolve this message link. Please try again.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('tapping the other workspace link in a message opens the local '
      'channel, not the browser', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (w, api) = (await tester.runAsync(open))!;
    addTearDown(w.dispose);
    w.channels = [
      RaftChannel({'id': localChannel, 'name': 'shared', 'joined': true}),
    ];
    w.channel = w.channels.first;
    w.messageDomain.ledger.switchServer('s1');
    w.messageDomain.ledger.ingest([
      {
        'id': 'quoter',
        'channelId': localChannel,
        'seq': '2',
        'senderId': 'alice',
        'senderType': 'user',
        'senderName': 'Alice',
        'messageType': 'chat',
        'content':
            'See https://app.slock.ai/s/$there/channel/$remoteChannel?msg=$targetId',
        'createdAt': '2026-06-22T02:30:00.000Z',
      },
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds[localChannel] = {'quoter'};
    api.routes['GET /messages/context/$targetId'] = (_) => {
      'channelId': localChannel,
      'targetMessageId': targetId,
      'messages': [],
    };
    api.routes['GET /servers/s1/setup-projection'] = (_) => {
      'phase': 'complete',
      'surface': 'complete',
      'blocksChat': false,
    };
    api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
    api.routes['GET /agents'] = (_) => [];
    api.routes['GET /servers/s1/members'] = (_) => [];
    api.routes['GET /channels/$localChannel/available-mentions'] = (_) => {
      'humans': [],
      'agents': [],
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(body: RaftChatView(controller: w)),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.text('linked message', findRichText: true).first);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final reads = [
      for (final c in api.calls)
        if (c.path == '/messages/context/$targetId')
          c.queryParameters['channelId'],
    ];
    // First the link is resolved as the other workspace's channel id, then the
    // answer's local channel is the one that opens.
    expect(reads.first, remoteChannel);
    expect(reads, contains(localChannel));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
