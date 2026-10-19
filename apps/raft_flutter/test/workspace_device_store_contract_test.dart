import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_cache.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';

typedef _Key = (String, String, String, String, String);

class _Cache implements WorkspaceCache {
  final records = <_Key, dynamic>{};
  final trace = <String>[];
  final started = Completer<void>();
  Completer<void>? block;
  bool failNextWrite = false;
  int translationReads = 0, translationWrites = 0, closeCalls = 0;

  @override
  Future<dynamic> read(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
  ) async {
    trace.add('read:$kind');
    return records[(origin, principal, server, kind, id)];
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
    final gate = block;
    block = null;
    trace.add('start:$kind');
    if (gate != null) {
      started.complete();
      await gate.future;
    }
    if (failNextWrite) {
      failNextWrite = false;
      trace.add('fail:$kind');
      throw StateError('Fixture device write failed');
    }
    records[(origin, principal, server, kind, id)] = value;
    trace.add('done:$kind');
  }

  @override
  Future<void> revokeChannel(
    String origin,
    String principal,
    String server,
    String channel,
  ) async {}
  @override
  Future<void> revokeServer(
    String origin,
    String principal,
    String server,
  ) async {
    trace.add('revoke:$principal:$server');
    records.removeWhere(
      (k, _) => k.$1 == origin && k.$2 == principal && k.$3 == server,
    );
  }

  @override
  Future<void> clearAccount(String origin, String principal) async {
    records.removeWhere((k, _) => k.$1 == origin && k.$2 == principal);
  }

  @override
  Future<List<Map<String, dynamic>>> readTranslations(
    String origin,
    String principal,
    String server,
  ) async {
    translationReads++;
    return const [];
  }

  @override
  Future<void> writeTranslations(
    String origin,
    String principal,
    String server,
    List<Map<String, dynamic>> entries,
  ) async {
    translationWrites++;
  }

  @override
  Future<void> close() async {
    closeCalls++;
  }
}

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => [];
}

class _Fixture {
  _Fixture() {
    client.user = RaftRecord({'id': 'alice'});
    client.selectServer('server');
    // Keep this test focused on device ordering; directory refresh has its
    // own real-cache and restart suites, which run unchanged with this one.
    directory = WorkspaceEntityDirectory(
      scope: () => null,
      query: (_) async => [],
      events: const Stream<RaftEvent>.empty(),
    );
    w =
        WorkspaceController(
            client,
            cache: cache,
            ownsClient: false,
            entityDirectory: directory,
          )
          ..server = RaftRecord({'id': 'server', 'role': 'owner'})
          ..channel = RaftChannel({'id': 'channel', 'joined': true});
    w.channels = [w.channel!];
    w.messageDomain.ledger.switchServer('server');
    addTearDown(() async {
      if (!release.isCompleted) release.complete();
      await w.flushCache();
      w.dispose();
      directory.dispose();
      await client.dispose();
    });
  }

  final cache = _Cache();
  final client = _Client();
  final release = Completer<void>();
  late final WorkspaceController w;
  late final WorkspaceEntityDirectory directory;

  Future<void> startBlockedWrite() async {
    cache.block = release;
    w.saveTranslationGate('server', {'enabled': true, 'revision': 1});
    await cache.started.future.timeout(const Duration(seconds: 5));
  }

  dynamic gate(String principal, String server) =>
      cache.records[(
        client.origin,
        principal,
        server,
        'translation-settings',
        '',
      )];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'ordered reads observe their preceding write and later writes stay FIFO',
    () async {
      final f = _Fixture();
      await f.startBlockedWrite();
      final reading = f.w.readTranslationGate('server');
      f.w.saveTranslationGate('server', {'enabled': false, 'revision': 2});
      await pumpEventQueue();
      expect(f.cache.trace, ['start:translation-settings']);

      f.release.complete();
      expect(await reading, {'enabled': true, 'revision': 1});
      await f.w.flushCache();
      expect(f.cache.trace, [
        'start:translation-settings',
        'done:translation-settings',
        'read:translation-settings',
        'start:translation-settings',
        'done:translation-settings',
      ]);
      expect(f.gate('alice', 'server'), {'enabled': false, 'revision': 2});
    },
  );

  test('retirement drains accepted writes and rejects pending translation work and new writes', () async {
    final f = _Fixture();
    await f.startBlockedWrite();
    final reading = f.w.readDeviceTranslations('server');
    f.w.saveTranslationGate('server', {'enabled': false, 'revision': 2});
    f.w.writeDeviceTranslations('server', [
      {'messageId': 'm1', 'channelId': 'channel', 'translation': 'queued'},
    ]);
    var retired = false;
    final retiring = f.w.retireCache().then((_) {
      retired = true;
    });
    f.w.saveTranslationGate('server', {'revision': 3});
    f.w.writeDeviceTranslations('server', [
      {'messageId': 'm2', 'channelId': 'channel', 'translation': 'late'},
    ]);
    await pumpEventQueue();
    expect(f.w.cacheWritable, isFalse);
    expect(retired, isFalse);
    expect(f.cache.closeCalls, 0);

    f.release.complete();
    await retiring;
    expect(await reading, isEmpty);
    await f.w.flushCache();
    expect(f.gate('alice', 'server'), {'enabled': false, 'revision': 2});
    expect(
      f.cache.translationReads,
      0,
      reason: 'a read waiting on writes rechecks retirement before disk I/O',
    );
    expect(f.cache.translationWrites, 0);
    expect(f.cache.trace.where((e) => e.startsWith('start:')), hasLength(2));
    f.w.dispose();
    expect(f.cache.closeCalls, 0, reason: 'the app owns the database lifetime');
  });

  test('a failed write reports through the controller and does not poison the queue', () async {
    final f = _Fixture();
    f.cache.failNextWrite = true;
    f.w.error = 'An existing user notice';
    var notifications = 0;
    f.w.addListener(() {
      notifications++;
    });
    f.w.saveTranslationGate('server', {'revision': 1});
    f.w.saveTranslationGate('server', {'revision': 2});
    await f.w.flushCache();
    expect(f.cache.trace, [
      'start:translation-settings',
      'fail:translation-settings',
      'start:translation-settings',
      'done:translation-settings',
    ]);
    expect(f.w.error, 'An existing user notice');
    expect(notifications, 1);
    expect(f.gate('alice', 'server'), {'revision': 2});
  });

  test(
    'server purge follows accepted writes and keeps the captured old identity',
    () async {
      final f = _Fixture();
      await f.startBlockedWrite();
      f.w.revokeServer('server');
      f.w.saveTranslationGate('server', {'revision': 2});
      expect(
        f.client.serverId,
        'server',
        reason: 'this controller does not own the client selection',
      );
      expect(f.w.server, isNull);
      expect(f.cache.trace, ['start:translation-settings']);
      f.client.user = RaftRecord({'id': 'bob'});
      f.client.selectServer('another-server');
      f.release.complete();
      await f.w.flushCache();
      expect(f.cache.trace, [
        'start:translation-settings',
        'done:translation-settings',
        'revoke:alice:server',
        'start:servers',
        'done:servers',
      ]);
      expect(f.gate('alice', 'server'), isNull);
      expect(
        f.cache.records[(f.client.origin, 'alice', '', 'servers', '')],
        [],
      );
    },
  );
}
