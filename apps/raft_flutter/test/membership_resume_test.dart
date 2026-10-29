import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

/// Another session of the account joins a server: the server tells only that
/// server's room, so this device sees it by re-reading the directory when the
/// app (or, on a desktop, the window) returns to the foreground.
class _Directory implements HttpClientAdapter {
  var rows = <Map<String, dynamic>>[
    {'id': 'A', 'name': 'Alpha', 'role': 'owner'},
  ];
  final calls = <String>[];
  int get directoryReads => calls.where((c) => c == 'GET /servers').length;
  int get scoped => calls.where((c) => c.contains('X-Server-Id')).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add('${o.method} ${o.path}');
    Object body = o.method == 'GET' ? <Object>[] : {};
    if (o.path == '/auth/login') {
      body = {
        'accessToken': 'test-only',
        'refreshToken': 'test-only',
        'user': {'id': 'alice'},
      };
    } else if (o.path == '/servers') {
      body = rows;
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Client extends RaftClient {
  _Client(_Directory d)
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

Future<void> _drain() => Future<void>.delayed(const Duration(milliseconds: 60));

/// The resume read is not a clock. Poll until it has landed, and give up
/// after two seconds so a dropped read still fails the assertion below.
Future<void> _applied(bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

Future<(WorkspaceController, _Directory)> _open() async {
  final dir = _Directory();
  final client = _Client(dir);
  await client.login('t', 't');
  final w = WorkspaceController(client);
  addTearDown(w.dispose);
  final a = RaftRecord(dir.rows.first);
  w.servers = [a];
  await w.selectServer(a);
  await _drain();
  dir.calls.clear();
  return (w, dir);
}

void main() {
  group('returning to the foreground re-reads the server directory', () {
    test('a server joined elsewhere is listed; the selection stays', () async {
      final (w, dir) = await _open();
      dir.rows = [
        ...dir.rows,
        {'id': 'B', 'name': 'Public', 'role': 'member'},
      ];
      w.resumeLiveSession();
      await _applied(() => w.servers.map((s) => s.id).join(',') == 'A,B');
      expect(w.servers.map((s) => s.id), ['A', 'B']);
      expect(w.server?.id, 'A');
      expect(w.client.serverId, 'A');
    });

    test('an unchanged server list refetches no channels or sidebar', () async {
      final (w, dir) = await _open();
      dir.rows = [
        ...dir.rows,
        {'id': 'B', 'name': 'Public', 'role': 'member'},
      ];
      dir.calls.clear();
      w.resumeLiveSession();
      await _applied(() => w.servers.map((s) => s.id).join(',') == 'A,B');
      // The directory request is counted before the list is written. A read
      // of B started by that write happens on a later turn.
      await _drain();
      // Nothing is read for B (a new row is only listed), and the open server
      // keeps its own loads to the usual resume reads.
      expect(dir.calls.where((c) => c.contains('/servers/B')), isEmpty);
    });

    test('two resumes inside the window make one directory read', () async {
      final (w, dir) = await _open();
      w.resumeLiveSession();
      await _applied(() => dir.directoryReads == 1);
      w.resumeLiveSession();
      w.resumeLiveSession();
      // Those two resumes return before a second directory read is counted.
      await _drain();
      expect(dir.directoryReads, 1);
    });

    test('a server the person left elsewhere is handled', () async {
      final (w, dir) = await _open();
      final b = RaftRecord({'id': 'B', 'name': 'Beta', 'role': 'owner'});
      w.servers = [...w.servers, b];
      dir.rows = [
        {'id': 'B', 'name': 'Beta', 'role': 'owner'},
      ];
      w.resumeLiveSession();
      await _applied(() => w.servers.map((s) => s.id).join(',') == 'B');
      expect(w.servers.map((s) => s.id), ['B']);
      expect(w.server?.id, 'B');
      expect(w.error, isNull);
    });
  });

  for (final width in [390.0, 1280.0]) {
    testWidgets('actual RaftApp $width: window focus regain lists the new '
        'server in the switcher without changing the selection', (t) async {
      final f = RootFixture();
      await f.mount(t, 'light', width, uri: Uri.parse('/s/alpha'));
      final w = f.workspace(t);
      expect(w.server!.id, 'a');
      int reads() => f.adapter.calls
          .where((c) => c.method == 'GET' && c.path == '/servers')
          .length;

      Future<void> openMenu() async {
        // Wide layout (>= 768, the Raft pack's `shell.browserTopBar: shown`,
        // no native window chrome in tests): the workspace entry is the top
        // bar's `topbar-workspace` (server_switcher_top_bar.dart:401) and the
        // rail header is empty (workspace_view.dart:2804), so `rail-workspace`
        // must not exist (raftShowsWorkspaceTopBar, workspace_top_bar.dart:18).
        // Phone widths keep `mobile-server-selector` and have no top bar.
        final mobile = width < 768;
        final entry = find.byKey(
          Key(mobile ? 'mobile-server-selector' : 'topbar-workspace'),
        );
        expect(entry, findsOneWidget);
        expect(
          find.byKey(Key(mobile ? 'topbar-workspace' : 'rail-workspace')),
          findsNothing,
        );
        expect(entry.hitTestable(), findsOneWidget);
        await t.tap(entry);
        await t.pumpAndSettle();
      }

      await openMenu();
      expect(find.byKey(const Key('server-switcher-menu')), findsOneWidget);
      expect(find.byKey(const ValueKey('server-menu-row-b')), findsOneWidget);
      expect(find.byKey(const ValueKey('server-menu-row-new')), findsNothing);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('server-switcher-menu')), findsNothing);

      f.servers.add({
        'id': 'new',
        'name': 'Public',
        'slug': 'public',
        'role': 'member',
      });
      final before = reads();
      // Window blur, then focus: the engine reports inactive then resumed.
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await f.flush(t);
      expect(reads(), before + 1);
      // A second flicker inside the window reads nothing.
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await f.flush(t);
      expect(reads(), before + 1);

      expect(w.servers.map((s) => s.id), ['a', 'b', 'new']);
      expect(w.server!.id, 'a');
      expect(
        f.router(t).currentConfiguration.toString(),
        startsWith('/s/alpha'),
      );
      await openMenu();
      expect(find.byKey(const Key('server-switcher-menu')), findsOneWidget);
      expect(find.byKey(const ValueKey('server-menu-row-new')), findsOneWidget);
      await f.close(t);
    });
  }
}
