import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/global_server_selector.dart';
import 'package:raft_flutter/features/workspace_view.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

const _origin = 'https://fixture.invalid';
const _memory = 'raft.server-surface.https%3A%2F%2Ffixture.invalid.alice';

int _reads(RootFixture f) => f.adapter.calls
    .where((c) => c.method == 'GET' && c.path == '/servers')
    .length;

/// Answers every read at once except `GET /servers`, which waits for [gate].
class _Gated implements HttpClientAdapter {
  Completer<int>? gate;
  var directoryReads = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    var status = 200;
    Object body = o.method == 'GET' ? <Object>[] : {};
    if (o.path == '/auth/login') {
      body = {
        'accessToken': 'test-only',
        'refreshToken': 'test-only',
        'user': {'id': 'alice'},
      };
    } else if (o.path == '/servers' && o.method == 'GET') {
      directoryReads++;
      final held = gate;
      if (held != null) status = await held.future;
      body = [
        {'id': 'A', 'name': 'Alpha', 'role': 'owner'},
      ];
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Client extends RaftClient {
  _Client(_Gated d)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = d,
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  bool get connected => true;
  @override
  void connect() {}
}

Future<(WorkspaceController, _Gated)> _openGated() async {
  final adapter = _Gated();
  final client = _Client(adapter);
  await client.login('t', 't');
  final w = WorkspaceController(client);
  addTearDown(w.dispose);
  final a = RaftRecord({'id': 'A', 'name': 'Alpha', 'role': 'owner'});
  w.servers = [a];
  await w.selectServer(a);
  await Future<void>.delayed(const Duration(milliseconds: 60));
  adapter.directoryReads = 0;
  return (w, adapter);
}

/// On a desktop the first window focus during startup arrives as `resumed`.
/// That resume refresh must not retire the directory read the boot flow is
/// still waiting for.
void main() {
  testWidgets('fresh launch: a resume during the first directory read does not '
      'strand the server selection', (t) async {
    final f = RootFixture();
    f.servers.removeLast();
    f.holds['GET /servers'] = Completer<dynamic>();
    await f.mount(
      t,
      'light',
      1280,
      cachedSession: true,
      uri: Uri.parse('/s/alpha'),
    );
    expect(find.byType(GlobalServerSelector), findsOneWidget);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await f.flush(t);
    f.holds['GET /servers']!.complete(null);
    await f.flush(t);
    expect(find.byType(WorkspaceView), findsOneWidget);
    expect(find.byType(GlobalServerSelector), findsNothing);
    expect(f.workspace(t).server!.id, 'a');
    expect(_reads(f), 1);
    await f.close(t);
  });


  testWidgets('cache-first start: a resume during the revalidation neither '
      'repeats the read nor drops the revocation sweep', (t) async {
    final first = RootFixture();
    await first.mount(t, 'light', 1280);
    await t.tap(find.byKey(const ValueKey('global-server-a')));
    await first.flush(t);
    final uri = first.router(t).currentConfiguration.toString();
    await first.workspace(t).flushCache();
    await first.close(t);
    // The device also holds a server the account has since left.
    first.cache.rows['$_origin|alice||servers|'] = [
      ...first.servers,
      {'id': 'gone', 'name': 'Gone', 'slug': 'gone', 'role': 'owner'},
    ];
    first.cache.rows['$_origin|alice|gone|channels|'] = {
      'channels': [],
      'dms': [],
    };
    final f = RootFixture(cache: first.cache);
    f.holds['GET /servers'] = Completer<dynamic>();
    await f.mount(
      t,
      'light',
      1280,
      cachedSession: true,
      preferences: {'$_memory.last': 'alpha', '$_memory.a': uri},
    );
    expect(find.byType(WorkspaceView), findsOneWidget);
    final w = f.workspace(t);
    expect(w.servers.map((s) => s.id), ['a', 'b', 'gone']);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await f.flush(t);
    f.holds['GET /servers']!.complete(null);
    await f.flush(t);
    expect(w.servers.map((s) => s.id), ['a', 'b']);
    expect(
      f.cache.rows.keys.where((k) => k.startsWith('$_origin|alice|gone|')),
      isEmpty,
    );
    expect(_reads(f), 1);
    await f.close(t);
  });

  group('a directory load in flight survives the foreground refresh', () {
    test('a resume while the load waits does not make it return false', () async {
      final (w, adapter) = await _openGated();
      adapter.gate = Completer<int>();
      final load = w.loadServerDirectory();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      w.resumeLiveSession();
      w.recoverMembership(coalesce: true);
      adapter.gate!.complete(200);
      expect(await load, isTrue);
      expect(adapter.directoryReads, 1);
      expect(w.servers.map((s) => s.id), ['A']);
    });

    test('a failed load frees the next refresh', () async {
      final (w, adapter) = await _openGated();
      adapter.gate = Completer<int>();
      final load = w.loadServerDirectory();
      final failed = expectLater(load, throwsA(anything));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      w.resumeLiveSession();
      adapter.gate!.complete(500);
      await failed;
      adapter.gate = null;
      await w.recoverMembership(coalesce: true);
      expect(adapter.directoryReads, 2);
      expect(w.servers.map((s) => s.id), ['A']);
    });

    test('a role event still retires the load', () async {
      final (w, adapter) = await _openGated();
      adapter.gate = Completer<int>();
      final load = w.loadServerDirectory();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      w.applyMembershipRole({
        'userId': 'alice',
        'serverId': 'A',
        'role': 'member',
      });
      adapter.gate!.complete(200);
      expect(await load, isFalse);
      expect(w.servers.single.string('role'), 'member');
    });

    test('a refresh someone asked for still supersedes the load', () async {
      final (w, adapter) = await _openGated();
      adapter.gate = Completer<int>();
      final load = w.loadServerDirectory();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      unawaited(w.recoverMembership());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      adapter.gate!.complete(200);
      expect(await load, isFalse);
      expect(adapter.directoryReads, 2);
    });
  });
}
