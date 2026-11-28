// A workspace with one agent whose runtime editor reads the server-described
// protocol-v2 form (Web 1.24 AgentProfileInfo `saveRuntimeFormV2Edit`): the
// agent's edit form, the create forms of the runtimes it can switch to, their
// option sources and the PATCH it ends in.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> editorAgent({
  String runtime = 'codex',
  String activity = 'offline',
  String status = 'inactive',
  Map<String, dynamic>? extra,
}) => {
  'id': 'a1',
  'name': 'alpha',
  'displayName': 'Alpha',
  'status': status,
  'activity': activity,
  'runtime': runtime,
  'model': 'gpt-5-codex',
  'machineId': 'm1',
  'reasoningEffort': 'medium',
  'creatorType': 'user',
  'creatorId': 'alice',
  ...?extra,
};

/// A v2 form of [runtime]: a required model (option source), a text command
/// and a Fast mode switch. [values] marks an edit form.
Map<String, dynamic> editorForm(
  String runtime, {
  Map<String, dynamic>? values,
}) => {
  'protocolVersion': 2,
  'runtimeId': runtime,
  'schemaVersion': '$runtime.fixture.v1',
  'dataSchema': {
    'type': 'object',
    'required': ['model'],
    'properties': {
      'model': {
        'type': 'string',
        'title': 'Model from Computer',
        'x-optionSource': 'model',
      },
      'command': {'type': 'string', 'title': 'Command from Computer'},
      'fastMode': {'type': 'boolean', 'title': 'Fast mode'},
    },
  },
  'uiSchema': {
    'order': ['model', 'command', 'fastMode'],
  },
  'optionSources': {
    'model': {
      'protocolVersion': 1,
      'runtimeId': runtime,
      'schemaVersion': '$runtime.fixture.v1',
      'sourceId': 'model',
      'kind': 'select',
      'pointer': '/model',
    },
  },
  'values': ?values,
};

class EditorClient extends RaftClient {
  EditorClient(this.agent)
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
    selectServer('s');
  }
  Map<String, dynamic> agent;
  final calls = <(String, String, dynamic)>[];

  /// `GET /agents/a1/runtime-options`.
  List<Map<String, dynamic>> options = [
    {
      'runtimeId': 'codex',
      'canSelectInThisContext': true,
      'runtimeFormV2': {'protocolVersion': 2},
    },
    {
      'runtimeId': 'claude',
      'canSelectInThisContext': true,
      'runtimeFormV2': {'protocolVersion': 2},
    },
    // No marker: this runtime has no form on the server.
    {'runtimeId': 'opencode', 'canSelectInThisContext': true},
  ];
  List<String> machineRuntimes = ['codex', 'claude', 'opencode'];
  String? configApply = 'when_idle';
  Object? patchError;
  Object? resetError;
  bool failUsageFlagEvaluation = false;
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}

  Iterable<(String, String, dynamic)> get patches =>
      calls.where((c) => c.$1 == 'PATCH');
  Iterable<(String, String, dynamic)> get formReads => calls.where(
    (c) => c.$2.contains('runtime-form') && !c.$2.contains('option-sources'),
  );

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
    calls.add((method, path, data));
    if (method == 'POST' && path == '/feature-flags/evaluate') {
      if (failUsageFlagEvaluation) {
        throw const FormatException('Invalid feature flag response');
      }
      return {
        'evaluations': [
          {'key': 'agent_usage_v0', 'enabled': false},
        ],
      };
    }
    if (path == '/agents') return [agent];
    if (path == '/agents/a1' && method == 'GET') return agent;
    if (path == '/agents/a1' && method == 'PATCH') {
      if (patchError case final Exception e) throw e;
      return {...agent, 'configApply': ?configApply};
    }
    if (path == '/agents/a1/reset') {
      if (resetError case final Exception e) throw e;
      return {};
    }
    if (path.endsWith('/skills')) return {'global': [], 'workspace': []};
    if (path == '/agents/a1/migration') return {'migration': null};
    if (path == '/servers/s/machines') {
      return {
        'machines': [
          {
            'id': 'm1',
            'name': 'Box',
            'status': 'online',
            'runtimes': machineRuntimes,
          },
        ],
      };
    }
    if (path == '/agents/a1/runtime-options') return {'options': options};
    if (path == '/agents/a1/runtime-form') {
      return editorForm(
        '${agent['runtime']}',
        values: {
          'model': 'loaded-model',
          'command': 'loaded-command',
          'fastMode': false,
        },
      );
    }
    final create = RegExp(r'/servers/s/machines/m1/runtime-forms/v2/([^/]+)$')
        .firstMatch(path);
    if (create != null) return editorForm(create.group(1)!);
    final source = RegExp(
      r'/runtime-forms/v2/([^/]+)/option-sources/model$|^/agents/a1/runtime-form/option-sources/model$',
    ).firstMatch(path);
    if (source != null) {
      final runtime = source.group(1) ?? '${agent['runtime']}';
      return {
        'protocolVersion': 1,
        'runtimeId': runtime,
        'schemaVersion': '$runtime.fixture.v1',
        'sourceId': 'model',
        'kind': 'select',
        'pointer': '/model',
        'options': [
          {'value': 'loaded-model', 'label': 'Loaded Model'},
          {'value': '$runtime-default', 'label': '$runtime default'},
        ],
        'defaultValue': '$runtime-default',
      };
    }
    throw StateError('Unexpected fixture endpoint: $method $path');
  }
}

/// Mounts the agent's profile and opens its runtime editor.
Future<EditorClient> openRuntimeEditor(
  WidgetTester tester,
  Map<String, dynamic> agent, {
  Size size = const Size(900, 2400),
  TargetPlatform platform = TargetPlatform.android,
  void Function(EditorClient)? setup,
  bool toasts = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = EditorClient(agent);
  setup?.call(c);
  final w = WorkspaceController(c)
    ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'});
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    w.dispose();
    await c.stream.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: platform),
      builder: toasts ? (context, child) => RaftToastHost(child: child!) : null,
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
  return c;
}

Finder editorKey(String key) => find.byKey(ValueKey(key));

bool runtimeEditorSaveEnabled(WidgetTester tester) =>
    tester
        .widget<RaftButton>(
          find.descendant(
            of: editorKey('runtime-editor-save'),
            matching: find.byType(RaftButton),
          ),
        )
        .onPressed !=
    null;

/// Picks [label] in the select at [key].
Future<void> chooseInEditor(
  WidgetTester tester,
  String key,
  String label,
) async {
  await tester.tap(editorKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

/// Types into the form's Command field (an edit that is a change by itself).
Future<void> typeCommand(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(
      of: editorKey('runtime-command'),
      matching: find.byType(TextField),
    ),
    text,
  );
  await tester.pump();
}

Future<void> saveRuntimeEditor(WidgetTester tester) async {
  await tester.tap(editorKey('runtime-editor-save'));
  await tester.pumpAndSettle();
}
