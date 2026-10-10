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
import 'package:raft_flutter/features/workspace_mode_settings_card.dart';
import 'package:raft_flutter/features/workspace_settings.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parity_harness.dart';
import 'members_settings/fixture_client.dart';

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
  };
  final enabled = {
    for (final MapEntry(:key, :value) in flagKeys.entries)
      if (flags.contains(key)) value,
  };
  final (w, _) = fixture.workspace({
    'GET /servers/visual-server': (_) => {...fixture.server, 'role': role},
    'POST /feature-flags/evaluate': (data) => {
      'evaluations': [
        for (final key in (data is Map ? data['keys'] as List? : null) ?? [])
          {'key': key, 'enabled': enabled.contains(key)},
      ],
    },
    ..._routes(ctx),
  }, fallback: (method, path, data) => _fx(ctx)['fallback']);
  final server = RaftRecord({...fixture.server, 'role': role});
  w
    ..server = server
    ..servers = [server];
  return ctx.frame(
    width: 1216,
    height: ctx.height,
    padding: EdgeInsets.zero,
    child: Material(
      type: MaterialType.transparency,
      child: WorkspaceSettings(
        controller: w,
        appearance: const RaftAppearance(mode: ThemeMode.light),
        onAppearance: (_) {},
        presentation: PersonalPresentationStore(),
        notifications: NativeNotificationService(
          platform: TargetPlatform.linux,
        ),
        onLogout: () async {},
        initialTab: ctx.props['tab'] as String,
        mobileRoot: false,
        workspaceModeCard: WorkspaceModeSettingsCard(controller: w),
        providerEnabled: flags.contains('providers'),
        bridgeEnabled: flags.contains('bridge'),
        labsEnabled: flags.contains('labs'),
        appVersion: _fx(ctx)['appVersion'] as String,
        // The React render host's origin (the QR encodes `<origin>/download`).
        frontendOrigin: Uri.parse(
          'http://127.0.0.1:${Platform.environment['PARITY_EXT_WEB_PORT'] ?? '4396'}',
        ),
      ),
    ),
  );
}

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
  'server.page',
  'server.panel',
  'billing.page',
  'billing.panel',
  'administration.page',
  'administration.panel',
  'integrations.page',
  'integrations.panel',
  'mcp.page',
  'mcp.panel',
  'labs.page',
  'labs.panel',
  'providers.page',
  'providers.panel',
  'im-bridges.page',
  'im-bridges.panel',
];
