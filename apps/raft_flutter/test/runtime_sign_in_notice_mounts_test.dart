// Web v1.24 `runtimeBelowDescription` (CreateAgentDialog.tsx, AgentProfileInfo
// .tsx, RuntimeConfigFields.tsx): under the Runtime field the picked runtime's
// "not signed in" notice shows, in the create-agent dialog (selected Computer,
// selected runtime) and in the profile's runtime editor (the agent's Computer,
// the draft runtime). Signed out is said, never enforced: Create and Save stay.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_runtime_editor.dart';
import 'package:raft_flutter/features/managed_agent_launcher.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/members_settings/runtime_forms.dart';
import 'support/runtime_auth_fixture.dart';

const _notice = ValueKey('runtime-picker-not-signed-in');

Map<String, dynamic> _view({
  bool codexOut = true,
  bool claudeOut = false,
  bool canAct = true,
}) => authView(
  canAct: canAct,
  runtimes: {
    'codex': {'kind': codexOut ? 'logged_out' : 'logged_in'},
    'claude': {'kind': claudeOut ? 'logged_out' : 'logged_in'},
  },
);

Map<String, dynamic> _machine({bool mine = true}) => {
  'id': 'mbp',
  'name': 'build-box',
  'status': 'online',
  'runtimes': ['codex', 'claude', 'pi'],
  'computerAttachedByCurrentUser': mine,
};

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
    selectServer('s');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final calls = <(String, String, dynamic)>[];
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
    calls.add((method, path, data));
    if (path.endsWith('/runtime-options')) {
      return {
        'options': [
          for (final r in ['codex', 'claude', 'pi'])
            {
              'runtimeId': r,
              'canSelectInThisContext': true,
              'runtimeFormV2': {'protocolVersion': 2},
            },
        ],
      };
    }
    if (path.endsWith('/runtime-forms/v2/codex')) {
      return msRuntimeForms['forms']['codex'];
    }
    if (path == '/agents/a1/runtime-form') return _editForm;
    if (path.endsWith('/option-sources/model')) {
      return {
        ...(_editForm['optionSources'] as Map)['model'] as Map,
        'options': [
          {'value': 'loaded-model', 'label': 'Loaded Model'},
        ],
      };
    }
    if (method == 'PATCH') return _agent;
    return <dynamic>[];
  }
}

const _agent = {
  'id': 'a1',
  'name': 'alpha',
  'displayName': 'Alpha',
  'status': 'inactive',
  'activity': 'offline',
  'runtime': 'codex',
  'model': 'gpt-5-codex',
  'machineId': 'mbp',
  'creatorType': 'user',
  'creatorId': 'alice',
};

const _editForm = {
  'protocolVersion': 2,
  'runtimeId': 'codex',
  'schemaVersion': 'codex.edit.fixture.v1',
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
    },
  },
  'uiSchema': {
    'order': ['model', 'command'],
  },
  'optionSources': {
    'model': {
      'protocolVersion': 1,
      'runtimeId': 'codex',
      'schemaVersion': 'codex.edit.fixture.v1',
      'sourceId': 'model',
      'kind': 'select',
      'pointer': '/model',
    },
  },
  'values': {'model': 'loaded-model', 'command': 'loaded-command'},
};

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  List<Map<String, dynamic>> machines = [];
  final posts = <Map<String, dynamic>>[];

  /// A role may create agents yet not edit Computers (no such stock role: the
  /// server's capability set is what decides).
  bool mayEditMachines = true;
  @override
  bool can(String capability, {RaftChannel? resource}) =>
      capability == 'editMachines' && !mayEditMachines
      ? false
      : super.can(capability, resource: resource);
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      path == '/servers/s/machines'
      ? {'machines': machines}
      : (client as _Client).request('GET', path);
  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    posts.add({'method': method, 'path': path, 'data': data});
    (client as _Client).calls.add((method, path, data));
    return {'id': 'agent-new', 'name': data is Map ? data['name'] : null};
  }
}

void main() {
  late _Client c;
  late _Workspace w;
  late FakeComputerApi api;

  setUp(() {
    api = FakeComputerApi(view: _view());
    c = _Client();
  });
  Future<void> bind({String role = 'owner'}) async {
    w = _Workspace(c)..server = RaftRecord({'id': 's', 'role': role});
    w.agentTabCache.putIfAbsent('runtime-auth', () => api.auth);
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
      await c.dispose();
      await api.dispose();
    });
  }

  const sizes = <(Size, TargetPlatform)>[
    (Size(856, 944), TargetPlatform.android),
    (Size(944, 856), TargetPlatform.android),
    (Size(390, 844), TargetPlatform.linux),
  ];

  group('create-agent dialog', () {
    Future<void> open(
      WidgetTester t, {
      Size size = const Size(390, 1400),
      TargetPlatform platform = TargetPlatform.linux,
      bool mine = true,
      String role = 'owner',
    }) async {
      await bind(role: role);
      w.mayEditMachines = mine;
      w.machines = [_machine(mine: mine)];
      await t.binding.setSurfaceSize(size);
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: platform),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showManagedAgentForm(context, w, initialName: 'Alice'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    Future<void> pick(WidgetTester t, String label) async {
      await t.tap(find.byType(RaftSelectField<String>).last);
      await t.pumpAndSettle();
      await t.tap(find.text(label).last);
      await t.pumpAndSettle();
    }

    for (final (size, platform) in sizes) {
      testWidgets('a signed-out runtime says so; Create still works '
          '($size ${platform.name})', (t) async {
        await open(t, size: size, platform: platform);
        await pick(t, 'Codex CLI');
        expect(find.byKey(_notice), findsOneWidget);
        expect(find.text('Codex CLI is not signed in on build-box.'), findsOne);
        expect(find.byKey(const ValueKey('runtime-picker-sign-in')), findsOne);
        await t.ensureVisible(find.widgetWithText(RaftButton, 'Create'));
        await t.tap(find.widgetWithText(RaftButton, 'Create'));
        await t.pumpAndSettle();
        expect(w.posts, hasLength(1));
        expect((w.posts.single['data'] as Map)['runtime'], 'codex');
      });
    }

    testWidgets('switching the runtime moves the notice', (t) async {
      api.view = _view(codexOut: false, claudeOut: true);
      await open(t);
      await pick(t, 'Codex CLI');
      expect(find.byKey(_notice), findsNothing);
      await pick(t, 'Claude Code');
      expect(find.text('Claude Code is not signed in on build-box.'), findsOne);
      await pick(t, 'Codex CLI');
      expect(find.byKey(_notice), findsNothing);
    });

    testWidgets('a person who may not see the Computer\'s accounts: no '
        'notice, no read', (t) async {
      await open(t, mine: false);
      await pick(t, 'Codex CLI');
      expect(find.byKey(_notice), findsNothing);
      expect(api.gets, isEmpty);
    });

    testWidgets('a runtime with no sign-in of its own: no notice, no read', (
      t,
    ) async {
      await open(t);
      api.gets.clear();
      await pick(t, 'Pi');
      expect(find.byKey(_notice), findsNothing);
      expect(api.gets, isEmpty);
    });

    testWidgets('signed in: nothing shows and no gap is left', (t) async {
      api.view = _view(codexOut: false);
      await open(t);
      await pick(t, 'Codex CLI');
      expect(find.byKey(_notice), findsNothing);
    });
  });

  group('agent runtime editor', () {
    Future<void> open(
      WidgetTester t, {
      Size size = const Size(900, 2400),
      TargetPlatform platform = TargetPlatform.linux,
      bool mine = true,
      String role = 'owner',
    }) async {
      await bind(role: role);
      await t.binding.setSurfaceSize(size);
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: platform),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAgentRuntimeEditor(
                  context,
                  controller: w,
                  agent: _agent,
                  machine: _machine(mine: mine),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> edit(WidgetTester t) async {
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    for (final (size, platform) in sizes) {
      testWidgets('a signed-out runtime says so; Save still works '
          '($size ${platform.name})', (t) async {
        await open(t, size: size, platform: platform);
        expect(find.byKey(_notice), findsNothing, reason: 'not editing');
        await edit(t);
        expect(find.text('Codex CLI is not signed in on build-box.'), findsOne);
        final command = find.descendant(
          of: find.byKey(const ValueKey('runtime-command')),
          matching: find.byType(TextField),
        );
        await t.enterText(command, 'updated-command');
        await t.pump();
        await t.ensureVisible(
          find.byKey(const ValueKey('runtime-editor-save')),
        );
        await t.tap(find.byKey(const ValueKey('runtime-editor-save')));
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('agent-runtime-editor')),
          findsNothing,
        );
        final patch = c.calls.singleWhere((call) => call.$1 == 'PATCH');
        expect((patch.$3 as Map)['formValues']['command'], 'updated-command');
        expect(find.byKey(_notice), findsNothing);
      });
    }

    testWidgets('switching the draft runtime moves the notice', (t) async {
      api.view = _view(codexOut: false, claudeOut: true);
      await open(t);
      await edit(t);
      expect(find.byKey(_notice), findsNothing);
      await t.tap(find.byKey(const ValueKey('runtime-editor-runtime')));
      await t.pumpAndSettle();
      await t.tap(find.text('Claude Code').last);
      await t.pumpAndSettle();
      expect(find.text('Claude Code is not signed in on build-box.'), findsOne);
    });

    testWidgets('a person who may not see the Computer\'s accounts: no '
        'notice, no read', (t) async {
      await open(t, mine: false, role: 'member');
      await edit(t);
      expect(find.byKey(const ValueKey('agent-runtime-editor')), findsOne);
      expect(find.byKey(_notice), findsNothing);
      expect(api.gets, isEmpty);
    });

    testWidgets('a runtime with no sign-in of its own: no notice', (t) async {
      api.view = _view(codexOut: false);
      await open(t);
      await edit(t);
      await t.tap(find.byKey(const ValueKey('runtime-editor-runtime')));
      await t.pumpAndSettle();
      await t.tap(find.text('Pi').last);
      await t.pumpAndSettle();
      expect(find.byKey(_notice), findsNothing);
    });
  });
}
