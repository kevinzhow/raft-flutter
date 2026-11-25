import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/create_agent_dialog.dart';
import 'package:raft_flutter/features/human_login.dart';
import 'package:raft_flutter/features/human_login_servers.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

import '../parity_harness.dart';
import 'thread_messages/chat_stage.dart' show ParityRaftClient;

final _fixture = jsonDecode(
  File('../../tool/parity-ext/fixtures/legacy-wave3a.json').readAsStringSync(),
) as Map<String, dynamic>;

WorkspaceController _workspace(ParityContext ctx) {
  final serverMap = Map<String, dynamic>.from(_fixture['server'] as Map);
  final userMap = Map<String, dynamic>.from(_fixture['user'] as Map);
  final machineMap = Map<String, dynamic>.from(_fixture['machine'] as Map);
  final runtimeOptions = List<Map<String, dynamic>>.from(
    (_fixture['runtimeOptions'] as List).map(
      (e) => Map<String, dynamic>.from(e as Map),
    ),
  );
  final serverId = serverMap['id'] as String;
  final client = ParityRaftClient({
    'GET /servers/$serverId/machines': (_) => {
      'machines': [machineMap],
    },
    'GET /servers/$serverId/agents/runtime-options': (_) => {
      'options': runtimeOptions,
    },
    'GET /servers/$serverId/machines/${machineMap['id']}/runtime-options': (
      _,
    ) => {'options': runtimeOptions},
    'GET /servers/$serverId/machines/${machineMap['id']}/runtime-forms/v2/claude':
        (_) => {
          'protocolVersion': 2,
          'runtimeId': 'claude',
          'schemaVersion': 'claude.create.v1',
          'revision': 'parity-1',
          'dataSchema': {'type': 'object', 'properties': <String, dynamic>{}},
          'uiSchema': {'order': <String>[]},
          'optionSources': <String, dynamic>{},
          'defaults': <String, dynamic>{},
          'capabilities': {
            'providerKinds': <String>[],
            'writeOnlyPointers': <String>[],
            'forbiddenPointers': <String>[],
          },
        },
    'GET /servers/$serverId/setup-projection': (_) => {
      'phase': 'in_progress',
      'surface': 'create_cindy',
      'currentStep': 'create_cindy',
      'blocksChat': true,
      'allowedExits': <String>[],
      'runtimeStatus': 'ready_recommended',
      'runtimeOptions': runtimeOptions,
      'hasConnectedComputer': true,
    },
    'GET /billing/subscription': (_) => {
      'plan': 'pro',
      'displayName': 'Pro',
      'limits': {'maxAgents': 10},
    },
  }, user: userMap)..selectServer(serverId);
  final server = RaftRecord(serverMap);
  final w = WorkspaceController(client)
    ..servers = [server]
    ..server = server;
  ctx.onDispose(w.dispose);
  return w;
}

Widget _stage(Widget child) => Builder(
  builder: (context) {
    final t = RaftTokens.of(context);
    return RaftRecipeBox(
      declareSurface: true,
      applyText: false,
      tokens: t.recipeTokens,
      style: RaftSlotStyle(
        {'background-color': CssColor(t.ui.layerCanvas.toARGB32())},
        const {},
        const ['bg-layer-canvas'],
        t.recipeTokens,
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  },
);

ParityCase _serverCreatePreview({required bool mobile, required bool custom}) =>
    ParityCase(
      widgets: const [
        'raft_ui:RaftOnboardingDotPane',
        'raft_ui:RaftServerCreatePreview',
      ],
      settle: const Duration(milliseconds: 250),
      build: (ctx) => _stage(
        Center(
          child: SizedBox(
            key: const ValueKey('wave3a-frame'),
            width: mobile ? 390 : 768,
            height: mobile ? 620 : 640,
            child: RaftOnboardingDotPane(
              child: RaftServerCreatePreview(
                serverName: custom ? 'Design Lab' : '',
                serverSlug: custom ? 'design-lab' : '',
              ),
            ),
          ),
        ),
      ),
    );

ParityCase _identityImpactPreview() => ParityCase(
  widgets: const ['raft_ui:RaftIdentityImpactPreview'],
  settle: const Duration(milliseconds: 350),
  build: (ctx) => _stage(
    Center(
      child: SizedBox(
        width: 768,
        height: 784,
        child: RaftOnboardingDotPane(
          child: Center(
            child: SizedBox(
              key: const ValueKey('wave3a-identity-preview'),
              width: 640,
              height: 520,
              child: const RaftIdentityImpactPreview(),
            ),
          ),
        ),
      ),
    ),
  ),
);

ParityCase _cindySetup() => ParityCase(
  widgets: const [
    'raft_flutter:CreateAgentDialog',
    'raft_ui:RaftCindySetupScreen',
  ],
  settle: const Duration(milliseconds: 300),
  build: (ctx) {
    final w = _workspace(ctx);
    final machineMap = Map<String, dynamic>.from(_fixture['machine'] as Map);
    return _stage(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: KeyedSubtree(
            key: const ValueKey('wave3a-cindy-setup'),
            child: CreateAgentDialog(
              controller: w,
              machines: [machineMap],
              initialMachineId: machineMap['id'] as String,
              initialRuntimeId: 'claude',
              onboarding: true,
              onSwitchServer: () {},
            ),
          ),
        ),
      ),
    );
  },
);

ParityCase _setupSurvey() => ParityCase(
  widgets: const ['raft_ui:RaftSetupSurveyCard'],
  settle: const Duration(milliseconds: 250),
  build: (_) => _stage(const _SetupSurveyHost()),
);

class _SetupSurveyHost extends StatefulWidget {
  const _SetupSurveyHost();

  @override
  State<_SetupSurveyHost> createState() => _SetupSurveyHostState();
}

class _SetupSurveyHostState extends State<_SetupSurveyHost> {
  final TextEditingController _otherController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: RaftSetupSurveyCard(
        key: const ValueKey('wave3a-setup-survey'),
        roles: const {
          'software_engineer': 'Software engineer',
          'tech_lead': 'Tech lead',
          'founder': 'Founder',
          'product_manager': 'Product manager',
          'designer': 'Designer',
          'data_ml': 'Data / ML',
          'devops_it': 'DevOps / IT',
          'student_learner': 'Student or learner',
          'other': 'Other',
        },
        sources: const {
          'twitter': 'Twitter / X',
          'linkedin': 'LinkedIn',
          'friend': 'A friend or colleague',
          'search': 'Search',
          'hn_reddit': 'Hacker News / Reddit',
          'podcast_blog': 'Podcast / blog / newsletter',
          'other': 'Other',
        },
        role: null,
        source: null,
        otherController: _otherController,
        saving: false,
        onRole: (_) {},
        onSource: (_) {},
        onContinue: () {},
        onSwitchServer: () {},
      ),
    ),
  );
}

ParityCase _setupHandoff() => ParityCase(
  widgets: const ['raft_ui:RaftSetupHandoffCard'],
  settle: const Duration(milliseconds: 250),
  build: (ctx) => _stage(
    Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: RaftSetupHandoffCard(
          key: const ValueKey('wave3a-setup-handoff'),
          starting: false,
          onDone: () {},
          onSwitchServer: () {},
        ),
      ),
    ),
  ),
);

ParityCase _setupComputer() => ParityCase(
  widgets: const ['raft_ui:RaftSetupComputerCard'],
  settle: const Duration(milliseconds: 250),
  build: (ctx) => _stage(
    Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: RaftSetupComputerCard(
          key: const ValueKey('wave3a-setup-computer'),
          computerName: "Wenyi's MacBook Pro",
          computerOnline: true,
          waiting: false,
          runtimeReady: true,
          runtimeNames: const ['Claude Code'],
          runtimeAnswered: true,
          recommendedRuntimes: const [
            RaftSetupRuntime(
              id: 'claude',
              displayName: 'Claude Code',
              abbreviation: 'CC',
              recommended: true,
              detected: true,
            ),
            RaftSetupRuntime(
              id: 'codex',
              displayName: 'Codex',
              abbreviation: 'CX',
              recommended: true,
              detected: false,
            ),
          ],
          supportedRuntimes: const [
            RaftSetupRuntime(
              id: 'opencode',
              displayName: 'OpenCode',
              abbreviation: 'OC',
              recommended: false,
              detected: false,
            ),
          ],
          offlineComputers: const [],
          recovering: false,
          legacyDaemon: false,
          guidePlatform: 'mac-linux',
          onGuidePlatform: (_) {},
          guideCommands: (
            'curl -fsSL https://cdn.raft.build/computer/install.sh | sh',
            'raft-computer setup /launch',
          ),
          serverSlug: 'launch',
          canReset: false,
          loading: false,
          onNext: () {},
          onSwitchServer: () {},
        ),
      ),
    ),
  ),
);

ParityCase _providerAccounts({required bool mobile}) => ParityCase(
  widgets: const [
    'raft_ui:RaftSectionHeader',
    'raft_ui:RaftListRowGroup',
    'raft_ui:RaftListRow',
    'raft_ui:RaftIconTile',
    'raft_ui:RaftButton',
  ],
  settle: const Duration(milliseconds: 200),
  build: (ctx) {
    final providers = List<Map<String, dynamic>>.from(
      (_fixture['providers'] as List).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final identities = List<Map<String, dynamic>>.from(
      (_fixture['identities'] as List).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    return _stage(
      Center(
        child: Builder(
          builder: (context) {
            final dark = RaftTokens.of(context).dark;
            return Container(
              key: const ValueKey('wave3a-frame'),
              width: mobile ? 358 : 560,
              color: RaftTokens.of(context).ui.layerCanvas,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RaftSectionHeader(
                    label: raftText(context, 'Connected accounts'),
                    icon: const RaftIcon(RaftGlyph.plug, size: 16),
                  ),
                  const SizedBox(height: RaftSpace.x3),
                  RaftListRowGroup(
                    children: [
                      for (final provider in providers)
                        (() {
                          final id = provider['id'] as String;
                          final label = provider['label'] as String;
                          final identity = identities
                              .where((i) => i['provider'] == id)
                              .firstOrNull;
                          return RaftListRow(
                            variant: RaftListRowVariant.plain,
                            interactive: false,
                            semanticLabel: '$label account',
                            children: [
                              RaftIconTile(
                                glyph: RaftGlyph.plug,
                                iconBuilder: (size, color) => switch (id) {
                                  'google' => const RaftBrandMark(
                                    RaftBrandMarkKind.google,
                                    height: RaftSpace.providerIcon,
                                  ),
                                  'github' => RaftBrandMark(
                                    RaftBrandMarkKind.github,
                                    height: RaftSpace.providerIcon,
                                    invert: dark,
                                  ),
                                  _ => const SizedBox.square(
                                    dimension: RaftSpace.providerIcon,
                                  ),
                                },
                              ),
                              RaftListRowBody(
                                children: [
                                  RaftListRowTitle(label),
                                  RaftListRowDescription(
                                    identity == null
                                        ? raftText(context, 'Not connected')
                                        : raftFormat(
                                            context,
                                            'Connected as {email}',
                                            {
                                              'email':
                                                  identity['providerEmail'] ??
                                                  '',
                                            },
                                          ),
                                  ),
                                ],
                              ),
                              RaftButton(
                                label: raftText(
                                  context,
                                  identity == null ? 'Connect' : 'Disconnect',
                                ),
                                uiVariant: RaftButtonVariant.outline,
                                uiSize: RaftButtonSize.md,
                                onPressed: () {},
                              ),
                            ],
                          );
                        })(),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  },
);

ParityCase _humanLoginServers({required bool mobile}) => ParityCase(
  widgets: const [
    'raft_flutter:HumanLoginServerField',
    'raft_ui:RaftCard',
    'raft_ui:RaftListRow',
    'raft_ui:RaftBadge',
  ],
  settle: const Duration(milliseconds: 200),
  build: (ctx) {
    final raw = List<Map<String, dynamic>>.from(
      (_fixture['loginServers'] as List).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final rows = [
      for (final s in raw)
        HumanLoginRow(
          HumanLoginServer(
            id: s['id'] as String,
            slug: s['slug'] as String,
            name: s['name'] as String,
          ),
          switch (s['state']) {
            'unavailable' => null,
            final state => HumanLoginClient(
              clientId: 'app-share',
              name: 'Artifact Share',
              marketplace: true,
              installRequired: state != 'ready',
              canInstall: state == 'install',
            ),
          },
        ),
    ];
    return _stage(
      Center(
        child: Builder(
          builder: (context) => Container(
            key: const ValueKey('wave3a-frame'),
            width: mobile ? 358 : 520,
            color: RaftTokens.of(context).ui.layerCanvas,
            padding: const EdgeInsets.all(8),
            child: HumanLoginServerField(
              lookup: HumanLoginLookup(rows),
              selectedId: 'srv-1',
              enabled: true,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );
  },
);

ParityCase _feedbackEmpty({required bool mobile}) => ParityCase(
  widgets: const ['raft_ui:RaftFeedbackEmptyState', 'raft_ui:RaftEmptyState'],
  settle: const Duration(milliseconds: 300),
  build: (ctx) => _stage(
    Center(
      child: Builder(
        builder: (context) => ColoredBox(
          color: RaftTokens.of(context).ui.layerCanvas,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: mobile ? 326 : 608,
                child: const RaftFeedbackEmptyState(
                  kind: RaftFeedbackFilter.all,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

ParityCase _searchSkeleton({required bool mobile}) => ParityCase(
  widgets: const ['raft_ui:RaftQuickSwitcherSkeleton', 'raft_ui:RaftSkeleton'],
  settle: const Duration(milliseconds: 200),
  build: (ctx) => _stage(
    Center(
      child: Builder(
        builder: (context) => Container(
          width: mobile ? 358 : 680,
          color: RaftTokens.of(context).ui.layerCanvas,
          child: const RaftQuickSwitcherSkeleton(),
        ),
      ),
    ),
  ),
);

ParityCase _searchError({required bool mobile}) => ParityCase(
  widgets: const ['raft_ui:RaftQuickSwitcherErrorCard', 'raft_ui:RaftBanner'],
  settle: const Duration(milliseconds: 200),
  build: (ctx) => _stage(
    Center(
      child: Builder(
        builder: (context) => Container(
          key: const ValueKey('wave3a-frame'),
          width: mobile ? 358 : 680,
          color: RaftTokens.of(context).ui.layerCanvas,
          padding: const EdgeInsets.all(20),
          child: RaftQuickSwitcherErrorCard(
            title: 'Search failed',
            body: 'The last search request failed. Existing results are preserved when possible, but this query needs a retry.',
            actionLabel: 'Retry',
            onAction: () {},
          ),
        ),
      ),
    ),
  ),
);

final Map<String, ParityCase> extLegacyWave3aCases = {
  for (final platform in const ['desktop', 'phone'])
    for (final suffix in const ['brutal', 'elegant-dark']) ...{
      'components.legacy-wave3a.server-create-preview.$platform.$suffix':
          _serverCreatePreview(mobile: platform == 'phone', custom: false),
      'components.legacy-wave3a.cindy-setup.$platform.$suffix': _cindySetup(),
      'components.legacy-wave3a.setup-survey.$platform.$suffix': _setupSurvey(),
      'components.legacy-wave3a.setup-handoff.$platform.$suffix':
          _setupHandoff(),
      'components.legacy-wave3a.setup-computer.$platform.$suffix':
          _setupComputer(),
      'components.legacy-wave3a.provider-accounts.$platform.$suffix':
          _providerAccounts(mobile: platform == 'phone'),
      'components.legacy-wave3a.human-login-servers.$platform.$suffix':
          _humanLoginServers(mobile: platform == 'phone'),
      'components.legacy-wave3a.feedback-empty.$platform.$suffix':
          _feedbackEmpty(mobile: platform == 'phone'),
      'components.legacy-wave3a.search-skeleton.$platform.$suffix':
          _searchSkeleton(mobile: platform == 'phone'),
      'components.legacy-wave3a.search-error.$platform.$suffix': _searchError(
        mobile: platform == 'phone',
      ),
    },
  for (final suffix in const ['brutal', 'elegant-dark']) ...{
    'components.legacy-wave3a.server-create-custom.desktop.$suffix':
        _serverCreatePreview(mobile: false, custom: true),
    'components.legacy-wave3a.identity-impact-preview.desktop.$suffix':
        _identityImpactPreview(),
  },
};
