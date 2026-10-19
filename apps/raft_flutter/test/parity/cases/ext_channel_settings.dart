// raft-flutter parity EXTENSION suite builders (tool/parity-ext): the channel
// and DM settings drawer (Web ChannelOverflowMenu -> OverflowSheet with the
// MembersStrip, EditChannelDialog panel and ChannelPreferencesSection), its
// ConfirmDialogs and the unsaved-changes prompt, at desktop and mobile widths.
// NOT official cases; ids are `components.channelsettings.<platform>.<state>.
// <theme>`, built from props.channel / role / guestFlag / pinned / routeSet
// exactly like tool/parity-ext/host/ChannelSettingsCases.tsx.
//
// The REAL WorkspaceView is mounted at the case viewport; the case's
// `capture.androidInteractions` tap the header gear (and whatever the React
// interactions click next) and `capture.androidKey` is the Flutter widget the
// React selector corresponds to (the sheet, the ConfirmDialog surface or the
// unsaved prompt).
//
// Data: tool/parity-ext/fixtures/channelsettings.json
// (fixtures['ext:channelsettings']).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parity_harness.dart';
import 'thread_composer/fake_workspace.dart';
import '../../support/app_services_fixture.dart';

Map<String, dynamic> _fx(ParityContext ctx) =>
    ctx.fixtures['ext:channelsettings'] as Map<String, dynamic>;

/// fixture `routes` + `routeSets[props.routeSet]`; `$pending` never answers,
/// `$status` fails with that status (the React provider spec does the same).
Map<String, dynamic> _routes(ParityContext ctx) {
  final fx = _fx(ctx);
  final merged = {
    ...Map<String, dynamic>.from(fx['routes'] as Map),
    ...Map<String, dynamic>.from(
      ((fx['routeSets'] as Map?)?[ctx.props['routeSet']] as Map?) ?? const {},
    ),
  };
  return {
    for (final MapEntry(:key, :value) in merged.entries)
      key: value is Map && value[r'$pending'] == true
          ? Completer<Object?>().future
          : value,
  };
}

WorkspaceController _workspace(ParityContext ctx) {
  SharedPreferences.setMockInitialValues({});
  final fx = _fx(ctx);
  final base = ParityThreadFixture(ctx.fixtureData);
  final role = ctx.props['role'] as String? ?? 'owner';
  final guestFlag = ctx.props['guestFlag'] == 'true';
  final channelId = ctx.props['channel'] as String;
  final routes = _routes(ctx);
  // Pin switch state (ChannelPreferencesSection reads sidebarOrder.pinned).
  if (ctx.props['pinned'] == 'true') {
    routes['GET /servers/visual-server/sidebar-order'] = {
      'channelOrder': [],
      'agentOrder': [],
      'dmOrder': [],
      'pinned': [
        {'kind': 'channel', 'id': channelId},
      ],
      'customSections': [],
      'sectionPlacements': [],
    };
  }
  final cindy = base.agent('cindy');
  final client = ParityFakeClient(
    user: base.authUser,
    routes: {
      ...routes,
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
      'GET /servers/visual-server/members': base.serverMembers,
      // Only the server_guest flag follows the case (props.guestFlag).
      'POST /feature-flags/evaluate': {
        'evaluations': [
          {'key': 'server_guest_v0', 'enabled': guestFlag},
        ],
      },
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
    ..server = RaftRecord({...base.serverRecord, 'role': role})
    ..channels = channels
    ..dms = dms;
  w.messageDomain.ledger.switchServer('visual-server');
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    final id = widget.ctx.props['channel'] as String;
    final channel = [...w.channels, ...w.dms].firstWhere((c) => c.id == id);
    await w.selectChannel(channel);
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

final ParityCase _case = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_flutter:ChannelSettings',
    'raft_ui:RaftOverflowSheet',
    'raft_ui:RaftMembersStrip',
    'raft_ui:RaftChannelInfoForm',
    'raft_ui:RaftOverflowActions',
  ],
  notes:
      'Extension suite (not official). Real WorkspaceView; the gear opens '
      'the product ChannelSettings drawer.',
  settle: const Duration(milliseconds: 900),
  build: (ctx) => _Host(ctx: ctx),
);

/// Every extension channel-settings case in the manifest being run, keyed by
/// id (the ids are generated by tool/parity-ext/build-channel-settings.py, so
/// the state list lives in one place).
final Map<String, ParityCase> extChannelSettingsCases = () {
  final path = Platform.environment['PARITY_MANIFEST'];
  if (path == null || !File(path).existsSync()) return <String, ParityCase>{};
  final cases =
      (jsonDecode(File(path).readAsStringSync()) as Map)['cases'] as List;
  return {
    for (final c in cases)
      if ((c as Map)['id'].toString().startsWith('components.channelsettings.'))
        c['id'] as String: _case,
  };
}();
