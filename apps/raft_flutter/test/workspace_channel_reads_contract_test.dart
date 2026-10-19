import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

RaftChannel _channel(String id, {String? name, String type = 'public'}) =>
    RaftChannel({
      'id': id,
      'serverId': 's1',
      'name': name ?? id,
      'type': type,
      'joined': true,
    });

class _ListRead {
  _ListRead(this.dm, this.server);
  final bool dm;
  final String? server;
  final result = Completer<List<RaftChannel>>();
}

class _RowRead {
  _RowRead(this.id, this.server);
  final String id;
  final String? server;
  final result = Completer<dynamic>();
}

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s1');
  }

  final bus = StreamController<RaftEvent>.broadcast(sync: true);
  final lists = <_ListRead>[];
  final rows = <_RowRead>[];
  final joins = <String>[];
  Future<void>? _closing;

  @override
  Stream<RaftEvent> get events => bus.stream;
  @override
  Future<List<RaftChannel>> channels({bool dm = false}) {
    final read = _ListRead(dm, serverId);
    lists.add(read);
    return read.result.future;
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) {
    if (path.startsWith('/channels/')) {
      final read = _RowRead(path.substring('/channels/'.length), serverId);
      rows.add(read);
      return read.result.future;
    }
    return Future<dynamic>.value({});
  }

  @override
  void joinChannel(String channelId) => joins.add(channelId);
  void emit(String name, dynamic payload) => bus.add(RaftEvent(name, payload));
  @override
  Future<void> dispose() => _closing ??= _close();
  Future<void> _close() async {
    await bus.close();
    await super.dispose();
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client, {super.presentationSource, super.ownsClient = true});

  bool closed = false;
  int notifications = 0, ordinaryQueries = 0;
  final rowCalls = <String>[];
  int listCalls = 0;
  Future<void> Function()? listOverride;
  Future<void> Function(String)? rowOverride;

  @override
  Future<void> refreshChannels() {
    listCalls++;
    return listOverride?.call() ?? super.refreshChannels();
  }

  @override
  Future<void> refreshChannel(String id) {
    rowCalls.add(id);
    return rowOverride?.call(id) ?? super.refreshChannel(id);
  }

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) {
    ordinaryQueries++;
    return super.query(path, query: query);
  }

  @override
  Future<void> refreshUnread() async {}
  @override
  void notifyListeners() {
    notifications++;
    super.notifyListeners();
  }

  @override
  void dispose() {
    if (closed) return;
    closed = true;
    super.dispose();
  }
}

class _Fixture {
  _Fixture() {
    root = make();
    addTearDown(() async {
      for (final page in pages.reversed) {
        page.dispose();
      }
      for (final read in client.rows) {
        if (!read.result.isCompleted) read.result.complete({});
      }
      for (final read in client.lists) {
        if (!read.result.isCompleted) read.result.complete([]);
      }
      await client.dispose();
    });
  }
  final client = _Client();
  final pages = <_Workspace>[];
  late final _Workspace root;

  _Workspace make({WorkspaceController? source, bool owns = true}) {
    final w = _Workspace(client, presentationSource: source, ownsClient: owns);
    pages.add(w);
    w.server = RaftRecord({'id': 's1', 'role': 'member'});
    w.channels = [_channel('c1')];
    if (source == null) w.messageDomain.ledger.switchServer('s1');
    return w;
  }

  (Future<void>, _ListRead, _ListRead) list(_Workspace w) {
    final before = client.lists.length;
    final done = w.refreshChannels();
    expect(client.lists.length, before + 2);
    final ordinary = client.lists[before], dm = client.lists[before + 1];
    expect((ordinary.dm, dm.dm), (false, true));
    return (done, ordinary, dm);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('constructing a receiver does not start channel I/O', () async {
    final f = _Fixture();
    final borrowed = f.make(source: f.root, owns: false);
    final editor = f.make(owns: false);
    expect(f.client.lists, isEmpty);
    expect(f.client.rows, isEmpty);
    expect(identical(borrowed.channels, f.root.channels), isFalse);
    expect(identical(editor.channels, f.root.channels), isFalse);
    expect(f.root.ordinaryQueries, 0);
  });

  test(
    'a later full list wins and unchanged rows retain their object',
    () async {
      final f = _Fixture(), w = f.root;
      final held = w.channels.single;
      final (first, firstChannels, firstDms) = f.list(w);
      final (second, secondChannels, secondDms) = f.list(w);
      secondChannels.result.complete([_channel('c1'), _channel('c2')]);
      secondDms.result.complete([]);
      await second;
      final accepted = w.channels;
      expect(identical(accepted.first, held), isTrue);
      firstChannels.result.complete([_channel('c1', name: 'stale')]);
      firstDms.result.complete([]);
      await first;
      expect(identical(w.channels, accepted), isTrue);
      expect(w.channels.map((c) => c.id), ['c1', 'c2']);
      expect(w.notifications, 1);
      expect(w.ordinaryQueries, 0);
    },
  );

  test('a row response older than an accepted full list is ignored', () async {
    final f = _Fixture(), w = f.root;
    final row = w.refreshChannel('c1');
    final (list, channels, dms) = f.list(w);
    channels.result.complete([_channel('c1', name: 'list-newer')]);
    dms.result.complete([]);
    await list;
    final held = w.channels.single;
    f.client.rows.single.result.complete(_channel('c1', name: 'row-old').json);
    await row;
    expect(identical(w.channels.single, held), isTrue);
    expect(w.channels.single.name, 'list-newer');
    expect(w.notifications, 1);
  });

  test(
    'new row writes retain their positions across an older full list',
    () async {
      final f = _Fixture(), w = f.root;
      final (list, channels, dms) = f.list(w);
      final shared = _channel('c2');
      w.putSharedChannelRow(shared);
      w.composer.drafts['pending-dm:peer'] = 'authored before DM exists';
      final real = _channel('d1', type: 'dm');
      await w.adoptResolvedDm('pending-dm:peer', real);
      channels.result.complete([_channel('c1')]);
      dms.result.complete([]);
      await list;
      expect(w.channels.map((c) => c.id), ['c1', 'c2']);
      expect(identical(w.channels.last, shared), isTrue);
      expect(w.dms.map((c) => c.id), ['d1']);
      expect(identical(w.dms.single, real), isTrue);
      expect(w.composer.drafts['d1'], 'authored before DM exists');
      expect(w.composer.drafts.containsKey('pending-dm:peer'), isFalse);
    },
  );

  test('coalesced row callers finish before the one queued reread', () async {
    final f = _Fixture(), w = f.root;
    final first = w.refreshChannel('c1');
    final second = w.refreshChannel('c1');
    final third = w.refreshChannel('c1');
    expect(identical(first, second), isTrue);
    expect(identical(first, third), isTrue);
    expect(f.client.rows, hasLength(1));
    f.client.rows.first.result.complete(_channel('c1', name: 'first').json);
    await first;
    expect(f.client.rows, hasLength(2));
    expect(f.client.rows.last.result.isCompleted, isFalse);
    expect(w.channels.single.name, 'first');
    expect(w.rowCalls, ['c1', 'c1', 'c1', 'c1']);
    final pendingReread = w.refreshChannel('c1');
    // This extra public caller schedules the next read, just as the old API.
    w.dispose();
    f.client.rows.last.result.complete(_channel('c1', name: 'late').json);
    await pendingReread;
    expect(f.client.rows, hasLength(2));
    expect(w.channels.single.name, 'first');
  });

  test(
    'borrowed full refresh delegates but a single row stays local',
    () async {
      final f = _Fixture(), source = f.root;
      final page = f.make(source: source, owns: false);
      source.listOverride = () async {};
      await page.refreshChannels();
      expect((page.listCalls, source.listCalls), (1, 1));
      expect(f.client.lists, isEmpty);
      final sourceRow = source.channels.single;
      final read = page.refreshChannel('c1');
      f.client.rows.single.result.complete(
        _channel('c1', name: 'page-only').json,
      );
      await read;
      expect(page.channels.single.name, 'page-only');
      expect(identical(source.channels.single, sourceRow), isTrue);
      expect(source.rowCalls, isEmpty);
    },
  );

  test(
    'receivers sharing one client do not merge their single-row reads',
    () async {
      final f = _Fixture(), source = f.root;
      final page = f.make(source: source, owns: false);
      final a = source.refreshChannel('c1'), b = page.refreshChannel('c1');
      expect(f.client.rows, hasLength(2));
      f.client.rows[1].result.complete(_channel('c1', name: 'borrowed').json);
      await b;
      f.client.rows[0].result.complete(_channel('c1', name: 'source').json);
      await a;
      expect(source.channels.single.name, 'source');
      expect(page.channels.single.name, 'borrowed');
    },
  );

  test(
    'a non-owning independent editor keeps its channel event filter',
    () async {
      final f = _Fixture(), source = f.root;
      final editor = f.make(owns: false);
      final held = editor.channels.single;
      f.client.emit('channel:updated', {
        'channel': _channel('c1', name: 'source-event').json,
      });
      expect(source.channels.single.name, 'source-event');
      expect(identical(editor.channels.single, held), isTrue);
      expect(f.client.rows, isEmpty);
      expect(f.client.lists, isEmpty);
      final own = editor.refreshChannel('c1');
      f.client.rows.single.result.complete(
        _channel('c1', name: 'editor-read').json,
      );
      await own;
      expect(editor.channels.single.name, 'editor-read');
      expect(source.channels.single.name, 'source-event');
    },
  );

  test('realtime fallback calls the public overridable read entries', () async {
    final f = _Fixture(), w = f.root;
    w.rowOverride = (_) async {};
    w.listOverride = () async {};
    f.client.emit('channel:updated', {'channel': _channel('unknown').json});
    f.client.emit('channel:authority-updated', {});
    f.client.emit('dm:new', {});
    expect(w.rowCalls, ['unknown']);
    expect(w.listCalls, 1);
    expect(f.client.rows, isEmpty);
    expect(f.client.lists, isEmpty);
  });

  test(
    'selection-state reset clears row protection without cancelling reads',
    () async {
      final f = _Fixture(), w = f.root;
      final (list, channels, dms) = f.list(w);
      w.putSharedChannelRow(_channel('c1', name: 'optimistic'));
      final single = w.refreshChannel('c2');
      final sameSingle = w.refreshChannel('c2');
      w.resetServerSelectionState();
      expect(identical(w.refreshChannel('c2'), sameSingle), isTrue);
      channels.result.complete([_channel('c1', name: 'original')]);
      dms.result.complete([]);
      await list;
      expect(w.channels.single.name, 'original');
      // The row authority map is cleared, not the in-flight reads or counters.
      f.client.rows.first.result.complete(_channel('c2').json);
      await single;
      expect(w.channels.map((c) => c.id), ['c1', 'c2']);
      expect(f.client.rows, hasLength(2));
      w.dispose();
    },
  );

  for (final change in [
    'principal',
    'server',
    'client-generation',
    'role',
    'ledger',
  ]) {
    test('a late single row is rejected after $change changes', () async {
      final f = _Fixture(), w = f.root;
      final held = w.channels.single;
      final read = w.refreshChannel('c1');
      switch (change) {
        case 'principal':
          f.client.user = RaftRecord({'id': 'bob'});
        case 'server':
          f.client.serverId = 's2';
        case 'client-generation':
          f.client.selectServer('s2');
          f.client.selectServer('s1');
        case 'role':
          w.server = RaftRecord({'id': 's1', 'role': 'viewer'});
        case 'ledger':
          w.messageDomain.ledger.switchServer('s2');
      }
      f.client.rows.single.result.complete(_channel('c1', name: 'stale').json);
      await read;
      expect(identical(w.channels.single, held), isTrue);
      expect(w.notifications, 0);
    });
  }

  test(
    'the full-list path keeps its existing ledger-only scope fence',
    () async {
      final f = _Fixture(), w = f.root;
      final (list, channels, dms) = f.list(w);
      // A fixture-only role assignment does not advance the ledger generation.
      w.server = RaftRecord({'id': 's1', 'role': 'viewer'});
      channels.result.complete([_channel('c1', name: 'accepted')]);
      dms.result.complete([]);
      await list;
      expect(w.channels.single.name, 'accepted');
      expect(w.notifications, 1);
    },
  );

  for (final error in [
    const RaftApiException('rate limited', status: 429),
    const RaftApiException.staleScope(),
    const RaftApiException('offline', status: 500),
  ]) {
    test(
      'background full-list error preserves rows: ${error.message}',
      () async {
        final f = _Fixture(), w = f.root;
        final held = w.channels;
        final (list, channels, dms) = f.list(w);
        channels.result.completeError(error);
        dms.result.complete([]);
        await list;
        expect(identical(w.channels, held), isTrue);
        if (error.status == 500) {
          expect(w.error, 'Something went wrong');
          expect(w.notifications, 1);
        } else {
          expect(w.error, isNull);
          expect(w.notifications, 0);
        }
      },
    );
  }

  test('an unheld denied row revokes that scope and notifies once', () async {
    final f = _Fixture(), w = f.root;
    final held = w.channels;
    final read = w.refreshChannel('missing');
    f.client.rows.single.result.completeError(
      const RaftApiException('denied', status: 403),
    );
    await read;
    expect(w.sessionScope.revokedChannels, {'missing'});
    expect(identical(w.channels, held), isTrue);
    expect(w.notifications, 1);
    expect(w.error, isNull);
  });

  test(
    'a transient single-row failure leaves the row and notice untouched',
    () async {
      final f = _Fixture(), w = f.root;
      final held = w.channels;
      final read = w.refreshChannel('c1');
      f.client.rows.single.result.completeError(
        const RaftApiException('offline', status: 500),
      );
      await read;
      expect(identical(w.channels, held), isTrue);
      expect(w.notifications, 0);
      expect(w.error, isNull);
    },
  );
}
