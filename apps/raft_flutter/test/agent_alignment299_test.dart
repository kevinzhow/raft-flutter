import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_flutter/features/agent_runtime_editor.dart';
import 'package:raft_flutter/features/create_agent_dialog.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_flutter/features/provider_views.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/agent_panel_fixture.dart';

const _label = 'Computer-approved custom model';
const _model = 'custom-model-id';

class _Client extends AgentPanelClient {
  final routes = <String, Object? Function()>{};
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      routes[path]?.call() ?? super.get(path, query: query);
}

class _Fixture {
  _Fixture() {
    client = _Client()..selectServer('s');
    agent = {...agentPanelAgent, 'model': _model, 'status': 'inactive'};
    routes = client.routes
      ..addAll({
        '/agents': () => [agent],
        '/agents/a': () => agent,
        '/servers/s/machines': () => {'machines': machines},
        '/servers/s/model-label-catalog': () => {
          'machines': {
            'm1': {
              'runtimes': {
                for (final runtime in ['codex', 'claude'])
                  runtime: {
                    'models': [
                      {'id': _model, 'label': _label},
                    ],
                  },
              },
            },
          },
        },
        '/agents/a/runtime-options': () => {
          'options': [
            {'runtimeId': 'codex', 'canSelectInThisContext': true},
          ],
        },
        '/servers/s/machines/m1/runtime-options': () => {'options': []},
        for (final runtime in ['codex', 'claude'])
          '/servers/s/machines/m1/runtime-models/$runtime': () => {
            'kind': 'live',
            'value': {
              'models': [
                {'id': _model, 'label': 'Runtime source fallback'},
              ],
            },
          },
        '/agents/a/workspace-files': () => {'files': []},
        '/provider-connections': () => {
          'connections': [
            {
              'id': 'p',
              'name': 'Gateway',
              'enabled': true,
              'assignedAgentCount': 2,
            },
          ],
          'providerOptions': [],
        },
        '/provider-connections/p/agents': () => {
          'agents': [
            {
              'id': 'a',
              'name': 'alpha',
              'runtime': 'codex',
              'status': 'online',
            },
            {
              'id': 'dead',
              'name': 'retired',
              'runtime': 'codex',
              'deleted': true,
            },
          ],
        },
      });
    client.flags.add('provider_connections_v0');
    w = AgentPanelWorkspace(client, routes: routes)
      ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'});
  }
  late final _Client client;
  late final AgentPanelWorkspace w;
  late final Map<String, Object? Function()> routes;
  late Map<String, dynamic> agent;
  final machines = [
    {
      ...agentPanelMachines.single,
      'runtimes': ['codex', 'claude'],
    },
  ];

  Future<void> mount(WidgetTester t, Widget child) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(900, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      w.dispose();
      await client.stream.close();
      await client.dispose();
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: Scaffold(body: child),
      ),
    );
    await t.pumpAndSettle();
  }

  AgentDetailPanel panel({AgentDetailTab tab = AgentDetailTab.profile}) =>
      AgentDetailPanel(
        controller: w,
        agent: agent,
        machines: machines,
        actions: const AgentDetailActions(),
        initialTab: tab,
        canManage: true,
        canViewPrivate: true,
      );
}

void main() {
  testWidgets('alignment299 profile uses the shared server model label', (
    t,
  ) async {
    final f = _Fixture();
    await f.mount(t, f.panel());
    expect(find.text(_label), findsOneWidget);
    expect(find.text(_model), findsNothing);
  });

  testWidgets('alignment299 a failed catalog read keeps a usable profile', (
    t,
  ) async {
    final f = _Fixture();
    f.routes['/servers/s/model-label-catalog'] = () =>
        throw const RaftApiException(
          'Catalog temporarily unavailable',
          status: 503,
        );
    await f.mount(t, f.panel());
    expect(find.text('Alpha Agent'), findsWidgets);
    expect(find.text(_model), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'alignment299 profile loads names after a same-controller server switch',
    (t) async {
      final f = _Fixture();
      await f.mount(t, f.panel());
      expect(find.text(_label), findsOneWidget);
      f.routes['/servers/other/model-label-catalog'] = () => {
        'machines': {
          'm1': {
            'runtimes': {
              'codex': {
                'models': [
                  {'id': _model, 'label': 'Other server model'},
                ],
              },
            },
          },
        },
      };
      f.client.selectServer('other');
      f.w.server = RaftRecord({'id': 'other', 'role': 'owner'});
      f.agent = {...f.agent, 'serverId': 'other'};
      f.w.notifyListeners();
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: TargetPlatform.linux),
          home: Scaffold(body: f.panel()),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text(_label), findsNothing);
      expect(find.text('Other server model'), findsOneWidget);
    },
  );

  testWidgets('alignment299 runtime model labels retain their model ids', (
    t,
  ) async {
    final f = _Fixture();
    await f.mount(
      t,
      AgentRuntimeEditor(
        controller: f.w,
        agent: f.agent,
        machine: f.machines.single,
        onClose: ([_]) {},
      ),
    );
    expect(find.text(_label), findsWidgets);
    expect(find.text('Runtime source fallback'), findsNothing);
    await t.tap(find.byKey(const ValueKey('runtime-editor-model')));
    await t.pumpAndSettle();
    expect(find.text(_label), findsWidgets);
    expect(find.text(_model), findsWidgets);
  });

  testWidgets('alignment299 choosing a catalog name submits the original id', (
    t,
  ) async {
    final f = _Fixture();
    f.agent = {...f.agent, 'model': 'prior-model'};
    var closed = false;
    await f.mount(
      t,
      AgentRuntimeEditor(
        controller: f.w,
        agent: f.agent,
        machine: f.machines.single,
        onClose: ([_]) => closed = true,
      ),
    );
    await t.tap(find.byKey(const ValueKey('runtime-editor-model')));
    await t.pumpAndSettle();
    await t.tap(find.text(_label).last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('runtime-editor-save')));
    await t.pumpAndSettle();
    final body =
        f.w.calls.singleWhere((c) => c.$1 == 'PATCH' && c.$2 == '/agents/a').$3
            as Map;
    expect(body['model'], _model);
    expect((body['runtimeConfig'] as Map)['model'], {
      'kind': 'preset',
      'id': _model,
    });
    expect(closed, isTrue);
  });

  testWidgets('alignment299 create pre-admission uses the shared catalog', (
    t,
  ) async {
    final f = _Fixture();
    await f.mount(
      t,
      CreateAgentDialog(
        controller: f.w,
        machines: f.machines,
        initialName: 'Valid-Agent',
      ),
    );
    final field = find.byWidgetPredicate(
      (w) => w is RaftAgentSelect<String> && w.semanticLabel == 'Model',
    );
    expect(field, findsOneWidget);
    final selected = t.widget<RaftAgentSelect<String>>(field);
    expect(selected.options.single.value, _model);
    expect(selected.options.single.label, _label);
  });

  testWidgets('alignment299 provider assigned live agent opens its profile', (
    t,
  ) async {
    final f = _Fixture();
    await f.mount(t, ProviderConnectionsView(controller: f.w));
    await t.tap(find.text('Assigned Agents'));
    await t.pumpAndSettle();
    await t.tap(find.text('alpha'));
    await t.pumpAndSettle();
    expect(f.w.location.query('profile'), 'agent:a');
    expect(find.text('Agents using Gateway'), findsNothing);
  });

  testWidgets(
    'alignment299 deleted assigned agent stays inert and detachable',
    (t) async {
      final f = _Fixture();
      await f.mount(t, ProviderConnectionsView(controller: f.w));
      await t.tap(find.text('Assigned Agents'));
      await t.pumpAndSettle();
      await t.tap(find.text('retired'));
      await t.pump();
      expect(f.w.location.query('profile'), isNull);
      expect(find.text('Agents using Gateway'), findsOneWidget);
      expect(find.byType(RaftListRow), findsWidgets);
      final tooltip = find.byWidgetPredicate(
        (w) => w is RaftTooltip && w.message == 'Detach Deleted Agent',
      );
      expect(tooltip, findsOneWidget);
    },
  );

  testWidgets('alignment299 assigned-agent dialog closes on authority change', (
    t,
  ) async {
    final f = _Fixture();
    await f.mount(t, ProviderConnectionsView(controller: f.w));
    await t.tap(find.text('Assigned Agents'));
    await t.pumpAndSettle();
    f.client.selectServer('other');
    f.w.server = RaftRecord({'id': 'other', 'role': 'owner'});
    f.w.notifyListeners();
    await t.pumpAndSettle();
    expect(find.text('Agents using Gateway'), findsNothing);
    expect(f.w.location.query('profile'), isNull);
  });

  testWidgets('alignment299 hosted workspace omits the local path bar', (
    t,
  ) async {
    final f = _Fixture();
    f.agent = {...f.agent, 'external': true, 'runtime': 'external'};
    await f.mount(t, f.panel(tab: AgentDetailTab.workspace));
    expect(find.text('~/.slock/agents/a/'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is RaftInlineIconButton && w.glyph == RaftGlyph.copy,
      ),
      findsNothing,
    );
  });

  testWidgets('alignment299 managed workspace retains its local path', (
    t,
  ) async {
    final f = _Fixture();
    await f.mount(t, f.panel(tab: AgentDetailTab.workspace));
    expect(find.text('~/.slock/agents/a/'), findsOneWidget);
  });

  testWidgets('alignment299 profile Start sends immediately without a dialog', (
    t,
  ) async {
    final f = _Fixture();
    await f.mount(
      t,
      FleetDetail(controller: f.w, computers: false, initial: f.agent),
    );
    await t.tap(find.byKey(const Key('agent-profile-inline-start-stop')));
    await t.pumpAndSettle();
    expect(
      f.w.calls.where((c) => c.$1 == 'POST' && c.$2 == '/agents/a/start'),
      hasLength(1),
    );
    expect(find.byType(RaftFormDialog), findsNothing);
  });

  testWidgets('alignment299 profile Stop still requires confirmation', (
    t,
  ) async {
    final f = _Fixture();
    f.agent = {...f.agent, 'status': 'active', 'activity': 'working'};
    await f.mount(
      t,
      FleetDetail(controller: f.w, computers: false, initial: f.agent),
    );
    await t.tap(find.byKey(const Key('agent-profile-inline-start-stop')));
    await t.pumpAndSettle();
    expect(
      f.w.calls.where((c) => c.$1 == 'POST' && c.$2 == '/agents/a/stop'),
      isEmpty,
    );
    expect(find.text('Keep Working'), findsOneWidget);
    await t.tap(find.text('Stop Agent').last);
    await t.pumpAndSettle();
    expect(
      f.w.calls.where((c) => c.$1 == 'POST' && c.$2 == '/agents/a/stop'),
      hasLength(1),
    );
  });
}
