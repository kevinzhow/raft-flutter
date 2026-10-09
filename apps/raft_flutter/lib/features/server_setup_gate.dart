import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'management_support.dart';
import 'create_agent_dialog.dart';
import 'computer_setup_commands.dart';

/// Settings and the setup surface share one invalidation signal, never a verdict.
final serverSetupRevision = ValueNotifier<int>(0);
void refreshServerSetup() => serverSetupRevision.value++;

const setupSurveyRoles = {
  'software_engineer': 'Software engineer',
  'engineering_leader': 'Tech lead',
  'founder': 'Founder',
  'product': 'Product manager',
  'design': 'Designer',
  'data_ml': 'Data / ML',
  'devops_it': 'DevOps / IT',
  'student': 'Student or learner',
  'other': 'Other',
};
const setupSurveySources = {
  'twitter_x': 'Twitter / X',
  'linkedin': 'LinkedIn',
  'friend_colleague': 'A friend or colleague',
  'search': 'Search',
  'hn_reddit': 'Hacker News / Reddit',
  'podcast_blog_newsletter': 'Podcast / blog / newsletter',
  'other': 'Other',
};

/// Replaces conversation content while the server says setup is owed.
/// Management navigation remains usable without declaring setup complete.
class ServerSetupGate extends StatefulWidget {
  const ServerSetupGate({
    super.key,
    required this.controller,
    required this.child,
    this.onSwitchServer,
  });
  final WorkspaceController controller;
  final Widget child;
  final VoidCallback? onSwitchServer;
  @override
  State<ServerSetupGate> createState() => _ServerSetupGateState();
}

class _ServerSetupGateState extends ManagementState<ServerSetupGate> {
  @override
  WorkspaceController get w => widget.controller;
  Map<String, dynamic>? projection;
  String? createdAgentId, notice;
  List<Map<String, dynamic>>? setupMachines;
  String? setupMachinesError;
  StreamSubscription<RaftEvent>? events;
  Timer? poll, debounce;
  String get base => '/servers/${w.server!.id}';
  bool get blocked =>
      projection?['phase'] != null &&
      (projection?['blocksChat'] == true ||
          (projection?['surface'] == 'complete' &&
              (managementMap(projection?['postSetup'])['surveyPending'] ==
                      true ||
                  managementMap(projection?['postSetup'])['handoffPending'] ==
                      true)));
  @override
  void initState() {
    super.initState();
    startManagement();
    serverSetupRevision.addListener(reload);
    listenEvents();
    poll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (blocked && !busy) reload();
    });
  }

  void listenEvents() {
    events = w.client.events.listen((e) {
      if (e.name.startsWith('machine:') ||
          e.name.startsWith('agent:') ||
          e.name.startsWith('server:') ||
          e.name == 'account:updated') {
        debounce?.cancel();
        debounce = Timer(const Duration(milliseconds: 200), reload);
      }
    });
  }

  @override
  void didUpdateWidget(ServerSetupGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      events?.cancel();
      debounce?.cancel();
      rebindManagementController();
      listenEvents();
    }
  }

  @override
  void dispose() {
    serverSetupRevision.removeListener(reload);
    events?.cancel();
    poll?.cancel();
    debounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reload();
  }

  @override
  void clearData() {
    projection = null;
    setupMachines = null;
    setupMachinesError = null;
    createdAgentId = null;
    notice = null;
  }

  @override
  Future<void> loadData(int request, int generation) async {
    if (w.server == null) return;
    final result = await w.client.get('$base/setup-projection');
    if (!accepts(generation, request)) return;
    projection = managementMap(result);
    if (projection?['surface'] == 'create_agent' && createdAgentId == null) {
      try {
        final catalog = managementMap(await w.client.get('$base/machines'));
        if (!accepts(generation, request)) return;
        setupMachines = managementRows(catalog['machines']);
        setupMachinesError = null;
      } catch (e) {
        if (!accepts(generation, request)) return;
        setupMachinesError = '$e';
        if (e is RaftApiException && [401, 403].contains(e.status)) {
          setupMachines = null;
        }
      }
    }
    // A failed refetch preserves the last authoritative projection.
  }

  Future<void> transition(String action) async {
    final effects = managementMap(projection?['sideEffectState']);
    if (effects[action == 'complete' ? 'completion' : 'transitions'] !=
        'enabled') {
      return;
    }
    final generation = w.client.generation, scope = authority;
    await run(() async {
      final result = await w.client.post(
        '$base/setup-transition',
        data: {'action': action},
      );
      if (!accepts(generation) || scope != authority) return;
      projection = managementMap(result);
      if (action == 'complete' && projection?['surface'] != 'complete') {
        throw StateError(
          'Setup is not complete. Refresh and finish the remaining step.',
        );
      }
    }, refresh: false);
  }

  // The Source gate renders CreateAgentDialog(onboardingShell="step")
  // directly. Computer/runtime admission belongs to that shared form; no
  // separate picker can silently choose a runtime before its catalog arrives.
  Future<void> completeCindy() async {
    if (createdAgentId == null || !w.can('createAgents') || busy) return;
    await transition('complete');
  }

  Widget cindyStep() {
    final generation = w.client.generation, scope = authority;
    final machines = setupMachines;
    if (createdAgentId != null || machines == null) {
      return RaftCindySetupScreen(
        fields: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null || setupMachinesError != null)
              RaftAgentBanner(
                status: RaftAgentBannerStatus.warning,
                description: (error ?? setupMachinesError)!,
                action: createdAgentId == null ? 'Try again' : null,
                onAction: createdAgentId == null ? reload : null,
              )
            else if (createdAgentId == null)
              const Center(child: RaftSpinner())
            else
              label('Cindy is ready to help you get started.'),
          ],
        ),
        busy: busy,
        onCreate:
            createdAgentId == null ||
                managementMap(projection?['sideEffectState'])['completion'] !=
                    'enabled'
            ? null
            : completeCindy,
        sessionActions: widget.onSwitchServer == null
            ? null
            : RaftCindySessionLink(
                onPressed: busy ? null : widget.onSwitchServer,
              ),
      );
    }
    return CreateAgentDialog(
      key: ValueKey('cindy-step-$scope'),
      controller: w,
      machines: machines,
      onboarding: true,
      closeOnCreated: false,
      onSwitchServer: widget.onSwitchServer,
      onCreated: (agent) {
        if (!accepts(generation) || scope != authority) return;
        final id = agent['id'];
        if (id is! String || id.isEmpty) return;
        setState(() => createdAgentId = id);
        // Remember a valid create ACK before completion. A failed completion
        // retries only that transition; it must never create a second Cindy.
        unawaited(completeCindy());
      },
    );
  }

  Future<void> survey() async {
    final saved = await form(
      'Tell us about you',
      [
        const RaftFormField(
          'signupRole',
          'What best describes you?',
          required: true,
          choices: setupSurveyRoles,
        ),
        const RaftFormField(
          'referralSource',
          'How did you hear about Raft?',
          required: true,
          choices: setupSurveySources,
        ),
        const RaftFormField('referralSourceOther', 'Other source'),
      ],
      (v) async {
        if (v['referralSource'] == 'other' &&
            v['referralSourceOther']!.length > 200) {
          throw StateError('Use at most 200 characters for the other source.');
        }
        await w.client.request(
          'PATCH',
          '/auth/me',
          data: {
            'signupRole': v['signupRole'],
            'referralSource': v['referralSource'],
            if (v['referralSource'] == 'other')
              'referralSourceOther': v['referralSourceOther'],
          },
        );
        await w.client.reloadUser();
      },
      submit: 'Continue',
    );
    if (saved) await reload();
  }

  Future<void> reset() async {
    if (!managementStrings(projection?['allowedExits']).contains('reset')) {
      return;
    }
    await confirm(
      'Start setup over?',
      'Every computer connected to this unfinished workspace will be revoked. Its old credentials will stop working; the installed Computer service is not removed.',
      () async {
        final generation = w.client.generation, scope = authority;
        final result = managementMap(await w.client.post('$base/setup-reset'));
        if (!accepts(generation) || scope != authority) return;
        projection = result;
        createdAgentId = null;
        notice =
            '${result['revokedComputers'] ?? 0} computer connections revoked.';
      },
      submit: 'Start over',
      destructive: true,
    );
    if (mounted) setState(() {});
  }

  bool windowsCommands = false;
  Widget label(String text) => Text(raftText(context, text));
  @override
  Widget build(BuildContext context) {
    if (!blocked) return widget.child;
    final current = projection!;
    if (current['surface'] == 'create_agent') {
      return PopScope(
        canPop: false,
        child: Center(child: SingleChildScrollView(child: cindyStep())),
      );
    }
    final post = managementMap(current['postSetup']);
    final completed = current['surface'] == 'complete';
    final commands = ComputerSetupCommands.build(
      slug: w.server?.string('slug') ?? '',
      serverUrl: w.client.origin,
      windows: windowsCommands,
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: RaftPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  raftText(
                    context,
                    completed
                        ? 'Finish setting up your workspace'
                        : 'Set up your workspace',
                  ),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                if (error != null)
                  Semantics(liveRegion: true, child: Text(error!)),
                if (notice != null)
                  Semantics(liveRegion: true, child: Text(notice!)),
                if (completed && post['surveyPending'] == true) ...[
                  label('Tell Cindy about yourself before continuing.'),
                  action('Tell us about you', survey),
                ] else if (completed && post['handoffPending'] == true) ...[
                  label('Cindy is ready to help you get started.'),
                  action(
                    "Let's Go",
                    () => run(() async {
                      final generation = w.client.generation, scope = authority;
                      final result = await w.client.post('$base/setup-handoff');
                      if (accepts(generation) && scope == authority) {
                        projection = managementMap(result);
                      }
                    }),
                  ),
                ] else ...[
                  label(
                    current['hasConnectedComputer'] == true
                        ? 'Turn on your connected Computer to continue setup.'
                        : 'Connect a Raft Computer to run your agents.',
                  ),
                  for (final c in managementRows(current['offlineComputers']))
                    Text('${c['name']} · ${raftText(context, 'Offline')}'),
                  Text(
                    '${raftText(context, 'Computer')}: ${current['computerStatus'] ?? 'unknown'}',
                  ),
                  Text(
                    '${raftText(context, 'Runtime')}: ${current['runtimeStatus'] ?? 'unknown'}',
                  ),
                  const SizedBox(height: 12),
                  label(
                    'Install Raft Computer on the computer where your agents will run, then connect this workspace.',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: label('macOS / Linux'),
                        selected: !windowsCommands,
                        onSelected: (_) =>
                            setState(() => windowsCommands = false),
                      ),
                      ChoiceChip(
                        label: label('Windows'),
                        selected: windowsCommands,
                        onSelected: (_) =>
                            setState(() => windowsCommands = true),
                      ),
                    ],
                  ),
                  if (commands != null) ...[
                    _command(commands.install),
                    _command(commands.setup),
                  ],
                  if (current['phase'] == 'not_started' &&
                      managementMap(
                            current['sideEffectState'],
                          )['transitions'] ==
                          'enabled')
                    action('Start setup', () => transition('start')),
                ],
                const SizedBox(height: 12),
                label(
                  'You can manage this workspace or switch workspaces from the sidebar while setup is unfinished.',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    action(
                      'Refresh setup',
                      () => run(() async {}, refresh: true),
                    ),
                    if (managementStrings(current['allowedExits'])
                        .contains('reset'))
                      action('Start over', reset),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _command(String command) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: SelectableText(command)),
        IconButton(
          tooltip: raftText(context, 'Copy command'),
          onPressed: () => Clipboard.setData(ClipboardData(text: command)),
          // raft-ui CopyableCodeAction: lucide Copy, size-3, strokeWidth 1.75.
          icon: const RaftIcon(RaftGlyph.copy, size: 12, strokeWidth: 1.75),
        ),
      ],
    ),
  );
}
