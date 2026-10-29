import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_cache.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

class _Pending {
  final started = Completer<void>();
  final response = Completer<dynamic>();
}

class _Cache implements WorkspaceCache {
  dynamic order;
  _Pending? readGate;
  final writes = <Map<String, dynamic>>[];

  @override
  Future<dynamic> read(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
  ) async {
    if (kind != 'sidebar-order') return null;
    final gate = readGate;
    readGate = null;
    if (gate != null) {
      gate.started.complete();
      return gate.response.future;
    }
    return order;
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
    if (kind == 'sidebar-order') writes.add(Map<String, dynamic>.from(value));
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
  ) async {}
  @override
  Future<void> clearAccount(String origin, String principal) async {}
  @override
  Future<List<Map<String, dynamic>>> readTranslations(
    String origin,
    String principal,
    String server,
  ) async => [];
  @override
  Future<void> writeTranslations(
    String origin,
    String principal,
    String server,
    List<Map<String, dynamic>> entries,
  ) async {}
  @override
  Future<void> close() async {}
}

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  final readQueue = <_Pending>[];
  final writeQueue = <_Pending>[];
  final reads = <String>[];
  final writes = <(String, String, Map<String, dynamic>)>[];
  final unexpected = <String>[];
  Future<void>? _closing;

  @override
  Stream<RaftEvent> get events => ingress.stream;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) {
    reads.add(path);
    if (readQueue.isEmpty) {
      unexpected.add('GET $path');
      return Future<dynamic>.value({});
    }
    final pending = readQueue.removeAt(0);
    pending.started.complete();
    return pending.response.future;
  }

  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
    bool workspaceScoped = true,
  }) {
    writes.add((method, path, Map<String, dynamic>.from(data as Map)));
    if (writeQueue.isEmpty) {
      unexpected.add('$method $path');
      return Future<dynamic>.value({});
    }
    final pending = writeQueue.removeAt(0);
    pending.started.complete();
    return pending.response.future;
  }

  @override
  Future<void> dispose() => _closing ??= _close();

  Future<void> _close() async {
    await ingress.close();
    await super.dispose();
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(
    super.client, {
    required super.cache,
    WorkspaceController? source,
    bool owns = false,
  }) : super(presentationSource: source, ownsClient: owns);
  Future<void> Function()? loadOverride;
  Future<void> Function(Map<String, dynamic>)? updateOverride;
  final loads = <Future<void>>[];
  int notifications = 0;
  bool closed = false;

  @override
  Future<void> loadSidebar() {
    final result = loadOverride?.call() ?? super.loadSidebar();
    loads.add(result);
    return result;
  }

  @override
  Future<void> updateSidebarOrder(Map<String, dynamic> updates) =>
      updateOverride?.call(updates) ?? super.updateSidebarOrder(updates);

  @override
  void notifyListeners() {
    notifications++;
    super.notifyListeners();
  }

  @override
  void dispose() {
    closed = true;
    super.dispose();
  }
}

class _Fixture {
  _Fixture() {
    client.user = RaftRecord({'id': 'alice'});
    client.selectServer('s1');
    addTearDown(() async {
      for (final pending in gates) {
        if (!pending.response.isCompleted) pending.response.complete({});
      }
      for (final w in pages.reversed) {
        if (!w.closed) {
          await w.flushCache();
          w.dispose();
        }
      }
      await client.dispose();
      expect(client.unexpected, isEmpty);
    });
  }

  final client = _Client();
  final cache = _Cache();
  final gates = <_Pending>[];
  final pages = <_Workspace>[];

  _Workspace make({WorkspaceController? source, bool owns = false}) {
    final w = _Workspace(client, cache: cache, source: source, owns: owns)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'});
    pages.add(w);
    return w;
  }

  _Pending gate() {
    final result = _Pending();
    gates.add(result);
    return result;
  }

  _Pending read() {
    final result = gate();
    client.readQueue.add(result);
    return result;
  }

  _Pending write() {
    final result = gate();
    client.writeQueue.add(result);
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cached order paints before the network response and fresh order is persisted', () async {
    final f = _Fixture();
    f.cache.order = {
      'channelOrder': ['cached'],
    };
    final w = f.make();
    final notifications = <Map<String, dynamic>>[];
    w.addListener(() => notifications.add(Map.from(w.sidebarOrder)));
    final response = f.read();
    final loading = w.loadSidebar();
    await response.started.future;
    expect(w.sidebarOrder, f.cache.order);
    expect(notifications, [f.cache.order]);
    expect(f.cache.writes, isEmpty);
    response.response.complete({
      'channelOrder': ['fresh'],
      'sectionsVersion': 4,
    });
    await loading;
    await w.flushCache();
    expect(w.sidebarOrder, {
      'channelOrder': ['fresh'],
      'sectionsVersion': 4,
    });
    expect(notifications.last, w.sidebarOrder);
    expect(f.cache.writes, [w.sidebarOrder]);
  });

  test('a newer load wins over a late same-scope response', () async {
    final f = _Fixture();
    final w = f.make();
    final first = f.read(), second = f.read();
    final a = w.loadSidebar();
    await first.started.future;
    final b = w.loadSidebar();
    await second.started.future;
    second.response.complete({
      'channelOrder': ['newer'],
    });
    await b;
    first.response.complete({
      'channelOrder': ['late'],
    });
    await a;
    await w.flushCache();
    expect(w.sidebarOrder, {
      'channelOrder': ['newer'],
    });
    expect(f.cache.writes, [w.sidebarOrder]);
  });

  for (final change in ['principal', 'role', 'record', 'server', 'dispose']) {
    test('a pending load cannot publish after $change changes', () async {
      final f = _Fixture();
      final w = f.make();
      final response = f.read();
      final loading = w.loadSidebar();
      await response.started.future;
      switch (change) {
        case 'principal':
          f.client.user = RaftRecord({'id': 'bob'});
        case 'role':
          w.server = RaftRecord({'id': 's1', 'role': 'member'});
        case 'record':
          w.server = RaftRecord({'id': 'other', 'role': 'owner'});
        case 'server':
          f.client.selectServer('s2');
        case 'dispose':
          w.dispose();
      }
      w.sidebarOrder = {
        'channelOrder': ['current'],
      };
      final notifications = w.notifications;
      response.response.complete({
        'channelOrder': ['stale-private'],
      });
      await loading;
      expect(w.sidebarOrder, {
        'channelOrder': ['current'],
      });
      expect(w.notifications, notifications);
      expect(f.cache.writes, isEmpty);
    });
  }

  test(
    'a stale cached read never paints or starts a network request',
    () async {
      final f = _Fixture();
      final cached = f.gate();
      f.cache.readGate = cached;
      final w = f.make();
      final loading = w.loadSidebar();
      await cached.started.future;
      w.server = RaftRecord({'id': 's1', 'role': 'member'});
      cached.response.complete({
        'customSections': ['private'],
      });
      await loading;
      expect(w.sidebarOrder, isEmpty);
      expect(f.client.reads, isEmpty);
    },
  );

  for (final malformed in [false, true]) {
    test(
      'cached order survives ${malformed ? 'malformed response' : 'offline failure'}',
      () async {
        final f = _Fixture();
        f.cache.order = {
          'channelOrder': ['cached'],
        };
        final w = f.make();
        final response = f.read();
        final loading = w.loadSidebar();
        await response.started.future;
        if (malformed) {
          response.response.complete(<dynamic>[]);
        } else {
          response.response.completeError(
            const RaftApiException('Offline', status: 503),
          );
        }
        await loading;
        expect(w.sidebarOrder, f.cache.order);
        expect(f.cache.writes, isEmpty);
      },
    );
  }

  test(
    'ordinary writes publish optimistically and merge the server reply',
    () async {
      final f = _Fixture();
      final w = f.make();
      w.sidebarOrder = {
        'channelOrder': ['old'],
        'dmOrder': ['dm'],
      };
      final response = f.write();
      final saving = w.updateSidebarOrder({
        'channelOrder': ['optimistic'],
      });
      expect(w.sidebarOrder, {
        'channelOrder': ['optimistic'],
        'dmOrder': ['dm'],
      });
      final request = f.client.writes.single;
      expect(request.$1, 'PATCH');
      expect(request.$2, '/servers/s1/sidebar-order');
      expect(request.$3, {
        'channelOrder': ['optimistic'],
      });
      response.response.complete({
        'channelOrder': ['accepted'],
        'pinnedVersion': 8,
      });
      await saving;
      await w.flushCache();
      expect(w.sidebarOrder, {
        'channelOrder': ['accepted'],
        'dmOrder': ['dm'],
        'pinnedVersion': 8,
      });
      expect(f.cache.writes.first['channelOrder'], ['optimistic']);
      expect(f.cache.writes.last, w.sidebarOrder);
    },
  );

  test('section writes serialize, adopt confirmed versions and keep newer optimism', () async {
    final f = _Fixture();
    final w = f.make();
    w.sidebarOrder = {'sectionsVersion': 3};
    final first = f.write(), second = f.write();
    final a = w.updateSidebarOrder({
      'customSections': ['A'],
    });
    final b = w.updateSidebarOrder({
      'sectionOrder': ['B'],
    });
    expect(f.client.writes, hasLength(1));
    expect(f.client.writes.first.$3['sectionsVersion'], 3);
    first.response.complete({
      'customSections': ['old-server'],
      'sectionsVersion': 4,
      'pinnedVersion': 6,
    });
    await second.started.future;
    expect(w.sidebarOrder['customSections'], ['A']);
    expect(w.sidebarOrder['sectionOrder'], ['B']);
    expect(w.sidebarOrder['pinnedVersion'], 6);
    expect(f.client.writes.last.$3, {
      'sectionOrder': ['B'],
      'sectionsVersion': 4,
    });
    second.response.complete({
      'customSections': ['accepted'],
      'sectionsVersion': 5,
      'pinnedVersion': 7,
    });
    await Future.wait([a, b]);
    expect(w.sidebarOrder, {
      'customSections': ['accepted'],
      'sectionOrder': ['B'],
      'sectionsVersion': 5,
      'pinnedVersion': 7,
    });
    w.sidebarOrder = {'sectionsVersion': 20};
    final third = f.write();
    final c = w.updateSidebarOrder({
      'sectionPlacements': ['C'],
    });
    expect(f.client.writes.last.$3['sectionsVersion'], 20);
    third.response.complete({'sectionsVersion': 21});
    await c;
  });

  test(
    'ordinary writes bypass the section queue without adding a version',
    () async {
      final f = _Fixture();
      final w = f.make();
      w.sidebarOrder = {'sectionsVersion': 3};
      final section = f.write(), ordinary = f.write();
      final a = w.updateSidebarOrder({
        'customSections': ['A'],
      });
      final b = w.updateSidebarOrder({
        'channelOrder': ['B'],
      });
      expect(f.client.writes, hasLength(2));
      expect(f.client.writes.last.$3, {
        'channelOrder': ['B'],
      });
      ordinary.response.complete({});
      section.response.complete({'sectionsVersion': 4});
      await Future.wait([a, b]);
    },
  );

  test(
    'a failed latest write restores the exact previous projection',
    () async {
      final f = _Fixture();
      final w = f.make();
      final previous = <String, dynamic>{
        'channelOrder': ['old'],
      };
      w.sidebarOrder = previous;
      final response = f.write();
      final saving = w.updateSidebarOrder({
        'channelOrder': ['new'],
      });
      response.response.completeError(
        const RaftApiException('Failed', status: 500),
      );
      await saving;
      await w.flushCache();
      expect(w.sidebarOrder, same(previous));
      expect(f.cache.writes.last, previous);
    },
  );

  test(
    'an older section failure preserves the newer queued projection',
    () async {
      final f = _Fixture();
      final w = f.make();
      w.sidebarOrder = {'sectionsVersion': 3};
      final first = f.write(), second = f.write();
      final a = w.updateSidebarOrder({
        'customSections': ['A'],
      });
      final previous = w.sidebarOrder;
      final b = w.updateSidebarOrder({
        'sectionOrder': ['B'],
      });
      first.response.completeError(
        const RaftApiException('Failed', status: 500),
      );
      await second.started.future;
      expect(w.sidebarOrder['sectionOrder'], ['B']);
      second.response.completeError(
        const RaftApiException('Failed again', status: 500),
      );
      await Future.wait([a, b]);
      expect(w.sidebarOrder, same(previous));
    },
  );

  test(
    'a conflict reloads through the overridable controller entrypoint',
    () async {
      final f = _Fixture();
      final w = f.make();
      var reloads = 0;
      w.loadOverride = () async {
        reloads++;
      };
      final response = f.write();
      final saving = w.updateSidebarOrder({
        'channelOrder': ['new'],
      });
      response.response.completeError(
        const RaftApiException('Conflict', status: 409),
      );
      await saving;
      expect(reloads, 1);
      expect(f.client.reads, isEmpty);
    },
  );

  test(
    'borrowed actions preserve source overrides and local presentation fields',
    () async {
      final f = _Fixture();
      final root = f.make();
      final page = f.make(source: root);
      root.sidebarOrder = {
        'channelOrder': ['root'],
      };
      final local = <String, dynamic>{
        'channelOrder': ['page'],
      };
      page.sidebarOrder = local;
      var loads = 0;
      Map<String, dynamic>? update;
      root.loadOverride = () async {
        loads++;
      };
      root.updateOverride = (value) async {
        update = value;
      };
      await page.loadSidebar();
      await page.updateSidebarOrder({
        'hiddenDmIds': ['hidden'],
      });
      expect(loads, 1);
      expect(update, {
        'hiddenDmIds': ['hidden'],
      });
      expect(page.sidebarOrder, same(local));
      expect(root.sidebarOrder, {
        'channelOrder': ['root'],
      });
      expect(f.client.reads, isEmpty);
      expect(f.client.writes, isEmpty);
    },
  );

  test('nested borrowed writes use one source section queue', () async {
    final f = _Fixture();
    final root = f.make();
    final page = f.make(source: root);
    final nested = f.make(source: page);
    root.sidebarOrder = {'sectionsVersion': 3};
    final first = f.write(), second = f.write();
    final a = page.updateSidebarOrder({
      'customSections': ['A'],
    });
    final b = nested.updateSidebarOrder({
      'sectionOrder': ['B'],
    });
    expect(f.client.writes, hasLength(1));
    first.response.complete({'sectionsVersion': 4});
    await second.started.future;
    expect(f.client.writes.last.$3['sectionsVersion'], 4);
    second.response.complete({'sectionsVersion': 5});
    await Future.wait([a, b]);
    expect(root.sidebarOrder['sectionOrder'], ['B']);
    expect(page.sidebarOrder, isEmpty);
    expect(nested.sidebarOrder, isEmpty);
  });

  test(
    'disposed ownership suppresses late acknowledgements and queued writes',
    () async {
      final f = _Fixture();
      final w = f.make();
      final response = f.write();
      final a = w.updateSidebarOrder({
        'customSections': ['A'],
      });
      final b = w.updateSidebarOrder({
        'sectionOrder': ['B'],
      });
      w.dispose();
      final state = w.sidebarOrder, notifications = w.notifications;
      response.response.complete({'sectionsVersion': 90});
      await Future.wait([a, b]);
      expect(f.client.writes, hasLength(1));
      expect(w.sidebarOrder, same(state));
      expect(w.notifications, notifications);
    },
  );

  test(
    'server changes suppress late write publication and old queued requests',
    () async {
      final f = _Fixture();
      final w = f.make();
      final response = f.write();
      final a = w.updateSidebarOrder({
        'customSections': ['A'],
      });
      final b = w.updateSidebarOrder({
        'sectionOrder': ['B'],
      });
      f.client.selectServer('s2');
      w.server = RaftRecord({'id': 's2', 'role': 'owner'});
      w.sidebarOrder = {
        'channelOrder': ['new-server'],
      };
      response.response.complete({'sectionsVersion': 90});
      await Future.wait([a, b]);
      expect(f.client.writes, hasLength(1));
      expect(w.sidebarOrder, {
        'channelOrder': ['new-server'],
      });
    },
  );

  test('a pinned event loads through the source controller once', () async {
    final f = _Fixture();
    final root = f.make(owns: true);
    final page = f.make(source: root);
    final response = f.read();
    f.client.ingress.add(const RaftEvent('pinned:updated', {}));
    await response.started.future;
    response.response.complete({
      'pinned': ['channel'],
    });
    await Future.wait(root.loads);
    expect(f.client.reads, ['/servers/s1/sidebar-order']);
    expect(root.sidebarOrder, {
      'pinned': ['channel'],
    });
    expect(page.loads, isEmpty);
  });
}
