import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_cache.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

Map<String, dynamic> _row(String id, String channel, int seq) => {
  'id': id,
  'channelId': channel,
  'seq': '$seq',
  'content': id,
  'senderType': 'user',
  'senderId': 'alice',
  'senderName': 'Alice',
  'createdAt': '2026-10-17T00:00:00.000Z',
};
RaftChannel _channel(String id, {bool dm = false, bool pending = false}) =>
    RaftChannel({
      'id': id,
      'name': id,
      'type': dm ? 'dm' : 'private',
      'joined': !pending,
      if (pending) 'pendingDm': true,
    });

class _Trace {
  bool active = false;
  final events = <Map<String, dynamic>>[];
  void add(String event, [Map<String, dynamic> facts = const {}]) {
    if (active) events.add({'event': event, ...facts});
  }
}

class _Cache implements WorkspaceCache {
  _Cache(this.trace);
  final _Trace trace;
  final records = <(String, String), dynamic>{};
  @override
  Future<dynamic> read(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
  ) async {
    trace.add('cache.read', {'kind': kind, 'id': id});
    return records[(kind, id)];
  }

  @override
  Future<void> write(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
    dynamic value,
  ) async {
    trace.add('cache.write', {'kind': kind, 'id': id});
    records[(kind, id)] = value;
  }

  @override
  Future<void> revokeChannel(String o, String p, String s, String id) async {
    trace.add('cache.revokeChannel', {'id': id});
  }

  @override
  Future<void> revokeServer(String o, String p, String s) async {}
  @override
  Future<void> clearAccount(String o, String p) async {}
  @override
  Future<List<Map<String, dynamic>>> readTranslations(
    String o,
    String p,
    String s,
  ) async => [];
  @override
  Future<void> writeTranslations(
    String o,
    String p,
    String s,
    List<Map<String, dynamic>> entries,
  ) async {}
  @override
  Future<void> close() async {}
}

class _Client extends RaftClient {
  _Client(this.trace)
    : super(
        origin: 'https://notification-contract.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'name': 'alice', 'displayName': 'Alice'});
    selectServer('server');
  }
  final _Trace trace;
  final bus = StreamController<RaftEvent>.broadcast(sync: true);
  final sendEntered = Completer<void>();
  final receipt =
      Completer<({RaftMessage message, Map<String, dynamic> receipt})>();
  Future<void>? closing;
  @override
  Stream<RaftEvent> get events => bus.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) => trace.add('join', {'id': id});
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    trace.add('api.get', {'path': path});
    if (path.startsWith('/messages/channel/')) {
      final id = path.split('/').last;
      return {
        'messages': [_row('$id-row', id, 10)],
        'hasMore': false,
        'threadSummariesByParentMessageId': <String, dynamic>{},
      };
    }
    if (path.startsWith('/messages/context/')) {
      final id = path.split('/').last, channel = query!['channelId'] as String;
      return {
        'messages': [_row(id, channel, 44)],
        'targetMessageId': id,
        'hasOlder': false,
        'hasNewer': true,
        'threadSummariesByParentMessageId': <String, dynamic>{},
      };
    }
    if (path == '/channels/c1/threads/parent') {
      return {'threadChannelId': 'thread', 'replyCount': 1};
    }
    if (path.startsWith('/tasks/channel/')) return {'tasks': <dynamic>[]};
    if (path == '/feature-flags/evaluate') return {'evaluations': []};
    if (path == '/channels/unread') return {'channels': <dynamic>[]};
    if (path == '/channels') return <dynamic>[];
    throw StateError('Unexpected fixture GET $path');
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    trace.add('api.post', {'path': path});
    if (path.endsWith('/read')) return <String, dynamic>{};
    throw StateError('Unexpected fixture POST $path');
  }

  @override
  Future<({RaftMessage message, Map<String, dynamic> receipt})> sendWithReceipt(
    String channelId,
    String content, {
    List<String>? attachments,
    List<Map<String, dynamic>>? mentions,
    String? randomId,
    bool asTask = false,
    String? timezone,
  }) {
    trace.add('api.send', {'channel': channelId, 'randomId': randomId});
    sendEntered.complete();
    return receipt.future;
  }

  @override
  Future<void> dispose() => closing ??= _close();
  Future<void> _close() async {
    await bus.close();
    await super.dispose();
  }
}

class _Fixture {
  _Fixture() {
    client = _Client(trace);
    cache = _Cache(trace);
    w = WorkspaceController(client, cache: cache, ownsClient: false)
      ..server = RaftRecord({'id': 'server', 'slug': 'demo', 'role': 'owner'})
      ..servers = [
        RaftRecord({'id': 'server', 'slug': 'demo', 'role': 'owner'}),
      ]
      ..channels = [_channel('c1'), _channel('c2')];
    w.channel = w.channels.first;
    w.ledger.switchServer('server');
    w.ledger.ingest([
      _row('parent', 'c1', 1),
    ], expectedGeneration: w.ledger.generation);
    w.visibleIds['c1'] = {'parent'};
    w.bindNavigation();
    w.addListener(() => trace.add('notify', _state()));
    addTearDown(() async {
      trace.active = false;
      w.dispose();
      await client.dispose();
    });
  }
  final trace = _Trace();
  late final _Client client;
  late final _Cache cache;
  late final WorkspaceController w;
  Map<String, dynamic> _state() => {
    'channel': w.channel?.id,
    'thread': w.threadChannelId,
    'parent': w.threadIdentity?.parentMessageId,
    'loading': w.channelLoading,
    'threadLoading': w.threadLoading,
    'resolving': w.threadResolutionLoading,
    'parentLoading': w.threadParentLoading,
    'newer': w.hasNewer,
    'highlight': w.highlightedMessageId,
    'unread': {
      for (final id in w.unread.keys.toList()..sort()) id: w.unread[id],
    },
    'uri': w.navigation.location.uri.toString(),
    'draftScopes': w.composer.drafts.keys.toList()..sort(),
    'channels': w.channels.map((row) => row.id).toList(),
    'dms': w.dms.map((row) => row.id).toList(),
    'holds': {
      for (final id in w.shareHolds.keys.toList()..sort()) id: w.shareHolds[id],
    },
    'timeline': w.timeline().map((m) => m.id).toList(),
    'messages': w.messages.map((m) => m.id).toList(),
    'replies': w.replies.map((m) => m.id).toList(),
    'error': w.error,
  };
  Future<void> start() async {
    await w.flushCache();
    trace.active = true;
    trace.add('start', _state());
  }

  Future<void> finish(String scenario) async {
    await w.flushCache();
    // Drain only already-scheduled completed I/O; no polling or wall-clock waits.
    await Future<void>.value();
    await w.flushCache();
    trace.add('end', _state());
    trace.active = false;
    final frozen = jsonDecode(
      File('test/fixtures/controller_refactor/notification_order.json')
          .readAsStringSync(),
    ) as Map;
    expect(
      trace.events.where((event) => event['event'] == 'notify').length,
      frozen['expectedNotifications'][scenario],
      reason: '$scenario notification count',
    );
    expect(
      trace.events,
      frozen['scenarios'][scenario],
      reason:
          '$scenario exact ordered notifications, states, requests and saves',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'N01 select channel: notifications bracket reads and saved selection',
    () async {
      final f = _Fixture(), w = f.w;
      w.unread = {'c2': 3};
      w.mentions = {'c2'};
      await f.start();
      await w.selectChannel(w.channels.last);
      expect(w.messages.map((m) => m.id), ['c2-row']);
      expect(w.channelLoading, isFalse);
      expect(w.error, isNull);
      expect(w.unread['c2'], 0);
      await f.finish('select-channel');
    },
  );
  test(
    'N02 jump to message: context flags and notifications keep order',
    () async {
      final f = _Fixture(), w = f.w;
      await f.start();
      await w.jumpToMessage('c2', 'target');
      expect(w.messages.map((m) => m.id), ['target']);
      expect(w.highlightedMessageId, 'target');
      expect(w.hasNewer, isTrue);
      expect(w.error, isNull);
      await f.finish('jump-message');
    },
  );
  test(
    'N03 thread open and close: resolving, reply and retirement notifications',
    () async {
      final f = _Fixture(), w = f.w;
      final parent = w.messages.single;
      await f.start();
      await w.openThread(parent);
      expect(w.threadChannelId, 'thread');
      expect(w.replies.map((m) => m.id), ['thread-row']);
      expect(w.threadResolutionError, isNull);
      w.closeThread();
      expect(w.threadIdentity, isNull);
      await f.finish('thread-open-close');
    },
  );
  test(
    'N04 prefetch: ordered task/page work emits no workspace notification',
    () async {
      final f = _Fixture(), w = f.w;
      w.unread = {'c2': 3};
      await f.start();
      await w.prefetchLikelyChannels();
      expect(w.messageWindows.accepted['c2'], isNotNull);
      expect(w.channel?.id, 'c1');
      expect(w.unread['c2'], 3);
      expect(f.trace.events.where((e) => e['event'] == 'notify'), isEmpty);
      await f.finish('prefetch');
    },
  );
  test(
    'N05 pending DM adoption: draft, row, notification then selection',
    () async {
      final f = _Fixture(), w = f.w;
      final pending = WorkspaceController.pendingDm(
        key: 'peer',
        serverId: 'server',
        name: 'Peer',
      );
      final real = _channel('dm-peer', dm: true);
      w.channel = pending;
      w.saveDraft('kept draft');
      w.holdShared(pending.id);
      await f.start();
      await w.adoptResolvedDm(pending.id, real);
      expect(w.channel?.id, real.id);
      expect(w.drafts[real.id], 'kept draft');
      expect(w.shareHolds.containsKey(real.id), isTrue);
      expect(w.dms.map((c) => c.id), [real.id]);
      expect(w.error, isNull);
      await f.finish('adopt-dm');
    },
  );
  test(
    'N06 send delivery: pending and accepted projections notify in order',
    () async {
      final f = _Fixture(), w = f.w;
      await f.start();
      final sending = w.send('sent', randomId: 'fixed-send');
      await f.client.sendEntered.future;
      f.trace.add('complete-receipt');
      f.client.receipt.complete((
        message: RaftMessage({
          ..._row('accepted-send', 'c1', 50),
          'content': 'sent',
          'randomId': 'fixed-send',
        }),
        receipt: <String, dynamic>{},
      ));
      expect(await sending, isTrue);
      expect(w.timeline().map((m) => m.id), contains('accepted-send'));
      expect(w.error, isNull);
      await f.finish('send-projection');
    },
  );
  test(
    'N07 borrowed selection keeps source-only notification routing',
    () async {
      final f = _Fixture(), w = f.w;
      final borrowed = WorkspaceController(
        f.client,
        presentationSource: w,
        ownsClient: false,
      );
      addTearDown(borrowed.dispose);
      var borrowedNotifications = 0;
      borrowed.addListener(() => borrowedNotifications++);
      await f.start();
      await borrowed.selectChannel(w.channels.last, autoRead: false);
      expect(w.channel?.id, 'c2');
      expect(borrowedNotifications, 0);
      await f.finish('borrowed-select');
    },
  );
}
