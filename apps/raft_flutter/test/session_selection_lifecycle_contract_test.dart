import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/followed_threads_store.dart';
import 'package:raft_flutter/data/message_translation_store.dart';
import 'package:raft_flutter/data/source_activity_unread_store.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';

import 'app_global_server_selector_test.dart' show RootCache;

class _Client extends RaftClient {
  _Client(this.trace)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s1');
  }
  final List<String> trace;
  final pending = <Completer<List<RaftChannel>>>[];
  bool holdNetwork = false;
  int connects = 0;
  void Function()? beforeChannels;
  @override
  void selectServer(String? id) {
    trace.add('client:$id');
    super.selectServer(id);
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => {};
  @override
  Future<List<RaftChannel>> channels({bool dm = false}) {
    beforeChannels?.call();
    trace.add('http:$serverId:$dm');
    if (!holdNetwork) return Future.value([]);
    final gate = Completer<List<RaftChannel>>();
    pending.add(gate);
    return gate.future;
  }

  @override
  void connect() {
    connects++;
    trace.add('connect');
  }
}

class _Cache extends RootCache {
  _Cache(this.trace);
  final List<String> trace;
  @override
  Future<dynamic> read(String o, String p, String s, String kind, String id) {
    trace.add('cache:$s:$kind');
    return super.read(o, p, s, kind, id);
  }
}

class _Directory extends WorkspaceEntityDirectory {
  _Directory(this.trace, this.client)
    : super(scope: () => null, query: (_) async => []);
  final List<String> trace;
  final _Client client;
  final gates = <String, Completer<void>>{};
  @override
  bool synchronize() {
    trace.add('entities:sync');
    return false;
  }

  @override
  Future<void> get restored {
    trace.add('entities:restore');
    return gates[client.serverId]?.future ?? Future.value();
  }

  @override
  Future<void> preload() {
    trace.add('entities:preload');
    return Future.value();
  }
}

class _Following extends FollowedThreadsStore {
  _Following(this.trace)
    : super(
        scope: () => null,
        query: (_) async => {},
        command: (_, _) async => {},
      );
  final List<String> trace;
  @override
  void start() {
    trace.add('following');
  }
}

class _Translations extends MessageTranslationStore {
  _Translations(super.w, this.trace);
  final List<String> trace;
  final gates = <String, Completer<void>>{};
  @override
  Future<void> restore() {
    trace.add('translations:restore');
    return gates[w.client.serverId]?.future ?? Future.value();
  }
}

class _Activity extends SourceActivityUnreadStore {
  _Activity(super.workspace, this.trace);
  final List<String> trace;
  @override
  void start() {
    trace.add('activity');
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(
    super.client,
    this.trace, {
    required super.cache,
    required super.entityDirectory,
    required super.followedThreads,
    super.presentationSource,
    bool owns = true,
  }) : super(ownsClient: owns);
  final List<String> trace;
  _Activity? activity;
  _Translations? translating;
  @override
  SourceActivityUnreadStore get activityUnread =>
      activity ??= _Activity(this, trace);
  @override
  _Translations get translations => translating ??= _Translations(this, trace);
  @override
  Future<void> refreshMessageSyncFlag() {
    trace.add('flags');
    expect(messageDomain.ledger.messages('old'), isEmpty);
    expect(composer.drafts, isEmpty);
    return Future.value();
  }

  @override
  Future<void> loadSidebar() {
    trace.add('sidebar');
    return Future.value();
  }

  @override
  Future<void> refreshUnread() async {}
  @override
  void notifyListeners() {
    trace.add('notify');
    super.notifyListeners();
  }

  @override
  void dispose() {
    activity?.dispose();
    translating?.dispose();
    super.dispose();
  }
}

class _Fixture {
  _Fixture() {
    client = _Client(trace);
    cache = _Cache(trace);
    addTearDown(() async {
      for (final w in pages) {
        for (final c in directories[w]!.gates.values) {
          if (!c.isCompleted) c.complete();
        }
        for (final c in w.translating?.gates.values ?? <Completer<void>>[]) {
          if (!c.isCompleted) c.complete();
        }
      }
      for (final c in client.pending) {
        if (!c.isCompleted) c.complete([]);
      }
      for (final w in pages.reversed) {
        await w.flushCache();
        w.dispose();
        directories[w]!.dispose();
        following[w]!.dispose();
      }
      await client.dispose();
    });
  }
  final trace = <String>[];
  late final _Client client;
  late final _Cache cache;
  final pages = <_Workspace>[];
  final directories = <_Workspace, _Directory>{};
  final following = <_Workspace, _Following>{};
  _Workspace make({bool owns = true, WorkspaceController? source}) {
    final directory = _Directory(trace, client), followed = _Following(trace);
    final w = _Workspace(
      client,
      trace,
      cache: cache,
      entityDirectory: directory,
      followedThreads: followed,
      presentationSource: source,
      owns: owns,
    )..server = RaftRecord({'id': 's1', 'role': 'owner'});
    directories[w] = directory;
    following[w] = followed;
    pages.add(w);
    return w;
  }
}

RaftRecord _server(String id) => RaftRecord({'id': id, 'role': 'owner'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('selection starts domains synchronously before reset, flags and first device read', () async {
    final f = _Fixture(), w = f.make();
    expect(f.trace, [
      'client:s1',
    ], reason: 'construction does not start domain work');
    w.messageDomain.ledger.switchServer('s1');
    w.messageDomain.ledger.ingest([
      {'id': 'old-message', 'channelId': 'old', 'seq': '1'},
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.composer.drafts['old'] = 'old draft';
    f.trace.clear();
    final selecting = w.selectServer(_server('s2'));
    expect(f.trace, [
      'client:s2',
      'activity',
      'entities:sync',
      'entities:restore',
      'translations:restore',
      'entities:preload',
      'following',
      'flags',
      'sidebar',
      'notify',
    ]);
    expect(w.messageDomain.ledger.serverId, 's2');
    await selecting;
    expect(
      f.trace.indexOf('cache:s2:channels'),
      greaterThan(f.trace.indexOf('notify')),
    );
    expect(f.client.connects, 1);
  });

  test(
    'cached hydration awaits both restorations and precedes fresh HTTP',
    () async {
      final f = _Fixture(), w = f.make();
      final entities = Completer<void>(), translations = Completer<void>();
      f.directories[w]!.gates['s2'] = entities;
      w.translations.gates['s2'] = translations;
      await f.cache.write(f.client.origin, 'alice', 's2', 'channels', '', {
        'channels': [
          {'id': 'cached', 'joined': false},
        ],
        'dms': [],
      });
      await f.cache.write(f.client.origin, 'alice', 's2', 'unread', '', {
        'cached': 2,
      });
      final hydrated = Completer<void>(), http = Completer<void>();
      var calls = 0, misses = 0;
      f.client.holdNetwork = true;
      f.client.beforeChannels = () {
        expect(entities.isCompleted && translations.isCompleted, isTrue);
        expect(hydrated.isCompleted, isTrue);
        if (!http.isCompleted) http.complete();
      };
      final selecting = w.selectServer(
        _server('s2'),
        onHydrated: () {
          calls++;
          expect(w.channels.single.id, 'cached');
          expect(w.unread, {'cached': 2});
          hydrated.complete();
        },
        onCacheMiss: () => misses++,
      );
      translations.complete();
      entities.complete();
      await http.future.timeout(const Duration(seconds: 5));
      expect(calls, 1);
      expect(misses, 0);
      expect(f.client.connects, 0);
      for (final gate in f.client.pending) {
        gate.complete([]);
      }
      await selecting;
      expect(f.client.connects, 1);
    },
  );

  test('cache miss callback stays ahead of fresh channel reads', () async {
    final f = _Fixture(), w = f.make();
    var misses = 0, hydrated = 0;
    f.client.beforeChannels = () {
      expect(misses, 1);
      expect(hydrated, 0);
    };
    await w.selectServer(
      _server('s2'),
      onHydrated: () => hydrated++,
      onCacheMiss: () => misses++,
    );
    expect(misses, 1);
  });

  test(
    'late A restoration cannot publish or connect after B selection',
    () async {
      final f = _Fixture(), w = f.make();
      final entities = Completer<void>();
      f.directories[w]!.gates['a'] = entities;
      var oldHydrated = 0, oldMiss = 0;
      final a = w.selectServer(
        _server('a'),
        onHydrated: () => oldHydrated++,
        onCacheMiss: () => oldMiss++,
      );
      await w.selectServer(_server('b'));
      entities.complete();
      await a;
      expect(w.server?.id, 'b');
      expect(w.messageDomain.ledger.serverId, 'b');
      expect(f.trace.where((s) => s.startsWith('http:a:')), isEmpty);
      expect(oldHydrated + oldMiss, 0);
      expect(f.client.connects, 1);
    },
  );

  test('sign-out during restoration rejects the old continuation', () async {
    final f = _Fixture(), w = f.make();
    final entities = Completer<void>();
    f.directories[w]!.gates['s2'] = entities;
    final selecting = w.selectServer(_server('s2'));
    f.client.user = null;
    f.client.selectServer(null);
    entities.complete();
    await selecting;
    expect(f.trace.where((s) => s.startsWith('http:')), isEmpty);
    expect(f.client.connects, 0);
  });

  test('independent borrowed editor cannot start server selection', () async {
    final f = _Fixture(), w = f.make(owns: false);
    f.trace.clear();
    await expectLater(w.selectServer(_server('s2')), throwsStateError);
    expect(f.trace, isEmpty);
  });

  test(
    'source presentation forwards callbacks and starts domains only once',
    () async {
      final f = _Fixture(),
          root = f.make(),
          borrowed = f.make(owns: false, source: root);
      f.trace.clear();
      var misses = 0;
      await borrowed.selectServer(_server('s2'), onCacheMiss: () => misses++);
      expect(f.trace.where((s) => s == 'client:s2'), hasLength(1));
      expect(f.trace.where((s) => s == 'activity'), hasLength(1));
      expect(borrowed.activity, isNull);
      expect(borrowed.translating, isNull);
      expect(misses, 1);
      expect(f.client.connects, 1);
    },
  );

  test('revoked server is rejected before any selection startup', () async {
    final f = _Fixture(), w = f.make();
    w.revokeServer('s2');
    f.trace.clear();
    await w.selectServer(_server('s2'));
    expect(f.trace, isEmpty);
    expect(f.client.serverId, 's1');
  });
}
