import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/feature_flag_client_facts.dart';
import 'package:raft_flutter/data/read_receipts.dart';

class _Client extends RaftClient implements ReadReceiptsAuthority {
  _Client()
    : super(
        origin: 'https://public-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'viewer'});
    selectServer('server');
  }

  final requests = <Completer<dynamic>>[];
  final evaluations = <Completer<dynamic>>[];
  final emits = <(String, Object?)>[];

  @override
  RaftClient get client => this;

  @override
  RaftRecord get server => RaftRecord({'id': serverId});

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) {
    expect(path, '/channels/room');
    final request = Completer<dynamic>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) {
    expect(path, '/feature-flags/evaluate');
    final request = Completer<dynamic>();
    evaluations.add(request);
    return request.future;
  }

  @override
  bool emitSocketEvent(String event, [Object? payload]) {
    emits.add((event, payload));
    return true;
  }
}

Map<String, Object> _detail({bool muted = true, int frontier = 7}) => {
  'peerReadStates': [
    {
      'peerKind': 'agent',
      'peerId': 'ada',
      'maxReadSeq': frontier,
      'mutedChannel': muted,
      'stoppedFollowing': true,
    },
    {'peerKind': 'human', 'peerId': 'human', 'maxReadSeq': 1},
  ],
};

RaftEvent _progress(int frontier) => RaftEvent('read_progress:updated', {
  'scopeId': 'room',
  'peers': [
    {'peerId': 'ada', 'maxReadSeq': frontier},
    {'peerId': 'human', 'maxReadSeq': 40},
    {'peerId': 'unknown', 'maxReadSeq': 40},
    {'peerId': 'ada', 'maxReadSeq': -1},
  ],
});

void main() {
  late _Client client;
  late ReadReceipts receipts;
  setUp(() {
    client = _Client();
    receipts = ReadReceipts(client);
  });
  tearDown(() => receipts.dispose());

  test('feature changes supersede an in-flight evaluation', () async {
    receipts.ensureProgressFlag();
    receipts.consumeEvent(
      const RaftEvent('server:features-changed', {
        'serverId': 'server',
        'keys': [RaftFeatureFlags.agentReadProgress],
      }),
    );
    expect(client.evaluations, hasLength(2));
    client.evaluations.last.complete({
      'evaluations': [
        {'key': RaftFeatureFlags.agentReadProgress, 'enabled': true},
      ],
    });
    await Future<void>.delayed(Duration.zero);
    expect(receipts.progressEnabled, isTrue);
    client.evaluations.first.complete({'evaluations': []});
    await Future<void>.delayed(Duration.zero);
    expect(receipts.progressEnabled, isTrue);
    client.selectServer('next');
    expect(receipts.progressEnabled, isFalse);
    receipts.ensureProgressFlag();
    expect(client.evaluations, hasLength(3));
    client.evaluations.last.complete({'evaluations': []});
    await Future<void>.delayed(Duration.zero);
  });

  test(
    'buffers progress during detail and advances exposed agents only',
    () async {
      receipts.consumeEvent(_progress(90));
      final hydrated = receipts.hydrate('room');
      receipts.consumeEvent(_progress(15));
      receipts.consumeEvent(_progress(12));
      client.requests.single.complete(_detail());
      await hydrated;
      final peers = receipts.scope('room')!.peers!;
      expect(peers.map((peer) => (peer.peerId, peer.maxReadSeq)), [
        ('ada', 15),
        ('human', 1),
      ]);
      receipts.consumeEvent(_progress(13));
      expect(receipts.scope('room')!.peers, same(peers));
      receipts.consumeEvent(_progress(21));
      expect(
        projectAgentReadReceipt(receipts.scope('room'), 'ada', 21),
        isTrue,
      );
    },
  );

  test('detail changes replace reachability and retain a live frontier', () {
    receipts.acceptDetail('room', _detail());
    receipts.consumeEvent(_progress(21));
    receipts.acceptDetail('room', _detail(muted: false));
    expect(projectAgentReadReceipt(receipts.scope('room'), 'ada', 21), isTrue);
    expect(receipts.scope('room')!.peers!.first.mutedChannel, isFalse);
    expect(receipts.scope('room')!.peers!.first.stoppedFollowing, isTrue);
  });

  test(
    'channel removal drops cached peers and fences a queued refresh',
    () async {
      final release = receipts.watchProgress('room');
      receipts.acceptDetail('room', _detail());
      receipts.consumeEvent(
        const RaftEvent('read_progress:detail_changed', {'scopeId': 'room'}),
      );
      receipts.consumeEvent(
        const RaftEvent('channel:removed', {'channelId': 'room'}),
      );
      expect(receipts.scope('room'), isNull);
      final request = receipts.hydrateIfStale('room');
      client.requests.first.complete(_detail());
      await Future<void>.delayed(Duration.zero);
      expect(receipts.scope('room'), isNull);
      expect(client.requests, hasLength(2));
      client.requests.last.complete(null);
      await request;
      release();
    },
  );

  test(
    'shared mounts watch once, refresh on rejoin and release once',
    () async {
      final releaseFirst = receipts.watchProgress('room');
      final releaseSecond = receipts.watchProgress('room');
      expect(client.emits.map((event) => event.$1), ['read_progress:watch']);
      expect(client.emits.single.$2, {'scopeId': 'room'});
      client.requests.single.complete(_detail());
      await receipts.hydrateIfStale('room');
      releaseFirst();
      expect(client.emits, hasLength(1));
      receipts.consumeEvent(const RaftEvent('rooms:joined', null));
      expect(client.emits.last.$1, 'read_progress:watch');
      expect(client.requests, hasLength(2));
      receipts.consumeEvent(
        const RaftEvent('read_progress:detail_changed', {'scopeId': 'room'}),
      );
      expect(client.requests, hasLength(2));
      client.requests[1].complete(_detail());
      await Future<void>.delayed(Duration.zero);
      expect(client.requests, hasLength(3));
      client.requests[2].complete(_detail(muted: false));
      await receipts.hydrateIfStale('room');
      expect(receipts.scope('room')!.peers!.first.mutedChannel, isFalse);
      releaseSecond();
      releaseSecond();
      expect(client.emits.last.$1, 'read_progress:unwatch');
      receipts.consumeEvent(
        const RaftEvent('thread:followers-updated', {
          'threadChannelId': 'room',
        }),
      );
      expect(client.requests, hasLength(3));
      final reopened = receipts.watchProgress('room');
      expect(client.requests, hasLength(4));
      expect(receipts.scope('room')!.peers!.first.maxReadSeq, 7);
      client.requests.last.complete(_detail());
      await receipts.hydrateIfStale('room');
      reopened();
    },
  );
}
