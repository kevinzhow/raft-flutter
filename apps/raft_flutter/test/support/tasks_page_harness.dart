// A scripted server for the Tasks page tests: the app's real client over a Dio
// adapter that records every request and answers GET /tasks/server (paged),
// GET /tasks/server/counts and the per-task writes from a task list.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_model.dart';
import 'package:raft_flutter/features/tasks_page/tasks_page_store.dart';
import 'package:raft_ui/raft_ui.dart';

const meId = 'alice';

Map<String, dynamic> pageTask(
  String id, {
  int? number,
  String status = 'todo',
  String? claimedBy,
  String createdBy = meId,
  String activityAt = '2026-11-17T10:00:00.000Z',
  String channelId = 'c1',
  Map<String, dynamic> extra = const {},
}) => {
  'id': id,
  'taskNumber': number ?? int.tryParse(id.replaceAll(RegExp(r'\D'), '')) ?? 1,
  'title': 'Task $id',
  'status': status,
  'channelId': channelId,
  'channelName': 'test',
  'channelType': 'channel',
  'createdAt': '2026-11-01T00:00:00.000Z',
  'updatedAt': activityAt,
  'activityAt': activityAt,
  'createdByType': 'user',
  'createdById': createdBy,
  if (claimedBy != null) 'claimedByType': 'user',
  if (claimedBy != null) 'claimedById': claimedBy,
  'isLegacy': false,
  'conversationAnchored': true,
  'conversationChannelId': 'conv-$id',
  'conversationReplyCount': 0,
  ...extra,
};

class TasksServer implements HttpClientAdapter {
  TasksServer({this.flag = true, List<Map<String, dynamic>>? tasks})
    : tasks = tasks ?? [];

  final bool flag;
  List<Map<String, dynamic>> tasks;
  final requests = <RequestOptions>[];

  /// Answers that replace the built-in ones: `'PATCH /tasks/t1/status'`.
  final routes = <String, (int, Object?) Function(RequestOptions)>{};

  /// Held answers: a request whose key is here waits for the completer.
  final holds = <String, Completer<void>>{};

  Iterable<RequestOptions> get taskReads =>
      requests.where((r) => r.path == '/tasks/server');
  Iterable<RequestOptions> get countReads =>
      requests.where((r) => r.path == '/tasks/server/counts');
  Iterable<RequestOptions> writes(String method) =>
      requests.where((r) => r.method == method && r.path.startsWith('/tasks/'));

  Map<String, String> query(RequestOptions o) => {
    for (final e in o.queryParameters.entries) e.key: '${e.value}',
  };

  bool _matches(Map<String, dynamic> t, Map<String, String> q) {
    List<String> list(String key) =>
        q[key] == null ? const [] : q[key]!.split(',');
    final status = list('status');
    if (status.isNotEmpty && !status.contains(t['status'])) return false;
    final channel = list('channel');
    if (channel.isNotEmpty && !channel.contains(t['channelId'])) return false;
    final assignee = list('assignee');
    final claimed = t['claimedById'] == null
        ? 'unassigned'
        : '${t['claimedByType']}:${t['claimedById']}';
    if (assignee.isNotEmpty && !assignee.contains(claimed)) return false;
    final creator = list('creator');
    if (creator.isNotEmpty &&
        !creator.contains('${t['createdByType']}:${t['createdById']}')) {
      return false;
    }
    final text = q['q'];
    if (text != null && text.isNotEmpty && !matchesQuery(t, text)) {
      return false;
    }
    switch (q['relation']) {
      case 'assigned_to_me':
        return t['claimedById'] == meId;
      case 'created_by_me':
        return t['createdById'] == meId && t['claimedById'] != meId;
      case 'from_my_message':
        return false;
    }
    return true;
  }

  List<Map<String, dynamic>> _sorted(
    Iterable<Map<String, dynamic>> rows,
    String sort,
  ) {
    final list = rows.toList();
    int key(Map<String, dynamic> t) => DateTime.parse(
      '${sort == 'created' ? t['createdAt'] : t['activityAt']}',
    ).millisecondsSinceEpoch;
    list.sort((a, b) {
      final c = key(b).compareTo(key(a));
      final order = c != 0 ? c : '${b['id']}'.compareTo('${a['id']}');
      return sort == 'activity_asc' ? -order : order;
    });
    return list;
  }

  (int, Object?) answer(RequestOptions o) {
    final route = routes['${o.method} ${o.path}'];
    if (route != null) return route(o);
    final q = query(o);
    switch ('${o.method} ${o.path}') {
      case 'POST /auth/login':
        return (
          200,
          {
            'accessToken': 'fixture-only',
            'refreshToken': 'fixture-only',
            'user': {'id': meId, 'name': 'alice'},
          },
        );
      case 'POST /feature-flags/evaluate':
        return (
          200,
          {
            'evaluations': [
              {'key': 'task_v2_conversations_v0', 'enabled': flag},
            ],
          },
        );
      case 'GET /tasks/server':
        final rows = _sorted(
          tasks.where((t) => _matches(t, q)),
          q['sort'] ?? 'activity',
        );
        final limit = int.parse(q['limit'] ?? '20');
        final from = int.tryParse(q['cursor'] ?? '') ?? 0;
        final slice = rows.skip(from).take(limit).toList();
        final more = from + limit < rows.length;
        return (
          200,
          {'tasks': slice, 'next_cursor': more ? '${from + limit}' : null},
        );
      case 'GET /tasks/server/counts':
        final rows = tasks.where((t) => _matches(t, q));
        return (
          200,
          {
            'counts': {
              for (final s in boardStatuses)
                s: rows.where((t) => t['status'] == s).length,
            },
            'relations': {
              'assigned_to_me': tasks
                  .where((t) => t['claimedById'] == meId)
                  .length,
              'created_by_me': 0,
              'from_my_message': 0,
            },
          },
        );
    }
    final status = RegExp(r'^/tasks/([^/]+)/status$').firstMatch(o.path);
    if (o.method == 'PATCH' && status != null) {
      final id = status.group(1)!;
      final body = o.data is Map ? o.data as Map : const {};
      final row = tasks.firstWhere((t) => t['id'] == id);
      row['status'] = body['status'];
      return (200, {'task': row});
    }
    final assignee = RegExp(r'^/tasks/([^/]+)/assignee$').firstMatch(o.path);
    if (o.method == 'PATCH' && assignee != null) {
      final id = assignee.group(1)!;
      final body = o.data is Map ? o.data as Map : const {};
      final row = tasks.firstWhere((t) => t['id'] == id);
      final who = body['assignee'];
      if (who is Map) {
        row['claimedByType'] = who['type'];
        row['claimedById'] = who['id'];
      } else {
        row.remove('claimedByType');
        row.remove('claimedById');
      }
      return (200, {'task': row});
    }
    if (o.method == 'DELETE' && RegExp(r'^/tasks/[^/]+$').hasMatch(o.path)) {
      tasks.removeWhere((t) => t['id'] == o.path.split('/').last);
      return (200, {'ok': true});
    }
    if (o.method == 'POST' && o.path == '/channels/threads/follow') {
      return (200, {'ok': true});
    }
    return (404, {'error': 'Unexpected endpoint'});
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final hold = holds['${options.method} ${options.path}'];
    if (hold != null) await hold.future;
    final (status, body) = answer(options);
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

Future<(WorkspaceController, TasksServer)> tasksFixture({
  bool flag = true,
  List<Map<String, dynamic>>? tasks,
  String role = 'owner',
}) async {
  final server = TasksServer(flag: flag, tasks: tasks);
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = server,
  );
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({'id': 's1', 'role': role});
  w.channel = RaftChannel({
    'id': 'c1',
    'name': 'test',
    'type': 'channel',
    'joined': true,
  });
  w.channels = [w.channel!];
  // The page's store lives with the controller; a test lets it go.
  addTearDown(() => TasksPageStore.of(w).dispose());
  return (w, server);
}

/// Lets the page's requests and its rebuilds settle.
Future<void> settleTasks(WidgetTester t, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// A MaterialApp with the Raft theme and the toast host, [child] as its page.
Widget tasksApp(
  Widget child, {
  TargetPlatform platform = TargetPlatform.linux,
}) => MaterialApp(
  theme: raftTheme().copyWith(platform: platform),
  home: RaftToastHost(child: Scaffold(body: child)),
);

void sizeWindow(WidgetTester t, Size size) {
  t.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(t.view.reset);
}
