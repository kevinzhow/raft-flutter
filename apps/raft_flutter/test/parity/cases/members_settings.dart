// Official cases owned by this group (default selection):
//   components.members.create-agent.dialog
//   components.members.create-agent.dialog-error
//   components.members.create-agent.dialog-onboarding
//   components.members.create-agent.claude-dialog
//   components.members.create-agent.claude-custom-provider-dialog
//   components.members.agent-detail.profile
//   components.channel.settings.panel
//   components.channel.members.add-panel
//   components.settings.root.page
//   components.settings.account.page
//   components.settings.account.error-state
//   components.settings.server.profile
//   components.settings.appearance.page
//   components.settings.notifications.page
//   components.members.agent-lifecycle-actions
//   components.members.avatar-management
//   components.members.create-agent.dialog-no-computer
//   components.members.create-agent.dialog-empty
//   components.members.create-agent.builtin-provider-dialog
//   components.members.create-agent.pi-provider-dialog
//
// Builders render the real Flutter app/raft_ui widgets for each case, laid
// out like the React render host fixture for the same case id. Cases the
// Flutter app cannot show go to [membersSettingsUncovered] with an honest reason.
//
// Every case here is a full 390x844 viewport capture (React crop.rect is the
// whole viewport), so no builder calls ctx.target. Product widgets are driven
// through a real WorkspaceController over an in-memory RaftClient
// (members_settings/fixture_client.dart) fed with shared/fixtureData.json and
// the endpoint mocks of react-provider.spec.ts.
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart'; // ignore: depend_on_referenced_packages
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/account_settings.dart';
import 'package:raft_flutter/features/admin_views.dart';
import 'package:raft_flutter/features/appearance_section.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_flutter/features/im_bridges_view.dart';
import 'package:raft_flutter/features/integrations_views.dart';
import 'package:raft_flutter/features/joint_channel_views.dart';
import 'package:raft_flutter/features/locale_settings_page.dart';
import 'package:raft_flutter/features/notification_settings_view.dart';
import 'package:raft_flutter/features/provider_views.dart';
import 'package:raft_flutter/features/runtime_form_dialog.dart';
import 'package:raft_flutter/features/server_views.dart';
import 'package:raft_flutter/features/settings_page.dart';
import 'package:raft_flutter/features/sidebar_preferences_view.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parity_harness.dart';
import 'members_settings/fixture_client.dart';
import 'members_settings/runtime_forms.dart';

final Map<String, ParityCase> membersSettingsCases = {
  'components.members.create-agent.dialog': _createAgent('codex'),
  'components.members.create-agent.dialog-error': _createAgent(
    'codex',
    name: 'bad name!!',
    extraNotes:
        ' Flutter RuntimeFormDialog has no client-side agent-name format rule '
        '(React NAME_REGEX inline error "Start with a letter..."); the invalid '
        'name is shown as typed with no inline error, which is the real Flutter '
        'state until the server rejects the submit.',
  ),
  'components.members.create-agent.dialog-onboarding': _createAgent(
    'codex',
    onboarding: true,
    extraNotes:
        ' Onboarding = RuntimeFormDialog(onboarding: true) as opened by '
        'server_setup_gate.dart (locked name "Cindy"); Flutter has no "Meet '
        'Cindy" hero layout.',
  ),
  'components.members.create-agent.dialog-empty': _createAgent(
    'codex',
    empty: true,
  ),
  'components.members.create-agent.claude-dialog': _createAgent('claude'),
  'components.members.create-agent.claude-custom-provider-dialog':
      _createAgent(
        'claude',
        customProvider: true,
        extraNotes:
            ' Provider set to Custom, API URL/API key/Claude Command filled like '
            'react-provider.spec.ts applyCaseFixtureState; Flutter has no MORE '
            'disclosure (advanced fields are always inline), dialog scrolled '
            'back to top.',
      ),
  'components.members.create-agent.builtin-provider-dialog': _createAgent(
    'builtin',
    extraNotes:
        ' Built-in Pi option sources need the Computer catalog; with no '
        'backend the real server answers 409 builtin_catalog_unavailable and '
        'the form has no option_source.status capability, so Flutter shows '
        'its load-error state.',
  ),
  'components.members.create-agent.pi-provider-dialog': _createAgent('pi'),
  'components.members.create-agent.dialog-no-computer': _noComputer,
  'components.members.agent-detail.profile': _agentDetail(lifecycle: false),
  'components.members.agent-lifecycle-actions': _agentDetail(lifecycle: true),
  'components.channel.settings.panel': _channelSettings(addPanel: false),
  'components.channel.members.add-panel': _channelSettings(addPanel: true),
  'components.settings.root.page': _settings('account', root: true),
  'components.settings.account.page': _settings('account'),
  'components.settings.account.error-state': _settings(
    'account',
    uploadError: true,
  ),
  'components.settings.server.profile': _settings('server'),
  'components.settings.appearance.page': _settings('appearance'),
  'components.settings.notifications.page': _settings('notifications'),
};

final Map<String, ParityUncovered> membersSettingsUncovered = {
  'components.members.avatar-management': const ParityUncovered(
    ParityGap.noFlutterSurface,
    'React AgentDetailPanel "Choose avatar" picker (generated pixel avatars, '
    'upload tile, Save/Cancel). Flutter FleetDetail (features/fleet_views.dart) '
    'has no avatar control for agents and no avatar picker exists anywhere in '
    'apps/raft_flutter/lib or packages/raft_ui (grep pixel:/avatar picker; the '
    'only agent avatar write is the fixed pixel:mug in onboarding create).',
  ),
};

// ---------------------------------------------------------------------------
// Hosts: plain scaffolding that opens product dialogs/routes the way the app
// does (showDialog / Navigator.push) once the first frame is laid out.

class _Host extends StatefulWidget {
  const _Host({required this.page, required this.open});
  final Widget page;
  final void Function(BuildContext context) open;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.open(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.page;
}

Map<String, dynamic> _forms(String runtime) =>
    Map<String, dynamic>.from(msRuntimeForms['forms'][runtime] as Map);
Map<String, dynamic>? _staticSource(String runtime, String source) {
  final s = (msRuntimeForms['staticSources'] as Map)['$runtime.$source'];
  return s == null ? null : Map<String, dynamic>.from(s as Map);
}

// ---------------------------------------------------------------------------
// Create agent: RuntimeFormDialog, the form managed_agent_launcher.dart opens
// after the computer and runtime are chosen.

ParityCase _createAgent(
  String runtime, {
  String? name,
  bool empty = false,
  bool onboarding = false,
  bool customProvider = false,
  String extraNotes = '',
}) => ParityCase(
  widgets: const [
    'raft_flutter:RuntimeFormDialog',
    'raft_ui:RaftButton',
    'material:AlertDialog',
  ],
  notes:
      'Flutter create-agent picks computer and runtime in two SimpleDialogs '
      '(managed_agent_launcher.dart) and then opens RuntimeFormDialog; the '
      'case props (computer Jiachengs-MacBook-Pro, runtime $runtime, name, '
      'description) are rendered as that final form. Form definition = the '
      'server registry v2 payload for "$runtime"; machine-probed option '
      'sources are unserved like in the React host (React itself never '
      'selects the runtime because it mocks no runtime-options, so its '
      'baseline shows "Select..."). No capacity banner exists in Flutter.'
      '$extraNotes',
  settle: const Duration(milliseconds: 600),
  build: (ctx) {
    final fixture = MsFixture(ctx);
    final base =
        'GET /servers/visual-server/machines/computer-mbp/runtime-forms/v2/$runtime';
    final form = _forms(runtime);
    final routes = <String, Object? Function(dynamic)>{base: (_) => form};
    for (final id in (form['optionSources'] as Map).keys) {
      final source = _staticSource(runtime, id as String);
      routes['$base/option-sources/$id'] = (_) =>
          source ??
          (runtime == 'builtin'
              ? const RaftApiException(
                  "The target Computer's Built-in model catalog is unavailable",
                  status: 409,
                )
              : const RaftApiException('Computer unavailable', status: 503));
    }
    final (w, _) = fixture.workspace(routes);
    final props = ctx.props;
    return _Host(
      page: const Scaffold(),
      open: (context) => showDialog(
        context: context,
        builder: (_) => RuntimeFormDialog(
          controller: w,
          machineId: 'computer-mbp',
          runtimeId: runtime,
          onboarding: onboarding,
          initialName: empty ? null : name ?? props['name'] as String?,
          initialDescription: empty ? null : props['description'] as String?,
        ),
      ),
    );
  },
  interact: customProvider ? _fillCustomProvider : null,
);

Future<void> _fillCustomProvider(WidgetTester t, ParityContext ctx) async {
  await t.pump(const Duration(milliseconds: 300));
  final dialog = find.byType(AlertDialog);
  await t.tap(
    find.descendant(of: dialog, matching: find.text('Default')).first,
  );
  await t.pump(const Duration(milliseconds: 400));
  await t.tap(find.text('Custom').last);
  await t.pump(const Duration(milliseconds: 400));
  await t.enterText(
    find.byKey(const ValueKey('runtime-apiUrl')),
    'https://gateway.example.com',
  );
  await t.enterText(
    find.byKey(const ValueKey('runtime-apiKey')),
    'visual-test-key',
  );
  await t.enterText(find.byKey(const ValueKey('runtime-command')), 'claude');
  await t.pump(const Duration(milliseconds: 100));
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pump(const Duration(milliseconds: 100));
  final scrollable = find
      .descendant(of: dialog, matching: find.byType(Scrollable))
      .first;
  t.state<ScrollableState>(scrollable).position.jumpTo(0);
  await t.pump(const Duration(milliseconds: 100));
}

/// Zero machines: FleetView "Create managed agent" → showManagedAgentForm
/// throws "Connect a computer..." and FleetView shows it inline.
final ParityCase _noComputer = ParityCase(
  widgets: const ['raft_flutter:FleetView', 'raft_ui:RaftButton'],
  notes:
      'Flutter has no zero-computer create-agent dialog: FleetView (agents) '
      '"Create managed agent" → showManagedAgentForm throws "Connect a '
      'computer before creating a managed agent." which FleetView renders as '
      'inline error text above the agent list.',
  build: (ctx) {
    final fixture = MsFixture(ctx);
    final (w, _) = fixture.workspace({
      'GET /agents': (_) => fixture.agents,
      'GET /servers/visual-server/machines': (_) => {'machines': []},
    });
    return Scaffold(
      body: SafeArea(
        child: FleetView(controller: w, computers: false),
      ),
    );
  },
  interact: (t, ctx) async {
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.text('Create managed agent'));
    await t.pump(const Duration(milliseconds: 100));
  },
);

// ---------------------------------------------------------------------------
// Agent detail: FleetDetail pushed from FleetView like on mobile.

ParityCase _agentDetail({required bool lifecycle}) => ParityCase(
  widgets: const ['raft_flutter:FleetDetail', 'material:AppBar'],
  notes: lifecycle
      ? 'React opens the AgentDetailPanel "More actions" menu (Direct Message, '
            'Stop Agent, Restart / Reset). Flutter FleetDetail has no actions '
            'menu: lifecycle controls are inline Start/Stop buttons and '
            'Restart/Reset tiles. Captured the Flutter lifecycle step instead: '
            'tapping "Restart runtime" opens the "Restart agent?" confirmation '
            '(same state the KMP fixture captures).'
      : 'Flutter agent detail is FleetDetail (Scaffold/AppBar + ListTiles); '
            'it has no Profile/Activity/Chat/Reminders tabs, avatar, info '
            'grid or runtime-config chips.',
  settle: const Duration(milliseconds: 700),
  build: (ctx) {
    final fixture = MsFixture(ctx);
    final row = fixture.agent('productUx');
    final (w, _) = fixture.workspace({
      'GET /agents/${row['id']}': (_) => row,
      'GET /agents': (_) => fixture.agents,
    });
    return _Host(
      page: const Scaffold(),
      open: (context) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              FleetDetail(controller: w, computers: false, initial: row),
        ),
      ),
    );
  },
  interact: lifecycle
      ? (t, ctx) async {
          await t.pump(const Duration(milliseconds: 600));
          final tile = find.text('Restart runtime');
          await t.ensureVisible(tile);
          await t.pump(const Duration(milliseconds: 50));
          await t.tap(tile);
          await t.pump(const Duration(milliseconds: 100));
        }
      : null,
);

// ---------------------------------------------------------------------------
// Channel settings: the ChannelSettings dialog workspace_view.dart opens.

ParityCase _channelSettings({required bool addPanel}) => ParityCase(
  widgets: [
    'raft_flutter:ChannelSettings',
    'raft_flutter:ChannelConversionSection',
    if (addPanel) 'material:AlertDialog',
    if (addPanel) 'material:CheckboxListTile',
  ],
  notes: addPanel
      ? 'Flutter add-member is ChannelSettings → "Add members" → AlertDialog '
            'of CheckboxListTiles (server members + agents not in the '
            'channel). Roster mock = react-provider.spec.ts empty channel '
            'members; candidates = its /servers/visual-server/members and '
            '/api/agents payloads.'
      : 'Flutter channel settings is the ChannelSettings Dialog (not a full '
            'screen panel). Channel members served empty as in the React '
            'add-panel mock so the roster request settles.',
  settle: const Duration(milliseconds: 600),
  build: (ctx) {
    final fixture = MsFixture(ctx);
    final channel = fixture.channel('design');
    final (w, _) = fixture.workspace({
      'GET /channels/${channel['id']}/members': (_) => {
        'agents': [],
        'humans': [],
        'externalMembers': [],
      },
      'GET /servers/visual-server/members': (_) => fixture.members,
      'GET /agents': (_) => fixture.agents,
    });
    return _Host(
      page: const Scaffold(),
      open: (context) => showDialog(
        context: context,
        builder: (_) =>
            ChannelSettings(controller: w, channel: RaftChannel(channel)),
      ),
    );
  },
  interact: addPanel
      ? (t, ctx) async {
          await t.pump(const Duration(milliseconds: 300));
          final button = find.text('Add members');
          await t.ensureVisible(button);
          await t.pump(const Duration(milliseconds: 50));
          await t.tap(button);
          await t.pump(const Duration(milliseconds: 100));
        }
      : null,
);

// ---------------------------------------------------------------------------
// Settings: RaftSettingsPage with the destination list WorkspaceView.settings()
// builds for an owner (workspace_view.dart), mobile layout.

class _AvatarPickerFixture extends FileSelectorPlatform {
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => XFile.fromData(
    Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47]),
    name: 'avatar.png',
    path: 'avatar.png',
    mimeType: 'image/png',
  );
}

ParityCase _settings(
  String tab, {
  bool root = false,
  bool uploadError = false,
}) => ParityCase(
  widgets: [
    'raft_flutter:RaftSettingsPage',
    if (root) 'raft_ui:RaftNavItem',
    if (root) 'raft_ui:RaftMobileRootHeader',
    if (tab == 'account' && !root) 'raft_flutter:AccountSettings',
    if (tab == 'server') 'raft_flutter:ServerSettingsView',
    if (tab == 'appearance') 'raft_flutter:RaftAppearanceSection',
    if (tab == 'notifications') 'raft_flutter:NotificationSettingsView',
  ],
  notes: [
    'Destinations mirror WorkspaceView.settings() for the fixture owner '
        '(Flutter groups Personal/Workspace only; no Resources group).',
    if (tab == 'account' && !root)
      '/auth/identities adds passwordConfigured:false (the state React shows '
          'as "Set a password"; its mock omits the field, which Flutter would '
          'render as "Sign-in methods could not be verified").',
    if (uploadError)
      'Error state reached through the real flow: "Change profile image" → '
          'file picker (FileSelectorPlatform fixture returns a PNG) → POST '
          '/auth/me/avatar fails with the React/Android fixture message '
          '"Avatar upload failed: upload_failed". Flutter renders that error '
          'at the bottom of the account card, so the page is scrolled until '
          'it is visible (React shows its banner above Save Profile).',
    if (tab == 'appearance')
      'Appearance = Light mode, Brutal light theme (the React fixture state).',
    if (tab == 'notifications')
      'NativeNotificationService(platform: android), permission not granted.',
  ].join(' '),
  settle: const Duration(milliseconds: 600),
  build: (ctx) {
    SharedPreferences.setMockInitialValues({});
    final fixture = MsFixture(ctx);
    final owner = fixture.owner;
    final (w, _) = fixture.workspace({
      'GET /auth/identities': (_) => {
        'identities': [
          {'provider': 'google', 'providerEmail': owner['email']},
        ],
        'passwordConfigured': false,
      },
      'GET /auth/providers': (_) => {
        'providers': [
          {'id': 'google', 'label': 'Google', 'enabled': true},
          {'id': 'github', 'label': 'GitHub', 'enabled': true},
        ],
      },
      'GET /servers/visual-server': (_) => fixture.server,
      'GET /servers/visual-server/invites': (_) => [],
      'GET /servers/visual-server/join-links': (_) => [],
      'POST /auth/me/avatar': (_) =>
          const RaftApiException('Avatar upload failed: upload_failed'),
    });
    if (uploadError) FileSelectorPlatform.instance = _AvatarPickerFixture();
    return Scaffold(
      body: _settingsPage(w, tab: tab, root: root),
    );
  },
  interact: uploadError
      ? (t, ctx) async {
          await t.pump(const Duration(milliseconds: 100));
          final trigger = find.byKey(const Key('account-profile-image'));
          await t.ensureVisible(trigger);
          await t.pump(const Duration(milliseconds: 50));
          await t.tap(trigger);
          await t.pump(const Duration(milliseconds: 100));
          await t.pump(const Duration(milliseconds: 100));
          await t.ensureVisible(
            find.text('Avatar upload failed: upload_failed'),
          );
          await t.pump(const Duration(milliseconds: 50));
        }
      : null,
);

Widget _settingsPage(
  WorkspaceController w, {
  required String tab,
  required bool root,
}) {
  final presentation = PersonalPresentationStore();
  final notifications = NativeNotificationService(
    platform: TargetPlatform.android,
  );
  return RaftSettingsPage(
    initialTab: tab,
    mobileRoot: root,
    destinations: [
      RaftSettingsDestination(
        'account',
        'Account',
        RaftGlyph.user,
        (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AccountSettings(controller: w),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: RaftButton(
                label: raftText(context, 'Sign out'),
                secondary: true,
                icon: Icons.logout,
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
      RaftSettingsDestination(
        'language',
        'Language & Region',
        RaftGlyph.globe,
        (_) => LocaleSettingsPage(controller: w),
      ),
      RaftSettingsDestination(
        'appearance',
        'Appearance',
        RaftGlyph.palette,
        (_) => RaftAppearanceSection(
          appearance: const RaftAppearance(mode: ThemeMode.light),
          onAppearance: (_) {},
          presentation: presentation,
        ),
      ),
      RaftSettingsDestination(
        'notifications',
        'Notifications',
        RaftGlyph.info,
        (_) => NotificationSettingsView(service: notifications),
      ),
      RaftSettingsDestination(
        'sidebar',
        'Sidebar preferences',
        RaftGlyph.columns2,
        (_) => SidebarPreferencesView(controller: w),
        group: 'Workspace',
        scroll: false,
      ),
      if (w.can('federateChannels'))
        RaftSettingsDestination(
          'joint-channels',
          'Joint channels',
          RaftGlyph.gitBranch,
          (_) => JointChannelsView(controller: w),
          group: 'Workspace',
          scroll: false,
        ),
      RaftSettingsDestination(
        'server',
        'Server profile',
        RaftGlyph.settings,
        (_) => ServerSettingsView(controller: w),
        group: 'Workspace',
        scroll: false,
      ),
      if (w.can('viewBilling'))
        RaftSettingsDestination(
          'billing',
          'Plan & Billing',
          RaftGlyph.fileText,
          (_) => BillingView(controller: w),
          group: 'Workspace',
          scroll: false,
        ),
      if (w.can('viewServerSettings'))
        RaftSettingsDestination(
          'administration',
          'Administration',
          RaftGlyph.settings,
          (_) => AdministrationView(controller: w),
          group: 'Workspace',
          scroll: false,
        ),
      if (w.can('manageIntegrations'))
        RaftSettingsDestination(
          'applications',
          'Applications',
          RaftGlyph.bot,
          (_) => IntegrationsView(controller: w),
          group: 'Workspace',
          scroll: false,
        ),
      // providers / IM bridges are feature-flag gated (providerEnabled /
      // bridgeEnabled default false in WorkspaceView); kept referenced so the
      // mirror stays in sync with the app's list.
      if (_flagged)
        RaftSettingsDestination(
          'providers',
          'Providers',
          RaftGlyph.lock,
          (_) => ProviderConnectionsView(controller: w),
          group: 'Workspace',
          scroll: false,
        ),
      if (_flagged)
        RaftSettingsDestination(
          'bridges',
          'IM bridges',
          RaftGlyph.link,
          (_) => IMBridgesView(controller: w),
          group: 'Workspace',
          scroll: false,
        ),
    ],
  );
}

const bool _flagged = false;
