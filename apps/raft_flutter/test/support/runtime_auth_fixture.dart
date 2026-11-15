// A small workspace and fake Computer APIs for the runtime sign-in, usage and
// limit reset tests: no network. The usage and sign-in clients are real; their
// `get` / `post` read the routes below.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/runtime_account_usage.dart';
import 'package:raft_flutter/data/runtime_auth.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_ui/raft_ui.dart';

class FixtureClient extends RaftClient {
  FixtureClient()
    : super(
        origin: 'https://fixture.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      <dynamic>[];
}

/// The Computer `c` of server `s`, with a few agents.
class FixtureWorkspace extends WorkspaceController {
  FixtureWorkspace(super.client) {
    server = RaftRecord({'id': 's', 'role': 'member'});
  }

  /// The `readiness` of Computer `c`, as the machine list sends it.
  Map<String, dynamic>? readiness;
  List<Map<String, dynamic>> agents = const [];
  List<String> runtimes = const ['claude', 'codex', 'qoder', 'pi', 'qwen'];

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      switch (path) {
        '/agents' => agents,
        '/servers/s/machines' => {
          'machines': [
            {
              'id': 'c',
              'name': 'build-box',
              'status': 'online',
              'runtimes': runtimes,
              'computerAttachedByCurrentUser': true,
              'readiness': ?readiness,
            },
          ],
        },
        _ => <dynamic>[],
      };

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async =>
      <String, dynamic>{};
}

/// What the Computer's runtime-auth and usage routes answer, and what was
/// asked of them.
class FakeComputerApi {
  FakeComputerApi({Map<String, dynamic>? view}) : view = view ?? authView();

  /// The `GET …/runtime-auth` answer.
  Map<String, dynamic> view;

  /// The `GET …/runtime-account-usage/<provider>` answer.
  Map<String, dynamic> usage = const {'state': 'missing'};
  final gets = <String>[], posts = <String>[];
  final bodies = <String, Map<String, dynamic>>{};

  /// `POST` answers by path suffix; a Future or a throwing function.
  final answers = <String, Object? Function(Map<String, dynamic> body)>{};
  final events = StreamController<RaftEvent>.broadcast(sync: true);

  late final auth = RuntimeAuthClient(
    get: (path) async {
      gets.add(path);
      if (path.endsWith('/runtime-auth')) return view;
      final handler = answers['GET ${path.split('/runtime-auth').last}'];
      return handler?.call(const {});
    },
    post: (path, body) async {
      posts.add(path);
      bodies[path] = body;
      for (final entry in answers.entries) {
        if (path.endsWith(entry.key)) return entry.value(body);
      }
      return <String, dynamic>{};
    },
    events: events.stream,
  );

  late final usageClient = RuntimeAccountUsageClient(
    get: (path) async {
      gets.add(path);
      return usage;
    },
    post: (path, body) async {
      posts.add(path);
      bodies[path] = body;
      for (final entry in answers.entries) {
        if (path.endsWith(entry.key)) return entry.value(body);
      }
      return {'accepted': true, 'state': 'requested'};
    },
  );

  Future<void> dispose() async {
    auth.dispose();
    await events.close();
  }
}

/// A `GET …/runtime-auth` answer: [runtimes] maps a runtime-auth id to its
/// status object (`{kind: logged_out}`).
Map<String, dynamic> authView({
  Map<String, Map<String, dynamic>> runtimes = const {},
  String availability = 'ok',
  bool canAct = true,
  List<String>? supported,
  List<String>? logout,
}) => {
  'status': {'runtimes': runtimes},
  'availability': availability,
  'canAct': canAct,
  'runtimes': ?supported,
  'logoutRuntimes': ?logout,
};

Map<String, dynamic> usageSnapshot({
  String provider = 'claude',
  String health = 'ok',
  int? resets,
  double used = .42,
  String windowStatus = 'ok',
}) => {
  'state': 'fresh',
  'snapshot': {
    'provider': provider,
    'collectedAt': DateTime.now()
        .subtract(const Duration(minutes: 5))
        .toUtc()
        .toIso8601String(),
    'accounts': [
      {
        'accountKey': 'k',
        'planLabel': 'Max',
        'maskedLabel': 'ali****@example.com',
        'health': health,
        'limitResetsAvailable': ?resets,
        'windows': [
          {
            'id': '5h',
            'label': '5h',
            'status': windowStatus,
            'usedRatio': used,
            'resetsAt': DateTime.now()
                .add(const Duration(hours: 3))
                .toUtc()
                .toIso8601String(),
          },
        ],
      },
    ],
  },
};

/// A pointer window (hover cards) or a finger (the bottom sheet).
Widget fixtureHost(Widget child, {bool touch = false}) => MaterialApp(
  theme: raftTheme().copyWith(
    platform: touch ? TargetPlatform.android : TargetPlatform.linux,
  ),
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

Future<FixtureWorkspace> fixtureWorkspace(WidgetTester t) async {
  final client = FixtureClient();
  final w = FixtureWorkspace(client);
  addTearDown(() async {
    w.dispose();
    await client.stream.close();
    await client.dispose();
  });
  await w.entityDirectory.preload();
  return w;
}

/// Pumps frames until [finder] matches or [max] frames pass (async fakes
/// answer in microtasks; the card builds over a few frames).
Future<void> settle(WidgetTester t, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}
