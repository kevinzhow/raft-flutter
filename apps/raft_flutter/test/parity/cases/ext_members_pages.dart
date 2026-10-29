// raft-flutter parity EXTENSION suite builders (tool/parity-ext): members /
// agents / humans pages that had no case (page inventory area 7, rows 4.06 /
// 4.07). NOT official cases; ids are
// `components.members-pages.<platform>.<key>.<theme>` (platform = desktop |
// phone), dispatched on props.extKind exactly like
// tool/parity-ext/host/MembersPagesCases.tsx.
//
// Data: tool/parity-ext/fixtures/members-pages.json (fixtures['ext:members-pages']),
// the same file the React render host imports; its `routes` + the case's route
// set answer the API on both providers. Cases whose Web page the Flutter app
// does not have are NOT registered here (the builder lists them as
// "Flutter page missing").
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_flutter/features/member_graph_view.dart';
import 'package:raft_flutter/features/member_profile_view.dart';
import 'package:raft_flutter/features/workspace_menu_invite.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parity_harness.dart';
import 'ext_channel_settings.dart' show extChannelSettingsCases;
import 'ext_members_pages_keys.g.dart';
import 'members_settings/runtime_forms.dart' show msRuntimeForms;
import 'fixture_when.dart';
import 'screens/screen_fixture.dart';
import '../../support/app_services_fixture.dart';

const _serverId = 'visual-server';

Map<String, dynamic> _fx(ParityContext ctx) =>
    ctx.fixtures['ext:members-pages'] as Map<String, dynamic>;

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
  final routes = _routes(ctx);
  var answer = resolveFixtureWhen(routes['$method $path'], query);
  // The agent's runtime form (v2 protocol) the edit dialog loads: the shared
  // codex form of the official create-agent cases (the Web host edits the same
  // config through its bundled catalog, which has no wire counterpart here).
  final form = RegExp(r'^/agents/[^/]+/runtime-form$').hasMatch(path);
  if (method == 'GET' && answer == null && form) {
    return Map<String, dynamic>.from(msRuntimeForms['forms']['codex'] as Map);
  }
  final source = RegExp(
    r'/runtime-form(s/v2/codex)?/option-sources/([^/]+)$',
  ).firstMatch(path);
  if (method == 'GET' && answer == null && source != null) {
    final found =
        (msRuntimeForms['staticSources'] as Map)['codex.${source[2]}'];
    if (found != null) return Map<String, dynamic>.from(found as Map);
    throw RaftApiException('Computer unavailable', status: 503);
  }
  if (answer == null) {
    return ScreenWire(ctx.fixtureData).common(method, path, query);
  }
  if (answer is Map && answer['\$pending'] == true) {
    return ScreenFixtureClient.pending;
  }
  if (answer is Map && answer['\$status'] != null) {
    throw RaftApiException('fixture error', status: answer['\$status'] as int);
  }
  return answer;
}

WorkspaceController _workspace(ParityContext ctx, {bool mobile = false}) {
  SharedPreferences.setMockInitialValues({});
  final wire = ScreenWire(ctx.fixtureData);
  final client = ScreenFixtureClient(
    (method, path, query) => _answer(ctx, method, path, query),
    user: wire.me(),
    server: _serverId,
  );
  final w = WorkspaceController(client, mobileNavigation: mobile);
  final server = RaftRecord(wire.server());
  w
    ..servers = [server]
    ..server = server;
  w.messageDomain.ledger.switchServer(_serverId);
  // The app always holds the channel lists; the Activity tab's reference pills
  // resolve against them.
  if ('${ctx.props['routeSet']}'.startsWith('act-')) {
    unawaited(w.refreshChannels());
  }
  return w;
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
  void initState() {
    super.initState();
    // `props.unavailable`: the Web route /agent/<id> for an id the store does
    // not hold (terminated or no access); reached by location, not by a row.
    if (widget.ctx.props['unavailable'] == 'true') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final route = widget.ctx.props['route'] as String;
        w.navigation.navigate(
          RaftLocation.at(
            serverSlug: w.location.serverSlug,
            route: RaftRoute.agent,
            entityId: route.split('/').last,
          ),
        );
        w.notifyListeners();
      });
    }
  }

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
      ),
      onAppearance: (_) async {},
      onLogout: () async {},
    ),
  );
}

/// The phone route page the app builds for `/human/<id>` and `/agent/<id>`
/// (the mobile members list pushes it): the real `MemberProfileView` / the
/// `FleetDetail` route over the page below, like the official screens.* cases.
Widget _phoneDetail(ParityContext ctx) {
  final route = ctx.props['route'] as String;
  if (route == '/members/graph') {
    // The phone page `/members/graph`: the graph route over the members page.
    return ScreenWorkspaceHost(
      create: () => _workspace(ctx, mobile: true)..loadSidebar(),
      builder: (context, w) => ScreenRouteStack(
        pages: [
          (_) => const SizedBox.expand(),
          (_) => MemberGraphPage(
            controller: w,
            sectionLabel: 'Connections',
            onBack: () {},
          ),
        ],
      ),
    );
  }
  final id = route.split('/').last;
  const webTabs = {'integrations': AgentDetailTab.apps};
  final tabName = (ctx.props['routeQuery'] as String?)?.split('=').last;
  final tab =
      webTabs[tabName] ??
      AgentDetailTab.values.where((t) => t.name == tabName).firstOrNull ??
      AgentDetailTab.profile;
  final roster =
      (_fx(ctx)['rosters'] as Map)[ctx.props['roster'] ?? 'default'] as List;
  final row = roster
      .whereType<Map>()
      .where((a) => a['id'] == id)
      .map(Map<String, dynamic>.from)
      .firstOrNull;
  return ScreenWorkspaceHost(
    // `loadSidebar` brings the server's `agentPanelTabOrder` (the Web store holds it from boot).
    create: () => _workspace(ctx, mobile: true)..loadSidebar(),
    builder: (context, w) => route.startsWith('/human/')
        ? MemberProfileView(
            controller: w,
            userId: id,
            onClose: () {},
            onBack: () {},
            onMessage: () async {},
          )
        : ScreenRouteStack(
            pages: [
              (_) => const SizedBox.expand(),
              (_) => FleetDetail(
                controller: w,
                computers: false,
                initial: row ?? {'id': id},
                initialTab: tab,
                clock: () => DateTime.fromMillisecondsSinceEpoch(
                  (ctx.fixtureData['locale']['nowEpochMillis'] as num).toInt(),
                  isUtc: true,
                ),
              ),
            ],
          ),
  );
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

/// The Report issue dialog alone (the Web host mounts `ReportIssueDialog`
/// with the first roster agent): the real `RaftReportIssueDialog`, whose
/// machine log option follows the agent's Computer row.
Widget _report(ParityContext ctx) {
  final roster = (_fx(ctx)['rosters'] as Map)['default'] as List;
  final agent = Map<String, dynamic>.from(roster.first as Map);
  final machineId = agent['machineId'];
  return RaftReportIssueDialog(
    agentName: '${agent['displayName'] ?? agent['name']}',
    hasMachine: machineId is String && machineId.isNotEmpty,
    canIncludeMachineLog: false,
    onSubmit: (_) async =>
        throw const RaftReportIssueFailure('not submitted in the capture'),
    onClose: () {},
  );
}

ParityCase _case(String kind) => ParityCase(
  widgets: switch (kind) {
    'invite' => const ['raft_flutter:RaftInviteHumanDialog'],
    'report' => const ['raft_ui:RaftReportIssueDialog'],
    _ => const [
      'raft_flutter:WorkspaceView',
      'raft_flutter:MemberProfileView',
      'raft_flutter:AgentDetailPanel',
      'raft_ui:RaftPanelHeaderBar',
    ],
  },
  notes: 'Extension suite (not official).',
  settle: const Duration(milliseconds: 600),
  build: (ctx) => switch (ctx.props['extKind']) {
    'main' =>
      ctx.props['platform'] == 'mobile' &&
              RegExp(
                r'^/(human/|agent/|members/graph)',
              ).hasMatch('${ctx.props['route']}')
          ? _phoneDetail(ctx)
          : _Shell(ctx: ctx),
    'invite' => _InviteHost(ctx: ctx),
    'report' => _report(ctx),
    _ => throw StateError('unknown members-pages kind ${ctx.props['extKind']}'),
  },
);

/// Every extension members-pages case Flutter implements, keyed by id
/// (3 themes each).
final Map<String, ParityCase> extMembersPagesCases = {
  for (final MapEntry(key: key, value: kind)
      in extMembersPagesCaseKinds.entries)
    for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
      'components.members-pages.$key.$theme': _case(kind),
};

/// The channel-settings drawer's members page cases (the
/// `components.channelsettings.{platform}.members-page` ones) with this suite's
/// fixture swapped in (the role action variant) and extra interactions from the case.
ParityCase _channelCase(String key) {
  final platform = key.startsWith('desktop') ? 'desktop' : 'mobile';
  final base =
      extChannelSettingsCases['components.channelsettings.$platform.members-page.brutal']!;
  ParityContext swap(ParityContext c) => ParityContext(
    caseJson: c.caseJson,
    fixtures: {
      ...c.fixtures,
      'ext:channelsettings': c.fixtures['ext:members-pages-channel'],
    },
    dark: c.dark,
  );
  return ParityCase(
    widgets: base.widgets,
    notes: 'Extension suite (not official). Base: ${base.notes}',
    settle: base.settle,
    build: (ctx) => base.build(swap(ctx)),
    interact: base.interact == null
        ? null
        : (t, ctx) => base.interact!(t, swap(ctx)),
  );
}

/// Channel members page cases, keyed `{platform}.channel-members.{state}`
/// (3 themes each).
final Map<String, ParityCase> extMembersPagesChannelCases = {
  // Empty without an extension manifest (extChannelSettingsCases is), e.g. in
  // the official tool/parity run.
  if (extChannelSettingsCases.isNotEmpty)
    for (final key in extMembersPagesChannelKeys)
      for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
        'components.members-pages.$key.$theme': _channelCase(key),
};
