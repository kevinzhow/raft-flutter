import 'package:raft_sync/raft_sync.dart';
import 'package:test/test.dart';

Map<String, dynamic> reply(int seq, {String sender = 'user'}) => {
  'id': 'r$seq',
  'seq': seq,
  'content': 'Reply $seq 中文',
  'senderId': 'alice',
  'senderType': sender,
  'senderName': 'alice',
  'createdAt': '2026-10-08T00:00:00Z',
  'conversationContext': {
    'channelType': 'thread',
    'parentMessageId': 'parent',
    'parentChannelId': 'channel',
    'parentChannelType': 'private',
  },
};
Map<String, dynamic> frame(int seq, {String epoch = 'one', int? count}) => {
  'parentMessageId': 'parent',
  'threadChannelId': 'thread',
  'replyCount': count ?? seq,
  'lastReplyAt': '2026-10-08T00:00:00Z',
  'participantIds': ['alice'],
  'latestReply': reply(seq),
  'syncCoreReplyWindow': {
    'producer': threadRepliesProducer,
    'discussion': {
      'root': {'kind': 'message', 'serverId': 'server', 'id': 'parent'},
      'relation': {'kind': 'replies'},
      'backing': 'sync-scope',
      'parentScopeKey': {
        'serverId': 'server',
        'scopeKind': 'private',
        'scopeId': 'channel',
      },
    },
    'window': {
      'kind': 'sync-scope-window',
      'scopeCursor': null,
      'epoch': epoch,
    },
  },
};
ThreadRepliesResult consume(ThreadRepliesSync sync, Map<String, dynamic> p) =>
    sync.consume(p, serverId: 'server', principalId: 'alice');

void main() {
  test(
    'canonical sparse core rejects duplicates/regressions and bounds top N',
    () {
      final sync = ThreadRepliesSync();
      for (final seq in [2, 10, 99, 100]) {
        expect(consume(sync, frame(seq)).kind, 'applied');
      }
      final last = consume(sync, frame(101));
      expect(last.summary!['latestReplies'].map((dynamic r) => r['seq']), [
        99,
        100,
        101,
      ]);
      expect(consume(sync, frame(10, count: 999)).kind, 'duplicate_dropped');
      expect(consume(sync, frame(101, count: 999)).kind, 'duplicate_dropped');
      expect(
        sync
            .scope(sync.scopeId('server', 'alice', 'parent', 'thread'))!
            .replyCount,
        101,
      );
      expect(sync.core.pendingRequests(), isEmpty); // sparse is not a gap
    },
  );
  test(
    'known canonical producer fails closed on wrong server/anchor/window',
    () {
      final sync = ThreadRepliesSync();
      final p = frame(5);
      expect(
        sync.consume(p, serverId: 'other', principalId: 'alice').kind,
        'dropped',
      );
      (p['latestReply']['conversationContext'] as Map)['parentChannelId'] =
          'wrong';
      expect(consume(sync, p).kind, 'dropped');
      final bad = frame(6);
      (bad['syncCoreReplyWindow']['window'] as Map).remove('epoch');
      expect(consume(sync, bad).kind, 'dropped');
      expect(
        sync.core.state(
          threadRepliesDomain,
          sync.scopeId('server', 'alice', 'parent', 'thread'),
        ),
        isNull,
      );
    },
  );
  test(
    'bundled snapshot fills equal-watermark provisional window and keeps epoch',
    () {
      final sync = ThreadRepliesSync();
      consume(sync, frame(12));
      final summary = sync.hydrateSummary(
        'server',
        'alice',
        'channel',
        'parent',
        {
          'threadChannelId': 'thread',
          'replyCount': 12,
          'latestReplies': [
            for (final n in [10, 11, 12]) projectThreadReply(reply(n)),
          ],
        },
      );
      expect((summary['latestReplies'] as List).map((dynamic r) => r['seq']), [
        10,
        11,
        12,
      ]);
      expect(
        consume(sync, frame(13, epoch: 'two')).kind,
        'rebaseline_requested',
      );
      expect(consume(sync, frame(12)).kind, 'duplicate_dropped');
    },
  );
  test(
    'epoch change coalesces bounded pending frames then replays after snapshot',
    () {
      final sync = ThreadRepliesSync();
      consume(sync, frame(90));
      final first = consume(sync, frame(5, epoch: 'two'));
      expect(first.kind, 'rebaseline_requested');
      for (final n in [6, 7, 8, 9]) {
        expect(
          consume(sync, frame(n, epoch: 'two')).kind,
          'rebaseline_pending',
        );
      }
      final complete = sync.completeRebaseline(
        first.request!,
        replies: [projectThreadReply(reply(4), snapshot: true)!],
        replyCount: 4,
      );
      expect(complete.kind, 'applied');
      expect(complete.summary!['replyCount'], 9);
      expect(
        (complete.summary!['latestReplies'] as List).map(
          (dynamic r) => r['seq'],
        ),
        [7, 8, 9],
      );
      expect(
        sync.core.scopeSyncState(
          threadRepliesDomain,
          first.request!.scopeId,
        )!['epoch'],
        'two',
      );
      expect(consume(sync, frame(9, epoch: 'two')).kind, 'duplicate_dropped');
    },
  );
  test('new epoch/reset/revocation rejects an older pending snapshot', () {
    final sync = ThreadRepliesSync();
    consume(sync, frame(10));
    final old = consume(sync, frame(1, epoch: 'two')).request!;
    final newer = consume(sync, frame(2, epoch: 'three')).request!;
    expect(
      sync.completeRebaseline(old, replies: [], replyCount: 0).kind,
      'duplicate_dropped',
    );
    expect(
      sync.completeRebaseline(newer, replies: [], replyCount: 0).kind,
      'applied',
    );
    final pending = consume(sync, frame(3, epoch: 'four')).request!;
    sync.revokeChannel('channel');
    expect(
      sync.completeRebaseline(pending, replies: [], replyCount: 0).kind,
      'duplicate_dropped',
    );
    expect(sync.scope(pending.scopeId), isNull);
    consume(sync, frame(4));
    final reset = consume(sync, frame(5, epoch: 'new')).request!;
    sync.reset();
    expect(
      sync.completeRebaseline(reset, replies: [], replyCount: 0).kind,
      'duplicate_dropped',
    );
  });
  test('legacy no-envelope frames retain fixed snapshot seam and count-only summary', () {
    final sync = ThreadRepliesSync();
    sync.hydrateSummary('server', 'alice', 'channel', 'parent', {
      'threadChannelId': 'thread',
      'replyCount': 3,
      'latestReplies': [projectThreadReply(reply(3))],
    });
    Map<String, dynamic> legacy(int seq) =>
        frame(seq)..remove('syncCoreReplyWindow');
    consume(sync, legacy(9));
    final late = consume(sync, legacy(8));
    expect(
      (late.summary!['latestReplies'] as List).map((dynamic r) => r['seq']),
      [3, 8, 9],
    );
    final replay = consume(sync, legacy(3));
    expect(replay.summary!['replyCount'], 9);
    final countOnly = consume(sync, {
      'parentMessageId': 'parent',
      'threadChannelId': 'thread',
      'replyCount': 10,
    });
    expect(countOnly.kind, 'legacy');
    expect(countOnly.summary!['replyCount'], 10);
  });
  test(
    'system replies advance count and snapshot seam without entering preview',
    () {
      final sync = ThreadRepliesSync();
      final p = frame(10);
      p['latestReply'] = reply(10, sender: 'system');
      final result = consume(sync, p);
      expect(result.summary!['replyCount'], 10);
      expect(result.summary!['latestReplies'], isEmpty);
      final projected = projectThreadReply({
        ...reply(11),
        'apiKey': 'synthetic-test-key',
      });
      expect(projected!.containsKey('apiKey'), false);
    },
  );
}
