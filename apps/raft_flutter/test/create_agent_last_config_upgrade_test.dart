// Upgrade of the remembered Create agent configuration (Web
// utils/createAgentLastConfig.ts): the previous release stored
// {machineId, runtime, model, customModelMode}; Web now writes only
// {machineId, runtime}. Both read back, nothing extra is shown, no model is
// restored, and the next create rewrites the record in the new shape.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/create_agent_last_config.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/managed_agent_launcher.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'parity/cases/members_settings/runtime_forms.dart';

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final posts = <Map<String, dynamic>>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/servers/s/machines') {
      return {
        'machines': [
          for (final (id, name) in [
            ('mbp', 'Studio Mac'),
            ('rig', 'Build Rig'),
          ])
            {
              'id': id,
              'name': name,
              'status': 'online',
              'runtimes': ['codex', 'claude'],
            },
        ],
      };
    }
    if (path.endsWith('/runtime-options')) {
      return {
        'options': [
          for (final r in ['claude', 'codex'])
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
    if (path.endsWith('/runtime-forms/v2/codex/option-sources/model')) {
      return {
        ...(msRuntimeForms['forms']['codex']['optionSources']['model'] as Map),
        'options': [
          {'value': 'gpt-5', 'label': 'GPT-5'},
          {'value': 'gpt-5-mini', 'label': 'GPT-5 Mini'},
        ],
        'defaultValue': 'gpt-5',
        'customValueAllowed': true,
      };
    }
    throw RaftApiException('Not found: $path', status: 404);
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    posts.add({'method': method, 'path': path, 'data': data});
    return {'id': 'agent-new', 'name': data['name']};
  }
}

const _key = 'raft:create-agent:last-config:v1:s';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Client c;
  late _Workspace w;
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    DevicePreferences.adopt(prefs);
    c = _Client()..user = RaftRecord({'id': 'alice'});
    c.selectServer('s');
    w = _Workspace(c)..server = RaftRecord({'id': 's', 'role': 'owner'});
  });
  tearDown(() async {
    DevicePreferences.reset();
    w.dispose();
    await c.stream.close();
    await c.dispose();
  });

  Future<void> open(WidgetTester t, String name) async {
    await t.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showManagedAgentForm(context, w, initialName: name),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  Future<void> create(WidgetTester t) async {
    await t.tap(
      find.descendant(
        of: find.byType(RaftAgentDialogButton),
        matching: find.text('Create'),
      ),
    );
    await t.pumpAndSettle();
  }

  test('the previous release record and the one Web writes now both read', () {
    for (final raw in [
      '{"machineId":"rig","runtime":"codex","model":"gpt-5-mini","customModelMode":false}',
      '{"machineId":"rig","runtime":"codex","model":"","customModelMode":"unexpected"}',
      '{"machineId":"rig","runtime":"codex"}',
    ]) {
      final config = CreateAgentLastConfig.parse(jsonDecode(raw));
      expect(config?.machineId, 'rig', reason: raw);
      expect(config?.runtime, 'codex', reason: raw);
    }
    expect(
      CreateAgentLastConfig.parse(
        jsonDecode('{"machineId":"","runtime":"codex"}'),
      ),
      isNull,
    );
    expect(
      CreateAgentLastConfig.parse(jsonDecode('{"machineId":"rig"}')),
      isNull,
    );
  });

  testWidgets('a record Web writes today restores computer and runtime', (
    t,
  ) async {
    await prefs.setString(_key, '{"machineId":"rig","runtime":"codex"}');
    await open(t, 'from-web');
    expect(find.text('Build Rig'), findsOneWidget);
    expect(find.text('Codex CLI'), findsOneWidget);
    expect(find.byType(RaftAgentBanner), findsNothing);
    await create(t);
    final data = w.posts.single['data'] as Map;
    expect(data['machineId'], 'rig');
    expect(data['runtime'], 'codex');
    expect(prefs.getString(_key), '{"machineId":"rig","runtime":"codex"}');
  });

  testWidgets(
    'the previous release record restores the same, drops the model, and is rewritten',
    (t) async {
      await prefs.setString(
        _key,
        '{"machineId":"rig","runtime":"codex","model":"gpt-5-mini","customModelMode":false}',
      );
      await open(t, 'upgraded');
      expect(find.text('Build Rig'), findsOneWidget);
      expect(find.text('Codex CLI'), findsOneWidget);
      // The runtime's server form owns the model default: the remembered
      // model is not applied, and nothing asks about it.
      expect(find.text('GPT-5'), findsOneWidget);
      expect(find.text('GPT-5 Mini'), findsNothing);
      expect(find.byType(RaftAgentBanner), findsNothing);
      await create(t);
      expect(
        ((w.posts.single['data'] as Map)['formValues'] as Map)['model'],
        'gpt-5',
      );
      expect(prefs.getString(_key), '{"machineId":"rig","runtime":"codex"}');
    },
  );
}
