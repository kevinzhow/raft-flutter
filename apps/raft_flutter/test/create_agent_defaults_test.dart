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
            {'runtimeId': r, 'canSelectInThisContext': true},
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

    test('every word pair is a valid, unreserved agent name', () {
      final pairs = [
        for (final a in agentNameAdjectives)
          for (final n in agentNameNouns) '$a-$n',
      ];
      expect(pairs, hasLength(90 * 90));
      for (final name in pairs) {
        expect(
          name.length <= 32 && nameRule.hasMatch(name),
          isTrue,
          reason: name,
        );
        expect(reserved.contains(name), isFalse);
      }
    });

    test('avoids taken names (case-insensitive) while a pair is free', () {
      final all = [
        for (final a in agentNameAdjectives)
          for (final n in agentNameNouns) '$a-$n',
      ];
      final free = all.last;
      final taken = [
        for (final n in all.take(all.length - 1)) ' ${n.toUpperCase()} ',
      ];
      for (var i = 0; i < 5; i++) {
        expect(suggestAgentName(exclude: taken, random: math.Random(i)), free);
      }
      // Every pair taken: the server's uniqueness check decides.
      expect(
        all,
        contains(suggestAgentName(exclude: all, random: math.Random(1))),
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
      const config = CreateAgentLastConfig(
        machineId: 'm1',
        runtime: 'codex',
        model: 'gpt-5',
        customModelMode: false,
      );
      config.write('srv/1');
      expect(
        prefs.getString('raft:create-agent:last-config:v1:srv%2F1'),
        '{"machineId":"m1","runtime":"codex","model":"gpt-5","customModelMode":false}',
      );
      final read = CreateAgentLastConfig.read('srv/1');
      expect(read?.machineId, 'm1');
      expect(read?.model, 'gpt-5');
      expect(CreateAgentLastConfig.read('other'), isNull);
    });

    test('malformed or oversized records mean nothing is remembered', () async {
      for (final raw in [
        'not json',
        '[]',
        '{"machineId":"","runtime":"codex","model":"","customModelMode":false}',
        '{"machineId":"m","runtime":"codex","model":"x","customModelMode":"no"}',
        '{"machineId":"m","runtime":"codex","model":"${'x' * 513}","customModelMode":false}',
      ]) {
        await prefs.setString(_key, raw);
        expect(CreateAgentLastConfig.read('s'), isNull, reason: raw);
      }
      await prefs.setString(
        _key,
        '{"machineId":"m","runtime":"codex","model":"","customModelMode":false}',
      );
      expect(CreateAgentLastConfig.read('s')?.model, '');
    });

    test('reading without preloaded preferences keeps the defaults', () {
      DevicePreferences.reset();
      expect(CreateAgentLastConfig.read('s'), isNull);
      const CreateAgentLastConfig(
        machineId: 'm',
        runtime: 'codex',
        model: '',
        customModelMode: false,
      ).write('s');
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
      expect(first, matches(RegExp(r'^[a-z]+-[a-z]+$')));
      expect(find.byKey(const Key('create-agent-random-name')), findsOneWidget);
      await t.tap(find.byKey(const Key('create-agent-random-name')));
      await t.pump();
      final second = nameValue(t);
      expect(second, matches(RegExp(r'^[a-z]+-[a-z]+$')));
      expect(second, isNot(first));
    });

    testWidgets('a rolled name never repeats a name already taken', (t) async {
      w
        ..machines = [_machine('mbp', 'Studio Mac')]
        ..agents = [
          for (final a in agentNameAdjectives.take(89))
            for (final n in agentNameNouns)
              {'id': '$a-$n', 'name': '$a-$n', 'status': 'active'},
          {'id': 'gone', 'name': 'zesty-zebra', 'deletedAt': '2026-10-01'},
        ];
      await w.services.entityDirectory.refresh(WorkspaceEntityKind.agents);
      await open(t);
      // Only the last adjective's pairs are free (zesty-*); a deleted agent
      // does not hold its name.
      expect(nameValue(t), startsWith('zesty-'));
      await t.tap(find.byKey(const Key('create-agent-random-name')));
      await t.pump();
      expect(nameValue(t), startsWith('zesty-'));
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
          matching: find.text('Create Agent'),
        ),
      );
      await t.pumpAndSettle();
      final data = w.posts.single['data'] as Map;
      expect(data['avatarUrl'], startsWith('pixel:'));
      final key = (data['avatarUrl'] as String).substring('pixel:'.length);
      expect(raftAgentAvatarChoices, contains(key));
      expect(key, isNot(anyOf('mug', 'finch')));
    });

    testWidgets('the last computer, runtime and model come back next time', (
      t,
    ) async {
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

      await prefs.setString(
        _key,
        '{"machineId":"rig","runtime":"codex","model":"gpt-5-mini","customModelMode":false}',
      );
      await open(t, name: 'second');
      expect(find.text('Build Rig'), findsOneWidget);
      expect(find.text('Codex CLI'), findsOneWidget);
      expect(find.text('GPT-5 Mini'), findsOneWidget);
      await t.tap(
        find.descendant(
          of: find.byType(RaftAgentDialogButton),
          matching: find.text('Create Agent'),
        ),
      );
      await t.pumpAndSettle();
      final data = w.posts.single['data'] as Map;
      expect(data['machineId'], 'rig');
      expect(data['runtime'], 'codex');
      expect((data['formValues'] as Map)['model'], 'gpt-5-mini');
    });

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
          matching: find.text('Create Agent'),
        ),
      );
      await t.pumpAndSettle();
      expect(
        prefs.getString(_key),
        '{"machineId":"mbp","runtime":"codex","model":"gpt-5-mini","customModelMode":false}',
      );
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
          matching: find.text('Create Agent'),
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
        await prefs.setString(
          _key,
          '{"machineId":"rig","runtime":"claude","model":"retired-model","customModelMode":false}',
        );
        await open(t, name: 'fallback');
        // The remembered computer is offline and its runtime is not offered.
        expect(find.text('Studio Mac'), findsOneWidget);
        expect(find.text('Codex CLI'), findsOneWidget);
        expect(find.text('GPT-5'), findsOneWidget);
        await t.tap(find.text('Cancel'));
        await t.pumpAndSettle();
        // A remembered model the runtime no longer lists is still a custom value
        // the source allows, but never a remembered model of another runtime.
        await prefs.setString(
          _key,
          '{"machineId":"mbp","runtime":"claude","model":"gpt-5-mini","customModelMode":false}',
        );
        await open(t, name: 'other-runtime');
        expect(find.text('GPT-5'), findsOneWidget);
      },
    );
  });
}
