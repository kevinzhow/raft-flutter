import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/followed_threads_store.dart';
import 'package:raft_flutter/data/panel_caches.dart';
import 'package:raft_flutter/data/source_channel_files_store.dart';
import 'package:raft_flutter/data/thread_search.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';

class _Events extends Stream<RaftEvent> {
  final controller = StreamController<RaftEvent>.broadcast(sync: true);
  int subscriptions = 0;

  @override
  StreamSubscription<RaftEvent> listen(
    void Function(RaftEvent)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    subscriptions++;
    return controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );

  final ingress = _Events();
  final reads = <String>[];
  Future<dynamic> Function(String)? read;
  int closed = 0;

  @override
  bool get signedIn => user != null;

  @override
  Stream<RaftEvent> get events => ingress;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) {
    reads.add(path);
    return read?.call(path) ?? Future<dynamic>.value({'files': <dynamic>[]});
  }

  @override
  Future<void> dispose() async {
    closed++;
    await ingress.controller.close();
    await super.dispose();
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(
    super.client, {
    WorkspaceController? source,
    super.entityDirectory,
    super.followedThreads,
  }) : super(presentationSource: source, ownsClient: false);

  final queries = <String>[];
  final commands = <String>[];
  bool closed = false;

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    queries.add(path);
    return path == FollowedThreadsStore.path
        ? {'threads': <dynamic>[]}
        : <dynamic>[];
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    commands.add('$method $path');
    return {'threadChannelId': 'thread'};
  }

  @override
  void dispose() {
    closed = true;
    super.dispose();
  }
}

class _Overrides extends _Workspace {
  _Overrides(super.client);
  late final customSearch = ThreadSearch(this);
  final customCache = ServerBoundCache<String, Object>(() => 'custom');
  final customFiles = SourceChannelFilesStore(
    channelId: 'custom',
    authority: () => 'custom',
    get: (path, {query}) async => {'files': <dynamic>[]},
  );

  @override
  ThreadSearch get threadSearch => customSearch;

  @override
  ServerBoundCache<String, Object> get agentTabCache => customCache;

  @override
  SourceChannelFilesStore channelFilesStore(String channelId) => customFiles;
}

class _Directory extends WorkspaceEntityDirectory {
  _Directory() : super(scope: () => null, query: (_) async => <dynamic>[]);
  int flushes = 0, disposals = 0;

  @override
  void flushDevice() {
    flushes++;
    super.flushDevice();
  }

  @override
  void dispose() {
    disposals++;
    super.dispose();
  }
}

class _Followed extends FollowedThreadsStore {
  _Followed()
    : super(
        scope: () => null,
        query: (_, {query}) async => {'threads': <dynamic>[]},
        command: (_, _) async => {},
      );
  int disposals = 0;

  @override
  void dispose() {
    disposals++;
    super.dispose();
  }
}

class _Fixture {
  _Fixture() {
    client.user = RaftRecord({'id': 'alice'});
    client.selectServer('s1');
    addTearDown(() async {
      for (final w in pages.reversed) {
        if (!w.closed) w.dispose();
      }
      await client.dispose();
    });
  }

  final client = _Client();
  final pages = <_Workspace>[];

  _Workspace make({
    WorkspaceController? source,
    WorkspaceEntityDirectory? directory,
    FollowedThreadsStore? followed,
  }) => adopt(
    _Workspace(
      client,
      source: source,
      entityDirectory: directory,
      followedThreads: followed,
    ),
  );

  T adopt<T extends _Workspace>(T w) {
    pages.add(w);
    w.server = RaftRecord({'id': 's1', 'role': 'owner'});
    w.channel = RaftChannel({'id': 'c1', 'joined': true});
    w.channels = [w.channel!];
    return w;
  }
}

void _alive(ChangeNotifier value) {
  void listener() {}
  value.addListener(listener);
  value.removeListener(listener);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'construction and passive service reads never start network work',
    () async {
      final f = _Fixture();
      final w = f.make();
      final subscriptions = f.client.ingress.subscriptions;
      expect(w.activityUnreadIfBound, isNull);
      expect(w.entityDirectory.started, isFalse);
      expect(w.followedThreads.started, isFalse);
      expect(identical(w.translations, w.translations), isTrue);
      expect(identical(w.threadSearch, w.threadSearch), isTrue);
      expect(identical(w.threadFollowers, w.threadFollowers), isTrue);
      expect(identical(w.announcements, w.announcements), isTrue);
      expect(identical(w.announcementGate, w.announcementGate), isTrue);
      expect(identical(w.agentTabCache, w.agentTabCache), isTrue);
      expect(identical(w.taskHistoryCache, w.taskHistoryCache), isTrue);
      expect(
        identical(w.channelFilesStore('c1'), w.channelFilesStore('c1')),
        isTrue,
      );
      expect(identical(w.activityUnread, w.activityUnread), isTrue);
      await Future<void>.value();
      expect(f.client.ingress.subscriptions, subscriptions + 2);
      expect(f.client.reads, isEmpty);
      expect(w.queries, isEmpty);
    },
  );

  test('nested presentations borrow the same session services and caches', () {
    final f = _Fixture();
    final root = f.make();
    final page = f.make(source: root);
    final nested = f.make(source: page);
    for (final w in [page, nested]) {
      expect(identical(w.translations, root.translations), isTrue);
      expect(identical(w.threadSearch, root.threadSearch), isTrue);
      expect(identical(w.threadFollowers, root.threadFollowers), isTrue);
      expect(identical(w.announcements, root.announcements), isTrue);
      expect(identical(w.announcementGate, root.announcementGate), isTrue);
      expect(identical(w.agentTabCache, root.agentTabCache), isTrue);
      expect(identical(w.taskHistoryCache, root.taskHistoryCache), isTrue);
      expect(
        identical(w.channelFilesStore('c1'), root.channelFilesStore('c1')),
        isTrue,
      );
      expect(identical(w.activityUnread, root.activityUnread), isTrue);
    }
  });

  test('default presentation directories and followed lists stay independently owned', () {
    final f = _Fixture();
    final root = f.make();
    final page = f.make(source: root);
    expect(identical(page.entityDirectory, root.entityDirectory), isFalse);
    expect(identical(page.followedThreads, root.followedThreads), isFalse);
    final directory = page.entityDirectory;
    final followed = page.followedThreads;
    page.dispose();
    expect(() => _alive(directory), throwsFlutterError);
    expect(() => _alive(followed), throwsFlutterError);
    _alive(root.entityDirectory);
    _alive(root.followedThreads);
  });

  test('injected repositories are neither flushed nor disposed by the presentation', () async {
    final f = _Fixture();
    final directory = _Directory();
    final followed = _Followed();
    addTearDown(directory.dispose);
    addTearDown(followed.dispose);
    final root = f.make();
    final page = f.make(source: root, directory: directory, followed: followed);
    expect(identical(page.entityDirectory, directory), isTrue);
    expect(identical(page.followedThreads, followed), isTrue);
    await page.flushCache();
    page.dispose();
    page.dispose();
    expect(directory.flushes, 0);
    expect(directory.disposals, 0);
    expect(followed.disposals, 0);
    _alive(directory);
    _alive(followed);
  });

  test('flush and disposal do not construct unused lazy services', () async {
    final f = _Fixture();
    final w = f.make();
    final subscriptions = f.client.ingress.subscriptions;
    final interceptors = f.client.http.interceptors.length;
    await w.flushCache();
    w.dispose();
    expect(f.client.ingress.subscriptions, subscriptions);
    expect(f.client.http.interceptors.length, interceptors);
    expect(w.activityUnreadIfBound, isNull);
    expect(f.client.reads, isEmpty);
    expect(f.client.closed, 0);
  });

  test('the session disposes constructed notifiers and unregisters its unread observer', () {
    final f = _Fixture();
    final w = f.make();
    final interceptors = f.client.http.interceptors.length;
    final owned = <ChangeNotifier>[
      w.entityDirectory,
      w.followedThreads,
      w.translations,
      w.threadSearch,
      w.threadFollowers,
      w.announcements,
      w.announcementGate,
      w.activityUnread,
    ];
    expect(f.client.http.interceptors.length, interceptors + 1);
    w.dispose();
    w.dispose();
    for (final store in owned) {
      expect(() => _alive(store), throwsFlutterError);
    }
    expect(f.client.http.interceptors.length, interceptors);
    expect(w.activityUnreadIfBound, isNull);
    expect(() => w.activityUnread, throwsStateError);
    expect(f.client.closed, 0);
  });

  test(
    'disposing a borrower leaves every source notifier and observer alive',
    () {
      final f = _Fixture();
      final root = f.make();
      final page = f.make(source: root);
      final shared = <ChangeNotifier>[
        page.translations,
        page.threadSearch,
        page.threadFollowers,
        page.announcements,
        page.announcementGate,
        page.activityUnread,
      ];
      final interceptors = f.client.http.interceptors.length;
      page.dispose();
      for (final store in shared) {
        _alive(store);
      }
      expect(f.client.http.interceptors.length, interceptors);
      expect(page.activityUnreadIfBound, isNull);
      expect(() => page.activityUnread, throwsStateError);
      expect(root.activityUnreadIfBound, same(shared.last));
    },
  );

  test(
    'if-bound reads stay passive and expose only the live source projection',
    () {
      final f = _Fixture();
      final root = f.make();
      final page = f.make(source: root);
      final subscriptions = f.client.ingress.subscriptions;
      final interceptors = f.client.http.interceptors.length;
      expect(page.activityUnreadIfBound, isNull);
      expect(root.activityUnreadIfBound, isNull);
      expect(f.client.ingress.subscriptions, subscriptions);
      expect(f.client.http.interceptors.length, interceptors);
      final projection = root.activityUnread;
      expect(page.activityUnreadIfBound, same(projection));
      page.dispose();
      expect(page.activityUnreadIfBound, isNull);
      expect(root.activityUnreadIfBound, same(projection));
    },
  );

  test('repositories keep dynamic query and command overrides', () async {
    final f = _Fixture();
    final w = f.make();
    await w.entityDirectory.refresh(WorkspaceEntityKind.agents);
    await w.followedThreads.refresh();
    await w.followedThreads.follow('parent');
    expect(w.queries, containsAll(['/agents', FollowedThreadsStore.path]));
    expect(w.commands, ['POST /channels/threads/follow']);
    expect(f.client.reads, isEmpty);
  });

  test('borrowers respect source getter and channel-store overrides', () {
    final f = _Fixture();
    final root = f.adopt(_Overrides(f.client));
    addTearDown(() => root.customSearch.dispose());
    final page = f.make(source: root);
    expect(page.threadSearch, same(root.customSearch));
    expect(page.agentTabCache, same(root.customCache));
    expect(page.channelFilesStore('c1'), same(root.customFiles));
    page.dispose();
    _alive(root.customSearch);
    expect(root.customFiles.authorized, isTrue);
  });

  test('the channel cache keeps its capacity and retires an evicted in-flight page', () async {
    final f = _Fixture();
    final w = f.make();
    w.channels = [
      for (var i = 0; i < 25; i++) RaftChannel({'id': 'c$i', 'joined': true}),
    ];
    final response = Completer<dynamic>();
    f.client.read = (_) => response.future;
    final oldest = w.channelFilesStore('c0');
    final pending = oldest.load();
    for (var i = 1; i < 25; i++) {
      w.channelFilesStore('c$i');
    }
    response.complete({'files': <dynamic>[]});
    await pending;
    expect(oldest.loaded, isFalse);
    expect(oldest.files, isEmpty);
    expect(w.channelFilesStore('c0'), isNot(same(oldest)));
    expect(w.queries, isEmpty);
    expect(f.client.reads, ['/channels/c0/files']);
  });

  for (final status in [401, 403, 500]) {
    test(
      'channel files preserve request failure classification for HTTP $status',
      () async {
        final f = _Fixture();
        final w = f.make();
        f.client.read = (_) => Future<dynamic>.error(
          RaftApiException('Fixture failure', status: status),
        );
        final store = w.channelFilesStore('c1');
        await store.load();
        expect(
          store.error,
          status == 500
              ? ChannelFilesFailure.unavailable
              : ChannelFilesFailure.unauthorized,
        );
        expect(store.loaded, isFalse);
        expect(w.queries, isEmpty);
      },
    );
  }
}
