// raft-flutter parity EXTENSION suite builders (tool/parity-ext): MISSING auth / onboarding / entry pages.
// NOT official cases; ids `components.auth-pages.<platform>.<surface>.<theme>` mirror
// tool/parity-ext/build-auth-pages.py and host/AuthPagesCases.tsx (dispatch on props.view).
//
// Data: tool/parity-ext/fixtures/auth-pages.json (fixtures['ext:auth-pages']); `routes` +
// `routeSets[props.routeSet]` answer the API for both providers (`$pending` never answers, `$status` fails
// with that status).
//
// Surfaces the Flutter app does not implement are listed in [extAuthPagesUncovered] with the reason (gap
// `noFlutterSurface`): the Web case still renders the page, the Flutter side has no widget to capture.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/account_onboarding.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/community_join.dart'
    show communityAgreementError;
import 'package:raft_flutter/features/global_server_selector.dart';
import 'package:raft_flutter/features/invite_accept_view.dart';
import 'package:raft_flutter/features/server_setup_gate.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';
import 'ext_settings.dart' show extSettingsPage;
import 'screens/screen_fixture.dart';

const _origin = 'http://localhost:13041';

Map<String, dynamic> _fx(ParityContext ctx) =>
    ctx.fixtures['ext:auth-pages'] as Map<String, dynamic>;

/// The fixture answer of `METHOD path` for this case, throwing the error a `$status` rule stands for.
Object? _answer(ParityContext ctx, String method, String path) {
  final fx = _fx(ctx);
  final merged = {
    ...Map<String, dynamic>.from(fx['routes'] as Map),
    ...Map<String, dynamic>.from(
      ((fx['routeSets'] as Map?)?[ctx.props['routeSet']] as Map?) ?? const {},
    ),
  };
  final value = merged['$method $path'];
  if (value is Map && value[r'$pending'] == true) {
    return ScreenFixtureClient.pending;
  }
  if (value is Map && value[r'$status'] != null) {
    final body = Map<String, dynamic>.from(value[r'$body'] as Map? ?? const {});
    throw RaftApiException.response(
      '${body['error'] ?? 'fixture error'}',
      status: value[r'$status'] as int,
      body: body,
    );
  }
  return value ?? <String, dynamic>{};
}

Widget _register(ParityContext ctx) => AuthView(
  origin: _origin,
  initialMode: 'register',
  onLogin: (_, _, _) async {},
  onRegister: (_, _, _, _) async {
    final answer = _answer(ctx, 'POST', '/auth/register');
    if (identical(answer, ScreenFixtureClient.pending)) {
      await Completer<void>().future;
    }
  },
  onOAuth: (_, _, _, _) async {},
  anonymousClientFactory: (origin) => ScreenFixtureClient(
    (method, path, query) => _answer(ctx, method, path),
    origin: origin,
  ),
);

/// App.tsx AuthBootstrapStatus / ServerSelectionPage / ServerResolver splashes: one cream box with the
/// label centred (main.dart shows the same widget while the session restores).
Widget _splash(String label) => RaftServerResolutionBody(label: label);

/// RootErrorFallback over fixtures `rootError` (message, stack, React component stack).
Widget _rootError(ParityContext ctx) {
  final error = _fx(ctx)['rootError'] as Map<String, dynamic>;
  return RaftRootErrorFallback(
    message: error['message'] as String,
    stack: error['stack'] as String,
    componentStack: error['componentStack'] as String,
    onReload: () {},
  );
}

/// ServerAccessDeniedPage over the case's server list (the fallback is the first server).
Widget _serverDenied(ParityContext ctx) {
  final servers =
      (_fx(ctx)['servers'] as Map)[ctx.props['servers']] as List? ?? const [];
  return RaftServerAccessDeniedPage(
    serverName: servers.isEmpty
        ? null
        : (servers.first as Map)['name'] as String,
    onContinue: () {},
  );
}

/// ServerSetupProjectionGate over a blank page (the Web case mounts the gate alone): the
/// deferred-setup resume bar floats at the bottom of the viewport.
Widget _setupGate(ParityContext ctx) {
  final fx = _fx(ctx);
  final server = Map<String, dynamic>.from(
    ((fx['servers'] as Map)[ctx.props['servers']] as List).first as Map,
  );
  return ScreenClientHost(
    create: () => ScreenFixtureClient(
      (method, path, query) => _answer(ctx, method, path),
      user: Map<String, dynamic>.from(fx['user'] as Map),
      server: server['id'] as String,
    ),
    builder: (context, client) => _SetupGateHost(
      controller: WorkspaceController(client)..server = RaftRecord(server),
    ),
  );
}

class _SetupGateHost extends StatefulWidget {
  const _SetupGateHost({required this.controller});
  final WorkspaceController controller;
  @override
  State<_SetupGateHost> createState() => _SetupGateHostState();
}

class _SetupGateHostState extends State<_SetupGateHost> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: ServerSetupGate(
      controller: widget.controller,
      child: const SizedBox.expand(),
    ),
  );
}

/// CommunityAgreementDialog over a blank page: `props.kind` 'error' fails the join with
/// agreement_changed, 'pending' never answers (the interaction presses "Agree & Continue").
Widget _communityAgreement(ParityContext ctx) {
  final agreement = _fx(ctx)['agreement'] as Map<String, dynamic>;
  final kind = ctx.props['kind'];
  return Stack(
    children: [
      const Positioned.fill(child: ColoredBox(color: Colors.white)),
      Positioned.fill(
        child: RaftCommunityAgreementDialog(
          title: agreement['title'] as String,
          version: agreement['version'] as int,
          bodyMarkdown: agreement['bodyMarkdown'] as String,
          errorMessage: communityAgreementError,
          onClose: () {},
          onAgree: () async {
            if (kind == 'pending') await Completer<void>().future;
            if (kind == 'error') {
              throw const RaftApiException('agreement_changed');
            }
          },
        ),
      ),
    ],
  );
}

Future<void> _agree(WidgetTester t, ParityContext ctx) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
  if (ctx.props['kind'] == 'error' || ctx.props['kind'] == 'pending') {
    await t.tap(find.text('Agree & Continue'));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }
}

/// InviteAcceptPage over the case's invite-info route set (`$pending` never answers, `$status`
/// fails); `props.user` 'verified' is the signed-in page.
Widget _invite(ParityContext ctx) => InviteAcceptView(
  token: 'parity-invite-token',
  signedIn: ctx.props['user'] == 'verified',
  loadInfo: () async {
    final answer = _answer(ctx, 'GET', '/auth/invite-info');
    if (identical(answer, ScreenFixtureClient.pending)) {
      await Completer<void>().future;
    }
    return Map<String, dynamic>.from(answer as Map);
  },
  accept: (agreementId) async {
    final answer = _answer(ctx, 'POST', '/auth/accept-invite');
    return InviteJoined(
      'srv-1',
      '${(answer as Map)['serverName'] ?? 'Raft Design'}',
    );
  },
  onEnter: (_) async => true,
  onSignIn: () {},
  onCreateAccount: () {},
  onGoToRaft: () {},
);

Future<void> _inviteInteract(WidgetTester t, ParityContext ctx) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
  if (ctx.id.contains('.invite.accept-error.')) {
    await t.tap(find.text('Join Server'));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }
}

Widget _serversLoading(ParityContext ctx) {
  final fx = _fx(ctx);
  return GlobalServerSelector(
    servers: const [],
    user: RaftRecord(Map<String, dynamic>.from(fx['user'] as Map)),
    loading: true,
    onSelect: (_) async {},
    onCreate: (_, _) async {},
    onLogout: () async {},
    onRetry: () async {},
  );
}

/// AccountIdentitySetupPage preview (the official profile-setup case's user: pending_new_designer, suggested
/// handle new_designer, no display name); showSessionFooter false mirrors the React preview mode.
Widget _identity(ParityContext ctx) {
  final wire = ScreenWire(ctx.fixtureData);
  return ScreenClientHost(
    create: () => ScreenFixtureClient(
      wire.common,
      user: {
        ...wire.me(),
        'name': 'pending_new_designer',
        'displayName': null,
        'profileSetupCompletedAt': null,
        'profileSetupSuggestedHandle': 'new_designer',
        'emailVerified': true,
      },
    ),
    builder: (context, client) => AccountOnboardingView(
      client: client,
      onComplete: () async {},
      onSignOut: () async {},
      showSessionFooter: false,
    ),
  );
}

Widget _serverSelector(ParityContext ctx) {
  final fx = _fx(ctx);
  final servers = (fx['servers'] as Map)[ctx.props['servers']] as List;
  return GlobalServerSelector(
    servers: [
      for (final server in servers)
        RaftRecord(Map<String, dynamic>.from(server as Map)),
    ],
    user: RaftRecord(Map<String, dynamic>.from(fx['user'] as Map)),
    loading: false,
    onSelect: (_) async {},
    onCreate: (_, _) async {},
    onLogout: () async {},
    onRetry: () async {},
  );
}

ParityCase _case(
  Widget Function(ParityContext) build, {
  String? note,
  ParityInteraction? interact,
}) => ParityCase(
  interact: interact,
  widgets: const ['raft_flutter:AuthView', 'raft_ui:RaftAuthPage'],
  notes: 'Extension suite (not official).${note == null ? '' : ' $note'}',
  settle: const Duration(milliseconds: 300),
  build: build,
);

/// surface name -> builder; the platform lists are in [_platforms].
final Map<String, ParityCase> _surfaces = {
  for (final s in const [
    'register.default',
    'register.filled',
    'register.unchecked',
    'register.invalid-email',
    'register.short-password',
    'register.error',
    'register.social',
  ])
    s: _case(_register),
  for (final s in const ['identity.default', 'identity.filled'])
    s: _case(_identity),
  for (final s in const ['server.create-first', 'server.create-first-filled'])
    s: _case(_serverSelector),
  // Settings pages: the ext-settings Flutter page (WorkspaceSettings) over fixtures/settings.json plus the
  // auth-pages route sets / server patches.
  for (final s in const [
    'settings.account-password',
    'settings.account-password-error',
    'settings.account-logout-confirm',
    'settings.server-danger-delete',
    'settings.server-danger-delete-typed',
    'settings.server-danger-member',
    'settings.server-danger-leave',
    'settings.archived-channels',
    'settings.downgrade-active',
    'settings.downgrade-expired',
    'settings.app-editor',
    'settings.release-notes',
    'settings.release-notes-loading',
    'settings.release-notes-error',
    'settings.release-notes-empty',
  ])
    s: ParityCase(
      widgets: const [
        'raft_flutter:WorkspaceSettings',
        'raft_flutter:RaftSettingsPage',
      ],
      notes: 'Extension suite (not official).',
      settle: const Duration(milliseconds: 800),
      build: extSettingsPage,
    ),
  'bootstrap.restoring': _case((_) => _splash('Restoring session…')),
  'bootstrap.loading': _case((_) => _splash('Loading…')),
  'servers.loading': _case(_serversLoading),
  'root-error.default': _case(_rootError),
  'invite.signed-out': _case(_invite, interact: _inviteInteract),
  'invite.signed-in': _case(_invite, interact: _inviteInteract),
  'invite.join-link': _case(_invite, interact: _inviteInteract),
  'invite.agreement': _case(_invite, interact: _inviteInteract),
  'invite.hidden-counts': _case(_invite, interact: _inviteInteract),
  'invite.seat-limit': _case(_invite, interact: _inviteInteract),
  'invite.expired': _case(_invite, interact: _inviteInteract),
  'invite.throttled': _case(_invite, interact: _inviteInteract),
  'invite.loading': _case(_invite, interact: _inviteInteract),
  'invite.accept-error': _case(_invite, interact: _inviteInteract),
  'servers.joining-community': _case((_) => _splash('Joining community…')),
  'community-agreement.default': _case(_communityAgreement, interact: _agree),
  'community-agreement.error': _case(_communityAgreement, interact: _agree),
  'community-agreement.joining': _case(_communityAgreement, interact: _agree),
  'setup-gate.resume-bar': _case(_setupGate),
  'server-denied.with-server': _case(_serverDenied),
  'server-denied.no-server': _case(_serverDenied),
};

/// Surfaces a platform does not run (see build-auth-pages.py `platforms`).
const _platforms = {
  'desktop': <String>{
    'settings.release-notes',
    'settings.release-notes-loading',
    'settings.release-notes-error',
    'settings.release-notes-empty',
  },
  'mobile': <String>{
    'server.create-first',
    'server.create-first-filled',
    'settings.server-danger-delete',
    'settings.server-danger-delete-typed',
    'settings.server-danger-member',
    'settings.server-danger-leave',
  },
};

const _themes = ['brutal', 'elegant', 'elegant-dark'];

/// Every extension auth-pages case with a Flutter page, keyed by id (3 themes each).
final Map<String, ParityCase> extAuthPagesCases = {
  for (final platform in _platforms.keys)
    for (final MapEntry(key: name, value: parityCase) in _surfaces.entries)
      if (!_platforms[platform]!.contains(name))
        for (final theme in _themes)
          'components.auth-pages.$platform.$name.$theme': parityCase,
};

/// Web pages the Flutter app has no widget for: surface name -> why.
const _missing = <String, String>{
  'setup-gate.loading':
      'Flutter page missing: the dedicated native setup surface is a Web page for native WebView hosts; the app renders setup natively with no loading page.',
  'setup-gate.unavailable':
      'Flutter page missing: the dedicated native setup surface is a Web page for native WebView hosts; the app renders setup natively with no unavailable page.',
  'setup-gate.load-failed':
      'Flutter page missing: the dedicated native setup surface is a Web page for native WebView hosts; the app renders setup natively with no load-failed page.',
  'setup-gate.complete':
      'Flutter page missing: the dedicated native setup surface is a Web page for native WebView hosts; the app renders setup natively with no completion page.',
};

/// Cases without a Flutter widget (gap noFlutterSurface), merged into parityUncovered by case_map.dart.
final Map<String, ParityUncovered> extAuthPagesUncovered = {
  for (final platform in _platforms.keys)
    for (final MapEntry(key: name, value: reason) in _missing.entries)
      for (final theme in _themes)
        'components.auth-pages.$platform.$name.$theme': ParityUncovered(
          ParityGap.noFlutterSurface,
          reason,
        ),
};
