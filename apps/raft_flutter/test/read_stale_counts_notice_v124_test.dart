import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/stale_counts_notice.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web v1.24 StaleCountsNotice (task #164): one notice under the sidebar head
/// and one under the Activity head while their reads may be out of date; it
/// goes away when a clean answer arrives.
class _Adapter implements HttpClientAdapter {
  final calls = <String>[];
  final answers =
      <
        String,
        List<({int status, Object body, Map<String, String> headers})>
      >{};

  void queue(
    String path,
    int status,
    Object body, [
    Map<String, String> headers = const {},
  ]) => (answers[path] ??= []).add((
    status: status,
    body: body,
    headers: headers,
  ));

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o.path);
    if (o.path == '/auth/login') {
      return _body(200, {
        'accessToken': 'fixture-only',
        'refreshToken': 'fixture-only',
        'user': {'id': 'alice'},
      }, const {});
    }
    final list = answers[o.path];
    final next = list == null || list.isEmpty
        ? (
            status: 200,
            body: <String, dynamic>{'channels': {}},
            headers: const <String, String>{},
          )
        : list.length == 1
        ? list.first
        : list.removeAt(0);
    if (next.status == 0) {
      throw DioException.connectionError(requestOptions: o, reason: 'offline');
    }
    return _body(next.status, next.body, next.headers);
  }

  ResponseBody _body(int status, Object body, Map<String, String> headers) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
          for (final e in headers.entries) e.key: [e.value],
        },
      );

  @override
  void close({bool force = false}) {}
}

class _Client extends RaftClient {
  _Client(_Adapter adapter)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

void main() {
  Future<(WorkspaceController, _Adapter, _Client)> fixture() async {
    final adapter = _Adapter();
    final client = _Client(adapter);
    await client.login('fixture', 'fixture');
    client.selectServer('s1');
    final w = WorkspaceController(client);
    w.server = RaftRecord({'id': 's1', 'role': 'owner'});
    addTearDown(w.dispose);
    return (w, adapter, client);
  }

  Widget host(WorkspaceController w) => MaterialApp(
    theme: raftTheme(),
    home: Scaffold(
      body: Column(
        children: [StaleCountsNotice.sidebar(w), StaleCountsNotice.activity(w)],
      ),
    ),
  );

  Future<void> read(WidgetTester t, _Client c, String path) async {
    await t.runAsync(() async {
      try {
        await c.get(path);
      } catch (_) {}
    });
    await t.pump();
  }

  final sidebar = find.byKey(const ValueKey('sidebar-stale-notice'));
  final activity = find.byKey(const ValueKey('activity-stale-notice'));

  testWidgets(
    '[BP-READ-050] a stale unread read shows the sidebar notice; a clean answer removes it',
    (t) async {
      final (w, adapter, client) =
          await t.runAsync(fixture) as (WorkspaceController, _Adapter, _Client);
      await t.pumpWidget(host(w));
      expect(sidebar, findsNothing);
      expect(activity, findsNothing);
      adapter.queue(
        '/channels/unread',
        200,
        {'channels': {}},
        {'x-raft-stale': 'rw_overloaded'},
      );
      await read(t, client, '/channels/unread');
      expect(sidebar, findsOneWidget);
      expect(activity, findsNothing);
      expect(
        find.text(
          "Unread counts may be out of date. They'll update on their own when Raft catches up.",
        ),
        findsOneWidget,
      );
      expect(find.byType(RaftSpinner), findsOneWidget);
      adapter.answers.clear();
      await read(t, client, '/channels/unread');
      expect(sidebar, findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'an unconfigured Activity read says temporarily unavailable, as a warning',
    (t) async {
      final (w, adapter, client) =
          await t.runAsync(fixture) as (WorkspaceController, _Adapter, _Client);
      await t.pumpWidget(host(w));
      adapter.queue('/channels/inbox', 503, {
        'error': 'no rw',
        'code': 'rw_unconfigured',
      });
      await read(t, client, '/channels/inbox');
      expect(activity, findsOneWidget);
      expect(sidebar, findsNothing);
      expect(find.text('Activity is temporarily unavailable.'), findsOneWidget);
      expect(find.byType(RaftSpinner), findsNothing);
      adapter.answers.clear();
      adapter.queue('/channels/inbox', 200, {'items': []});
      await read(t, client, '/channels/inbox');
      expect(activity, findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );
}
