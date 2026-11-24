import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/message_gap_sync.dart';
import 'package:raft_flutter/data/read_receipts.dart';
import 'package:raft_flutter/data/workspace_cache.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_message_windows.dart';
import 'package:raft_flutter/features/agent_read_badge.dart';

Map<String, dynamic> _row(String channel, int seq, {String? content}) => {
  'id': '$channel-$seq',
  'channelId': channel,
  'seq': '$seq',
  'content': content ?? '$channel row $seq',
  'senderId': 'bob',
  'senderType': 'user',
  'createdAt': '2026-10-20T00:00:00Z',
};

class _SpyCache implements WorkspaceCache {
  final writes = <(String, String)>[];

  @override
  Future<dynamic> read(o, p, s, String kind, String id) async => null;

  @override
  Future<void> write(o, p, s, String kind, String id, value) async {
    writes.add((kind, id));
  }

  @override
  Future<void> revokeChannel(o, p, s, String id) async {}

  @override
  Future<void> revokeServer(o, p, s) async {}

  @override
  Future<void> clearAccount(o, p) async {}

  @override
  Future<List<Map<String, dynamic>>> readTranslations(o, p, s) async => [];

  @override
  Future<void> writeTranslations(o, p, s, entries) async {}

  @override
  Future<void> close() async {}
}

class _CountingMap extends MapBase<String, dynamic> {
  _CountingMap(this.backing);
  final Map<String, dynamic> backing;
  bool enabled = false;
  int reads = 0;

  @override
  dynamic operator [](Object? key) {
    if (enabled && key == 'channelCapabilities') reads++;
    return backing[key];
  }

  @override
  Iterable<String> get keys => backing.keys;

  @override
  void operator []=(String key, dynamic value) =>
      throw UnsupportedError('Read-only fixture');

  @override
  void clear() => throw UnsupportedError('Read-only fixture');

  @override
  dynamic remove(Object? key) => throw UnsupportedError('Read-only fixture');
}

class _CountingChannel extends RaftChannel {
  _CountingChannel(String id)
    : super({'id': id, 'type': 'private', 'joined': true}) {
    counted = _CountingMap(super.json);
  }
  late final _CountingMap counted;

  @override
  Map<String, dynamic> get json => counted;
}

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://perf-pr-b-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
    selectServer('s');
  }

  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final posts = <String>[];
  final details = <String, dynamic>{};
  List<Map<String, dynamic>> syncMessages = [];

  @override
  Stream<RaftEvent> get events => stream.stream;

  void emit(String name, dynamic payload) =>
      stream.add(RaftEvent(name, payload));

  @override
  void connect() {}

  @override
  void joinChannel(String id) {}

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/channels') {
      return [
        {'id': 'c1', 'name': 'general', 'type': 'channel', 'joined': true},
      ];
    }
    if (path == '/messages/sync') {
      return syncMessages;
    }
    if (path.startsWith('/channels/') && path.length > 10) {
      final id = path.substring(10);
      if (details.containsKey(id)) return details[id];
    }
    if (path == '/servers/s/machines') return {'machines': <dynamic>[]};
    return <dynamic>[];
  }

  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async => {
    'messages': [_row(id, 1), _row(id, 2)],
    'threadSummariesByParentMessageId': {},
  };

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    posts.add(path);
    if (path.endsWith('/read')) {
      return {'maxReadSeq': 100, 'readStateVersion': 1};
    }
    return {};
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  testWidgets(
    'non-workspace socket events emit 0 WorkspaceController notifies and 0 shell rebuilds',
    (tester) async {
      final client = _Client();
      final cache = _SpyCache();
      final w = WorkspaceController(client, cache: cache)
        ..server = RaftRecord({'id': 's', 'role': 'owner'})
        ..channels = [
          RaftChannel({
            'id': 'c1',
            'name': 'general',
            'type': 'channel',
            'joined': true,
          }),
        ];
      w.messageDomain.ledger.switchServer('s');
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
        w.dispose();
        await client.stream.close();
      });

      var shellBuilds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: w,
              builder: (context, _) {
                shellBuilds++;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final baselineShellBuilds = shellBuilds;

      var workspaceNotifies = 0;
      w.addListener(() => workspaceNotifies++);

      client.emit('agent:typing', {'agentId': 'ada', 'channelId': 'c1'});
      client.emit('read_progress:updated', {'scopeId': 'c1', 'peers': []});
      client.emit('scope_read:updated', {
        'scopeId': 'c1',
        'peerKind': 'agent',
        'peerId': 'ada',
        'maxReadSeq': 10,
      });
      client.emit('activity:changed', {'serverId': 's'});
      client.emit('sync:changed', {'serverId': 's'});
      client.emit('task:updated', {'id': 't1', 'channelId': 'c1'});
      client.emit('agent:seen', {
        'agentId': 'ada',
        'lastSeenAt': '2026-10-20T00:00:00Z',
      });
      client.emit('daemon:status', {'status': 'ok'});
      client.emit('server:member-added', {'serverId': 's', 'userId': 'bob'});
      client.emit('read_state:updated', {'serverId': 'other', 'scopeId': 'c1'});
      await tester.pumpAndSettle();

      expect(
        workspaceNotifies,
        0,
        reason:
            'Measured workspaceNotifies=$workspaceNotifies for 10 non-workspace socket events.',
      );
      expect(
        shellBuilds - baselineShellBuilds,
        0,
        reason:
            'Measured shellRebuilds=${shellBuilds - baselineShellBuilds} for 10 non-workspace socket events.',
      );
    },
  );

  test('ReadReceipts updates do not double-fire WorkspaceController', () async {
    final client = _Client();
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'})
      ..channels = [
        RaftChannel({
          'id': 'c1',
          'name': 'general',
          'type': 'channel',
          'joined': true,
        }),
      ];
    addTearDown(() async {
      w.dispose();
      await client.stream.close();
    });

    client.details['c1'] = {
      'peerReadStates': [
        {'peerKind': 'agent', 'peerId': 'ada', 'maxReadSeq': 3},
      ],
    };
    watchReadFrontiers(w, 'c1');
    await _settle();

    var workspaceNotifies = 0;
    var receiptNotifies = 0;
    w.addListener(() => workspaceNotifies++);
    w.readReceipts.addListener(() => receiptNotifies++);

    client.emit('scope_read:updated', {
      'scopeId': 'c1',
      'peerKind': 'agent',
      'peerId': 'ada',
      'maxReadSeq': 12,
    });
    await _settle();

    expect(
      projectAgentReadReceipt(w.readReceipts.scope('c1'), 'ada', 10),
      isTrue,
    );
    expect(receiptNotifies, 1);
    expect(
      workspaceNotifies,
      0,
      reason:
          'Measured workspaceNotifies=$workspaceNotifies on scope_read:updated.',
    );
  });

  test('non-ledger workspace notifications do not sweep cached conversation windows', () async {
    final client = _Client();
    final channels = [
      _CountingChannel('alpha'),
      for (var i = 0; i < 50; i++) _CountingChannel('cached-$i'),
    ];
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'})
      ..channels = channels;
    addTearDown(() async {
      w.dispose();
      await client.stream.close();
    });

    w.messageDomain.ledger.switchServer('s');
    for (final channel in channels) {
      w.messageWindows.acceptRows(liveWindowWrite, channel.id, [
        _row(channel.id, 1),
        _row(channel.id, 2),
      ], replace: true);
    }
    await w.selectChannel(channels.first, autoRead: false, navigate: false);
    for (final channel in channels.skip(1)) {
      expect(w.messageWindows.channel(channel.id), isNotNull);
    }
    // Initial synchronize after opening all 51 windows.
    w.notifyListeners();

    for (final channel in channels.skip(1)) {
      channel.counted
        ..reads = 0
        ..enabled = true;
    }

    // Emit a non-ledger notification and direct notifyListeners with unchanged ledger.
    client.emit('pinned:updated', {});
    await _settle();
    w.notifyListeners();

    final unrelatedReads = channels
        .skip(1)
        .fold<int>(0, (sum, channel) => sum + channel.counted.reads);
    expect(
      unrelatedReads,
      0,
      reason:
          'Measured unrelatedReads=$unrelatedReads across 50 cached windows.',
    );

    // Positive check: channel revocation still retires the affected window.
    final cached0 = w.messageWindows.channel('cached-0')!;
    client.emit('channel:removed', {'channelId': 'cached-0'});
    expect(cached0.retired, isTrue);
  });

  test('no-op MessageGapSync short-circuits without notify, markRead, or window save', () async {
    final client = _Client();
    final cache = _SpyCache();
    final w = WorkspaceController(client, cache: cache)
      ..server = RaftRecord({'id': 's', 'role': 'owner'})
      ..channels = [
        RaftChannel({
          'id': 'alpha',
          'name': 'alpha',
          'type': 'private',
          'joined': true,
        }),
      ];
    addTearDown(() async {
      w.dispose();
      await client.stream.close();
    });

    w.messageDomain.ledger.switchServer('s');
    w.messageWindows.acceptRows(liveWindowWrite, 'alpha', [
      _row('alpha', 1),
      _row('alpha', 2),
    ], replace: true);
    await w.selectChannel(w.channels.first, autoRead: false, navigate: false);
    await _settle();

    cache.writes.clear();
    client.posts.clear();
    var workspaceNotifies = 0;
    w.addListener(() => workspaceNotifies++);

    client.syncMessages = [_row('alpha', 1), _row('alpha', 2)];
    final ok = await MessageGapSync.run(w.messageDomain, 'alpha');
    await _settle();

    expect(ok, isTrue);
    final windowWrites = cache.writes.where((e) => e.$1 == 'window').length;
    final readPosts = client.posts.where((p) => p.endsWith('/read')).length;
    expect(
      workspaceNotifies,
      0,
      reason:
          'Measured workspaceNotifies=$workspaceNotifies on no-op gap sync.',
    );
    expect(
      windowWrites,
      0,
      reason: 'Measured windowWrites=$windowWrites on no-op gap sync.',
    );
    expect(
      readPosts,
      0,
      reason: 'Measured readPosts=$readPosts on no-op gap sync.',
    );

    // Positive check: when /messages/sync returns a new message, it ingests and notifies.
    client.syncMessages = [
      _row('alpha', 1),
      _row('alpha', 2),
      _row('alpha', 3),
    ];
    final syncedNew = await MessageGapSync.run(w.messageDomain, 'alpha');
    await _settle();
    expect(syncedNew, isTrue);
    expect(w.messageDomain.messages.last.id, 'alpha-3');
    expect(workspaceNotifies, greaterThan(0));
    expect(cache.writes.where((e) => e.$1 == 'window').length, greaterThan(0));
  });

  test('unaccepted read_state:updated performs 0 disk writes and 0 workspace notifies', () async {
    final client = _Client();
    final cache = _SpyCache();
    final w = WorkspaceController(client, cache: cache)
      ..server = RaftRecord({'id': 's', 'role': 'owner'})
      ..channels = [
        RaftChannel({
          'id': 'c1',
          'name': 'general',
          'type': 'channel',
          'joined': true,
        }),
      ];
    addTearDown(() async {
      w.dispose();
      await client.stream.close();
    });

    // Positive case: accepted newer read_state:updated persists and notifies.
    var workspaceNotifies = 0;
    w.addListener(() => workspaceNotifies++);
    client.emit('read_state:updated', {
      'serverId': 's',
      'scopeId': 'c1',
      'maxReadSeq': 10,
      'readStateVersion': 5,
    });
    await _settle();
    expect(workspaceNotifies, 1);
    expect(
      cache.writes.where((e) => e.$1 == 'read-frontiers' || e.$1 == 'unread'),
      isNotEmpty,
    );

    // Reset and emit stale + foreign read_state:updated events.
    workspaceNotifies = 0;
    cache.writes.clear();
    client.emit('read_state:updated', {
      'serverId': 's',
      'scopeId': 'c1',
      'maxReadSeq': 5,
      'readStateVersion': 4,
    });
    client.emit('read_state:updated', {
      'serverId': 'other',
      'scopeId': 'c1',
      'maxReadSeq': 99,
      'readStateVersion': 99,
    });
    await _settle();

    expect(
      cache.writes.length,
      0,
      reason:
          'Measured cacheWrites=${cache.writes.length} on unaccepted read_state:updated.',
    );
    expect(
      workspaceNotifies,
      0,
      reason:
          'Measured workspaceNotifies=$workspaceNotifies on unaccepted read_state:updated.',
    );
  });
}
