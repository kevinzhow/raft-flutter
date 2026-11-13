// raft-flutter parity EXTENSION suite builders (tool/parity-ext): composer
// states - the "As task" checkbox, the pending-mention action strip and the
// composer warnings (agent stopped delivery, unresolved mentions, channel
// conversion in progress) plus the #channel popover with an archived channel.
// NOT official cases; ids are
// `components.composer-states.<surface>.<platform>.<state>.<theme>`, dispatched
// on props like tool/parity-ext/host/ComposerStatesCases.tsx.
//
// The REAL WorkspaceView is mounted at the case viewport with the shared shell
// workspace (fixtures['ext:shell'] preset default) plus the state's message
// routes and the `POST /v2/messages` receipt (fixtures['ext:composer-states']);
// the capture is a keyed overlay (`composer-window`) over the same bottom
// rectangle the React host marks.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' show addTearDown;
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';
import 'ext_shell.dart' show shellWorkspace;
import 'thread_messages/chat_stage.dart' show ParityIdentities;
import '../../support/app_services_fixture.dart';

Map<String, dynamic> _state(ParityContext ctx) {
  final states = Map<String, dynamic>.from(
    (ctx.fixtures['ext:composer-states'] as Map)['states'] as Map,
  );
  return Map<String, dynamic>.from(states[ctx.props['state']] as Map);
}

WorkspaceController _workspace(ParityContext ctx) {
  // The React provider pins its clock to the fixture instant.
  final now = DateTime.fromMillisecondsSinceEpoch(
    (ctx.fixtureData['locale']['nowEpochMillis'] as num).toInt(),
  );
  sourceTimeNow = () => now;
  addTearDown(() => sourceTimeNow = DateTime.now);
  final state = _state(ctx);
  final selected = state['selected'] as String;
  // Same directory the React host seeds (visualAgents / visualMembers).
  final ids = ParityIdentities(ctx);
  final w = shellWorkspace(
    ctx,
    selected: selected,
    routes: {
      'GET /agents': ids.agents,
      'GET /servers/visual-server/members': ids.members,
      'GET /tasks/channel/$selected': {'tasks': <dynamic>[]},
      ...Map<String, dynamic>.from(state['routes'] as Map),
    },
  );
  // The store patch of the React host: fields of the open conversation, extra
  // channels (an archived one for the #channel popover).
  final patch = Map<String, dynamic>.from(state['patch'] as Map);
  RaftChannel patched(RaftChannel c) =>
      c.id == selected ? RaftChannel({...c.json, ...patch}) : c;
  w.channels = [
    for (final c in w.channels) patched(c),
    for (final c in state['extraChannels'] as List)
      RaftChannel(Map<String, dynamic>.from(c as Map)),
  ];
  w.dms = [for (final c in w.dms) patched(c)];
  return w;
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
    final id = _state(widget.ctx)['selected'] as String;
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

/// The `composer-window` rectangle (same numbers as the React marker).
Rect _window(ParityContext ctx) {
  final height = double.parse('${ctx.props['windowHeight']}');
  if (ctx.props['platform'] == 'mobile') {
    return Rect.fromLTWH(0, ctx.height - height, ctx.width, height);
  }
  final rail = 56.0;
  return Rect.fromLTWH(
    rail + 240,
    ctx.height - height,
    ctx.width - rail - 240,
    height,
  );
}

Widget _build(ParityContext ctx) => Stack(
  children: [
    Positioned.fill(child: _Host(ctx: ctx)),
    Positioned.fromRect(
      rect: _window(ctx),
      child: const IgnorePointer(
        child: SizedBox.expand(key: ValueKey('composer-window')),
      ),
    ),
  ],
);

final ParityCase _case = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_ui:RaftComposer',
    'raft_ui:RaftPendingMentionActionStrip',
    'raft_ui:RaftComposerNotice',
  ],
  notes:
      'Extension suite (not official). Real WorkspaceView, composer states '
      'over the composed channel / DM screen.',
  settle: const Duration(milliseconds: 1200),
  build: _build,
);

const _states = {
  'as-task': ['as-task'],
  'pending-mention': ['single', 'multi'],
  'warning': ['agent-stopped', 'unresolved', 'conversion'],
  'suggestions': ['archived'],
};

/// Every extension composer-state case, keyed by id (3 themes each).
final Map<String, ParityCase> extComposerStateCases = {
  for (final MapEntry(key: surface, value: names) in _states.entries)
    for (final platform in const ['desktop', 'mobile'])
      for (final state in names)
        for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
          'components.composer-states.$surface.$platform.$state.$theme': _case,
};
