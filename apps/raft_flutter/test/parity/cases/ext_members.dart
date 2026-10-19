// raft-flutter parity EXTENSION suite builders (tool/parity-ext): members
// directory, profiles, agent detail tabs, agent / member dialogs, Activity and
// Saved states. NOT official cases; ids are `components.members-ext.<key>.<theme>`,
// dispatched on props.extCase / props.extKind exactly like
// tool/parity-ext/host/MemberCases.tsx.
//
// Data: tool/parity-ext/fixtures/members.json (fixtures['ext:members']), the
// same file the React render host imports; its `routes` + the case's route set
// answer the API on both providers.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/desktop_directory_view.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/workspace_menu_invite.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/features/desktop_navigation_policy.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parity_harness.dart';
import 'ext_members_keys.g.dart';
import 'screens/screen_fixture.dart';
import '../../support/app_services_fixture.dart';

const _serverId = 'visual-server';

Map<String, dynamic> _fx(ParityContext ctx) =>
    ctx.fixtures['ext:members'] as Map<String, dynamic>;

/// `routes` overlaid with the case's `routeSet` (the React provider's rule).
Map<String, dynamic> _routes(ParityContext ctx) => {
  ...Map<String, dynamic>.from(_fx(ctx)['routes'] as Map),
  ...?(_fx(ctx)['routeSets'] as Map?)?[ctx.props['routeSet']] as Map?,
};

/// Answer for [method] [path] from the fixture routes: `$pending` never
/// completes, `$status` fails like the React provider's fulfilled error.
Object? _answer(
  ParityContext ctx,
  String method,
  String path,
  Map<String, dynamic>? query,
) {
  final answer = _routes(ctx)['$method $path'];
  if (answer == null) return ScreenWire(ctx.fixtureData).common(method, path, query);
  if (answer is Map && answer['\$pending'] == true) {
    return ScreenFixtureClient.pending;
  }
  if (answer is Map && answer['\$status'] != null) {
    throw RaftApiException('fixture error', status: answer['\$status'] as int);
  }
  return answer;
}

WorkspaceController _workspace(ParityContext ctx) {
  SharedPreferences.setMockInitialValues({});
  final wire = ScreenWire(ctx.fixtureData);
  final client = ScreenFixtureClient(
    (method, path, query) => _answer(ctx, method, path, query),
    user: wire.me(),
    server: _serverId,
  );
  final w = WorkspaceController(client);
  final server = RaftRecord(wire.server());
  w
    ..servers = [server]
    ..server = server;
  w.messageDomain.ledger.switchServer(_serverId);
  return w;
}

/// `agent:<id>` / `human:<id>` from the case props (the open detail).
DesktopContentTarget? _selected(ParityContext ctx) {
  final value = ctx.props['selected'] as String?;
  if (value == null) return null;
  final [kind, id] = value.split(':');
  return DesktopContentTarget(
    kind == 'agent' ? DesktopContentKind.agent : DesktopContentKind.human,
    id,
  );
}

class _Shell extends StatefulWidget {
  const _Shell({required this.ctx});
  final ParityContext ctx;
  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  late final WorkspaceController w = _workspace(widget.ctx)
    ..section = 'members'
    ..loadSidebar();

  @override
  void dispose() {
    w.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => withAppServices(
    WorkspaceView(
      controller: w,
      appearance: RaftAppearance(
        mode: widget.ctx.dark ? ThemeMode.dark : ThemeMode.light,
        light: widget.ctx.family,
      ),
      onAppearance: (_) async {},
      onLogout: () async {},
    ),
  );
}

/// The real shell at the case viewport; cases crop the detail pane through
/// `capture.androidKey` (`desktop-content-detail`, the React `thread-main-column`).
Widget _main(ParityContext ctx) => _Shell(ctx: ctx);

/// The fixture-routed workspace the resource panels read through (`query`) and
/// write to (`command`, accepted like the fixture `POST` routes).
class _ResourceWorkspace extends WorkspaceController {
  _ResourceWorkspace(super.client, this.ctx);
  final ParityContext ctx;

  @override
  Future<void> refreshUnread() async {}

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    final answer = _routes(ctx)['GET ${path.split('?').first}'];
    if (answer is Map && answer['\$pending'] == true) {
      return Completer<dynamic>().future;
    }
    if (answer is Map && answer['\$status'] != null) {
      throw RaftApiException('fixture error', status: answer['\$status'] as int);
    }
    return answer ?? super.query(path, query: query);
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async =>
      _routes(ctx)['$method $path'] ?? <String, dynamic>{};
}

/// ThreadsInbox / SavedPanel in the official 342x620 box: `ResourceView` for the
/// section, answering the fixture routes.
Widget _resource(ParityContext ctx) {
  final panel = ctx.props['panel'] as String;
  SharedPreferences.setMockInitialValues({});
  final wire = ScreenWire(ctx.fixtureData);
  final client = ScreenFixtureClient(
    (method, path, query) => _answer(ctx, method, path, query),
    user: wire.me(),
    server: _serverId,
  );
  final w = _ResourceWorkspace(client, ctx);
  final server = RaftRecord(wire.server());
  w
    ..servers = [server]
    ..server = server
    ..section = panel;
  w.messageDomain.ledger.switchServer(_serverId);
  final now = DateTime.fromMillisecondsSinceEpoch(
    (ctx.fixtureData['locale']['nowEpochMillis'] as num).toInt(),
  );
  return RaftDensityScope(
    density: RaftDensity.desktop,
    child: ctx.frame(
      width: 342,
      height: 620,
      padding: EdgeInsets.zero,
      child: Scaffold(
        body: ResourceView(
          controller: w,
          section: panel,
          clock: () => now,
          onBack: () {},
          searchMemory: SearchMemoryStore(
            storage: _MemoryStorage(),
            clock: () => now,
          ),
          restoreSearchState: false,
          onMessage: (_, _) async {},
        ),
      ),
    ),
  );
}

class _MemoryStorage implements SearchMemoryStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// The Invite human dialog over a blank page (the official host mounts the
/// dialog alone): opened once the first frame is up, like a click on `+`.
class _InviteHost extends StatefulWidget {
  const _InviteHost({required this.ctx});
  final ParityContext ctx;
  @override
  State<_InviteHost> createState() => _InviteHostState();
}

class _InviteHostState extends State<_InviteHost> {
  late final WorkspaceController w = _workspace(widget.ctx);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showWorkspaceMenuInvite(context, w);
    });
  }

  @override
  void dispose() {
    w.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
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
        selected: _selected(ctx),
        onSelected: (_) {},
      ),
    ),
  ),
);

ParityCase _case(String kind) => ParityCase(
  widgets: switch (kind) {
    'list' => const ['raft_flutter:DesktopDirectoryView', 'raft_ui:RaftNavItem'],
    'main' => const ['raft_flutter:WorkspaceView', 'raft_flutter:MemberProfileView', 'raft_ui:RaftPanelHeaderBar'],
    _ => const ['raft_flutter:WorkspaceView'],
  },
  notes: 'Extension suite (not official).',
  settle: const Duration(milliseconds: 600),
  build: (ctx) => switch (ctx.props['extKind']) {
    'list' => _list(ctx),
    'main' => _main(ctx),
    'resource' => _resource(ctx),
    'invite' => _InviteHost(ctx: ctx),
    _ => throw StateError('unknown members-ext kind ${ctx.props['extKind']}'),
  },
);

/// Every extension members case, keyed by id (3 themes each).
final Map<String, ParityCase> extMemberCases = {
  for (final MapEntry(key: key, value: kind) in extMemberCaseKinds.entries)
    for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
      'components.members-ext.$key.$theme': _case(kind),
};
