// raft-flutter parity EXTENSION suite builders (tool/parity-ext): the
// Computers rail list, the Computer detail page and its dialogs, at the
// desktop viewport each extension case declares. NOT official cases; ids are
// `components.computers.<extCase>.<theme>`, dispatched on props.extCase /
// props.extKind exactly like tool/parity-ext/host/ComputerCases.tsx.
//
// Data: tool/parity-ext/fixtures/computers.json (fixtures['ext:computers']),
// the same file the React render host imports.
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/add_computer_dialog.dart';
import 'package:raft_flutter/features/computer_detail_view.dart';
import 'package:raft_flutter/features/desktop_directory_view.dart';
import 'package:raft_flutter/features/desktop_navigation_policy.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parity_harness.dart';
import 'screens/screen_fixture.dart';

const _serverId = 'visual-server';

Map<String, dynamic> _fx(ParityContext ctx) =>
    ctx.fixtures['ext:computers'] as Map<String, dynamic>;

/// The machine list a case's page loaded: `lists[props.list]`, the detail
/// variant replacing its row (same rule as the React provider route).
List<Map<String, dynamic>> _machines(ParityContext ctx) {
  final fx = _fx(ctx);
  final machines = Map<String, dynamic>.from(fx['machines'] as Map);
  final detail = ctx.props['machine'] == null
      ? null
      : machines[ctx.props['machine']] as Map?;
  return [
    for (final id in (fx['lists'][ctx.props['list'] ?? 'default'] as List))
      Map<String, dynamic>.from(
        detail != null && detail['id'] == id ? detail : machines[id] as Map,
      ),
  ];
}

WorkspaceController _workspace(ParityContext ctx) {
  SharedPreferences.setMockInitialValues({});
  final fx = _fx(ctx);
  final wire = ScreenWire(ctx.fixtureData);
  final routes = Map<String, dynamic>.from(fx['routes'] as Map);
  final loading = '${ctx.props['loading']}' == 'true';
  final client = ScreenFixtureClient(
    (method, path, query) {
      if (method == 'GET' && path == '/servers/$_serverId/machines') {
        return loading
            ? ScreenFixtureClient.pending
            : {
                'machines': _machines(ctx),
                'latestComputerVersion': fx['latestComputerVersion'],
                'latestComputerReleaseNotes': null,
              };
      }
      if (method == 'GET' && path == '/agents') {
        return [
          for (final a in fx['agents'] as List)
            {...Map<String, dynamic>.from(a as Map), 'serverId': _serverId},
        ];
      }
      final answer = routes['$method $path'];
      if (answer != null) return answer;
      return wire.common(method, path, query);
    },
    user: wire.me(),
    server: _serverId,
  );
  final w = WorkspaceController(client);
  final server = RaftRecord(wire.server());
  w
    ..servers = [server]
    ..server = server;
  w.ledger.switchServer(_serverId);
  return w;
}

Widget _list(ParityContext ctx) => ScreenWorkspaceHost(
  create: () => _workspace(ctx),
  builder: (context, w) => ctx.frame(
    width: 240,
    height: ctx.height,
    padding: EdgeInsets.zero,
    // The app mounts the column under the workspace Scaffold's Material.
    child: Material(
      type: MaterialType.transparency,
      child: DesktopDirectoryView(
        controller: w,
        computers: true,
        selected: ctx.props['selected'] == null
            ? null
            : DesktopContentTarget(
                DesktopContentKind.computer,
                ctx.props['selected'] as String,
              ),
        onSelected: (_) {},
      ),
    ),
  ),
);

/// The desktop detail column (1280 - 64 rail - 240 sidebar = 976).
Widget _detail(ParityContext ctx) => ScreenWorkspaceHost(
  create: () {
    final w = _workspace(ctx);
    w.entityDirectory.ensure([WorkspaceEntityKind.computers]);
    return w;
  },
  builder: (context, w) => ctx.frame(
    width: 976,
    height: ctx.height,
    padding: EdgeInsets.zero,
    child: Material(
      type: MaterialType.transparency,
      child: ListenableBuilder(
        listenable: w.entityDirectory,
        builder: (context, _) {
          final id = (_fx(ctx)['machines'][ctx.props['machine']] as Map)['id'];
          final machine = w.entityDirectory.computer(id as String);
          return machine == null
              ? const SizedBox.shrink()
              : ComputerDetailPanel(
                  controller: w,
                  machine: machine,
                  remoteUpgradeV2:
                      ctx.props['flags'] is Map &&
                      (ctx.props['flags']
                              as Map)['remote_computer_upgrade_v2'] ==
                          true,
                  // The React host is the Vite dev server (VITE_DEPLOYMENT_ENV
                  // unset): commands carry no --server-url, exactly as
                  // production does for its default server.
                  deployment: 'development',
                );
        },
      ),
    ),
  ),
);

Widget _add(ParityContext ctx) => ScreenWorkspaceHost(
  create: () {
    final w = _workspace(ctx);
    w.entityDirectory.ensure([WorkspaceEntityKind.computers]);
    return w;
  },
  builder: (context, w) => ctx.frame(
    width: ctx.width,
    height: ctx.height,
    padding: EdgeInsets.zero,
    child: ColoredBox(
      // The Modal backdrop over the white render-host page.
      color: Colors.white,
      child: Builder(
        builder: (context) {
          final t = RaftTokens.of(context);
          return Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: t.brutal
                      ? Colors.black.withValues(alpha: .6)
                      : t.colors['layer-backdrop']!,
                ),
              ),
              AddComputerDialog(controller: w, deployment: 'development'),
            ],
          );
        },
      ),
    ),
  ),
);

ParityCase _case(String kind) => ParityCase(
  widgets: switch (kind) {
    'list' => const [
      'raft_flutter:DesktopDirectoryView',
      'raft_ui:RaftComputerSidebarHeading',
      'raft_ui:RaftComputerRow',
    ],
    'add' => const ['raft_flutter:AddComputerDialog'],
    _ => const [
      'raft_flutter:ComputerDetailPanel',
      'raft_ui:RaftCopyableCode',
      'raft_ui:RaftRuntimeChip',
    ],
  },
  notes: 'Extension suite (not official).',
  settle: const Duration(milliseconds: 600),
  build: (ctx) => switch (ctx.props['extKind']) {
    'list' => _list(ctx),
    'add' => _add(ctx),
    _ => _detail(ctx),
  },
);

/// Every extension computers case, keyed by id (3 themes each).
final Map<String, ParityCase> extComputerCases = {
  for (final key in _extCaseKeys)
    for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
      'components.computers.$key.$theme': _case(_kindOf(key)),
};

String _kindOf(String key) => key.startsWith('list.')
    ? 'list'
    : key.startsWith('add-dialog')
    ? 'add'
    : 'detail';

const _extCaseKeys = [
  'list.rows',
  'list.states',
  'list.empty',
  'list.loading',
  'list.row-selected',
  'list.row-hover',
  'add-dialog',
  'add-dialog.connect',
  'detail.panel',
  'detail.header',
  'detail.identity',
  'detail.name',
  'detail.description',
  'detail.info',
  'detail.agents',
  'detail.workspaces',
  'detail.service',
  'detail.recovery-guide',
  'detail.delete',
  'detail.state.offline',
  'detail.state.up-to-date',
  'detail.state.upgrading',
  'detail.state.disk-low',
  'detail.state.legacy',
  'detail.state.one-click',
  'detail.state.offline.recovery-card',
  'detail.edit-name',
  'detail.edit-description',
  'detail.select-mode',
  'detail.select-all',
  'detail.workspaces-scanned',
  'detail.recovery-guide-open',
  'detail.offline-setup-open',
  'detail.restart-progress',
  'dialog.bulk-restart',
  'dialog.stop-agents',
  'dialog.delete-workspace',
  'dialog.delete-blocked',
  'dialog.delete',
];
