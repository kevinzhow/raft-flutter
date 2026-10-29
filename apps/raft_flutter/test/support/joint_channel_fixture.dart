// Shared fixture of the joint-channel tests: a recording HTTP adapter, a
// workspace that records channel selection, and a MaterialApp host.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final routes = <String, FutureOr<dynamic> Function(RequestOptions)>{};
  final statuses = <String, int>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    calls.add(o);
    final key = '${o.method} ${o.path}',
        route = routes['${o.method} ${o.path}'];
    return ResponseBody.fromString(
      jsonEncode(
        route == null ? {'error': 'Unexpected request'} : await route(o),
      ),
      statuses[key] ?? (route == null ? 404 : 200),
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Client extends RaftClient {
  _Client({
    required super.origin,
    required super.sessionStore,
    required super.transport,
  });
  final forwarded = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => forwarded.stream;
  @override
  Future<void> dispose() async {
    await forwarded.close();
    await super.dispose();
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  String? selected;
  int refreshes = 0;
  @override
  Future<void> selectChannel(
    RaftChannel next, {
    bool autoRead = true,
    bool navigate = true,
    bool retainContextUntilAccepted = false,
    bool preserveThread = false,
    VoidCallback? onDraftRestored,
  }) async {
    selected = next.id;
  }

  @override
  Future<void> refreshChannels() async {
    refreshes++;
  }
}

Future<(_Workspace, _Adapter)> fixture([String role = 'owner']) async {
  final a = _Adapter();
  a.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture',
    'refreshToken': 'fixture',
    'user': {'id': 'alice'},
  };
  final c = _Client(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = a,
  );
  await c.login('fixture', 'fixture');
  c.selectServer('s1');
  final w = _Workspace(c)..server = RaftRecord({'id': 's1', 'role': role});
  a.routes['GET /channels/joint-invites'] = (_) => {'invites': []};
  a.routes['GET /channels'] = (_) => [];
  a.routes['GET /agents'] = (_) => [
    {'id': 'a1', 'name': 'Cindy'},
    {'id': 'deleted', 'name': 'Deleted', 'deletedAt': '2026'},
  ];
  a.routes['GET /servers/s1/members'] = (_) => [
    {'userId': 'alice', 'name': 'Self'},
    {'userId': 'bob', 'displayName': 'Bob'},
  ];
  return (w, a);
}

Widget host(Widget child) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(body: child),
);
