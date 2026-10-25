// raft-flutter parity EXTENSION suite builders (tool/parity-ext): the desktop
// Settings page (Settings rail + panel) for the Workspace and Resources groups.
// NOT official cases; ids are `components.ext-settings.<extCase>.<theme>`,
// built from props.tab / props.role / props.flags / props.routeSet exactly like
// tool/parity-ext/host/SettingsCases.tsx.
//
// Frame: the desktop shell minus the 64px rail (1216 wide), i.e. the
// WorkspaceSettings page WorkspaceView.settings() mounts in the content
// column. Data: tool/parity-ext/fixtures/settings.json (fixtures['ext:settings'])
// on top of the official fixture user/server (members_settings MsFixture).
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/features/workspace_settings.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_flutter/platform/app_update.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parity_harness.dart';
import 'members_settings/fixture_client.dart';
import 'release_notes_source.dart';

Map<String, dynamic> _fx(ParityContext ctx) =>
    ctx.fixtures['ext:settings'] as Map<String, dynamic>;

/// fixture `routes` + `routeSets[props.routeSet]`; `$pending` never answers,
/// `$status` fails with that status (the React provider spec does the same).
MsRoutes _routes(ParityContext ctx) {
  final fx = _fx(ctx);
  final merged = {
    ...Map<String, dynamic>.from(fx['routes'] as Map),
    ...Map<String, dynamic>.from(
      ((fx['routeSets'] as Map?)?[ctx.props['routeSet']] as Map?) ?? const {},
    ),
    // Missing-page route sets (fixtures/auth-pages.json) apply to the same cases by name.
    ...Map<String, dynamic>.from(
      ((((ctx.fixtures['ext:auth-pages'] as Map?)?['routeSets'])
                  as Map?)?[ctx.props['routeSet']]
              as Map?) ??
          const {},
    ),
    // WP6 route sets (fixtures/wp6.json) apply to the same cases by name.
    ...Map<String, dynamic>.from(
      ((((ctx.fixtures['ext:wp6'] as Map?)?['routeSets'])
                  as Map?)?[ctx.props['routeSet']]
              as Map?) ??
          const {},
    ),
    // RaftBench route sets (fixtures/raftbench.json).
    ...Map<String, dynamic>.from(
      ((((ctx.fixtures['ext:raftbench'] as Map?)?['routeSets'])
                  as Map?)?[ctx.props['routeSet']]
              as Map?) ??
          const {},
    ),
  };
  return {
    for (final MapEntry(:key, :value) in merged.entries)
      key: (_) {
        if (value is Map && value[r'$pending'] == true) {
          return Completer<Object?>().future;
        }
        if (value is Map && value[r'$status'] != null) {
          return RaftApiException(
            'fixture error',
            status: value[r'$status'] as int,
          );
        }
        return value;
      },
  };
}

Widget _page(ParityContext ctx) {
  SharedPreferences.setMockInitialValues({});
  final fixture = MsFixture(ctx);
  final role = ctx.props['role'] as String? ?? 'owner';
  final flags = '${ctx.props['flags'] ?? ''}'.split(',').toSet();
  // Server feature flags the React host sets before render (props.flags).
  const flagKeys = {
    'labs': 'server_labs_ui_v0',
    'providers': 'provider_connections_v0',
    'bridge': 'slack_bridge_v0',
    'analytics': 'product_analytics_settings_v0',
    'raftbench': 'raftbench_overview_v0',
  };
  final enabled = {
    for (final MapEntry(:key, :value) in flagKeys.entries)
      if (flags.contains(key)) value,
  };
  final routeSet = ctx.props['routeSet'] as String? ?? '';
  // Store-primed Administration states (the React host patches the same).
  final serverJson = {
    ...fixture.server,
    'role': role,
    if (routeSet == 'admin-hide-humans') 'hideHumansFromMembers': true,
    // Missing-page cases patch the server record (props.patch names fixtures/auth-pages.json
    // `serverPatches`, e.g. planDowngradedAt).
    ...Map<String, dynamic>.from(
      (((ctx.fixtures['ext:auth-pages'] as Map?)?['serverPatches']
                  as Map?)?[ctx.props['patch']]
              as Map?) ??
          const {},
    ),
  };
  final (w, fixtureClient) = fixture.workspace(
    channels: ctx.props['tab'] == 'raftbench'
        ? const ['design', 'androidArtifacts']
        : const ['design'],
    {
      'GET /servers/visual-server': (_) => serverJson,
      // The official spec's /api/agents rows (fxAgentDetailAgents).
      'GET /agents': (_) => fixture.agents,
      'POST /feature-flags/evaluate': (data) => {
        'evaluations': [
          for (final key in (data is Map ? data['keys'] as List? : null) ?? [])
            {'key': key, 'enabled': enabled.contains(key)},
        ],
      },
      ..._routes(ctx),
    },
    fallback: (method, path, data) => _fx(ctx)['fallback'],
  );
  // WP6 per-case signed-in user preferences (host/Wp6Cases.tsx
  // PARITY_EXT_WP6_USER_PREFS).
  // The official visual user (VisualTestingCases.tsx) translates manually.
  final prefs = ctx.props['extKind'] != 'wp6'
      ? null
      : {
          'preferredTranslationMode': 'manual',
          'preferredTranslationDisplay': 'translated',
          'preferredTimeFormat': '24h',
          ...?switch (ctx.props['prefs']) {
            'translation-off' => {'preferredTranslationMode': 'off'},
            'translation-manual' => {
              'preferredTranslationDisplay': 'bilingual',
            },
            _ => null,
          },
        };
  if (prefs != null) {
    fixtureClient.user = RaftRecord({...?fixtureClient.user?.json, ...prefs});
  }
  if (routeSet == 'admin-all-visible') {
    w.channels = [
      RaftChannel({
        ...fixture.channel('design'),
        'id': 'channel-all',
        'name': 'all',
      }),
      ...w.channels,
    ];
  }
  // Missing-page case 'archived': archived channels join the channel list (the React host
  // patches the channel store with fixtures/auth-pages.json `archivedChannels`).
  if (ctx.props['patch'] == 'archived') {
    final base = w.channels.first.json;
    w.channels = [
      ...w.channels,
      for (final c
          in (ctx.fixtures['ext:auth-pages'] as Map)['archivedChannels']
              as List)
        RaftChannel({
          ...base,
          ...Map<String, dynamic>.from(c as Map),
          'joined': true,
        }),
    ];
  }
  final server = RaftRecord(serverJson);
  w
    ..server = server
    ..servers = [server];
  // Mobile cases: SettingsPanel fills the 390px viewport (the React host
  // mounts it alone); desktop: the 1216px page beside the 64px rail.
  final mobile = ctx.props['platform'] == 'mobile';
  // The React provider freezes its clock at the fixture instant (the Free
  // trial notice and relative dates read it).
  final now = DateTime.fromMillisecondsSinceEpoch(
    (ctx.fixtureData['locale']['nowEpochMillis'] as num).toInt(),
  );
  Widget page(AppUpdateService? updates) => Material(
    type: MaterialType.transparency,
    child: WorkspaceSettings(
      controller: w,
      appUpdate: updates,
      appearance: const RaftAppearance(mode: ThemeMode.light),
      onAppearance: (_) {},
      presentation: PersonalPresentationStore(),
      notifications: NativeNotificationService(platform: TargetPlatform.linux),
      onLogout: () async {},
      initialTab: ctx.props['tab'] as String,
      mobileRoot: false,
      providerEnabled: flags.contains('providers'),
      bridgeEnabled: flags.contains('bridge'),
      labsEnabled: flags.contains('labs'),
      now: () => now,
      appVersion: _fx(ctx)['appVersion'] as String,
      // The React render host's origin (the QR encodes `<origin>/download`).
      frontendOrigin: Uri.parse(
        'http://127.0.0.1:${Platform.environment['PARITY_EXT_WEB_PORT'] ?? '4396'}',
      ),
    ),
  );
  return ctx.frame(
    width: mobile ? ctx.width : 1216,
    height: ctx.height,
    padding: EdgeInsets.zero,
    child: ctx.props['tab'] == 'release-notes'
        ? ParityReleaseNotesSource(
            load: () => fixtureClient.request('GET', '/release-notes'),
            version: _fx(ctx)['appVersion'] as String,
            now: now,
            platform: mobile ? TargetPlatform.android : TargetPlatform.linux,
            builder: page,
          )
        : page(null),
  );
}

/// The Settings page of one extension case (shared with the WP6 cases).
Widget extSettingsPage(ParityContext ctx) => _page(ctx);

final _case = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceSettings',
    'raft_flutter:RaftSettingsPage',
    'raft_ui:RaftSettingsSidebarList',
    'raft_ui:RaftSettingsPanelFrame',
  ],
  notes: 'Extension suite (not official).',
  settle: const Duration(milliseconds: 800),
  build: _page,
);

/// Every extension settings case, keyed by id (3 themes each).
final Map<String, ParityCase> extSettingsCases = {
  for (final key in _extSettingsKeys)
    for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
      'components.ext-settings.$key.$theme': _case,
};

const _extSettingsKeys = [
  'nav.owner',
  'nav.owner-all',
  'nav.member',
  'nav.guest',
  'nav.release-notes-active',
  'nav.row-hover',
  'about.page',
  'about.panel',
  'about.version',
  'about.mobile-app',
  'about.workspace',
  'release-notes.page',
  'release-notes.panel',
  'release-notes.current',
  'release-notes.retracted',
  'release-notes.older',
  'release-notes.loading',
  'release-notes.error',
  'release-notes.empty',
  'feedback.page',
  'feedback.panel',
  'feedback.empty',
  'feedback.loading',
  'feedback.error',
  'feedback.new',
  'feedback.new-filled',
  'feedback.new-submitting',
  'feedback.new-error',
  'feedback.ticket',
  'feedback.ticket-reply',
  'feedback.ticket-reply-error',
  'feedback.ticket-closed',
  'feedback.close-menu',
  'feedback.close-confirm',
  'feedback.close-confirm-resolved',
  'feedback.close-error',
  'server.page',
  'server.panel',
  'billing.page',
  'billing.panel',
  'billing.current-plan',
  'billing.summary',
  'billing.pro',
  'billing.pro-plan',
  'billing.pro-summary',
  'billing.admin',
  'billing.loading',
  'billing.confirm-checkout',
  'billing.mobile',
  'billing.mobile-pro',
  'administration.page',
  'administration.panel',
  'administration.all',
  'administration.admins',
  'administration.system-channels',
  'administration.invites',
  'administration.join-links',
  'administration.pre-join-agreement',
  'administration.onboarding',
  'administration.translation',
  'administration.product-analytics',
  'administration.member-permissions',
  'administration.admins.picker-open',
  'administration.admins.selected',
  'administration.admins.as-admin',
  'administration.invites.empty',
  'administration.join-links.empty',
  'administration.pre-join-agreement.disabled',
  'administration.onboarding.setup',
  'administration.translation.provider-warning',
  'administration.system-channels.visible',
  'administration.member-permissions.hidden',
  'administration.invites.confirm',
  'administration.join-links.confirm',
  'administration.mobile.admins',
  'administration.mobile.join-links',
  'administration.mobile.onboarding',
  'administration.mobile.pre-join-agreement',
  'integrations.page',
  'integrations.panel',
  'integrations.installed',
  'integrations.my-apps',
  'integrations.list',
  'integrations.member',
  'integrations.empty',
  'integrations.detail',
  'integrations.detail-installed',
  'integrations.installed-detail',
  'integrations.mobile',
  'integrations.mobile-detail',
  'mcp.page',
  'mcp.panel',
  'labs.page',
  'labs.panel',
  'providers.page',
  'providers.panel',
  'im-bridges.page',
  'im-bridges.panel',
  'account.page',
  'account.panel',
  'appearance.page',
  'appearance.panel',
  'notifications.page',
  'notifications.panel',
  'about.mobile',
  'mcp.mobile',
  'labs.mobile',
  'providers.mobile',
  'im-bridges.mobile',
];
