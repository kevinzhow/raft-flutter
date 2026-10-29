// Field-parity (Web v1.21.23 shapes): server payloads from
// test/fixtures/field_parity/*.json against the Flutter readers. Fixtures only,
// no real server: every payload follows the v1.21.23 server source named in its
// `_source`.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_flutter/features/agent_migration_presentation.dart';
import 'package:raft_flutter/features/agent_trajectory_log.dart';
import 'package:raft_flutter/data/migration_error.dart';
import 'package:raft_ui/raft_ui.dart';

dynamic _fixture(String name) => jsonDecode(
  File('test/fixtures/field_parity/$name.json').readAsStringSync(),
);

class _Api implements HttpClientAdapter {
  final routes = <String, dynamic Function(RequestOptions)>{};
  final calls = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o);
    final route = routes['${o.method} ${o.path}'];
    return ResponseBody.fromString(
      jsonEncode(route == null ? {'error': 'Unexpected ${o.path}'} : route(o)),
      route == null ? 404 : 200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Client extends RaftClient {
  _Client(_Api api)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = api,
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  bool get connected => true;
  @override
  void connect() {}
  @override
  void joinChannel(String channelId) {}
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      <dynamic>[];
}

Future<(WorkspaceController, _Api)> _controller() async {
  final api = _Api();
  api.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  api.routes['GET /channels'] = (_) => <dynamic>[];
  api.routes['GET /channels/dm'] = (_) => <dynamic>[];
  api.routes['GET /channels/unread'] = (_) => {'channels': {}};
  api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
  final client = _Client(api);
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client)
    ..server = RaftRecord({'id': 's1', 'role': 'owner'});
  return (w, api);
}

void main() {
  group('agents-migration-target-detection', () {
    final body = _fixture('agents-migration-target-detection') as Map;
    String text(Map response, {bool zh = false}) {
      final presentation = migrationErrorPresentation(
        code: response['code'] as String,
        rawMessage: response['error'] as String,
        context: MigrationErrorContext.start,
        details: response['details'],
      );
      return presentation.message.resolve(
        (source) => zh ? raftChinese[source] ?? source : source,
      );
    }

    test('a target still detecting says to try again in a moment', () {
      final response = body['409 target still detecting'] as Map;
      expect(migrationHasCopy(response['code'] as String), isTrue);
      expect(
        text(response),
        'The target computer is still detecting its runtimes. Try again in a moment.',
      );
      expect(text(response, zh: true), '目标计算机正在检测运行时，请稍后重试。');
    });

    test('an unfinished detection names the runtime and says to rescan', () {
      final response = body['409 target detection did not finish'] as Map;
      expect(
        text(response),
        "The target computer's last runtime detection did not finish for claude. Rescan its runtimes on the Computer page, then try again.",
      );
      expect(
        text(response, zh: true),
        '目标计算机上一次运行时检测没有完成 claude 的检测。请在该计算机页面重新检测运行时后重试。',
      );
    });
  });

  group('channels-joint-create-same-admin', () {
    final body = _fixture('channels-joint-create-same-admin') as Map;

    test('the create request carries sameAdmin per invite target', () {
      final request = body['request'] as Map;
      expect(request['visibility'], 'joint');
      expect(
        (request['jointInvites'] as List).single,
        containsPair('sameAdmin', true),
      );
    });

    test('the created channel and its accepted invite parse', () {
      final response = Map<String, dynamic>.from(body['response'] as Map);
      final channel = RaftChannel(response);
      expect(
        (channel.id, channel.name, channel.type, channel.joined),
        ('c5555555-5555-4555-8555-555555555501', 'launch-room', 'joint', true),
      );
      final invite = (response['jointInvites'] as List).single as Map;
      expect(invite['status'], 'accepted');
      expect(invite['acceptedVia'], 'same_admin');
      // A direct connection leaves no pending invite to chase.
      expect(response['jointInvite'], isNull);
    });
  });

  group('channels-unread-thread-unread', () {
    final body = _fixture('channels-unread-thread-unread') as Map;

    test(
      'the summary with threadUnread still yields every channel count',
      () async {
        final (w, api) = await _controller();
        addTearDown(w.dispose);
        api.routes['GET /channels/unread'] = (_) => body['response'];
        await w.refreshUnread();
        expect(
          w.conversationReads.unread['77777777-7777-4777-8777-777777777777'],
          4,
        );
        expect(
          w.conversationReads.unread['88888888-8888-4888-8888-888888888888'],
          2,
        );
        expect(w.conversationReads.unread.containsKey('threadUnread'), isFalse);
      },
    );

    test('a stale-served summary is read like a fresh one', () async {
      final (w, api) = await _controller();
      addTearDown(w.dispose);
      api.routes['GET /channels/unread'] = (_) => body['stale response'];
      await w.refreshUnread();
      expect(
        w.conversationReads.unread['77777777-7777-4777-8777-777777777777'],
        1,
      );
      expect(w.conversationReads.unread.containsKey('stale'), isFalse);
    });
  });

  group('channels-followed-threads-paged', () {
    final body = _fixture('channels-followed-threads-paged') as Map;

    Future<List<Map<String, dynamic>>> read(String page) async {
      final (w, api) = await _controller();
      addTearDown(w.dispose);
      api.routes['GET /channels/threads/followed'] = (_) => body[page];
      await w.followedThreads.refresh();
      return w.followedThreads.threads;
    }

    test('a paged answer with next is followed to the last page', () async {
      final (w, api) = await _controller();
      addTearDown(w.dispose);
      final cursors = <Object?>[];
      api.routes['GET /channels/threads/followed'] = (o) {
        final cursor = o.queryParameters['cursor'];
        cursors.add(cursor);
        return body[cursor == null
            ? 'first page (limit=1)'
            : 'last page (cursor)'];
      };
      await w.followedThreads.refresh();
      final rows = w.followedThreads.threads;
      expect(rows.map((r) => r['threadChannelId']), [
        't1000000-0000-4000-8000-0000000000f2',
        't1000000-0000-4000-8000-0000000000f4',
      ]);
      expect(cursors, hasLength(2));
      expect(rows.first['hasMention'], isTrue);
      expect(rows.first['parentMessageCreatedAt'], '2026-10-10T08:00:00.000Z');
    });

    test(
      'the last page, an unpaged answer and a stale page all parse',
      () async {
        expect(await read('last page (cursor)'), hasLength(1));
        expect(await read('unpaged (no limit)'), hasLength(1));
        expect(await read('stale first page'), hasLength(1));
      },
    );
  });

  group('agents-activity-log-subagent-ended', () {
    final rows = [
      for (final row
          in (_fixture('agents-activity-log-subagent-ended') as Map)['rows']
              as List)
        Map<String, dynamic>.from(row as Map),
    ];

    test('every row with the new subagent phase and outcome is admitted', () {
      final admitted = admittedAgentTrajectoryRows(rows);
      expect(admitted, hasLength(rows.length));
      expect(mergeAgentTrajectoryLog(const [], admitted), hasLength(5));
    });

    testWidgets('the activity log draws them without an exception', (t) async {
      final client = _Client(_Api());
      final w = _Workspace(client)
        ..server = RaftRecord({'id': 's', 'role': 'owner'});
      addTearDown(() async {
        w.dispose();
        await client.stream.close();
        await client.dispose();
      });
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: AgentActivityTab(
              controller: w,
              agentId: 'agent',
              initialEntries: rows,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      // The badge of every lineage row, whatever its phase or outcome.
      expect(
        find.text('Subagent: Explore', findRichText: true),
        findsNWidgets(3),
      );
      expect(find.text('Subagent: Plan', findRichText: true), findsOneWidget);
      // The bare badge of the no-type row and, in the Raft look, the title of
      // the system row (the Web row keeps the entry title beside its badge).
      expect(find.text('Subagent', findRichText: true), findsNWidgets(2));
    });
  });
}
