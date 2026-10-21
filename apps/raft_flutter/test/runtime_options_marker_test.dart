import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/computer_detail_view.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_flutter/features/managed_agent_launcher.dart';
import 'package:raft_flutter/features/management_support.dart';
import 'package:raft_flutter/features/runtime_options_request.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bulk_agent_model_test.dart' show ModelClient, machine;

const _header = 'X-Raft-Runtime-Form-V2';

/// The marker each `.../runtime-options` read carried (null = none).
final _seen = <String, String?>{};

void _record(String path) {
  if (path.endsWith('/runtime-options')) {
    _seen[path] = RaftClient.currentRequestHeaders[_header];
  }
}

class _BulkClient extends ModelClient {
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
  }) {
    _record(path);
    return super.request(method, path, data: data, query: query);
  }
}

class _EditorClient extends RaftClient {
  _EditorClient()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
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
  }) async {
    _record(path);
    if (path == '/agents' || path == '/agents/a1') {
      final agent = {
        'id': 'a1',
        'name': 'alpha',
        'displayName': 'Alpha',
        'status': 'inactive',
        'activity': 'offline',
        'runtime': 'codex',
        'model': 'gpt-5-codex',
        'machineId': 'm1',
        'creatorType': 'user',
        'creatorId': 'alice',
      };
      return path == '/agents' ? [agent] : agent;
    }
    if (path == '/servers/s/machines') return {'machines': <dynamic>[]};
    if (path == '/agents/a1/runtime-options') {
      return {
        'options': [
          {'runtimeId': 'codex', 'canSelectInThisContext': true},
        ],
      };
    }
    return [];
  }
}

class _CreateWorkspace extends WorkspaceController {
  _CreateWorkspace(super.client);
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    _record(path);
    if (path == '/servers/s/machines') {
      return {
        'machines': [
          {
            'id': 'mbp',
            'name': 'Box',
            'status': 'online',
            'runtimes': ['codex'],
          },
        ],
      };
    }
    if (path.endsWith('/runtime-options')) {
      return {
        'options': [
          {'runtimeId': 'codex', 'canSelectInThisContext': true},
        ],
      };
    }
    throw RaftApiException('Not found: $path', status: 404);
  }
}

void main() {
  setUp(() {
    _seen.clear();
    SharedPreferences.setMockInitialValues({});
  });

  test('readRuntimeOptions marks the read, and only that read', () async {
    final client = _EditorClient()..selectServer('s');
    addTearDown(() async {
      await client.stream.close();
      await client.dispose();
    });
    await readRuntimeOptions(() => client.get('/agents/a1/runtime-options'));
    expect(_seen['/agents/a1/runtime-options'], '1');
    _seen.clear();
    await client.get('/agents/a1/runtime-options');
    expect(_seen['/agents/a1/runtime-options'], isNull);
  });

  testWidgets('the Runtime editor reads an agent\'s runtime-options marked', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = _EditorClient()..selectServer('s');
    final w = WorkspaceController(c)
      ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'});
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: FleetDetail(
            controller: w,
            computers: false,
            initial: const {'id': 'a1'},
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agent-edit-runtime')));
    await tester.pumpAndSettle();
    expect(_seen['/agents/a1/runtime-options'], '1');
  });

  testWidgets('Create Agent reads the Computer\'s runtime-options marked', (
    tester,
  ) async {
    final c = _EditorClient()..selectServer('s');
    final w = _CreateWorkspace(c)
      ..server = RaftRecord({'id': 's', 'role': 'owner'});
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
      await c.dispose();
    });
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showManagedAgentForm(context, w),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(_seen['/servers/s/machines/mbp/runtime-options'], '1');
  });

  testWidgets('bulk Change model reads each agent\'s runtime-options marked', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = _BulkClient();
    final workspace = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'});
    rememberServerFlag(
      workspace,
      'bulk_change_model_web_v0',
      true,
      pageIdentity(workspace),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      workspace.dispose();
      await client.stream.close();
      await client.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: ComputerDetailPanel(controller: workspace, machine: machine),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> tap(String key) async {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await tap('computer-agents-select');
    await tap('computer-agent-a1');
    await tap('computer-bulk-change-model');
    await tap('bulk-model-runtime');
    await tester.tap(find.text('Claude Code').last);
    await tester.pumpAndSettle();
    await tap('bulk-model-next');
    expect(_seen['/agents/a1/runtime-options'], '1');
  });
}
