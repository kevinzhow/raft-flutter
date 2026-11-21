// Create Agent dialog defaults (Web v1.21.23 CreateAgentDialog): a suggested
// name with a dice button, the last computer / runtime / model remembered per
// server, a random pixel avatar for new agents, and the channel context line.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/agent_name_generator.dart';
import 'package:raft_flutter/data/create_agent_last_config.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
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
  List<Map<String, dynamic>> machines = [];
  List<Map<String, dynamic>> agents = [];
  List<String> runtimes = ['codex'];
  bool failCreate = false;
  final posts = <Map<String, dynamic>>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/servers/s/machines') return {'machines': machines};
    if (path == '/agents') return agents;
    if (path.endsWith('/runtime-options')) {
      return {
        'options': [
          for (final r in runtimes)
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
    if (failCreate) {
      throw RaftApiException.response(
        'Boom',
        status: 500,
        body: {'error': 'Boom'},
      );
    }
    return {'id': 'agent-new', 'name': data['name']};
  }
}

Map<String, dynamic> _machine(String id, String name, {String? status}) => {
  'id': id,
  'name': name,
  'status': status ?? 'online',
  'runtimes': ['codex', 'claude'],
};

const _key = 'raft:create-agent:last-config:v1:s';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('suggested names', () {
    final nameRule = RegExp(r'^\p{L}[\p{L}\p{N}_-]*$', unicode: true);
    const reserved = {
      'all',
      'human',
      'humans',
      'agent',
      'agents',
      'here',
      'idle',
      'busy',
      'system',
      'reminders',
    };

    test('every name and pair is a valid, unreserved agent name', () {
      final candidates = [
        ...agentClassicNames,
        for (final a in agentNameAdjectives)
          for (final n in agentClassicNames) '$a-$n',
      ];
      expect(agentClassicNames, hasLength(136));
      expect(agentNameAdjectives, hasLength(90));
      // Same lists as Web v1.24 shared agentNameGenerator.ts.
      expect(agentClassicNames.first, 'Ada');
      expect(agentClassicNames.last, 'Zoe');
      expect(agentNameAdjectives.first, 'Amber');
      expect(agentNameAdjectives.last, 'Zesty');
      expect(agentClassicNames, isNot(contains('Cindy')));
      for (final name in candidates) {
        expect(
          name.length <= 32 && nameRule.hasMatch(name),
          isTrue,
          reason: name,
        );
        expect(reserved.contains(name.toLowerCase()), isFalse);
      }
    });

    test('first name, then Adjective-Name, then a number, never taken', () {
      // A free first name while one is left (case-insensitive, trimmed).
      final lastName = agentClassicNames.last;
      final takenNames = [
        for (final n in agentClassicNames.take(agentClassicNames.length - 1))
          ' ${n.toUpperCase()} ',
      ];
      for (var i = 0; i < 5; i++) {
        expect(
          suggestAgentName(exclude: takenNames, random: math.Random(i)),
          lastName,
        );
      }
      // Every first name taken: an adjective pair, e.g. Swift-Leo.
      final pair = suggestAgentName(
        exclude: agentClassicNames,
        random: math.Random(3),
      );
      final parts = pair.split('-');
      expect(agentNameAdjectives, contains(parts.first));
      expect(agentClassicNames, contains(parts.last));
      // Every name and pair taken: the first free number.
      final everything = [
        ...agentClassicNames,
        for (final a in agentNameAdjectives)
          for (final n in agentClassicNames) '$a-$n',
      ];
      final numbered = suggestAgentName(
        exclude: everything,
        random: math.Random(1),
      );
      expect(numbered, matches(RegExp(r'^[A-Za-z]+-[A-Za-z]+2$')));
      final base = numbered.substring(0, numbered.length - 1);
      expect(
        suggestAgentName(
          exclude: [...everything, '${base}2'],
          random: math.Random(1),
        ),
        '${base}3',
      );
    });
  });

  group('remembered configuration', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      DevicePreferences.adopt(prefs);
    });
    tearDown(DevicePreferences.reset);

    test('stores the Web record under the per-server Web key', () {
      expect(CreateAgentLastConfig.read('srv/1'), isNull);
      const config = CreateAgentLastConfig(machineId: 'm1', runtime: 'codex');
      config.write('srv/1');
      expect(
        prefs.getString('raft:create-agent:last-config:v1:srv%2F1'),
        '{"machineId":"m1","runtime":"codex"}',
      );
      final read = CreateAgentLastConfig.read('srv/1');
      expect(read?.machineId, 'm1');
      expect(read?.runtime, 'codex');
      expect(CreateAgentLastConfig.read('other'), isNull);
    });

    test('malformed or oversized records mean nothing is remembered', () async {
      for (final raw in [
        'not json',
        '[]',
        '{"machineId":"","runtime":"codex"}',
        '{"machineId":"m","runtime":""}',
        '{"machineId":"m"}',
        '{"machineId":"${'x' * 513}","runtime":"codex"}',
      ]) {
        await prefs.setString(_key, raw);
        expect(CreateAgentLastConfig.read('s'), isNull, reason: raw);
      }
      // A record of the previous release still reads: its model is ignored.
      await prefs.setString(
        _key,
        '{"machineId":"m","runtime":"codex","model":"","customModelMode":false}',
      );
      expect(CreateAgentLastConfig.read('s')?.runtime, 'codex');
    });

    test('reading without preloaded preferences keeps the defaults', () {
      DevicePreferences.reset();
      expect(CreateAgentLastConfig.read('s'), isNull);
      const CreateAgentLastConfig(machineId: 'm', runtime: 'codex').write('s');
    });
  });

  group('dialog', () {
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

    Future<Future<Map<String, dynamic>?>> open(
      WidgetTester t, {
      String? name,
      String? channel,
      String? note,
      int seed = 7,
    }) async {
      late Future<Map<String, dynamic>?> result;
      await t.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => result = showManagedAgentForm(
                  context,
                  w,
                  initialName: name,
                  autoJoinChannelName: channel,
                  prefilledNameNote: note,
                  random: math.Random(seed),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      return result;
    }

    String nameValue(WidgetTester t) => t
        .widget<TextField>(
          find.descendant(
            of: find.byType(RaftAgentTextInput).first,
            matching: find.byType(TextField),
          ),
        )
        .controller!
        .text;

    testWidgets('a new agent starts with a suggested name the dice rerolls', (
      t,
    ) async {
      w.machines = [_machine('mbp', 'Studio Mac')];
      await w.services.entityDirectory.refresh(WorkspaceEntityKind.agents);
      await open(t);
      final first = nameValue(t);
      expect(agentClassicNames, contains(first));
      expect(find.byKey(const Key('create-agent-random-name')), findsOneWidget);
      await t.tap(find.byKey(const Key('create-agent-random-name')));
      await t.pump();
      final second = nameValue(t);
      expect(agentClassicNames, contains(second));
      expect(second, isNot(first));
    });

    testWidgets('a rolled name never repeats a name already taken', (t) async {
      w
        ..machines = [_machine('mbp', 'Studio Mac')]
        ..agents = [
          for (final n in agentClassicNames.take(agentClassicNames.length - 1))
            {'id': n, 'name': n.toLowerCase(), 'status': 'active'},
          {'id': 'gone', 'name': 'Zoe', 'deletedAt': '2026-10-01'},
        ];
      await w.services.entityDirectory.refresh(WorkspaceEntityKind.agents);
      await open(t);
      // Only Zoe is free; a deleted agent does not hold its name.
      expect(nameValue(t), 'Zoe');
      // Rolling again skips the current Zoe too, so it falls back to a pair.
      await t.tap(find.byKey(const Key('create-agent-random-name')));
      await t.pump();
      expect(nameValue(t), matches(RegExp(r'^[A-Za-z]+-[A-Za-z]+$')));
      expect(nameValue(t), isNot('Zoe'));
    });

    testWidgets('a prefilled name, even an empty one, is kept', (t) async {
      w.machines = [_machine('mbp', 'Studio Mac')];
      await open(t, name: 'Alice');
      expect(nameValue(t), 'Alice');
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      await open(t, name: '');
      expect(nameValue(t), '');
    });

    testWidgets('the channel context line and the prefill note show', (
      t,
    ) async {
      w.machines = [_machine('mbp', 'Studio Mac')];
      await open(
        t,
        name: 'planner',
        channel: 'design',
        note: 'The leading @ was removed automatically.',
      );
      expect(
        find.text('Will join #design automatically after it is created'),
        findsOneWidget,
      );
      expect(
        find.text('The leading @ was removed automatically.'),
        findsOneWidget,
      );
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      await open(t, name: 'planner');
      expect(find.textContaining('automatically after'), findsNothing);
    });

    testWidgets('a created agent gets a random pixel avatar preset', (t) async {
      w.machines = [_machine('mbp', 'Studio Mac')];
      await open(t, name: 'avatar-bot', seed: 3);
      await t.tap(
        find.descendant(
          of: find.byType(RaftAgentDialogButton),
          matching: find.text('Create'),
        ),
      );
      await t.pumpAndSettle();
      final data = w.posts.single['data'] as Map;
      expect(data['avatarUrl'], startsWith('pixel:'));
      final key = (data['avatarUrl'] as String).substring('pixel:'.length);
      expect(raftAgentAvatarChoices, contains(key));
      expect(key, isNot(anyOf('mug', 'finch')));
    });

    testWidgets(
      'the last computer and runtime come back next time, not the model',
      (t) async {
        w
          ..machines = [
            _machine('mbp', 'Studio Mac'),
            _machine('rig', 'Build Rig'),
          ]
          ..runtimes = ['claude', 'codex'];
        await open(t, name: 'first');
        // Nothing remembered yet: the first online computer, the first runtime.
        expect(prefs.getString(_key), isNull);
        await t.tap(find.text('Cancel'));
        await t.pumpAndSettle();

        await prefs.setString(_key, '{"machineId":"rig","runtime":"codex"}');
        await open(t, name: 'second');
        expect(find.text('Build Rig'), findsOneWidget);
        expect(find.text('Codex CLI'), findsOneWidget);
        // The runtime's server form owns the model default.
        expect(find.text('GPT-5'), findsOneWidget);
        await t.tap(
          find.descendant(
            of: find.byType(RaftAgentDialogButton),
            matching: find.text('Create'),
          ),
        );
        await t.pumpAndSettle();
        final data = w.posts.single['data'] as Map;
        expect(data['machineId'], 'rig');
        expect(data['runtime'], 'codex');
        expect((data['formValues'] as Map)['model'], 'gpt-5');
      },
    );

    testWidgets('creating an agent remembers what it used, per server', (
      t,
    ) async {
      w
        ..machines = [
          _machine('mbp', 'Studio Mac'),
          _machine('rig', 'Build Rig'),
        ]
        ..runtimes = ['codex'];
      await open(t, name: 'first');
      await t.tap(find.byKey(const ValueKey('runtime-model')));
      await t.pumpAndSettle();
      await t.tap(find.text('GPT-5 Mini').last);
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byType(RaftAgentDialogButton),
          matching: find.text('Create'),
        ),
      );
      await t.pumpAndSettle();
      expect(prefs.getString(_key), '{"machineId":"mbp","runtime":"codex"}');
      expect(CreateAgentLastConfig.read('another-server'), isNull);
    });

    testWidgets('a failed create remembers nothing', (t) async {
      w
        ..machines = [_machine('mbp', 'Studio Mac')]
        ..runtimes = ['codex'];
      w.failCreate = true;
      await open(t, name: 'first');
      await t.tap(
        find.descendant(
          of: find.byType(RaftAgentDialogButton),
          matching: find.text('Create'),
        ),
      );
      await t.pumpAndSettle();
      expect(prefs.getString(_key), isNull);
    });

    testWidgets(
      'an unavailable remembered computer, runtime or model falls back',
      (t) async {
        w
          ..machines = [
            _machine('mbp', 'Studio Mac'),
            _machine('rig', 'Build Rig', status: 'offline'),
          ]
          ..runtimes = ['codex'];
        await prefs.setString(_key, '{"machineId":"rig","runtime":"claude"}');
        await open(t, name: 'fallback');
        // The remembered computer is offline and its runtime is not offered.
        expect(find.text('Studio Mac'), findsOneWidget);
        expect(find.text('Codex CLI'), findsOneWidget);
        expect(find.text('GPT-5'), findsOneWidget);
      },
    );
  });
}
