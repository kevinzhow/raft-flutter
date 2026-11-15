import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/runtime_form_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

/// A runtime-form fixture of the Web source mirror (packages/runtime-form at
/// tag v1.24.0-source.1), shared with the raft_client tests.
Map<String, dynamic> runtimeFormFixture(String name) {
  final dir = [
    '../../packages/raft_client/test/fixtures/runtime_form',
    'packages/raft_client/test/fixtures/runtime_form',
  ].firstWhere((path) => File('$path/$name').existsSync());
  return Map<String, dynamic>.from(
    jsonDecode(File('$dir/$name').readAsStringSync()) as Map,
  );
}

Map<String, dynamic> deepCopy(Object value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

class RuntimeFormClient extends RaftClient {
  RuntimeFormClient()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

/// Serves runtime-form reads from [routes] (path suffix to a body or a
/// function of the query) and records every read and every create/save.
class RuntimeFormWorkspace extends WorkspaceController {
  RuntimeFormWorkspace(super.client);

  /// Matched by `path.endsWith`, longest suffix first.
  final routes = <String, Object? Function(Map<String, dynamic>? query)>{};
  final reads = <({String path, Map<String, dynamic>? query})>[];
  final commands = <({String method, String path, dynamic data})>[];
  Object? failWith;

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    reads.add((path: path, query: query));
    final failure = failWith;
    if (failure != null && !path.contains('/option-sources/')) throw failure;
    final suffixes = routes.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final suffix in suffixes) {
      if (path.endsWith(suffix)) return routes[suffix]!(query);
    }
    throw RaftApiException('Not found: $path', status: 404);
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    commands.add((method: method, path: path, data: data));
    return {'id': 'agent-new'};
  }
}

class RuntimeFormRig {
  RuntimeFormRig() {
    client = RuntimeFormClient()..user = RaftRecord({'id': 'alice'});
    client.selectServer('s');
    workspace = RuntimeFormWorkspace(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'});
  }
  late final RuntimeFormClient client;
  late final RuntimeFormWorkspace workspace;
  final controllers = <RuntimeFormController>[];

  RuntimeFormController controller(String runtimeId, {String? agentId}) {
    final c = RuntimeFormController(
      workspace,
      machineId: 'm',
      runtimeId: runtimeId,
      agentId: agentId,
      valid: () => true,
      language: 'en',
    );
    controllers.add(c);
    return c;
  }

  Future<void> dispose() async {
    for (final c in controllers) {
      c.dispose();
    }
    workspace.dispose();
    await client.stream.close();
    await client.dispose();
  }

  /// The fields of [form] in a scrollable page; links open into [opened].
  Widget page(
    RuntimeFormController form, {
    List<Uri>? opened,
    List<Widget> leading = const [],
  }) => MaterialApp(
    theme: raftTheme(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: RuntimeFormFields(
          form: form,
          leading: leading,
          openLink: (uri) => opened?.add(uri),
        ),
      ),
    ),
  );
}

Finder runtimeKey(String key) => find.byKey(ValueKey(key));

/// The same text as shown in Chinese Raft.
Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

/// The base route of a create form for [runtime] on machine `m`.
String runtimeFormBase(String runtime) =>
    '/servers/s/machines/m/runtime-forms/v2/$runtime';
