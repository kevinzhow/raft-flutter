// raft-flutter parity EXTENSION suite builders (tool/parity-ext): composed
// screens - the desktop channel / DM screen (rail + sidebar + header + tabs +
// timeline + composer), the phone channel / DM page, the composer @mention and
// #channel suggestion popovers and the populated Activity list. NOT official
// cases; ids are `components.screens-ext.<surface>.<platform>.<state>.<theme>`,
// dispatched on props like tool/parity-ext/host/ScreenCases.tsx.
//
// The REAL WorkspaceView is mounted at the case viewport with the shared shell
// workspace (fixtures['ext:shell'] preset default) plus the scene's message /
// inbox routes (fixtures['ext:screens']); windowed cases capture a keyed overlay
// (`screen-window`) over the same rectangle the React host marks.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' show addTearDown;
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';
import 'ext_shell.dart' show shellWorkspace;
import 'thread_messages/chat_stage.dart' show ParityIdentities;
import '../../support/app_services_fixture.dart';

Map<String, dynamic> _scene(ParityContext ctx) {
  final scenes = Map<String, dynamic>.from(
    (ctx.fixtures['ext:screens'] as Map)['scenes'] as Map,
  );
  return Map<String, dynamic>.from(scenes[ctx.props['scene']] as Map);
}

WorkspaceController _workspace(ParityContext ctx) {
  // The React provider pins its clock to the fixture instant.
  final now = DateTime.fromMillisecondsSinceEpoch(
    (ctx.fixtureData['locale']['nowEpochMillis'] as num).toInt(),
  );
  sourceTimeNow = () => now;
  addTearDown(() => sourceTimeNow = DateTime.now);
  final scene = _scene(ctx);
  final selected = scene['selected'] as String?;
  // Same directory the React host seeds (visualAgents / visualMembers).
  final ids = ParityIdentities(ctx);
  return shellWorkspace(
    ctx,
    selected: selected,
    routes: {
      'GET /agents': ids.agents,
      'GET /servers/visual-server/members': ids.members,
      if (selected != null)
        'GET /tasks/channel/$selected': {'tasks': <dynamic>[]},
      ...Map<String, dynamic>.from(scene['routes'] as Map),
    },
  );
}

class _Host extends StatefulWidget {
  const _Host({required this.ctx});
  final ParityContext ctx;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late final WorkspaceController w = _workspace(widget.ctx);
  // The Web browser default (hide-empty off), like the shell cases.
  final presentation = PersonalPresentationStore();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    final id = _scene(widget.ctx)['selected'] as String?;
    if (id == null) {
      w.setSection('activity');
      return;
    }
    final channel = [...w.channels, ...w.dms].firstWhere((c) => c.id == id);
    await w.selectChannel(channel);
  }

  @override
  Widget build(BuildContext context) => withAppServices(
    WorkspaceView(
      controller: w,
      presentation: presentation,
      appearance: RaftAppearance(
        mode: widget.ctx.dark ? ThemeMode.dark : ThemeMode.light,
      ),
      onAppearance: (_) async {},
      onLogout: () async {},
    ),
  );
}

/// The `screen-window` rectangle of windowed cases (same numbers as the React marker).
Rect? _window(ParityContext ctx) {
  final rail = 56.0;
  return switch (ctx.props['win']) {
    'activity' => Rect.fromLTWH(0, 0, rail + 560, ctx.height),
    'composer' => Rect.fromLTWH(
      rail + 240,
      ctx.height - 340,
      ctx.width - rail - 240,
      340,
    ),
    _ => null,
  };
}

Widget _build(ParityContext ctx) {
  final window = _window(ctx);
  return Stack(
    children: [
      Positioned.fill(child: _Host(ctx: ctx)),
      if (window != null)
        Positioned.fromRect(
          rect: window,
          child: IgnorePointer(
            child: const SizedBox.expand(key: ValueKey('screen-window')),
          ),
        ),
    ],
  );
}

final ParityCase _case = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_ui:RaftMessageTimeline',
    'raft_ui:RaftComposer',
  ],
  notes: 'Extension suite (not official). Real WorkspaceView, composed screen.',
  settle: const Duration(milliseconds: 1200),
  build: _build,
);

const _states = {
  'channel': ['desktop.full', 'mobile.full'],
  'dm': ['desktop.human', 'desktop.agent', 'mobile.agent'],
  'composer': ['desktop.mention', 'desktop.channel'],
  'activity': ['desktop.list'],
};

/// Every extension composed-screen case, keyed by id (3 themes each).
final Map<String, ParityCase> extScreenCases = {
  for (final MapEntry(key: surface, value: states) in _states.entries)
    for (final state in states)
      for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
        'components.screens-ext.$surface.$state.$theme': _case,
};
