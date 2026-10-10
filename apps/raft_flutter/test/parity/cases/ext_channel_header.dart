// raft-flutter parity EXTENSION suite builders (tool/parity-ext): the
// conversation headers - channel (short / long / no description, private),
// agent and human DM, the side thread panel - plus the Chat/Tasks/Files tab
// strip under them, at desktop and mobile widths. NOT official cases; ids are
// `components.channelheader.<platform>.<state>.<theme>`, dispatched on
// props like tool/parity-ext/host/ChannelHeaderCases.tsx.
//
// The REAL WorkspaceView is mounted at the case viewport and the capture is
// the same window the React host clips: the top `windowHeight` px of the
// desktop main column (viewport - rail - 240 sidebar), of the 400px side
// thread column, or of the 390 mobile page.
//
// Data: tool/parity-ext/fixtures/channelheader.json (fixtures['ext:channelheader']).
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parity_harness.dart';
import 'thread_composer/fake_workspace.dart';

Map<String, dynamic> _fx(ParityContext ctx) =>
    ctx.fixtures['ext:channelheader'] as Map<String, dynamic>;

WorkspaceController _workspace(ParityContext ctx) {
  SharedPreferences.setMockInitialValues({});
  final fx = _fx(ctx);
  final base = ParityThreadFixture(ctx.fixtureData);
  final cindy = base.agent('cindy');
  final designer = base.human('designer');
  final client = ParityFakeClient(
    user: base.authUser,
    routes: {
      'GET /agents': [
        {
          'id': cindy['id'],
          'serverId': 'visual-server',
          'name': cindy['name'],
          'displayName': cindy['displayName'],
          'avatarUrl': cindy['avatar'],
          'description': cindy['description'],
          'status': cindy['status'],
          'activity': cindy['activity'],
          'activityDetail': cindy['activityDetail'],
          'deletedAt': null,
        },
      ],
      'GET /servers/visual-server/members': [
        ...base.serverMembers,
        {
          'id': designer['id'],
          'userId': designer['id'],
          'serverId': 'visual-server',
          'name': designer['name'],
          'displayName': designer['displayName'],
          'description': designer['description'],
          'avatarUrl': null,
          'email': designer['email'],
          'role': designer['role'],
        },
      ],
    },
  );
  final channels = [
    for (final c in fx['channels'] as List)
      RaftChannel(Map<String, dynamic>.from(c as Map)),
  ];
  final dms = [
    for (final c in fx['dms'] as List)
      RaftChannel(Map<String, dynamic>.from(c as Map)),
  ];
  final w = WorkspaceController(client)
    ..server = RaftRecord(base.serverRecord)
    ..channels = channels
    ..dms = dms;
  w.ledger.switchServer('visual-server');
  return w;
}

/// Window the React host clips, in viewport coordinates.
Rect _window(ParityContext ctx) {
  final height = (ctx.props['windowHeight'] as num? ?? 120).toDouble();
  if (ctx.props['platform'] == 'mobile') {
    return Rect.fromLTWH(0, 0, ctx.width, height);
  }
  final width = ctx.props['thread'] == 'true'
      ? 400.0
      : ctx.width - (ctx.family == RaftFamily.brutal ? 64 : 56) - 240;
  return Rect.fromLTWH(ctx.width - width, 0, width, height);
}

class _Host extends StatefulWidget {
  const _Host({required this.ctx});
  final ParityContext ctx;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late final WorkspaceController w = _workspace(widget.ctx);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    final ctx = widget.ctx;
    final id = ctx.props['channel'] as String;
    final channel = [...w.channels, ...w.dms].firstWhere((c) => c.id == id);
    await w.selectChannel(channel);
    if (ctx.props['thread'] == 'true') {
      final thread = Map<String, dynamic>.from(_fx(ctx)['thread'] as Map);
      await w.openThreadIdentity(
        parentChannelId: thread['parentChannelId'] as String,
        parentMessageId: thread['parentMessageId'] as String,
        initialThreadChannelId: thread['threadChannelId'] as String,
      );
    }
  }

  @override
  Widget build(BuildContext context) => WorkspaceView(
    controller: w,
    appearance: RaftAppearance(
      mode: widget.ctx.dark ? ThemeMode.dark : ThemeMode.light,
      light: widget.ctx.family,
    ),
    onAppearance: (_) async {},
    onLogout: () async {},
  );
}

Widget _build(ParityContext ctx) {
  final window = _window(ctx);
  return Align(
    alignment: Alignment.topLeft,
    child: ctx.target(
      SizedBox.fromSize(
        size: window.size,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: ctx.width,
            maxWidth: ctx.width,
            minHeight: ctx.height,
            maxHeight: ctx.height,
            child: Transform.translate(
              offset: -window.topLeft,
              child: _Host(ctx: ctx),
            ),
          ),
        ),
      ),
    ),
  );
}

final ParityCase _case = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_ui:RaftChannelHeader',
    'raft_ui:RaftThreadHeader',
    'raft_ui:RaftConversationTabs',
  ],
  notes: 'Extension suite (not official). Real WorkspaceView, clipped window.',
  settle: const Duration(milliseconds: 900),
  build: _build,
);

const _states = {
  'desktop': [
    'short',
    'long',
    'none',
    'private',
    'dm-agent',
    'dm-human',
    'thread',
    'hover-search',
    'newline',
  ],
  'mobile': ['short', 'long', 'none', 'private', 'dm-agent', 'thread', 'newline'],
};

/// Every extension conversation-header case, keyed by id (3 themes each).
final Map<String, ParityCase> extChannelHeaderCases = {
  for (final MapEntry(key: platform, value: states) in _states.entries)
    for (final state in states)
      for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
        'components.channelheader.$platform.$state.$theme': _case,
};
