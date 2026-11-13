// WP-LIVE (Web v1.24.0): holes behind live rows, GET /sync/changes, the new
// socket events the session applies itself, actor resolve and lost channels.
import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/actor_directory.dart';
import 'package:raft_flutter/data/channel_access_loss.dart';
import 'package:raft_flutter/data/workspace_live_sync.dart';

import 'support/history_automatic_fixture.dart';

class _NoJitter implements Random {
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
  @override
  int nextInt(int max) => 0;
}

Map<String, dynamic> _row(int seq) => {
  'id': 'm$seq',
  'channelId': 'chat',
  'seq': '$seq',
  'content': 'Body $seq',
  'senderType': 'user',
  'senderId': 'bob',
};

class _LiveClient extends HistoryAuditClient {
  /// Rows the server holds past the seeded 100.
  final server = <int>{};
  final wire = <String>[];
  final syncFailures = <Object>[];
  final changes = <Object>[];
  final resolved = <List>[];
  Object? resolveFailure;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/messages/sync') {
      wire.add('sync ${query!['since_seq']}');
      if (syncFailures.isNotEmpty) throw syncFailures.removeAt(0);
      final since = int.parse('${query['since_seq']}');
      return [
        for (final n in server.toList()..sort())
          if (n > since) _row(n),
      ];
    }
    if (path.contains('sidebar-order')) wire.add('sidebar');
    if (path == '/channels') wire.add('channels');
    return super.get(path, query: query);
  }

  @override
  void resumeSince(BigInt seq, String? sinceHorizon) =>
      wire.add('resume $seq $sinceHorizon');

  @override
  Future<dynamic> getForServer(
    String server,
    String path, {
    Map<String, dynamic>? query,
  }) async {
    if (path != '/sync/changes') return {};
    wire.add('changes ${query?['since']}');
    final answer = changes.isEmpty ? null : changes.removeAt(0);
    if (answer is Exception) throw answer;
    return answer ??
        {'cursor': 'c-end', 'hasMore': false, 'changes': [], 'reset': null};
  }

  @override
  Future<dynamic> postForServer(
    String server,
    String path, {
    dynamic data,
  }) async {
    if (path != '/actors/resolve') return {};
    resolved.add(data['actors'] as List);
    final failure = resolveFailure;
    if (failure != null) throw failure;
    return {
      'actors': [
        for (final ref in data['actors'] as List)
          {
            'kind': ref['kind'],
            'id': ref['id'],
            'homeServerId': '99999999-9999-4999-8999-999999999999',
            'name': 'peer-${ref['id'].substring(0, 4)}',
            'displayName': null,
            'avatarUrl': null,
          },
      ],
    };
  }
}

class _Case extends HistoryAuditCase {
  @override
  // ignore: overridden_fields
  final _LiveClient client = _LiveClient();

  void live(int n) {
    server.add(n);
    client.incoming.add(RaftEvent('message:new', _row(n)));
  }

  Set<int> get server => client.server;

  Future<void> settle([int ms = 60]) async {
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(Duration(milliseconds: ms ~/ 3));
      await cache.messageHistory.receiver.settled;
    }
  }

  Iterable<String> get shown => w.messageDomain.messages.map((m) => m.id);
}

const _peerA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _peerB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

void main() {
  setUp(() => WorkspaceLiveSync.random = _NoJitter());

  group('live gap fill (Web liveGapFill.ts)', () {
    test('[BP-RT-030] [BP-READ-021] a live row across a seq jump is shown at '
        'once and the hole behind it is read in the background', () async {
      final c = _Case();
      addTearDown(c.close);
      await c.seed();
      c.server.add(101); // never pushed: the socket missed it
      c.live(102);
      expect(c.shown.last, 'm102', reason: 'the live row shows at once');
      await c.settle();
      expect(c.client.wire, ['sync 100'], reason: 'from the window tail');
      expect(c.shown, containsAllInOrder(['m100', 'm101', 'm102']));
    });

    test('a contiguous live row reads nothing', () async {
      final c = _Case();
      addTearDown(c.close);
      await c.seed();
      c.live(101);
      await c.settle();
      expect(c.client.wire.where((e) => e.startsWith('sync')), isEmpty);
    });

    test('[BP-RT-046] a failed fill retries after 1 s', () async {
      final c = _Case();
      addTearDown(c.close);
      await c.seed();
      c.client.syncFailures.add(
        const RaftApiException('Server error', status: 500),
      );
      c.server.add(101);
      c.live(102);
      await c.settle();
      expect(c.shown, isNot(contains('m101')));
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await c.settle();
      expect(c.client.wire, ['sync 100', 'sync 100']);
      expect(c.shown, contains('m101'));
    });

    test('[BP-RT-043] a heartbeat re-reads a scope still owing a fill, '
        'whatever its seq says', () async {
      final c = _Case();
      addTearDown(c.close);
      await c.seed();
      c.client.syncFailures.add(
        const RaftApiException('Server error', status: 500),
      );
      c.server.add(101);
      c.live(102);
      await c.settle();
      c.client.incoming.add(const RaftEvent('heartbeat', {'seq': 50}));
      await c.settle();
      expect(c.client.wire, ['sync 100', 'sync 100']);
      expect(c.shown, contains('m101'));
    });

    test(
      '[BP-RT-046] a channel this person lost stops reading /messages/sync',
      () async {
        final c = _Case();
        addTearDown(c.close);
        await c.seed();
        c.client.syncFailures.add(
          RaftApiException.response(
            'Access denied',
            status: 403,
            body: {'error': 'Access denied'},
          ),
        );
        c.live(102);
        await c.settle();
        expect(ChannelAccessLoss.of(c.client).isLost('chat'), isTrue);
        c.client.incoming.add(const RaftEvent('heartbeat', {'seq': 500}));
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        await c.settle();
        expect(c.client.wire, [
          'sync 100',
        ], reason: 'no retry, no heartbeat read');
        ChannelAccessLoss.of(c.client).clear('chat');
        expect(ChannelAccessLoss.of(c.client).isLost('chat'), isFalse);
      },
    );

    test('another 403 (not a channel denial) does not mark the channel', () {
      final c = HistoryAuditClient();
      addTearDown(c.dispose);
      ChannelAccessLoss.of(c).noteReadError(
        'chat',
        RaftApiException.response(
          'Email verification required',
          status: 403,
          body: {'error': 'Email verification required'},
        ),
      );
      expect(ChannelAccessLoss.of(c).isLost('chat'), isFalse);
    });
  });

  group('GET /sync/changes (Web syncChangesClient.ts)', () {
    Future<_Case> connected() async {
      final c = _Case();
      addTearDown(c.close);
      await c.seed();
      c.client.incoming.add(const RaftEvent('connected', null));
      await c.settle();
      return c;
    }

    test('the first connect takes no cursor', () async {
      final c = await connected();
      expect(c.client.wire.where((e) => e.startsWith('changes')), isEmpty);
    });

    test(
      '[BP-RT-041] a reconnect takes a cursor, then reads the lists after it; the next '
      'reconnect pulls instead of re-reading the sidebar and channels',
      () async {
        final c = await connected();
        c.client.changes.add({
          'cursor': 'c0',
          'hasMore': false,
          'changes': [],
          'reset': null,
        });
        c.client.wire.clear();
        c.client.incoming.add(const RaftEvent('connected', null));
        await c.settle();
        expect(c.client.wire.first, 'changes null');
        expect(c.client.wire, containsAll(['sidebar', 'channels']));
        expect(WorkspaceLiveSync.of(c.client).syncSession!.hasCursor, isTrue);

        c.client.wire.clear();
        c.client.incoming.add(const RaftEvent('connected', null));
        c.client.incoming.add(const RaftEvent('rooms:joined', {}));
        await c.settle();
        expect(c.client.wire, contains('changes c0'));
        expect(c.client.wire, isNot(contains('sidebar')));
        expect(c.client.wire, isNot(contains('channels')));
      },
    );

    test('a server with sync off (404) keeps the old reloads', () async {
      final c = await connected();
      c.client.changes.add(
        RaftApiException.response(
          'Incremental sync is off',
          status: 404,
          body: {'error': 'off', 'code': 'sync_changes_off'},
        ),
      );
      c.client.wire.clear();
      c.client.incoming.add(const RaftEvent('connected', null));
      await c.settle();
      expect(c.client.wire, containsAll(['changes null', 'sidebar']));
      expect(WorkspaceLiveSync.of(c.client).syncSession!.hasCursor, isFalse);
    });

    test('[BP-RT-077] sync:changed pulls at once; a sidebar_order change re-reads it; '
        'invalid_cursor drops the cursor and reloads the lists', () async {
      final c = await connected();
      c.client.changes.addAll([
        {'cursor': 'c0', 'hasMore': false, 'changes': [], 'reset': null},
      ]);
      c.client.incoming.add(const RaftEvent('connected', null));
      await c.settle();
      c.client.wire.clear();
      c.client.changes.add({
        'cursor': 'c1',
        'hasMore': false,
        'changes': [
          {
            'seq': 1,
            'entity': 'sidebar_order',
            'id': 'server',
            'op': 'upsert',
            'row': {},
          },
        ],
        'reset': null,
      });
      c.client.incoming.add(const RaftEvent('sync:changed', {}));
      await c.settle();
      expect(c.client.wire, ['changes c0', 'sidebar']);

      c.client.wire.clear();
      c.client.changes.add(
        RaftApiException.response(
          'since must be a cursor',
          status: 400,
          body: {'error': 'bad', 'code': 'invalid_cursor'},
        ),
      );
      c.client.incoming.add(const RaftEvent('sync:changed', {}));
      await c.settle();
      expect(c.client.wire, containsAll(['changes c1', 'sidebar', 'channels']));
      expect(WorkspaceLiveSync.of(c.client).syncSession!.hasCursor, isFalse);
    });
  });

  group('sync horizon (server v1.24 syncResume.ts)', () {
    test('[BP-RT-039] the next resume round sends the horizon the last answer '
        'carried; horizonReset re-reads the visible scopes', () async {
      final c = _Case();
      addTearDown(c.close);
      await c.seed();
      c.client.incoming.add(const RaftEvent('rooms:joined', {}));
      await c.settle();
      expect(c.client.wire, contains('resume 100 null'));
      c.client.incoming.add(
        const RaftEvent('sync:resume:response', {
          'messages': [],
          'currentSeq': 100,
          'hasMore': false,
          'horizon': 'h-1',
          'horizonReset': true,
        }),
      );
      await c.settle();
      expect(c.client.wire, contains('sync 100'), reason: 'horizonReset');
      c.client.wire.clear();
      c.client.incoming.add(const RaftEvent('rooms:joined', {}));
      await c.settle();
      expect(c.client.wire, contains('resume 100 h-1'));
    });
  });

  group('new socket events', () {
    test(
      '[BP-RT-073] user:profile-updated patches the signed-in person',
      () async {
        final c = _Case();
        addTearDown(c.close);
        c.client.user = RaftRecord({
          'id': _peerA,
          'name': 'alice',
          'email': 'kept',
        });
        c.w.toString();
        c.client.incoming.add(
          const RaftEvent('user:profile-updated', {
            'serverId': _peerB,
            'userId': _peerA,
            'name': 'alice2',
            'displayName': 'Alice',
            'avatarUrl': null,
            'gravatarHash': '',
          }),
        );
        await c.settle();
        expect(c.client.user!.json['displayName'], 'Alice');
        expect(c.client.user!.json['name'], 'alice2');
        expect(c.client.user!.json['email'], 'kept');
      },
    );

    test(
      '[BP-RT-074] appearance:updated patches the server row theme',
      () async {
        final c = _Case();
        addTearDown(c.close);
        c.w.servers = [
          RaftRecord({'id': 'server', 'role': 'owner', 'theme': null}),
        ];
        c.client.incoming.add(
          const RaftEvent('appearance:updated', {
            'serverId': 'server',
            'theme': 'space',
            'themeDecor': true,
          }),
        );
        await c.settle();
        expect(c.w.servers.single.json['theme'], 'space');
        expect(c.w.servers.single.json['themeDecor'], true);
      },
    );

    test(
      '[BP-RT-078] thread:reply_updated edits the inline preview in place',
      () async {
        final c = _Case();
        addTearDown(c.close);
        c.client.summaries = {
          'm100': {
            'threadChannelId': 'thread',
            'replyCount': 1,
            'latestReplies': [
              {
                'messageId': 'r1',
                'seq': 900,
                'preview': 'original',
                'senderId': 'bob',
                'senderType': 'user',
                'createdAt': '2026-11-01T00:00:00Z',
              },
            ],
          },
        };
        await c.seed();
        c.client.incoming.add(
          const RaftEvent('thread:reply_updated', {
            'id': 'r1',
            'seq': 900,
            'channelId': 'thread',
            'content': 'edited',
            'updatedAt': '2026-11-02T00:00:00Z',
            'createdAt': '2026-11-01T00:00:00Z',
            'conversationContext': {
              'channelType': 'thread',
              'parentMessageId': 'm100',
              'parentChannelId': 'chat',
            },
          }),
        );
        await c.settle();
        final summary =
            c.w.messageDomain.threadSummariesFor('chat')['m100'] as Map;
        expect((summary['latestReplies'] as List).single['preview'], 'edited');
        expect(summary['replyCount'], 1);
      },
    );
  });

  group('POST /actors/resolve (Web actorResolve.ts)', () {
    test('refs are batched once per scope; a 404 turns it off', () async {
      final client = _LiveClient();
      addTearDown(client.dispose);
      final actors = ActorDirectory.of(client);
      var notified = 0;
      actors.addListener(() => notified++);
      actors.request([
        (kind: 'agent', id: _peerA),
        (kind: 'human', id: _peerB),
        (kind: 'agent', id: 'not-a-uuid'),
      ]);
      actors.request([(kind: 'agent', id: _peerA)]);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(client.resolved, hasLength(1));
      expect(client.resolved.single, hasLength(2));
      expect(actors.row('agent', _peerA)!.name, startsWith('peer-'));
      expect(notified, 1);
      actors.request([(kind: 'agent', id: _peerA)]);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(client.resolved, hasLength(1), reason: 'asked once');

      client.resolveFailure = const RaftApiException('Not found', status: 404);
      actors.request([
        (kind: 'agent', id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      actors.request([
        (kind: 'agent', id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(client.resolved, hasLength(2), reason: 'off after a 404');
    });

    test(
      '[BP-RT-072] actor:updated refreshes the row of the current scope',
      () async {
        final c = _Case();
        addTearDown(c.close);
        c.w.toString();
        c.client.incoming.add(
          const RaftEvent('actor:updated', {
            'kind': 'agent',
            'id': _peerA,
            'homeServerId': _peerB,
            'name': 'renamed',
            'displayName': 'Renamed',
            'avatarUrl': null,
          }),
        );
        await c.settle();
        expect(
          ActorDirectory.of(c.client).row('agent', _peerA)!.displayName,
          'Renamed',
        );
      },
    );
  });
}
