import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/cause_notice.dart';
import '../data/freshness.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'management_support.dart';
import 'create_agent_dialog.dart';
import 'computer_setup_commands.dart';
import 'delete_server_confirm.dart';
import 'resource_cards.dart';

/// Settings and the setup surface of one workspace share an invalidation
/// signal, never a verdict. It belongs to the controller (account / server
/// session) it was raised on, so another controller's gate does not reload.
final _setupSignals = Expando<_SetupSignal>('serverSetupSignal');

/// A named type so the test leak ignore list can name it: it is held by an
/// Expando on the controller and released by GC, never disposed.
class _SetupSignal extends ValueNotifier<int> {
  _SetupSignal() : super(0);
}

ValueNotifier<int> _setupSignal(WorkspaceController w) =>
    _setupSignals[w] ??= _SetupSignal();
void refreshServerSetup(WorkspaceController w) => _setupSignal(w).value++;

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
    this.now,
  });
  final WorkspaceController controller;
  final Widget child;
  final VoidCallback? onSwitchServer;

  /// Clock of the relative "last seen" times (fixture captures freeze it).
  final DateTime Function()? now;
  @override
  State<ServerSetupGate> createState() => _ServerSetupGateState();
}

class _ServerSetupGateState extends ManagementState<ServerSetupGate> {
  @override
  WorkspaceController get w => widget.controller;

  /// SetupSessionFooter "Delete this server": owners only.
  bool get ownerDeletes => setupShowsDeleteServer(w);
  VoidCallback? get deleteServer =>
      setupDeleteServerAction(context, w, busy: busy);
  Map<String, dynamic>? projection;
  // ignore: raft_lints/avoid_imperative_notice_state -- createdAgentId clears on setup reset and server/account switch (clearData); notice is written by reset() but never rendered and clears on server/account switch (clearData).
  String? createdAgentId, notice;
  List<Map<String, dynamic>>? setupMachines;

  /// The failed machine-list read. It describes a list the current step has
  /// to show, so it ends with that need (the step moved on) or the next read.
  final _machinesFailure = CauseNotice();
  String? get setupMachinesError => _machinesFailure.message;
  bool get _needsMachines =>
      (projection?['surface'] == 'create_agent' && createdAgentId == null) ||
      projection?['surface'] == 'computer_runtime';
  StreamSubscription<RaftEvent>? events;
  Timer? debounce;
  RaftForegroundPeriodic? poll;
  final resumeReload = Freshness(const Duration(seconds: 20));
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
    _signal = _setupSignal(w)..addListener(reload);
    listenEvents();
    // Stops while hidden/paused; resume reloads (didChangeAppLifecycleState).
    poll = RaftForegroundPeriodic(const Duration(seconds: 10), () {
      if (blocked && !busy) reload();
    });
  }

  void listenEvents() {
    // Setup state is server-owned; only account and server-level changes can
    // move it. Membership churn of other users and agent/machine heartbeats
    // never re-read it (see [directoryChanged]).
    events = w.client.events.listen((e) {
      if ((e.name.startsWith('server:') &&
              !e.name.startsWith('server:member')) ||
          e.name == 'account:updated') {
        scheduleReload();
      }
    });
    _directory = w.services.entityDirectory..addListener(directoryChanged);
    _seenRevisions = directoryRevisions();
    _signature = setupSignature();
  }

  void scheduleReload() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 200), reload);
  }

  WorkspaceEntityDirectory? _directory;
  ValueNotifier<int>? _signal;
  String? _signature;
  (int, int)? _seenRevisions;

  /// The directory's scoped counters for what setup reads: computers and
  /// agents. Members, presence and activity never move them.
  (int, int) directoryRevisions() => (
    w.services.entityDirectory.computerRevision,
    w.services.entityDirectory.agentRevision,
  );

  /// Source ServerSetupProjectionGate re-reads the projection when the
  /// machines' id/status/runtimes change. Agent creation moves the
  /// create-agent step, so the agent id set is part of the signature too.
  /// Activity, presence and session patches leave it unchanged.
  String setupSignature() {
    final directory = w.services.entityDirectory;
    final machines = [
      for (final m in directory.rows(WorkspaceEntityKind.computers))
        '${m['id']}:${m['status']}:'
            '${m['runtimes'] is List ? (m['runtimes'] as List).join(',') : ''}',
    ]..sort();
    final agents = [
      for (final a in directory.rows(WorkspaceEntityKind.agents)) '${a['id']}',
    ]..sort();
    return '${machines.join('|')}#${agents.join('|')}';
  }

  void directoryChanged() {
    // Cheap fence first: the signature is only recomputed when a computer or
    // agent list actually moved.
    final revisions = directoryRevisions();
    if (revisions == _seenRevisions) return;
    _seenRevisions = revisions;
    final next = setupSignature();
    if (next == _signature) return;
    _signature = next;
    if (mounted && (projection == null || blocked)) scheduleReload();
  }

  @override
  void didUpdateWidget(ServerSetupGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      events?.cancel();
      debounce?.cancel();
      _directory?.removeListener(directoryChanged);
      _signal?.removeListener(reload);
      if (_announcementServer != null) {
        oldWidget.controller.services.announcementGate.detach(
          _announcementServer!,
        );
        _announcementServer = null;
      }
      rebindManagementController();
      _signal = _setupSignal(w)..addListener(reload);
      listenEvents();
    }
  }

  /// The server whose setup this gate reads, registered with the
  /// announcement gate (Web: the gate is mounted for the current server).
  String? _announcementServer;
  void _attachAnnouncementGate() {
    final id = w.server?.id;
    if (id == _announcementServer) return;
    final gate = w.services.announcementGate;
    if (_announcementServer != null) gate.detach(_announcementServer!);
    _announcementServer = id;
    if (id != null) gate.attach(id);
  }

  /// Every resolved read sets the Web `announcementGateState`; a failed
  /// first read (no projection) reads as blocked.
  void _reportAnnouncementGate(String serverId) {
    if (w.server?.id != serverId) return;
    w.services.announcementGate.report(serverId, projection);
  }

  @override
  void dispose() {
    if (_announcementServer != null) {
      w.services.announcementGate.detach(_announcementServer!);
    }
    _signal?.removeListener(reload);
    events?.cancel();
    _directory?.removeListener(directoryChanged);
    poll?.dispose();
    debounce?.cancel();
    surveyOther.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && resumeReload.due()) reload();
  }

  @override
  String get snapshotKey => 'server-setup';
  @override
  Map<String, Object?> captureSnapshot() => {
    'projection': projection,
    'setupMachines': setupMachines,
  };
  @override
  bool restoreSnapshot(Map<String, Object?> fields) {
    projection = fields['projection'] as Map<String, dynamic>?;
    setupMachines = fields['setupMachines'] as List<Map<String, dynamic>>?;
    return true;
  }

  @override
  void clearData() {
    projection = null;
    setupMachines = null;
    _machinesFailure.clear();
    _surveyFailure.clear();
    createdAgentId = null;
    notice = null;
  }

  @override
  Future<void> loadData(int request, int generation) async {
    _attachAnnouncementGate();
    if (w.server == null) return;
    final serverId = w.server!.id;
    final Object? result;
    try {
      result = await w.client.get('$base/setup-projection');
    } catch (_) {
      if (accepts(generation, request)) _reportAnnouncementGate(serverId);
      rethrow;
    }
    if (!accepts(generation, request)) return;
    projection = managementMap(result);
    _reportAnnouncementGate(serverId);
    if (_needsMachines) {
      try {
        final catalog = await w.client.get('$base/machines');
        if (!accepts(generation, request)) return;
        setupMachines = managementRows(
          catalog is List ? catalog : managementMap(catalog)['machines'],
        );
        _machinesFailure.clear();
      } catch (e) {
        if (!accepts(generation, request)) return;
        _machinesFailure.raise(
          userErrorText(
            e,
            fallback: 'Server setup could not be updated. Try again.',
            where: 'setup machines',
          ),
          whileTrue: () => _needsMachines,
        );
        if (e is RaftApiException && [401, 403].contains(e.status)) {
          setupMachines = null;
        }
      }
    }
    // A failed refetch preserves the last authoritative projection.
  }

  /// The owner deferred setup: the conversation stays usable and a bar offers
  /// to resume (Web `projection.phase === 'deferred'` and `!blocksChat`).
  bool get deferred =>
      projection?['phase'] == 'deferred' && projection?['blocksChat'] != true;

  /// ServerSetupProjectionGate.handleResume: start the setup again; the
  /// projection it answers decides what shows next. A failure is kept in
  /// [error] (the bar shows none, like Web) for the step that follows.
  Future<void> resume() async {
    if (busy) return;
    final generation = w.client.generation, scope = authority;
    await run(() async {
      final result = await w.client.post(
        '$base/setup-transition',
        data: {'action': 'start'},
      );
      if (!accepts(generation) || scope != authority) return;
      projection = managementMap(result);
      _reportAnnouncementGate(w.server!.id);
    }, refresh: false);
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
      _reportAnnouncementGate(w.server!.id);
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
        sessionActions: setupSessionActions(
          context,
          w,
          onSwitchServer: widget.onSwitchServer,
          busy: busy,
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

  String? surveyRole, surveySource;

  /// The failed survey save; it ends with the survey (answered, or another
  /// server's setup took over: [clearData]) or the next submit.
  final _surveyFailure = CauseNotice();
  String? get surveyError => _surveyFailure.message;
  bool get _surveyPending =>
      managementMap(projection?['postSetup'])['surveyPending'] == true;
  final surveyOther = TextEditingController();

  /// ServerSetupSurveyStep.handleSubmit: one PATCH /auth/me carrying the role
  /// and the referral source (the role is what closes the survey gate).
  Future<void> submitSurvey() async {
    final role = surveyRole, source = surveySource;
    if (role == null || source == null || busy) return;
    setState(_surveyFailure.clear);
    await run(() async {
      try {
        await w.client.request(
          'PATCH',
          '/auth/me',
          data: {
            'signupRole': role,
            'referralSource': source,
            if (source == 'other')
              'referralSourceOther': surveyOther.text.trim(),
          },
        );
        await w.client.reloadUser();
      } on RaftApiException {
        if (mounted) {
          setState(
            () => _surveyFailure.raise(
              "Couldn't save your answers. Try again.",
              whileTrue: () => _surveyPending,
            ),
          );
        }
        return;
      }
      await reload();
    }, refresh: false);
  }

  /// ServerSetupProjectionGate `StepContainer`: `flex min-h-full w-full
  /// overflow-y-auto p-4` around a `m-auto` step.
  Widget stepPage(Widget step) => LayoutBuilder(
    builder: (context, box) {
      final padding = raftScrollPadding(context, const EdgeInsets.all(16));
      return RaftKeyboardScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (box.maxHeight - padding.vertical).clamp(
              0,
              double.infinity,
            ),
          ),
          child: Center(child: step),
        ),
      );
    },
  );

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
    saveSnapshot();
  }

  bool windowsCommands = false;
  Widget label(String text) => Text(raftText(context, text));
  @override
  Widget build(BuildContext context) {
    if (!blocked) {
      // The child keeps its place in the tree whether or not the bar shows.
      return Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (deferred)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RaftSetupResumeBar(onResume: resume, loading: busy),
            ),
        ],
      );
    }
    final current = projection!;
    if (current['surface'] == 'create_agent') {
      return PopScope(
        canPop: false,
        child: Center(
          child: SingleChildScrollView(
            padding: raftScrollPadding(context),
            child: cindyStep(),
          ),
        ),
      );
    }
    final post = managementMap(current['postSetup']);
    final completed = current['surface'] == 'complete';
    if (completed && post['surveyPending'] == true) {
      return stepPage(
        RaftSetupSurveyCard(
          key: const ValueKey('setup-survey'),
          roles: setupSurveyRoles,
          sources: setupSurveySources,
          role: surveyRole,
          source: surveySource,
          error: surveyError,
          saving: busy,
          onRole: (id) => setState(() => surveyRole = id),
          onSource: (id) => setState(() => surveySource = id),
          otherController: surveyOther,
          onContinue: submitSurvey,
          onSwitchServer: busy ? null : widget.onSwitchServer,
          onDeleteServer: deleteServer,
          showDeleteServer: ownerDeletes,
        ),
      );
    }
    if (completed && post['handoffPending'] == true) {
      return stepPage(
        RaftSetupHandoffCard(
          key: const ValueKey('setup-handoff'),
          starting: busy,
          onSwitchServer: busy ? null : widget.onSwitchServer,
          onDeleteServer: deleteServer,
          showDeleteServer: ownerDeletes,
          onDone: () => run(() async {
            final generation = w.client.generation, scope = authority;
            final result = await w.client.post('$base/setup-handoff');
            if (accepts(generation) && scope == authority) {
              projection = managementMap(result);
            }
          }),
        ),
      );
    }
    return stepPage(computerStep(current));
  }

  /// packages/shared `getSetupRuntimeOptions()` (supported, not deprecated,
  /// not the built-in; Copilot CLI is deprecated since Web v1.21.12): id,
  /// display name, abbreviation.
  static const _setupRuntimes = <(String, String, String)>[
    ('claude', 'Claude Code', 'CC'),
    ('codex', 'Codex CLI', 'CX'),
    ('grok', 'Grok Build', 'GK'),
    ('kimi-sdk', 'Kimi Code', 'KC'),
    ('cursor', 'Cursor CLI', 'CU'),
    ('opencode', 'OpenCode', 'OC'),
    ('pi', 'Pi', 'PI'),
  ];

  /// ServerSetupComputerRuntimeStep fed by the server's projection (the
  /// verdicts) and the machine list (the computer being connected).
  Widget computerStep(Map<String, dynamic> current) {
    final options = managementRows(current['runtimeOptions']);
    final byId = {for (final o in options) '${o['runtimeId']}': o};
    RaftSetupRuntime entry((String, String, String) r) => RaftSetupRuntime(
      id: r.$1,
      displayName: r.$2,
      abbreviation: r.$3,
      detected: byId[r.$1]?['capabilityStatus'] == 'available',
      recommended: r.$1 == 'claude' || r.$1 == 'codex',
    );
    final visible = [
      for (final r in _setupRuntimes)
        if (byId.containsKey(r.$1)) r,
    ];
    final recommended = [
      for (final r in visible)
        if (r.$1 == 'claude' || r.$1 == 'codex') entry(r),
    ];
    final supported = [
      for (final r in visible)
        if (r.$1 != 'claude' && r.$1 != 'codex') entry(r),
    ]..sort((a, b) => a.displayName.compareTo(b.displayName));
    final detectedNames = [
      for (final r in _setupRuntimes)
        if (byId[r.$1]?['capabilityStatus'] == 'available') r.$2,
    ];
    final status = '${current['runtimeStatus'] ?? 'unknown'}';
    final ready = status == 'ready_recommended' || status == 'ready_other';
    final machines = setupMachines ?? const <Map<String, dynamic>>[];
    final computers = [
      for (final m in machines)
        if (m['isComputer'] != false) m,
    ];
    final computer =
        computers.where((m) => m['status'] == 'online').firstOrNull ??
        computers.firstOrNull;
    final online = computer != null
        ? computer['status'] == 'online'
        : current['computerStatus'] == 'online';
    final offline = managementRows(current['offlineComputers']);
    final recovering = !online && current['hasConnectedComputer'] == true;
    final rows = offline.isNotEmpty
        ? offline
        : [
            if (computer != null)
              {
                'name': computer['name'],
                'lastHeartbeat': null,
                'isComputer': computer['isComputer'],
              },
          ];
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final commands = ComputerSetupCommands.build(
      slug: w.server?.string('slug') ?? '',
      serverUrl: w.client.origin,
      windows: windowsCommands,
    );
    return RaftSetupComputerCard(
      key: const ValueKey('setup-computer'),
      computerName: computer == null ? null : '${computer['name']}',
      computerOnline: online,
      waiting: computer != null && !online,
      runtimeReady: ready,
      runtimeNames: detectedNames,
      runtimeAnswered: status == 'not_ready' || status == 'error',
      recommendedRuntimes: recommended,
      supportedRuntimes: supported,
      offlineComputers: [
        for (final m in rows)
          RaftSetupOfflineComputer(
            '${m['name']}',
            lastSeen: m['lastHeartbeat'] == null
                ? null
                : resourceRelativeTime(
                    '${m['lastHeartbeat']}',
                    now: widget.now?.call(),
                    chinese: chinese,
                  ),
          ),
      ],
      recovering: recovering,
      legacyDaemon: rows.any((m) => m['isComputer'] == false),
      guidePlatform: windowsCommands ? 'windows' : 'mac-linux',
      onGuidePlatform: (v) => setState(() => windowsCommands = v == 'windows'),
      guideCommands: commands == null
          ? null
          : (commands.install, commands.setup),
      guideInstallAndSetup: commands?.installAndSetup,
      serverSlug: w.server?.string('slug'),
      canReset: managementStrings(current['allowedExits']).contains('reset'),
      loading: busy,
      error: error ?? setupMachinesError,
      onStartOver: reset,
      onNext: () {
        if (current['phase'] == 'not_started' &&
            managementMap(current['sideEffectState'])['transitions'] ==
                'enabled') {
          transition('start');
        } else {
          run(() async {});
        }
      },
      onSwitchServer: busy ? null : widget.onSwitchServer,
      onDeleteServer: deleteServer,
      showDeleteServer: ownerDeletes,
      onCopyInstallCommand: (id, command) =>
          Clipboard.setData(ClipboardData(text: command)),
    );
  }
}
