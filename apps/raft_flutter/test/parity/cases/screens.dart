// Official cases owned by this group (default selection):
//   screens.auth.login.signing
//   screens.auth.profile-setup
//   screens.members.agent-detail.profile
//   screens.members.agent-detail.profile.computer-offline
//   screens.members.agent-detail.profile.computer-missing
//   screens.members.agent-detail.profile.no-computer
//   screens.members.agent-detail.profile.long-machine-name
//   screens.members.agent-detail.profile.daemon-only
//   screens.members.agent-detail.profile.no-membership
//   screens.members.agent-detail.profile.loading-state
//   screens.members.agent-detail.reminders
//   screens.members.agent-detail.workspace
//   screens.members.agent-detail.apps
//   screens.members.agent-detail.activity
//   screens.members.human.profile
//   screens.settings.server-danger-modal
//   screens.home.loading
//
// Builders render the real Flutter app/raft_ui widgets for each case, laid
// out like the React render host fixture for the same case id. Cases the
// Flutter app cannot show go to [screenUncovered] with an honest reason.
//
// All of these are `real-screen` captures: React mounts the real route with
// mocked APIs and captures the full 390x844 viewport (crop.rect 0,0,390,844),
// so no builder calls ctx.target. The Flutter builders mount the real
// screen/route widget with a fixture RaftClient (cases/screens/
// screen_fixture.dart) answering the same routes react-provider.spec.ts
// mocks, built from shared/fixtureData.json.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/account_onboarding.dart';
import 'package:raft_flutter/features/agent_apps_view.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_flutter/features/member_profile_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parity_harness.dart';
import 'screens/screen_fixture.dart';

final Map<String, ParityCase> screenCases = {
  'screens.auth.login.signing': _loginSigning,
  'screens.auth.profile-setup': _profileSetup,
  'screens.members.agent-detail.profile': _agentProfile('productUx'),
  'screens.members.agent-detail.profile.computer-offline': _agentProfile(
    'computerOffline',
  ),
  'screens.members.agent-detail.profile.computer-missing': _agentProfile(
    'computerMissing',
  ),
  'screens.members.agent-detail.profile.no-computer': _agentProfile(
    'noComputer',
  ),
  'screens.members.agent-detail.profile.long-machine-name': _agentProfile(
    'longMachine',
  ),
  'screens.members.agent-detail.profile.daemon-only': _agentProfile(
    'daemonOnly',
  ),
  'screens.members.agent-detail.profile.no-membership': _agentProfile(
    'noMembership',
  ),
  'screens.members.agent-detail.profile.loading-state': _agentProfile(
    'productUx',
    machinesLoading: true,
  ),
  'screens.members.agent-detail.workspace': _agentInspection(
    'workspace-files',
  ),
  'screens.members.agent-detail.activity': _agentInspection('activity-log'),
  'screens.members.agent-detail.apps': _agentApps,
  'screens.members.human.profile': _humanProfile,
  'screens.settings.server-danger-modal': _serverDangerModal,
  'screens.home.loading': _homeLoading,
};

final Map<String, ParityUncovered> screenUncovered = {
  'screens.members.agent-detail.reminders': const ParityUncovered(
    ParityGap.noFlutterSurface,
    'The Flutter app has no agent Reminders surface: FleetDetail '
    '(lib/features/fleet_views.dart, the agent detail route) has no tabs and '
    'no reminders entry, and nothing under lib/ requests /reminders or '
    'renders a reminder list (grep "reminder" only hits a permission '
    'description and an integration scope id).',
  ),
};

const _serverId = 'visual-server';
const _productUxId = 'agent-product-ux';

/// A WorkspaceController bound to the fixture server, like the mounted app
/// after bootstrap selected `visual-server` (role owner).
WorkspaceController _workspace(
  ParityContext ctx, {
  ScreenRoute? route,
  bool bootstrap = false,
}) {
  SharedPreferences.setMockInitialValues({});
  final wire = ScreenWire(ctx.fixtureData);
  final client = ScreenFixtureClient(
    route ?? wire.common,
    user: wire.me(),
    server: bootstrap ? null : _serverId,
  );
  final w = WorkspaceController(client, mobileNavigation: true);
  if (bootstrap) {
    unawaited(w.bootstrap());
  } else {
    final server = RaftRecord(wire.server());
    w
      ..servers = [server]
      ..server = server;
    w.ledger.switchServer(_serverId);
  }
  return w;
}

/// The route stack the app builds on mobile: the Agents directory pushes
/// `FleetDetail` (fleet_views.dart FleetView onTap) and FleetDetail pushes
/// its inspection/app-access pages. The directory page under the stack is
/// offstage and not captured, so it is left empty.
Widget _agentStack(
  WorkspaceController w,
  Map<String, dynamic> agent, [
  WidgetBuilder? pushed,
]) => ScreenRouteStack(
  pages: [
    (_) => const SizedBox.expand(),
    (_) => FleetDetail(controller: w, computers: false, initial: agent),
    ?pushed,
  ],
);

ParityCase _agentProfile(String agentKey, {bool machinesLoading = false}) =>
    ParityCase(
      widgets: const ['raft_flutter:FleetDetail', 'material:AppBar'],
      notes:
          'Flutter agent detail is FleetDetail (fleet_views.dart), a Material '
          'Scaffold/AppBar + ListTile list with no Profile/Activity/Chat tab '
          'strip, no avatar, no Computer/Computer status/version rows, no '
          'runtime chips, env vars or created-agents section. It reads only '
          'GET /agents/<id>, so the computer offline/missing/none/long-name/'
          'daemon-only states are not represented.'
          '${machinesLoading ? ' Machines request held in flight like React; FleetDetail never requests machines, so it renders the same as the default profile.' : ''}'
          '${agentKey == 'noMembership' ? ' serverRole omitted on the wire: FleetDetail hides its "Workspace role" tile.' : ''}',
      build: (ctx) => ScreenWorkspaceHost(
        create: () {
          final wire = ScreenWire(ctx.fixtureData);
          return _workspace(
            ctx,
            route: (m, p, q) =>
                machinesLoading && p == '/servers/$_serverId/machines'
                ? ScreenFixtureClient.pending
                : wire.common(m, p, q),
          );
        },
        builder: (context, w) =>
            _agentStack(w, ScreenWire(ctx.fixtureData).agent(agentKey)),
      ),
    );

ParityCase _agentInspection(String kind) => ParityCase(
  widgets: const [
    'raft_flutter:FleetInspection',
    'raft_flutter:FleetDetail',
    'material:AppBar',
    'material:ListTile',
  ],
  notes:
      'Flutter has no agent ${kind == 'activity-log' ? 'Activity' : 'Workspace'} '
      'tab; the equivalent is the "${kind == 'activity-log' ? 'Activity log' : 'Workspace files'}" '
      'page FleetDetail pushes (FleetInspection kind=$kind), shown here on top '
      'of the real route stack with the same mocked '
      '/agents/$_productUxId/$kind payload.'
      '${kind == 'activity-log' ? ' FleetInspection reads name/detail/message keys, so the {timestamp, entry} rows render as generic "Entry" tiles.' : ''}',
  build: (ctx) => ScreenWorkspaceHost(
    create: () => _workspace(ctx),
    builder: (context, w) => _agentStack(
      w,
      ScreenWire(ctx.fixtureData).agent('productUx'),
      (_) => FleetInspection(
        controller: w,
        base: '/agents/$_productUxId',
        kind: kind,
        computers: false,
      ),
    ),
  ),
);

final ParityCase _agentApps = ParityCase(
  widgets: const [
    'raft_flutter:AgentAppAccessView',
    'raft_flutter:FleetDetail',
  ],
  notes:
      'Flutter has no agent Apps tab; the equivalent is the "App access" '
      'page FleetDetail pushes (AgentAppAccessView), with the same empty '
      '/integrations/agents/<id> mocks. PRODUCT DEFECT: the app pushes it in '
      'a bare MaterialPageRoute with no Material ancestor (debug assertion '
      '"No Material widget found" from its DropdownButton); the capture adds '
      'a transparent, non-painting Material so it can build.',
  build: (ctx) => ScreenWorkspaceHost(
    create: () => _workspace(ctx),
    builder: (context, w) => _agentStack(
      w,
      ScreenWire(ctx.fixtureData).agent('productUx'),
      // The product pushes AgentAppAccessView in a bare MaterialPageRoute
      // with no Material ancestor, which asserts "No Material widget found"
      // (DropdownButton/IconButton) in debug. A transparent Material (no
      // paint) is the minimum host needed to build it at all.
      (_) => Material(
        type: MaterialType.transparency,
        child: AgentAppAccessView(controller: w, agentId: _productUxId),
      ),
    ),
  ),
);

final ParityCase _humanProfile = ParityCase(
  widgets: const ['raft_flutter:MemberProfileView', 'material:Scaffold'],
  notes:
      'MemberProfileView is the Flutter HumanRoute/ProfilePanel contract '
      '(desktop master-detail pane); the mobile Members list instead opens '
      'an AlertDialog. It is hosted in a plain Scaffold here, standing in for '
      'the workspace shell Scaffold that hosts it in the app. Loads the same '
      '/servers/visual-server/members/visual-human-1/profile payload.',
  build: (ctx) => ScreenWorkspaceHost(
    create: () => _workspace(ctx),
    builder: (context, w) => Scaffold(
      body: SafeArea(
        child: MemberProfileView(
          controller: w,
          userId: ctx.fixtureData['humans']['owner']['memberId'] as String,
          onClose: () {},
          onMessage: () async {},
        ),
      ),
    ),
  ),
);

Widget _workspaceView(ParityContext ctx, WorkspaceController w) =>
    WorkspaceView(
      controller: w,
      appearance: RaftAppearance(light: ctx.family),
      onAppearance: (_) async {},
      onLogout: () async {},
    );

final ParityCase _serverDangerModal = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_flutter:RaftSettingsPage',
    'raft_flutter:ServerSettingsView',
    'raft_ui:RaftConfirmDialog',
  ],
  notes:
      'Real mobile route: WorkspaceView → Settings tab → "Server Profile" '
      '(ServerSettingsView) → "Delete Server" (server-danger-delete-button), '
      'which opens the DangerZoneSection RaftConfirmDialog.',
  build: (ctx) => ScreenWorkspaceHost(
    create: () => _workspace(ctx, bootstrap: true),
    builder: (context, w) => _workspaceView(ctx, w),
  ),
  interact: (t, ctx) async {
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byKey(const Key('mobile-tab-settings')));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byKey(const Key('workspace-settings-nav-server')));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byKey(const Key('server-danger-delete-button')));
    // React waits 120ms after the click.
    await t.pump(const Duration(milliseconds: 120));
    await t.pump(const Duration(milliseconds: 300));
  },
);

final ParityCase _homeLoading = ParityCase(
  widgets: const ['raft_flutter:WorkspaceView'],
  notes:
      'Post sign-in transition: the real WorkspaceController.bootstrap() runs '
      'with /servers answered and /channels, /channels/dm, /agents, '
      '/channels/saved and machines held in flight exactly like React. '
      'Flutter keeps w.loading true until channels arrive and shows its '
      'loading state instead of sidebar skeleton rows.',
  build: (ctx) => ScreenWorkspaceHost(
    create: () {
      final wire = ScreenWire(ctx.fixtureData);
      const held = {
        '/channels',
        '/channels/dm',
        '/agents',
        '/channels/saved',
        '/servers/$_serverId/machines',
      };
      return _workspace(
        ctx,
        bootstrap: true,
        route: (m, p, q) =>
            held.contains(p) ? ScreenFixtureClient.pending : wire.common(m, p, q),
      );
    },
    builder: (context, w) => _workspaceView(ctx, w),
  ),
);

/// Fixture origin: the app's default `RAFT_ORIGIN` (lib/main.dart).
const _origin = 'http://localhost:13041';

final ParityCase _loginSigning = ParityCase(
  widgets: const ['raft_flutter:AuthView', 'raft_ui:RaftButton'],
  notes:
      'AuthView (the app\'s signed-out home) with /auth/providers mocked to '
      'Google + GitHub like React. Email/password filled, Sign in tapped and '
      'onLogin held in flight: Flutter shows RaftButton busy and disables '
      'the inputs while busy (React keeps them enabled).',
  build: (ctx) => AuthView(
    origin: _origin,
    onLogin: (_, _, _) => Completer<void>().future,
    onRegister: (_, _, _, _) async {},
    onOAuth: (_, _, _, _) async {},
    anonymousClientFactory: (origin) => ScreenFixtureClient(
      (m, p, q) => p == '/auth/providers'
          ? {
              'providers': [
                {'id': 'google', 'label': 'Google', 'enabled': true},
                {'id': 'github', 'label': 'GitHub', 'enabled': true},
              ],
            }
          : {},
    ),
  ),
  interact: (t, ctx) async {
    await t.enterText(find.byKey(const Key('login-email')), 'artin@raft.build');
    await t.enterText(
      find.byKey(const Key('login-password')),
      'visual-sign-in-secret',
    );
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.byKey(const Key('login-submit')));
    await t.pump(const Duration(milliseconds: 120));
  },
);

final ParityCase _profileSetup = ParityCase(
  widgets: const [
    'raft_flutter:AccountOnboardingView',
    'raft_ui:RaftOnboardingPage',
    'raft_ui:RaftAuthField',
  ],
  notes:
      'AccountOnboardingView profile step for the React previewUser '
      '(pending_new_designer, suggested handle new_designer, no display '
      'name, verified). showSessionFooter false mirrors the React host\'s '
      'preview mode (OnboardingCreateShell showSessionFooter={!previewMode}). '
      'The case values are typed like the React fills; leaving the username '
      'field runs the same on-blur availability precheck.',
  build: (ctx) {
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
  },
  interact: (t, ctx) async {
    await t.enterText(
      find.byKey(const Key('onboarding-username')),
      '${ctx.props['profileSetupHandle'] ?? 'new_designer'}',
    );
    await t.enterText(
      find.byKey(const Key('onboarding-display-name')),
      '${ctx.props['profileSetupDisplayName'] ?? 'New Designer'}',
    );
    await t.pump(const Duration(milliseconds: 50));
    await t.pump(const Duration(milliseconds: 50));
  },
);
