// Official cases owned by this group (default selection):
//   components.members.create-agent.dialog
//   components.members.create-agent.dialog-error
//   components.members.create-agent.claude-dialog
//   components.members.create-agent.claude-custom-provider-dialog
//   components.members.agent-detail.profile
//   components.members.agent-detail.status.* (v1.24 status chip and runtime error banner, each with a .dark twin)
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
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart'
    show
        ImagePickerPlatform,
        ImageSource,
        ImagePickerOptions; // ignore: depend_on_referenced_packages
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_members.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_flutter/features/managed_agent_launcher.dart';
import 'package:raft_flutter/features/workspace_settings.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parity_harness.dart';
import 'screens.dart' show agentDetailParityCase;
import 'members_settings/fixture_client.dart';
import 'members_settings/runtime_forms.dart';

final Map<String, ParityCase> membersSettingsCases = {
  'components.members.create-agent.dialog': _createAgent('codex'),
  'components.members.create-agent.dialog-error': _createAgent(
    'codex',
    name: 'bad name!!',
    extraNotes:
        ' The invalid prefill reports the NAME_REGEX error from the first '
        'render (Web task #1139 E-state).',
  ),
  'components.members.create-agent.dialog-empty': _createAgent(
    'codex',
    empty: true,
  ),
  'components.members.create-agent.claude-dialog': _createAgent('claude'),
  'components.members.create-agent.claude-custom-provider-dialog': _createAgent(
    'claude',
    customProvider: true,
    extraNotes:
        ' Provider set to Custom, API URL/API key filled, MORE opened and '
        'Claude Command filled like react-provider.spec.ts, modal scrolled '
        'back to top.',
  ),
  'components.members.create-agent.builtin-provider-dialog': _createAgent(
    'builtin',
  ),
  'components.members.create-agent.pi-provider-dialog': _createAgent('pi'),
  'components.members.create-agent.dialog-no-computer': _noComputer,
  'components.members.agent-detail.profile': _agentDetail(lifecycle: false),
  ..._agentStatusCases,
  'components.members.avatar-management': agentDetailParityCase(
    'productUx',
    notes:
        'Actual profile avatar trigger opens the scoped preset/upload editor.',
    then: (t, ctx) async {
      await t.tap(find.byKey(const ValueKey('agent-profile-avatar-trigger')));
      await t.pump(const Duration(milliseconds: 500));
    },
  ),
  'components.members.agent-lifecycle-actions': _agentDetail(lifecycle: true),
  'components.channel.settings.panel': _channelSettings,
  'components.channel.members.add-panel': _channelAddMember,
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

final Map<String, ParityUncovered> membersSettingsUncovered = {};

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
// Create agent: showManagedAgentForm → CreateAgentDialog, the dialog every
// "Create Agent" entry opens (FleetView, action cards).

/// react-provider.spec.ts visualBillingInfo() for a non-billing case (Free
/// plan, 2/2 agents): served to the no-computer case only (Web 1.24 split the capacity
/// banner out of the other create cases).
Map<String, dynamic> _visualBilling() => {
  'plan': 'free',
  'displayName': 'Free',
  'serverPlan': 'free',
  'source': 'server',
  'capacity': {'maxHumans': 1, 'maxAgents': 2, 'maxUniversalSeats': -1},
  'usage': {'humans': 2, 'agents': 2, 'universalSeats': 0},
};

/// VisualTestingCases.tsx primeCreateAgentStores: the primary computer with
/// the case's runtimes plus the offline studio rig.
List<Map<String, dynamic>> _createAgentMachines(
  MsFixture fixture,
  List<String> runtimes,
) => [
  // Web's visual host machines carry no hostname, so its picker label is the name.
  {
    ...fixture.machine('primary'),
    'status': 'online',
    'runtimes': runtimes,
    'hostname': null,
  },
  {
    ...fixture.machine('studio'),
    'status': 'offline',
    'runtimes': ['codex'],
    'hostname': null,
  },
];

ParityCase _createAgent(
  String runtime, {
  String? name,
  bool empty = false,
  bool customProvider = false,
  String extraNotes = '',
}) => ParityCase(
  widgets: const [
    'raft_flutter:CreateAgentDialog',
    'raft_ui:RaftAgentDialogCard',
    'raft_ui:RaftStableField',
    'raft_ui:RaftAgentSelect',
    'raft_ui:RaftAgentTextInput',
    'raft_ui:RaftAgentBanner',
    'raft_ui:RaftButton',
  ],
  notes:
      'showManagedAgentForm → CreateAgentDialog (DialogCard, capacity '
      'Banner from /billing/subscription, COMPUTER / NAME / DESCRIPTION '
      'StableFields, RUNTIME select from runtime-options, then the '
      "runtime's v2 fields; Cancel / Create Agent). Served like the "
      'React host: visualBillingInfo, the primed machines '
      '(Jiachengs-MacBook-Pro runtimes ${customProvider ? '[claude, codex]' : '[$runtime, ...]'} + offline studio), '
      '${customProvider ? 'the scoped claude runtime-options catalog and the claude v2 form' : 'the React HTTP 200 fallback without runtime options, so RUNTIME stays "Select..." and the declared-Claude pre-admission MODEL picker shows the bundled catalog with the failed machine source'}.'
      '$extraNotes',
  settle: const Duration(milliseconds: 600),
  build: (ctx) {
    final fixture = MsFixture(ctx);
    final machineRuntimes = switch (runtime) {
      'claude' => ['claude', 'codex'],
      'codex' => ['codex', 'claude'],
      _ => [runtime, 'claude', 'codex'],
    };
    final server = '/servers/visual-server/machines';
    final base = 'GET $server/computer-mbp/runtime-forms/v2/$runtime';
    final form = _forms(runtime);
    // Web 1.24 split the capacity banner into its own case: the create cases
    // show no banner, so no billing summary is served.
    final routes = <String, Object? Function(dynamic)>{
      'GET $server': (_) => {
        'machines': _createAgentMachines(fixture, machineRuntimes),
      },
      base: (_) => form,
      // Pinned React react-provider.spec.ts:1490 transport fallback.
      if (!customProvider)
        'GET $server/computer-mbp/runtime-options': (_) => {
          'agents': [],
          'humans': [],
          'results': [],
        },
      if (customProvider)
        'GET $server/computer-mbp/runtime-options': (_) => {
          'context': 'new_agent',
          'machineId': 'computer-mbp',
          'options': [
            {
              'runtimeId': 'claude',
              'capabilityStatus': 'available',
              'admissionStatus': 'available_for_new',
              'admissionReason': null,
              'current': false,
              'availableForNew': true,
              'manageableForCurrentAgent': false,
              'canSelectInThisContext': true,
              'runtimeFormV2': {'protocolVersion': 2},
            },
          ],
        },
    };
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
      // VisualTestingCases.tsx2493: main bg-white; modal tokens still follow theme.
      page: const Scaffold(backgroundColor: Colors.white),
      open: (context) => showManagedAgentForm(
        context,
        w,
        suggestedComputer: 'computer-mbp',
        // Web: `prefilledName=""` for the empty case; only an absent
        // prefill starts with a suggested name.
        initialName: empty ? '' : name ?? props['name'] as String?,
        initialDescription: empty ? null : props['description'] as String?,
      ),
    );
  },
  interact: customProvider ? _fillCustomProvider : null,
);

/// react-provider.spec.ts: provider → Custom, fill API URL / API key, open
/// MORE, fill the Claude command, scroll the modal back to the top.
Future<void> _fillCustomProvider(WidgetTester t, ParityContext ctx) async {
  await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('runtime-provider')));
  await t.pump(const Duration(milliseconds: 200));
  await t.tap(find.text('Custom').last);
  await t.pump(const Duration(milliseconds: 200));
  await t.enterText(
    find.byKey(const ValueKey('runtime-apiUrl')),
    'https://gateway.example.com',
  );
  await t.enterText(
    find.byKey(const ValueKey('runtime-apiKey')),
    'visual-test-key',
  );
  await t.ensureVisible(find.text('Advanced'));
  await t.pump(const Duration(milliseconds: 100));
  await t.tap(find.text('Advanced'));
  await t.pump(const Duration(milliseconds: 100));
  await t.enterText(find.byKey(const ValueKey('runtime-command')), 'claude');
  await t.pump(const Duration(milliseconds: 100));
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pump(const Duration(milliseconds: 100));
  final modal = find
      .ancestor(
        of: find.byKey(const ValueKey('runtime-provider')),
        matching: find.byType(Scrollable),
      )
      .first;
  t.state<ScrollableState>(modal).position.jumpTo(0);
  await t.pump(const Duration(milliseconds: 100));
}

/// Zero machines: showManagedAgentForm opens CreateAgentDialog's
/// "Connect a computer first" branch.
final ParityCase _noComputer = ParityCase(
  widgets: const [
    'raft_flutter:CreateAgentDialog',
    'raft_ui:RaftAgentDialogCard',
    'raft_ui:RaftAgentBanner',
    'raft_ui:RaftButton',
  ],
  notes:
      'showManagedAgentForm with zero computers → CreateAgentDialog '
      'needs-computer branch: DialogCard, info Banner "Connect a computer '
      'first", Cancel / Add Computer.',
  settle: const Duration(milliseconds: 400),
  build: (ctx) {
    final fixture = MsFixture(ctx);
    final (w, _) = fixture.workspace({
      'GET /billing/subscription': (_) => _visualBilling(),
      'GET /servers/visual-server/machines': (_) => {'machines': []},
    });
    return _Host(
      // VisualTestingCases.tsx2493: main bg-white; modal tokens still follow theme.
      page: const Scaffold(backgroundColor: Colors.white),
      open: (context) => showManagedAgentForm(context, w),
    );
  },
);

// ---------------------------------------------------------------------------
// Agent detail: the same FleetDetail/AgentDetailPanel route as
// screens.members.agent-detail.profile (screens.dart).

ParityCase _agentDetail({required bool lifecycle}) => agentDetailParityCase(
  'productUx',
  notes: lifecycle
      ? ' Lifecycle actions = the header "More Actions" overflow menu '
            '(Direct Message, Stop Agent, Restart / Reset), opened by the '
            'same mouse click as the React provider, retaining trigger hover.'
      : '',
  then: lifecycle
      ? (t, ctx) async {
          final trigger = find.byKey(
            const Key('agent-profile-overflow-trigger'),
          );
          final point = t.getCenter(trigger);
          final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
          addTearDown(mouse.removePointer);
          await mouse.addPointer(location: point);
          await mouse.down(point);
          await mouse.up();
          await t.pump(const Duration(milliseconds: 200));
        }
      : null,
);

// ---------------------------------------------------------------------------
// Web v1.24 opens the channel Details page at phone width. Its member
// capture starts on the full-width roster and opens Add member there.

final ParityCase _channelSettings = ParityCase(
  widgets: const ['raft_flutter:ChannelSettings', 'raft_ui:RaftOverflowSheet'],
  notes: 'Product Details page mounted at the manifest phone viewport.',
  settle: const Duration(milliseconds: 600),
  build: (ctx) {
    final fixture = MsFixture(ctx);
    final channel = RaftChannel({
      ...fixture.channel('design'),
      'channelCapabilities': {
        'editChannelMetadata': true,
        'changeChannelVisibility': true,
        'archiveChannels': true,
        'deleteChannels': true,
        'addChannelMembers': true,
      },
    });
    final (w, _) = fixture.workspace({
      'GET /channels/${channel.id}/members': (_) => {
        'agents': [],
        'humans': [],
        'externalMembers': [],
      },
    });
    w
      ..channel = channel
      ..channels = [channel];
    return Scaffold(
      body: ChannelSettings(
        controller: w,
        channel: channel,
        isPanel: true,
        page: true,
        details: true,
        onClose: () {},
      ),
    );
  },
);

final ParityCase _channelAddMember = ParityCase(
  widgets: const [
    'raft_flutter:ChannelMembers',
    'raft_ui:RaftMemberPickerContent',
  ],
  notes:
      'Product ChannelMembers page with the Add member action driven from the '
      'same starting roster and directory as the Web case.',
  settle: const Duration(milliseconds: 600),
  build: (ctx) {
    final fixture = MsFixture(ctx);
    final channel = Map<String, dynamic>.from(fixture.channel('design'))
      // VisualTestingCases.tsx grants addChannelMembers for this case only.
      ..['channelCapabilities'] = {'addChannelMembers': true};
    final (w, _) = fixture.workspace({
      'GET /channels/${channel['id']}/members': (_) => {
        'agents': [],
        'humans': [],
        'externalMembers': [],
      },
      'GET /servers/visual-server/members': (_) => fixture.members,
      'GET /agents': (_) => fixture.agents,
    });
    final mounted = RaftChannel(channel);
    w.channels = [mounted];
    return Scaffold(
      body: ChannelMembers(
        controller: w,
        channel: mounted,
        page: true,
        onClose: () {},
      ),
    );
  },
  interact: (t, ctx) async {
    await t.pump(const Duration(milliseconds: 300));
    final add = find.byKey(const ValueKey('add-member-open'));
    await t.tap(add);
    await t.pump(const Duration(milliseconds: 250));
  },
);

// ---------------------------------------------------------------------------
// Settings: RaftSettingsPage with the destination list WorkspaceView.settings()
// builds for an owner (workspace_view.dart), mobile layout.

class _AvatarPhotoPickerFixture extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile.fromData(
    Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47]),
    name: 'avatar.png',
    path: 'avatar.png',
    mimeType: 'image/png',
  );
}

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
    'raft_flutter:WorkspaceSettings',
    if (root) 'raft_ui:RaftSettingsSidebarList',
    if (root) 'raft_ui:RaftMobileRootHeader',
    if (tab == 'account' && !root) 'raft_flutter:AccountSettings',
    if (tab == 'server') 'raft_flutter:ServerSettingsView',
    if (tab == 'appearance') 'raft_flutter:RaftAppearanceSection',
    if (tab == 'notifications') 'raft_flutter:NotificationSettingsView',
  ],
  notes: [
    'WorkspaceSettings (the widget WorkspaceView.settings() mounts) for the '
        'fixture owner.',
    if (tab == 'account' && !root)
      '/auth/identities adds passwordConfigured:false (the state React shows '
          'as "Set a password"; its mock omits the field, which Flutter would '
          'render as "Sign-in methods could not be verified").',
    if (uploadError)
      'Error state reached through the real flow: tap the profile avatar '
          '(account-profile-image) → file picker (FileSelectorPlatform fixture '
          'returns a PNG) → POST /auth/me/avatar fails with the React/Android '
          'fixture message "Avatar upload failed: upload_failed", shown above '
          'the profile form like AccountSection.',
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
      'POST /auth/me/avatar': (_) => RaftApiException.response(
        'Avatar upload failed: upload_failed',
        status: 500,
        body: const {'error': 'Avatar upload failed: upload_failed'},
      ),
    });
    if (uploadError) {
      final documents = FileSelectorPlatform.instance;
      final photos = ImagePickerPlatform.instance;
      FileSelectorPlatform.instance = _AvatarPickerFixture();
      ImagePickerPlatform.instance = _AvatarPhotoPickerFixture();
      ctx.onDispose(() {
        FileSelectorPlatform.instance = documents;
        ImagePickerPlatform.instance = photos;
      });
    }
    return Scaffold(
      body: _settingsPage(ctx, w, tab: tab, root: root),
    );
  },
  interact: uploadError
      ? (t, ctx) async {
          await t.pump(const Duration(milliseconds: 100));
          final trigger = find.byKey(const Key('account-profile-image'));
          // The avatar is already within the mounted viewport. Source's
          // initial-error fixture keeps its initial scroll position; a real
          // upload failure must likewise leave this visible page in place.
          expect(
            t
                .getRect(trigger)
                .overlaps(
                  Offset.zero & t.view.physicalSize / t.view.devicePixelRatio,
                ),
            true,
          );
          await t.tap(trigger);
          await t.pump(const Duration(milliseconds: 100));
          await t.pump(const Duration(milliseconds: 100));
          expect(
            find.text('Avatar upload failed: upload_failed'),
            findsOneWidget,
          );
          await t.pump(const Duration(milliseconds: 50));
        }
      : null,
);

Widget _settingsPage(
  ParityContext ctx,
  WorkspaceController w, {
  required String tab,
  required bool root,
}) {
  final presentation = PersonalPresentationStore();
  final notifications = NativeNotificationService(
    platform: TargetPlatform.android,
  );
  ctx.onDispose(presentation.dispose);
  ctx.onDispose(notifications.dispose);
  return WorkspaceSettings(
    controller: w,
    // React fixture state: Light mode, Brutal light theme.
    appearance: const RaftAppearance(mode: ThemeMode.light),
    onAppearance: (_) {},
    presentation: presentation,
    notifications: notifications,
    onLogout: () async {},
    initialTab: tab,
    mobileRoot: root,
  );
}

// ---------------------------------------------------------------------------
// Agent profile status (Web v1.24.0 AgentStatusBadge / AgentRuntimeErrorNotice;
// VisualTestingCases `primeCredentialStatus` / `primeRuntimeErrorView`): the
// same profile route with the stored error and the live activity seeded the way
// the React host seeds its stores. Each id has a `.dark` twin.

const _credentialHeldDetail =
    'Codex CLI is not logged in on this computer. Sign in again, then restart the agent. (Reported by another agent on the same sign-in.)';
const _credentialBillingDetail =
    "Codex CLI reported that the provider's billing or credit balance is exhausted. Raft stopped retrying because retries cannot succeed until the balance is restored. Messages that were waiting are kept and will be delivered when the agent starts again. Add credits or switch this agent to another model or provider, then restart the agent.";
const _runtimeErrorScrubbedDetail =
    '429 Too Many Requests: You have hit your usage limit for this billing period (account [redacted]). Try again after the limit resets.';

/// `RUNTIME_ERROR_CODE_SENTENCES.usage_limit`: what the server sends a member
/// in place of the error's text.
const _usageLimitMemberSentence =
    "The agent's model provider usage limit has been reached. Wait for the limit to reset, or ask the agent's owner to switch it to another model or account.";

Map<String, dynamic> _otherCreator(Map<String, dynamic> fx) => {
  'creatorId': fx['humans']['designer']['id'],
  'creator': {
    'type': 'human',
    'id': fx['humans']['designer']['id'],
    'name': fx['humans']['designer']['name'],
    'displayName': fx['humans']['designer']['displayName'],
    'avatarUrl': null,
    'gravatarHash': '',
  },
};

ParityCase _statusCase({
  required String note,
  Map<String, dynamic> Function(Map<String, dynamic> fx)? patch,
  required Map<String, dynamic> frame,
  bool member = false,
}) => agentDetailParityCase(
  'productUx',
  notes: ' $note',
  agentPatch: patch,
  liveFrame: frame,
  memberRole: member,
);

final Map<String, ParityCase> _agentStatusCases = {
  for (final dark in const ['', '.dark']) ...{
    'components.members.agent-detail.status.credential-held-sign-in$dark':
        _statusCase(
          note:
              'Idle status with credentialHold user_reauth, no stored error: '
              '"Sign-in needed for Codex CLI" on the error light, with Retry.',
          patch: (_) => {'lastRuntimeError': null},
          frame: const {
            'activity': 'online',
            'detail': _credentialHeldDetail,
            'detailKind': 'idle',
            'credentialHold': {'reason': 'user_reauth'},
          },
        ),
    'components.members.agent-detail.status.credential-own-billing$dark':
        _statusCase(
          note:
              'Own BillingError: "Provider balance exhausted" chip with Retry '
              'and the billing banner.',
          patch: (fx) => {
            'lastRuntimeError': {
              'message': _credentialBillingDetail,
              'at': fx['times']['recentActivityAtIso'],
              'actionRequired': true,
              'errorClass': 'BillingError',
              'errorReason': 'billing_exhausted',
              'fingerprint': '0123456789abcdef',
              'reasonProvenance': 'runtime_error_event',
            },
          },
          frame: const {
            'activity': 'error',
            'detail': _credentialBillingDetail,
            'detailKind': 'runtime_error',
          },
        ),
    'components.members.agent-detail.status.credential-member-view$dark':
        _statusCase(
          note:
              'A member who did not create the agent: generic Error chip, '
              'Retry, no reason.',
          member: true,
          patch: (fx) => {'lastRuntimeError': null, ..._otherCreator(fx)},
          frame: const {
            'activity': 'online',
            'detail': _credentialHeldDetail,
            'detailKind': 'idle',
            'credentialHold': {'reason': 'user_reauth'},
          },
        ),
    'components.members.agent-detail.status.runtime-error-code-member$dark':
        _statusCase(
          note:
              'usage_limit seen by a member: the chip reads the code title, '
              'the banner the member sentence, no copy and no logs.',
          member: true,
          patch: (fx) => {
            'lastRuntimeError': {
              'message': _usageLimitMemberSentence,
              'code': 'usage_limit',
              'at': fx['times']['recentActivityAtIso'],
              'actionRequired': false,
            },
            ..._otherCreator(fx),
          },
          frame: const {
            'activity': 'error',
            'detail': _usageLimitMemberSentence,
            'detailKind': 'runtime_error',
            'errorCode': 'usage_limit',
          },
        ),
    'components.members.agent-detail.status.runtime-error-code-manager$dark':
        _statusCase(
          note:
              'usage_limit seen by the manager: the manager sentence over the '
              'scrubbed two-line detail, with Copy info and View logs.',
          patch: (fx) => {
            'lastRuntimeError': {
              'message': _runtimeErrorScrubbedDetail,
              'code': 'usage_limit',
              'at': fx['times']['recentActivityAtIso'],
              'actionRequired': false,
            },
          },
          frame: const {
            'activity': 'error',
            'detail': _runtimeErrorScrubbedDetail,
            'detailKind': 'runtime_error',
            'errorCode': 'usage_limit',
          },
        ),
  },
};
