// Agent detail panel, rebuilt from Web
// packages/web/src/features/agent/AgentDetailPanel.tsx (v1.24.0; the status
// chip and the runtime error banner follow it, other tabs are being ported): PanelHeader
// (back, avatar, name, overflow actions), the scrollable tab strip
// (Profile / Activity / Chat / Reminders / Workspace / Apps / MCP) and each
// tab's content. FleetDetail keeps the data loading, authority fencing and
// lifecycle commands and hands them to this view.
import 'dart:async';
import 'dart:convert' show base64Decode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/agent_hosted_runtime.dart';
import '../data/runtime_config.dart';
import '../data/source_time_formatter.dart';
import '../data/runtime_error.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'agent_archive_requests.dart';
import 'agent_activity_pane.dart';
import 'agent_recent_activity.dart';
import 'agent_apps_view.dart';
import 'agent_diagnostic_info.dart';
import 'feedback_attachment_preview.dart' show showFeedbackImage;
import 'agent_archive_section.dart';
import 'agent_connections_section.dart';
import 'agent_hosted_model.dart';
import 'agent_lounge_button.dart';
import 'agent_identity_adoption.dart';
import 'agent_hosted_usage.dart';
import 'agent_migration_section.dart';
import 'agent_chat_peer.dart';
import 'agent_computer_offline_card.dart';
import 'agent_profile_rules.dart';
import 'agent_task_open.dart';
import 'agent_skills_section.dart';
export 'agent_skills_section.dart' show AgentSkillsSection;
import 'external_agent_setup.dart';
import 'channel_form_fields.dart' show ChannelCandidateAvatar;
import 'create_channel_dialog.dart' show ChannelMemberCandidate;
import 'agent_raw_log.dart' show agentCachedActivityEntries;
export 'agent_raw_log.dart' show AgentActivityTab, agentCachedActivityEntries;
import 'runtime_usage_chip.dart';
import 'agent_runtime_catalog.dart' show reasoningEfforts, runtimeInfos;
import 'agent_model_limits_warning.dart';
import 'agent_runtime_models.dart' show runtimeModelLabel;
import 'agent_runtime_labels.dart'
    show RuntimeDeprecatedHereState, runtimeLabelWithStatus;
import 'agent_metadata_projection.dart';
import 'agent_runtime_error_banner_view.dart';
import 'agent_runtime_error_state.dart';
import 'agent_status_chip_view.dart';
import 'agent_status_state.dart';
import 'agent_tool_stuck_notice.dart';
import 'model_label_catalog.dart';
import 'model_label_listener.dart';
import 'mcp_views.dart';
import 'panel_width_store.dart';
import 'agent_avatar_dialog.dart' show agentProfileAvatarUrl;
import 'resource_cards.dart' show resourceRelativeTime;

/// ProfilePanel.tsx:349–401: immediately usable blank header and loading
/// body until a real accepted profile exists. No avatar, status, tabs or facts.
class SourceProfileLoadingPanel extends StatelessWidget {
  const SourceProfileLoadingPanel({
    super.key,
    this.onBack,
    this.onClose,
    this.error,
    this.onRetry,
  });
  final VoidCallback? onBack, onClose, onRetry;
  final String? error;
  @override
  Widget build(BuildContext context) => RaftPanelTextScope(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftPanelHeaderBar(
          useHostChrome: true,
          title: '',
          onBack: onBack,
          backTooltip: raftText(context, 'Back'),
          actions: [
            if (onClose != null)
              RaftPanelIconButton(
                glyph: RaftGlyph.x,
                tooltip: raftText(context, 'Close Profile'),
                onPressed: onClose,
              ),
          ],
        ),
        Expanded(
          child: error == null
              ? RaftPanelMessage(raftText(context, 'Loading profile…'))
              // Web page-level load failure: message + outline Retry.
              : RaftLoadError('Profile could not be loaded.', onRetry: onRetry),
        ),
      ],
    ),
  );
}

/// AgentWorkspace `formatSize`.
String workspaceFileSize(int bytes) => bytes < 1024
    ? '$bytes B'
    : bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(1)} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

enum AgentDetailTab { profile, activity, chat, reminders, workspace, apps, mcp }

/// Lifecycle and edit commands owned by FleetDetail.
class AgentDetailActions {
  const AgentDetailActions({
    this.onBack,
    this.onClose,
    this.backAlways = false,
    this.onEditName,
    this.onEditDescription,
    this.onEditRole,
    this.onEditAvatar,
    this.onEditRuntime,
    this.onStartStop,
    this.onRestartReset,
    this.onStopHostedTurn,
    this.onDelete,
    this.canArchive = false,
    this.onOpenComputer,
    this.onOpenCreator,
    this.onOpenChannel,
    this.onOpenMessage,
    this.onMessage,
    this.canMigrate = false,
    this.canShowCloudArrival = false,
    this.onPermissions,
    this.onReportIssue,
  });

  /// Keep the Back chevron at md+ (`backButtonVisibility="always"`).
  final bool backAlways;

  /// The viewer may archive the agent and delete an archived agent's
  /// workspace (Web `canArchiveAgent`: deleteAgents or the human creator).
  final bool canArchive;

  /// Mount the Agent migration section (Web `AgentMigrationSection`: the
  /// viewer manages a non-external agent that has a computer).
  final bool canMigrate;

  /// A cloud agent the viewer manages: mount the migration section to show the
  /// end of the move that brought it to the cloud (Web `arrivalOnly`).
  final bool canShowCloudArrival;

  /// Info rows: the Computer name opens that Computer; the creator opens
  /// their profile (`human` or `agent`).
  final ValueChanged<String>? onOpenComputer, onOpenChannel;
  final void Function(String type, String id)? onOpenCreator;

  /// A reminder's message permalink: jump back to that message.
  final ValueChanged<String>? onOpenMessage;
  final VoidCallback? onBack,
      onClose,
      onEditName,
      onEditDescription,
      onEditRole,
      onEditAvatar,
      onEditRuntime,
      onStartStop,
      onRestartReset,
      /// Stop the running turn (the agent stays): the link of the tool-stuck
      /// notice under the status chip (Web `canStopThisTurn`). Null hides it.
      onStopHostedTurn,
      onDelete,
      onMessage,
      onPermissions,
      /// Report Issue (offered only when the build names a feedback export
      /// worker, Web `FEEDBACK_EXPORT_ENABLED`).
      onReportIssue;
}

/// Shared runtime catalog (packages/shared/src/runtimeCatalog.ts RUNTIMES).
const sourceRuntimeDisplayNames = <String, String>{
  'claude': 'Claude Code',
  'codex': 'Codex CLI',
  'grok': 'Grok Build',
  'builtin': 'Built-in Pi',
  'antigravity': 'Antigravity CLI',
  'kimi-sdk': 'Kimi Code',
  'kimi': 'Kimi CLI',
  'copilot': 'Copilot CLI',
  'cursor': 'Cursor CLI',
  'gemini': 'Gemini CLI',
  'opencode': 'OpenCode',
  'pi': 'Pi',
};

/// Web `reasoningEffortLabelId`: the ladder label, else Default.
String _reasoningEffortLabel(String? effort) =>
    reasoningEfforts.where((e) => e.$1 == effort).firstOrNull?.$2 ?? 'Default';

class AgentDetailPanel extends StatefulWidget {
  const AgentDetailPanel({
    super.key,
    required this.controller,
    required this.agent,
    required this.machines,
    required this.actions,
    this.liveActivity,
    this.initialTrajectoryLog = const [],
    this.initialTab = AgentDetailTab.profile,
    this.canManage = false,
    this.canViewPrivate = false,
    this.canControlRuntime = false,
    this.canStopAgent,
    this.busy = false,
    this.error,
    this.onDismissError,
    this.clock,
  });
  final WorkspaceController controller;
  final Map<String, dynamic> agent;

  /// null while GET /servers/:id/machines is in flight.
  final List<Map<String, dynamic>>? machines;
  final AgentDetailActions actions;

  /// Latest `agent:activity` socket projection ({activity, detail}).
  final Map<String, dynamic>? liveActivity;

  /// Already admitted session trajectory; distinct from the REST response.
  final List<Map<String, dynamic>> initialTrajectoryLog;
  final AgentDetailTab initialTab;
  final bool canManage, canViewPrivate, canControlRuntime, busy;

  /// Web `canStopAgent`: Stop Agent on top of runtime control (`stopAgents` or
  /// the creator). Null follows [canControlRuntime].
  final bool? canStopAgent;
  final String? error;

  /// The `startError` strip's dismiss `X`.
  final VoidCallback? onDismissError;
  final DateTime Function()? clock;
  @override
  State<AgentDetailPanel> createState() => _AgentDetailPanelState();
}

SourceTimeFormatter agentTimeFormatter(
  BuildContext context,
  WorkspaceController w,
) => SourceTimeFormatter(
  locale: Localizations.localeOf(context).toLanguageTag(),
  preferredTimezone:
      w.client.user?.string('preferredTimezone') ??
      w.client.user?.string('timezone'),
  preferredTimeFormat: sourceTimeFormatPreference(
    w.client.user?.string('preferredTimeFormat') ??
        w.client.user?.string('timeFormat'),
  ),
  systemTimeFormat: MediaQuery.alwaysUse24HourFormatOf(context)
      ? SourceTimeFormat.twentyFourHour
      : null,
);

class _AgentDetailPanelState extends State<AgentDetailPanel>
    with
        ModelLabelCatalogListener<AgentDetailPanel>,
        RuntimeDeprecatedHereState<AgentDetailPanel>,
        AgentLoungeListener<AgentDetailPanel> {
  @override
  WorkspaceController get runtimeCatalogWorkspace => widget.controller;

  @override
  WorkspaceController get loungeWorkspace => widget.controller;

  @override
  WorkspaceController? get modelLabelWorkspace =>
      _bounded ? null : widget.controller;
  late AgentDetailTab tab = widget.initialTab;

  Map<String, dynamic> get a => widget.agent;
  String get displayName => agentRowName(a);
  bool get external => a['external'] == true || a['runtime'] == 'external';

  /// Web `externalStatus?.hostedRuntime ?? agent.hostedRuntime`: the hosted
  /// provisioning summary, present for callers who can manage the agent.
  Map? get _hostedRuntime {
    final fromStatus = externalStatus?['hostedRuntime'];
    final value = fromStatus is Map ? fromStatus : a['hostedRuntime'];
    return value is Map ? value : null;
  }

  AgentAmbientDisplay get _display => agentRowAmbientDisplay(
    a,
    live: widget.liveActivity,
    now: (widget.clock ?? DateTime.now)(),
  );
  String get activity => _display.activity;
  bool get online => activity != 'offline';

  /// Another server's agent, or a channel_summary card, stays on the public
  /// profile. Caller flags are the current server's capabilities; they do not
  /// apply to that projection.
  bool get _bounded => isBoundedPublicAgent(a, widget.controller.server?.id);
  bool get _canManage => widget.canManage && !_bounded;
  bool get _canViewPrivate => widget.canViewPrivate && !_bounded;
  bool get _canControlRuntime => widget.canControlRuntime && !_bounded;

  /// Web `agentRuntimeControls` for this agent: no Start or Restart / Reset
  /// while its Computer is offline, Stop stays unless a person stopped it.
  ({bool start, bool stop, bool restartReset}) get _controls =>
      agentRuntimeControls(
        canControl: _canControlRuntime && !external,
        canStop: widget.canStopAgent ?? widget.canControlRuntime,
        isOnline: online,
        computerOffline: isAgentComputerOffline(a, widget.machines),
        stoppedByPerson: a['status'] == 'stopped',
      );
  bool get _canMessage => !_bounded && widget.actions.onMessage != null;

  /// AGENT_PANEL_TABS filtered by visibility, then ordered like raft-ui
  /// `reconcileTabOrder`: the server's `agentPanelTabOrder` first (`channels` /
  /// `dms` are the legacy ids of Chat, `integrations` of Apps), the rest in
  /// their default order.
  List<AgentDetailTab> get tabs {
    // An archived agent keeps its profile and a read-only workspace.
    final archived = a['deletedAt'] != null;
    final visible = archived
        ? [
            AgentDetailTab.profile,
            if (_canViewPrivate) AgentDetailTab.workspace,
          ]
        : [
            AgentDetailTab.profile,
            if (_canViewPrivate) ...[
              AgentDetailTab.activity,
              AgentDetailTab.chat,
              AgentDetailTab.reminders,
              AgentDetailTab.workspace,
              AgentDetailTab.apps,
            ],
            if (_canManage) AgentDetailTab.mcp,
          ];
    final stored = widget.controller.sidebarOrder['agentPanelTabOrder'];
    final ordered = <AgentDetailTab>[];
    for (final raw in stored is List ? stored : const []) {
      final id = switch (raw) {
        'channels' || 'dms' => AgentDetailTab.chat,
        'integrations' => AgentDetailTab.apps,
        _ => AgentDetailTab.values.where((t) => t.name == raw).firstOrNull,
      };
      if (id != null && visible.contains(id) && !ordered.contains(id)) {
        ordered.add(id);
      }
    }
    return [
      ...ordered,
      for (final id in visible)
        if (!ordered.contains(id)) id,
    ];
  }

  bool diagnosticCopied = false;
  Timer? diagnosticTimer;

  /// Web `useArchivedAgentMachineName`: the Computer an archived agent last
  /// ran on (its archive record); advisory, any failure keeps the plain
  /// "No computer assigned".
  String? archivedMachine;
  String? archivedMachineFor;

  Future<void> loadArchivedMachine() async {
    final id = '${a['id']}';
    if (a['deletedAt'] == null || _bounded || archivedMachineFor == id) return;
    archivedMachineFor = id;
    try {
      final archive = await fetchAgentArchive(widget.controller, id);
      if (!mounted || archivedMachineFor != id) return;
      setState(() => archivedMachine = archive?.machineName);
    } catch (_) {}
  }

  /// GET /agents/:id/external-status (external agents): the setup state the
  /// presence line and the External setup block share.
  Map<String, dynamic>? externalStatus;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when a status read succeeds and on an agent change (didUpdateWidget); stale reads are fenced by externalStatusFor.
  String? externalStatusError;
  String? externalStatusFor;

  @override
  void initState() {
    super.initState();
    _adoptCachedExternalStatus();
    unawaited(loadExternalStatus());
    unawaited(loadArchivedMachine());
    unawaited(loadExternalDiagnostics());
  }

  /// A revisit shows the last accepted setup state at its first frame (the
  /// presence line and the setup block do not change when the read lands).
  void _adoptCachedExternalStatus() {
    if (!external) return;
    final cached = widget.controller.agentTabCache.peek(
      'external-status/${a['id']}',
    );
    if (cached is Map<String, dynamic>) externalStatus = cached;
  }

  @override
  void didUpdateWidget(AgentDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.agent['id'] != a['id'] ||
        oldWidget.agent['runtime'] != a['runtime'] ||
        oldWidget.agent['external'] != a['external']) {
      if (oldWidget.agent['id'] != a['id']) {
        // The status, its failure and the in-flight read belong to the
        // previous agent.
        externalStatus = null;
        externalStatusError = null;
        externalStatusFor = null;
        archivedMachine = null;
        archivedMachineFor = null;
        externalDiagnostics = null;
        externalDiagnosticsFor = null;
        _adoptCachedExternalStatus();
      }
      unawaited(loadExternalStatus());
    }
    unawaited(loadArchivedMachine());
    unawaited(loadExternalDiagnostics());
  }

  /// A fresher external status from the cloud agent's status panel (its poll
  /// while the provider works, the read after Retry).
  void adoptExternalStatus(Map<String, dynamic> status) {
    widget.controller.agentTabCache.put('external-status/${a['id']}', status);
    setState(() {
      externalStatus = status;
      externalStatusError = null;
    });
  }

  Future<void> loadExternalStatus() async {
    final id = '${a['id']}';
    if (!external || _bounded || externalStatusFor == id) return;
    externalStatusFor = id;
    try {
      final status = await widget.controller.client.get(
        '/agents/$id/external-status',
      );
      if (!mounted || externalStatusFor != id) return;
      if (status is Map) {
        final accepted = Map<String, dynamic>.from(status);
        widget.controller.agentTabCache.put('external-status/$id', accepted);
        setState(() {
          externalStatus = accepted;
          externalStatusError = null;
        });
      }
    } catch (e) {
      if (!mounted || externalStatusFor != id) return;
      setState(
        () => externalStatusError = userErrorText(
          e,
          fallback: 'Failed to load external setup status',
          where: 'agent external status',
        ),
      );
    }
  }

  @override
  void dispose() {
    diagnosticTimer?.cancel();
    _errorCopiedTimer?.cancel();
    super.dispose();
  }

  /// External agents: `GET /agents/:id/external-diagnostics`, keyed by agent
  /// (a switch never shows the previous agent's facts). Null while loading or
  /// when the read failed; the text then says "unavailable".
  Map<String, dynamic>? externalDiagnostics;
  String? externalDiagnosticsFor;

  Future<void> loadExternalDiagnostics() async {
    final id = '${a['id']}';
    if (!external || _bounded || !_canViewPrivate || a['deletedAt'] != null) {
      return;
    }
    if (externalDiagnosticsFor == id) return;
    externalDiagnosticsFor = id;
    try {
      final view = admittedExternalDiagnostics(
        await widget.controller.query('/agents/$id/external-diagnostics'),
      );
      if (!mounted || externalDiagnosticsFor != id) return;
      setState(() => externalDiagnostics = view);
    } catch (_) {
      // A failed read counts as unavailable.
    }
  }

  /// `buildAgentDiagnosticInfo`: managed agents carry their identity, runtime,
  /// Computer and live state; external agents the external diagnostics.
  String get diagnosticInfo {
    final id = '${a['id']}';
    final log = agentCachedActivityEntries(widget.controller, id);
    final stamp = log.isEmpty ? null : log.last['timestamp'];
    final display = _display;
    return buildAgentDiagnosticInfo(
      agent: a,
      title: raftText(context, 'Raft diagnostic info'),
      serverId: widget.controller.server?.id,
      machine: machine,
      activity: display.activity,
      detailKind: display.detailKind,
      activityDetail: display.detail,
      lastActivityAtMs: stamp is num ? stamp.toInt() : null,
      errorMessage: _canViewPrivate ? runtimeErrorDiagnostic : null,
      externalDiagnostics: externalDiagnostics,
    );
  }

  /// The raw diagnostic kept for the copy text even when the banner shows the
  /// classified catalog message (Web `diagnosticErrorMessage`).
  String? get runtimeErrorDiagnostic {
    final display = _display;
    if (display.activity != 'error' && a['lastRuntimeError'] == null) {
      return null;
    }
    final raw = display.activity == 'error'
        ? display.detail
        : '${(a['lastRuntimeError'] as Map?)?['message'] ?? ''}';
    final typed = a['lastRuntimeError'];
    if (typed is Map &&
        typed['errorClass'] != null &&
        typed['errorReason'] != null) {
      return [
        raw,
        'class=${typed['errorClass']} reason=${typed['errorReason']} fingerprint=${typed['fingerprint']}',
      ].where((line) => line.isNotEmpty).join('\n');
    }
    return raw;
  }

  Future<void> copyDiagnosticInfo() async {
    await Clipboard.setData(ClipboardData(text: diagnosticInfo));
    if (!mounted) return;
    setState(() => diagnosticCopied = true);
    diagnosticTimer?.cancel();
    diagnosticTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => diagnosticCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!canRenderWorkspaceAgent(a, widget.controller.server?.id)) {
      return SourceProfileLoadingPanel(
        onBack: widget.actions.onBack,
        error: widget.error,
      );
    }
    final visible = tabs;
    final current = visible.contains(tab) ? tab : AgentDetailTab.profile;
    final controls = _controls;
    final menu = <RaftMenuEntry>[
      ?(_bounded ? null : agentLoungeMenuEntry(context, widget.controller, a)),
      if (controls.start || controls.stop)
        RaftMenuEntry(
          label: raftText(
            context,
            controls.stop ? 'Stop agent' : 'Start agent',
          ),
          glyph: controls.stop ? RaftGlyph.square : RaftGlyph.play,
          onPressed: widget.actions.onStartStop,
        ),
      if (controls.restartReset)
        RaftMenuEntry(
          label: raftText(context, 'Restart / reset'),
          glyph: RaftGlyph.rotateCcw,
          onPressed: widget.actions.onRestartReset,
        ),
    ];
    return LayoutBuilder(
      builder: (context, box) =>
          _panel(context, current, visible, menu, box.maxWidth),
    );
  }

  Widget _panel(
    BuildContext context,
    AgentDetailTab current,
    List<AgentDetailTab> visible,
    List<RaftMenuEntry> menu,
    double panelWidth,
  ) {
    final chrome = RaftPanelHeaderChrome.maybeOf(context);
    final moves = chrome?.moves ?? const [];
    final showMessage = a['deletedAt'] == null && _canMessage;
    final inlineCommands = a['deletedAt'] == null && panelWidth > 480;
    final hasClose =
        widget.actions.onClose != null &&
        MediaQuery.sizeOf(context).width >= 768;
    final foldMessage =
        showMessage &&
        (chrome?.foldsProfileMessage(
              context,
              width: panelWidth,
              hasClose: hasClose,
              hasMenu: menu.isNotEmpty || moves.isNotEmpty,
            ) ??
            false);
    final overflow = [
      if (foldMessage)
        RaftMenuEntry(
          label: raftText(context, 'Direct message'),
          leading: const RaftDirectMessageIcon(size: 18),
          onPressed: widget.actions.onMessage,
        ),
      if (a['deletedAt'] == null && !inlineCommands) ...menu,
      ...moves,
    ];
    return RaftPanelTextScope(
      sans: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftPanelHeaderBar(
            title: displayName,
            useHostChrome: true,
            handlesHostMoves: true,
            // Web v1.21.12: the `@handle` subtitle.
            subtitle: '@${a['name'] ?? ''}',
            profileHandle: true,
            profileBody: true,
            iconAlwaysVisible: true,
            // `useMobileBack` renders the chevron below `md` only.
            onBack:
                MediaQuery.sizeOf(context).width >= 768 &&
                    !widget.actions.backAlways
                ? null
                : widget.actions.onBack,
            backTooltip: raftText(context, 'Back'),
            iconSlot: (chrome?.showsProfileAvatar(panelWidth) ?? true)
                ? RaftAvatarSlot(
                    name: displayName,
                    avatarUrl: agentProfileAvatarUrl(
                      widget.controller.client.origin,
                      a['avatarUrl'] as String?,
                    ),
                    slot: RaftAvatarSlotContext.panelHeader,
                  )
                : null,
            actions: [
              if (showMessage && !foldMessage)
                RaftPanelIconButton(
                  key: const Key('agent-profile-message'),
                  icon: (size, color) =>
                      RaftDirectMessageIcon(size: size, color: color),
                  tooltip: raftText(context, 'Direct message'),
                  onPressed: widget.actions.onMessage,
                ),
              if (inlineCommands && menu.isNotEmpty) ..._inlineActions(context),
              if (overflow.isNotEmpty)
                RaftOverflowMenuButton(
                  key: const Key('agent-profile-overflow-trigger'),
                  entries: overflow,
                  tooltip: raftText(context, 'More Actions'),
                ),
              // AgentDetailHeader `onClose` (`hidden md:flex`): the profile
              // overlay's close action once the back chevron is gone.
              if (hasClose)
                RaftPanelIconButton(
                  glyph: RaftGlyph.x,
                  tooltip: raftText(context, 'Close Profile'),
                  onPressed: widget.actions.onClose,
                ),
            ],
          ),
          // Web `startError` strip: between the header and the tab bar.
          if (widget.error != null)
            RaftPanelErrorStrip(
              widget.error!,
              onDismiss: widget.onDismissError,
            ),
          ?_runtimeErrorBanner(context, current),
          RaftPanelTabBar<AgentDetailTab>(
            tabs: [for (final id in visible) _tabSpec(context, id)],
            value: current,
            onChanged: (v) => setState(() => tab = v),
            // Web `SortableTabsList`: the new order of the visible tabs is the
            // server's `agentPanelTabOrder`.
            onReorder: (order) {
              unawaited(
                widget.controller.updateSidebarOrder({
                  // Web's id of the Apps tab is `integrations`.
                  'agentPanelTabOrder': [
                    for (final id in order)
                      id == AgentDetailTab.apps ? 'integrations' : id.name,
                  ],
                }),
              );
              // The order applies at once (the PATCH follows).
              setState(() {});
            },
          ),
          Expanded(
            child: RaftSectionPager<AgentDetailTab>(
              key: ValueKey((
                widget.controller.client.origin,
                widget.controller.client.generation,
                widget.controller.client.user?.id,
                widget.controller.server?.id,
                widget.controller.server?.string('role'),
                a['id'],
              )),
              sections: visible,
              value: current,
              onChanged: (value) => setState(() => tab = value),
              swipeEnabled: RaftInteraction.of(context).touch,
              builder: _content,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _inlineActions(BuildContext context) => [
    ?(_bounded ? null : agentLoungeInlineAction(context, widget.controller, a)),
    if (_controls.start || _controls.stop)
      RaftPanelIconButton(
        key: const Key('agent-profile-inline-start-stop'),
        glyph: _controls.stop ? RaftGlyph.square : RaftGlyph.play,
        tooltip: raftText(
          context,
          _controls.stop ? 'Stop agent' : 'Start agent',
        ),
        onPressed: widget.actions.onStartStop,
      ),
    if (_controls.restartReset)
      RaftPanelIconButton(
        key: const Key('agent-profile-inline-restart-reset'),
        glyph: RaftGlyph.rotateCcw,
        tooltip: raftText(context, 'Restart / reset'),
        onPressed: widget.actions.onRestartReset,
      ),
  ];

  RaftPanelTab<AgentDetailTab> _tabSpec(
    BuildContext context,
    AgentDetailTab id,
  ) => switch (id) {
    AgentDetailTab.profile => RaftPanelTab(
      id,
      raftText(context, 'Profile'),
      RaftGlyph.bot,
    ),
    AgentDetailTab.activity => RaftPanelTab(
      id,
      raftText(context, 'Activity'),
      RaftGlyph.activity,
    ),
    // raft-ui ChatIcon: a speech bubble with three dots.
    AgentDetailTab.chat => RaftPanelTab.custom(
      id,
      raftText(context, 'Chat'),
      iconBuilder: (size, color, strokeWidth) =>
          RaftChatIcon(size: size, color: color, strokeWidth: strokeWidth),
    ),
    AgentDetailTab.reminders => RaftPanelTab(
      id,
      raftText(context, 'Reminders'),
      RaftGlyph.bellRing,
    ),
    AgentDetailTab.workspace => RaftPanelTab(
      id,
      raftText(context, 'Workspace'),
      RaftGlyph.folderOpen,
    ),
    AgentDetailTab.apps => RaftPanelTab(
      id,
      raftText(context, 'Apps'),
      RaftGlyph.link2,
    ),
    AgentDetailTab.mcp => RaftPanelTab(
      id,
      raftText(context, 'MCP'),
      RaftGlyph.blocks,
    ),
  };

  Widget _content(BuildContext context, AgentDetailTab id) {
    final w = widget.controller;
    final agentId = a['id'] as String;
    return switch (id) {
      AgentDetailTab.profile => _profile(context),
      AgentDetailTab.activity => AgentActivityPane(
        key: ValueKey('agent-activity-pane-$agentId'),
        controller: w,
        agentId: agentId,
        machineId: a['machineId'] as String?,
        activity: _display.activity,
        activityText: _statusText(context),
        initialEntries: widget.initialTrajectoryLog,
        onOpenComputer: widget.actions.onOpenComputer,
        onOpenTask: (channelId, number) =>
            openAgentActivityTask(context, w, channelId, number),
        canStopSubagents: canStopSubagentsOf(
          agent: a,
          controlAgentRuntime: _canControlRuntime,
        ),
      ),
      AgentDetailTab.chat => AgentChatTab(
        key: ValueKey('agent-chat-$agentId'),
        controller: w,
        agentId: agentId,
        clock: widget.clock,
        onOpenChannel: widget.actions.onOpenChannel,
      ),
      AgentDetailTab.reminders => AgentRemindersTab(
        key: ValueKey('agent-reminders-$agentId'),
        controller: w,
        agentId: agentId,
        clock: widget.clock,
        onOpenMessage: widget.actions.onOpenMessage,
      ),
      AgentDetailTab.workspace => AgentWorkspaceTab(
        key: ValueKey('agent-workspace-$agentId'),
        controller: w,
        agentId: agentId,
        hosted: external,
      ),
      AgentDetailTab.apps => AgentAppAccessView(
        controller: w,
        agentId: agentId,
      ),
      AgentDetailTab.mcp => AgentMcpView(controller: w, agentId: agentId),
    };
  }

  // ------------------------------------------------------------- profile

  Map<String, dynamic>? get machine {
    final id = a['machineId'];
    if (id is! String) return null;
    return widget.machines?.where((m) => m['id'] == id).firstOrNull;
  }

  /// components/machine MachineRunLabel descriptor.
  String runLabel(Map<String, dynamic> m, BuildContext context) {
    // Web v1.24 AgentProfileInfo.tsx:125-130: the version only (a legacy
    // daemon's too, no "legacy" word); offline or unknown is a dash.
    final v = m['status'] != 'online'
        ? null
        : m['isComputer'] == true
        ? m['computerVersion']
        : m['daemonVersion'];
    return v == null ? '—' : 'v$v';
  }

  /// Web v1.24 AgentProfileInfo.tsx:658-660: the role is plain text.
  Widget _roleValue(BuildContext context, ({String label, bool known}) chip) {
    final text = chip.known
        ? raftText(context, chip.label == 'admin' ? 'Admin' : 'Member')
        : chip.label;
    return RaftCssText(text);
  }

  String createdDate(BuildContext context) {
    final raw = a['createdAt'];
    final date = raw is String ? DateTime.tryParse(raw) : null;
    if (date == null) return '';
    return DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
        .format(agentTimeFormatter(context, widget.controller).wallTime(date));
  }

  /// EXTERNAL_AGENT_ONLINE_WINDOW_MS (store/presenceClock.ts).
  static const _externalOnlineWindow = Duration(milliseconds: 120000);

  /// An external agent's presence (Web `useAgentDisplayState().isOnline`): its
  /// credential seen within the online window; an explicit offline (the agent
  /// declared it stopped) shows at once.
  bool get _externalOnline {
    final seen = a['lastSeenAt'] is String
        ? DateTime.tryParse(a['lastSeenAt'] as String)
        : null;
    final now = (widget.clock ?? DateTime.now)();
    final seenOnline =
        seen != null && now.difference(seen) < _externalOnlineWindow;
    final hasState = agentHasActivityState(a, live: widget.liveActivity);
    return seenOnline && !(hasState && _display.activity == 'offline');
  }

  /// Web v1.24 `AgentStatusBadge` (features/agent/AgentStatusBadge.tsx): the
  /// profile header's chip. An external agent reads its presence (the
  /// credential seen within the online window) and managers its setup state;
  /// while it is seen with a non-idle activity the chip reads like a managed
  /// agent's. A managed agent's chain is agent_status_state.dart.
  AgentStatusChip _statusChip(BuildContext context) {
    final display = _display;
    final hasState = agentHasActivityState(a, live: widget.liveActivity);
    if (external) {
      final seen = a['lastSeenAt'] is String
          ? DateTime.tryParse(a['lastSeenAt'] as String)
          : null;
      final now = (widget.clock ?? DateTime.now)();
      final seenOnline =
          seen != null && now.difference(seen) < _externalOnlineWindow;
      final shown =
          seenOnline &&
          hasState &&
          display.activity != 'online' &&
          display.activity != 'offline';
      if (!shown) {
        // An explicit offline (the agent declared it stopped) shows at once.
        final online =
            seenOnline && !(hasState && display.activity == 'offline');
        final chinese = Localizations.localeOf(context).languageCode == 'zh';
        return resolveExternalStatusChip(
          online: online,
          showDetail: _canViewPrivate,
          setupState: externalStatus?['setupState'] as String?,
          hasStatus: externalStatus != null,
          lastSeenRelative: !online && seen != null
              ? resourceRelativeTime(
                  a['lastSeenAt'] as String,
                  now: now,
                  chinese: chinese,
                )
              : null,
          name: displayName,
        );
      }
    }
    final deleted = a['deletedAt'] != null;
    final machineOffline = machine?['status'] == 'offline';
    final runtime = '${a['runtime'] ?? ''}';
    return resolveAgentStatusChip(
      AgentStatusInput(
        row: a,
        activity: display.activity,
        detailKind: display.detailKind,
        detail: display.detail,
        hasActivityState: hasState,
        machineOffline: machineOffline,
        showDetail: _canViewPrivate,
        // The menu's Restart: whoever may control the runtime, not while the
        // Computer is offline (a restart cannot reach it).
        canRestart:
            restartResetOffered(_canControlRuntime, machineOffline) && !deleted,
        canOpenModelSettings:
            _canManage &&
            !deleted &&
            !external &&
            widget.actions.onEditRuntime != null,
        runtimeName: sourceRuntimeDisplayNames[runtime] ?? runtime,
        modelLabel: (model) => runtimeModelLabel(runtime, model),
        errorCode: agentActivityErrorCode(
          a,
          live: widget.liveActivity,
          activity: display.activity,
        ),
        spawnFailure:
            _canViewPrivate && display.detailKind == 'runtime_unavailable'
            ? agentRowSpawnFailure(a)
            : null,
        spawnFailureText: _spawnFailureText(context),
        readiness: a['readiness'] is Map ? a['readiness'] as Map : null,
      ),
    );
  }

  /// A failed start's typed reason standing in for the daemon's detail (Web
  /// `formatSpawnFailureDetail`), for viewers who see details.
  String? _spawnFailureText(BuildContext context) {
    final display = _display;
    if (!_canViewPrivate || display.detailKind != 'runtime_unavailable') {
      return null;
    }
    final formatter = agentTimeFormatter(context, widget.controller);
    final now = (widget.clock ?? DateTime.now)();
    return spawnFailureDetailText(
      agentRowSpawnFailure(a),
      display.detail,
      (source, values) => raftFormat(context, source, values),
      retryTime: (atMs) => agentPauseRetryTime(formatter, atMs, now),
    );
  }

  /// Retry: the menu's Restart (`POST /agents/:id/reset {mode: restart}`).
  Future<void> _retryStart() => widget.controller.command(
    'POST',
    '/agents/${a['id']}/reset',
    data: const {'mode': 'restart'},
  );

  /// An Info value that navigates: a hover-underlined button with the full
  /// text as its tooltip, or the plain value when nothing can open it.
  Widget _profileLink({
    required Key key,
    required VoidCallback? onPressed,
    required String tooltip,
    required Widget child,
  }) => onPressed == null
      ? child
      : RaftTooltip(
          message: tooltip,
          child: RaftProfileLink(key: key, onPressed: onPressed, child: child),
        );

  /// Web `viewAvatar`: a custom (uploaded) avatar opens enlarged for people
  /// who cannot change it.
  Future<void> viewAvatar() async {
    final url = agentProfileAvatarUrl(
      widget.controller.client.origin,
      a['avatarUrl'] as String?,
    );
    if (url == null) return;
    try {
      final bytes = await RaftImageBytes.instance.load(url);
      if (!mounted) return;
      await showFeedbackImage(
        context,
        filename: displayName,
        contentType: 'image/png',
        bytes: bytes,
      );
    } catch (_) {
      if (mounted) showRaftToast(context, 'Failed to load file');
    }
  }

  bool _errorCopied = false;
  Timer? _errorCopiedTimer;

  Future<void> _copyErrorInfo() async {
    await Clipboard.setData(ClipboardData(text: diagnosticInfo));
    if (!mounted) return;
    setState(() => _errorCopied = true);
    _errorCopiedTimer?.cancel();
    _errorCopiedTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _errorCopied = false);
    });
  }

  /// Web v1.24 runtime error banner (`hasRuntimeError`, AgentDetailPanel.tsx):
  /// the agent is in `error` or carries a `lastRuntimeError`. The error detail
  /// reaches every member over the socket, so people who may not see private
  /// surfaces get the code's sentence or a generic line, and no actions.
  Widget? _runtimeErrorBanner(BuildContext context, AgentDetailTab current) {
    final display = _display;
    final runtime = '${a['runtime'] ?? ''}';
    final spec = resolveRuntimeErrorBanner(
      activity: display.activity,
      activityDetail: display.detail,
      errorCode: agentActivityErrorCode(
        a,
        live: widget.liveActivity,
        activity: display.activity,
      ),
      lastRuntimeError: a['lastRuntimeError'],
      canViewDetails: _canViewPrivate,
      canOpenModelSettings:
          _canManage &&
          a['deletedAt'] == null &&
          !external &&
          widget.actions.onEditRuntime != null,
      agentTitle: displayName,
      runtimeName:
          runtimeInfos.where((r) => r.id == runtime).firstOrNull?.name ??
          runtime,
      spawnLookupReason: agentRowSpawnLookupReason(a),
    );
    if (spec == null) return null;
    return agentRuntimeErrorBanner(
      context,
      spec,
      copied: _errorCopied,
      onCopy: _copyErrorInfo,
      onViewLogs: current == AgentDetailTab.activity
          ? null
          : () => setState(() => tab = AgentDetailTab.activity),
      onOpenModelSettings: widget.actions.onEditRuntime,
    );
  }

  /// The agent's status line (header and Activity overview): the activity text
  /// with a failed start's typed reason standing in for the daemon's detail
  /// (Web `formatSpawnFailureDetail`). The classified runtime error text
  /// (`agent.runtimeError.*`, the install / lookup copy) belongs to the banner
  /// under the head, not here.
  String _statusText(BuildContext context) {
    final display = _display;
    return agentActivityText(
      display.activity,
      _canViewPrivate ? _spawnFailureText(context) ?? display.detail : '',
      _canViewPrivate ? display.detailKind : null,
      errorCode: agentActivityErrorCode(
        a,
        live: widget.liveActivity,
        activity: display.activity,
      ),
      translate: (source, values) => raftFormat(context, source, values),
    );
  }

  /// The Model row's value: the model badge and, when the running process
  /// reports a different runtime or model than the saved one, Web's
  /// `runningConfigHint` under it.
  Widget _modelValue(
    BuildContext context,
    Map<String, dynamic> a,
    RuntimeConfig config,
    String model,
    String runtime,
  ) {
    final label = model.isEmpty
        ? raftText(context, 'Default')
        : modelDisplayLabel(
            widget.controller,
            machineId: a['machineId'] as String?,
            runtime: runtime,
            model: model,
          );
    // v1.24: plain `font-mono` text (v1.21: an accent badge).
    final badge = RaftCssText(label, style: RaftInfoRow.monoStyleOf(context));
    final hint = _runningSwitchesHint(context, a, config);
    if (hint == null) return badge;
    return RaftGapColumn(
      gap: 4,
      children: [
        Align(alignment: Alignment.centerLeft, child: badge),
        RaftCssText(
          hint,
          key: const ValueKey('agent-runtime-config-running'),
          style: RaftPanelText.caption(RaftTokens.of(context)),
        ),
      ],
    );
  }

  /// Web `runningConfigHint` (AgentProfileInfo.tsx:169-173): what the running
  /// process reports (`runtimeProfile.current`) differs from the saved config,
  /// which applies at the agent's next idle point. Unknown or equal says
  /// nothing; an agent that is not running reports nothing.
  String _runtimeName(String id) =>
      runtimeInfos.where((r) => r.id == id).firstOrNull?.name ?? id;

  String? _runningSwitchesHint(
    BuildContext context,
    Map<String, dynamic> a,
    RuntimeConfig config,
  ) {
    if (!(online || a['status'] == 'active')) return null;
    final profile = a['runtimeProfile'];
    final running = profile is Map ? profile['current'] : null;
    if (running is! Map) return null;
    final runningRuntime = running['runtime'];
    final runningModel = running['model'];
    String? say(String runningText, String savedText) => raftFormat(
      context,
      'Running {running} · switches to {saved} when idle',
      {'running': runningText, 'saved': savedText},
    );
    if (runningRuntime is String &&
        runningRuntime.isNotEmpty &&
        runningRuntime != config.runtime) {
      return say(_runtimeName(runningRuntime), _runtimeName(config.runtime));
    }
    if (runningModel is String &&
        runningModel.isNotEmpty &&
        config.model.isNotEmpty &&
        runningModel != config.model) {
      return say(
        runtimeModelLabel(config.runtime, runningModel),
        runtimeModelLabel(config.runtime, config.model),
      );
    }
    return null;
  }

  Widget _profile(BuildContext context) {
    final t = RaftTokens.of(context);
    final canEdit = _canManage && a['deletedAt'] == null;
    final agentId = '${a['id']}';
    final statusChip = _statusChip(context);
    // Web AgentStatusBadge: the stuck snapshot of the live frame (a frame
    // without one clears it) or the row's, hidden while offline or blocked.
    final live = widget.liveActivity;
    final toolStuck = visibleToolStuck(
      live != null && live.containsKey('toolStuck')
          ? AgentToolStuck.parse(live['toolStuck'])
          : agentRowToolStuck(a),
      isOnline: online,
      blocked: agentBlockedStateOf(a['blockedReason']),
    );
    final role = a['serverRole'];
    final roleChip = agentServerRoleChip(role, deletedAt: a['deletedAt']);
    final machineId = a['machineId'];
    final pending = machineId is String && widget.machines == null && !external;
    final m = machine;
    final creator = a['creator'];
    // Web `currentRuntimeConfig = hydrateRuntimeConfigForm(agent)`: the
    // structured runtimeConfig (mode, reasoning, model), flat columns as the
    // fallback. Never read the flat columns directly for these rows.
    final config = RuntimeConfig.fromAgent(a);
    final runtime = config.runtime;
    final model = config.model;
    final env = {
      if (a['envVars'] is Map)
        for (final e in (a['envVars'] as Map).entries) '${e.key}': '${e.value}',
    };
    // Web AgentStatusBadge (with Retry / Change model and the tool-stuck
    // notice): the card's first line, or under the handle without the card.
    final statusRow = a['deletedAt'] == null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AgentStatusChipView(
                key: ValueKey('agent-status-$agentId'),
                chip: statusChip,
                runtimeId: a['runtime'] is String
                    ? a['runtime'] as String
                    : null,
                tooltip: statusChip.tooltip,
                onRetry: _canControlRuntime ? _retryStart : null,
                onChangeModel: widget.actions.onEditRuntime,
                onOpenComputer: widget.actions.onOpenComputer == null
                    ? null
                    : () {
                        final id = a['machineId'];
                        if (id is String) {
                          widget.actions.onOpenComputer!(id);
                        }
                      },
              ),
              if (toolStuck != null)
                AgentToolStuckNotice(
                  key: ValueKey('agent-tool-stuck-$agentId'),
                  toolStuck: toolStuck,
                  onStop: widget.actions.onStopHostedTurn,
                ),
            ],
          )
        : null;
    // Web `showRecentActivity`: the profile's now card says what the agent is
    // doing, in place of the status chip under the handle.
    final showRecentActivity =
        tabs.contains(AgentDetailTab.activity) && a['deletedAt'] == null;
    final controls = _controls;
    final buttons = <Widget>[
      if (controls.start || controls.stop)
        RaftButton(
          label: raftText(
            context,
            controls.stop ? 'Stop agent' : 'Start agent',
          ),
          glyph: controls.stop ? RaftGlyph.square : RaftGlyph.play,
          tone: RaftButtonRecipeVariant.outline,
          size: RaftButtonRecipeSize.md,
          expand: true,
          onPressed: widget.busy ? null : widget.actions.onStartStop,
        ),
      if (controls.restartReset)
        RaftButton(
          label: raftText(context, 'Restart / reset'),
          glyph: RaftGlyph.rotateCcw,
          tone: RaftButtonRecipeVariant.outline,
          size: RaftButtonRecipeSize.md,
          expand: true,
          onPressed: widget.busy ? null : widget.actions.onRestartReset,
        ),
      // AgentDetailPanel Actions: `CopyButton` "Copy diagnostic info" (outline,
      // Clipboard / Check icon), between Restart / Reset and Archive.
      RaftButton(
        key: const ValueKey('agent-copy-diagnostic'),
        label: raftText(
          context,
          diagnosticCopied ? 'Diagnostic info copied' : 'Copy diagnostic info',
        ),
        glyph: diagnosticCopied ? RaftGlyph.check : RaftGlyph.clipboard,
        tone: RaftButtonRecipeVariant.outline,
        size: RaftButtonRecipeSize.md,
        expand: true,
        onPressed: copyDiagnosticInfo,
      ),
      // `FEEDBACK_EXPORT_ENABLED && <Button variant="warning">` (Bug icon).
      if (widget.actions.onReportIssue != null)
        RaftButton(
          key: const ValueKey('agent-report-issue'),
          label: raftText(context, 'Report issue'),
          glyph: RaftGlyph.bug,
          tone: RaftButtonRecipeVariant.warning,
          size: RaftButtonRecipeSize.md,
          expand: true,
          onPressed: widget.busy ? null : widget.actions.onReportIssue,
        ),
      if (widget.actions.onDelete != null)
        RaftButton(
          key: const ValueKey('agent-archive-button'),
          label: raftText(context, 'Archive agent'),
          glyph: RaftGlyph.archive,
          tone: RaftButtonRecipeVariant.danger,
          size: RaftButtonRecipeSize.md,
          expand: true,
          onPressed: widget.busy ? null : widget.actions.onDelete,
        ),
    ];
    return ListView(
      key: const Key('fleet-detail'),
      padding: raftScrollPadding(context),
      children: [
        if (agentSourceServerLabel(a, widget.controller.server?.id)
            case final source?)
          RaftPanelSection(
            topBorder: false,
            vertical: 12,
            gap: 4,
            children: [
              RaftSectionEyebrow(raftTextZh(context, 'From', '来自')),
              RaftCssText(
                source,
                style: raftCssText.merge(
                  RaftTypography.heading(
                    t,
                    size: 14,
                    line: 20,
                  ).copyWith(color: t.colors['foreground-strong']),
                ),
              ),
            ],
          ),
        RaftProfileIdentity(
          name: displayName,
          handle: '${a['name'] ?? ''}',
          avatarUrl: agentProfileAvatarUrl(
            widget.controller.client.origin,
            a['avatarUrl'] as String?,
          ),
          avatarButton: canEdit,
          // Web: a manager changes the avatar; anyone else with a custom
          // (uploaded) avatar can enlarge it. An archived agent's is static.
          onAvatar: canEdit
              ? widget.actions.onEditAvatar
              : a['deletedAt'] == null &&
                    isCustomAgentAvatar(a['avatarUrl'] as String?)
              ? viewAvatar
              : null,
          avatarLabel: canEdit ? null : raftText(context, 'View avatar'),
          onEditName: canEdit ? widget.actions.onEditName : null,
          // With the Recent activity card the status is its first line.
          statusRow: statusRow == null || showRecentActivity ? null : statusRow,
          // `min-h-[66px]`.
          minHeight: 66,
        ),
        // Web `AgentComputerOfflineCard`: in place of Start while the Computer
        // is offline.
        if (a['deletedAt'] == null && !external && !_bounded)
          AgentComputerOfflineCard(
            controller: widget.controller,
            machine: machine,
            formatter: agentTimeFormatter(context, widget.controller),
            onOpenComputer: widget.actions.onOpenComputer == null
                ? null
                : () => widget.actions.onOpenComputer!('${a['machineId']}'),
          ),
        if (showRecentActivity && statusRow != null)
          AgentRecentActivity(
            key: ValueKey('agent-recent-activity-$agentId'),
            controller: widget.controller,
            agentId: agentId,
            activity: _display.activity,
            activityText: _statusText(context),
            status: statusRow,
            onOpenActivity: () => setState(() => tab = AgentDetailTab.activity),
            clock: widget.clock,
          ),
        // Onboarding identity adoption (the server's onboarding agent only).
        if (_canManage &&
            widget.controller.server?.string('onboardingAgentId') == agentId)
          AgentOnboardingIdentity(
            key: ValueKey('identity-adoption-$agentId'),
            controller: widget.controller,
            agentId: agentId,
            identityKey:
                '${a['name']}|${a['displayName']}|${a['description']}|${a['avatarUrl']}',
          ),
        // Description: `px-5 py-3` (no top border).
        RaftPanelSection(
          topBorder: false,
          vertical: 12,
          children: [
            RaftDescriptionBlock(
              text: '${a['description'] ?? ''}',
              onEdit: canEdit ? widget.actions.onEditDescription : null,
              editKey: const ValueKey('agent-edit-description'),
            ),
          ],
        ),
        // `showOperationalInfo && isExternalAgent && canManageAgent`
        if (external && _canManage)
          ExternalAgentSetup(
            key: ValueKey('external-setup-$agentId'),
            controller: widget.controller,
            agent: a,
            status: externalStatus,
            statusError: externalStatusError,
            online: _externalOnline,
            lastSeenAt: a['lastSeenAt'] as String?,
            clock: widget.clock,
            hostedRuntime: HostedRuntimeSummary.parse(_hostedRuntime),
            onStatus: adoptExternalStatus,
          ),
        // `showOperationalInfo && isExternalAgent && canManageAgent &&
        // hostedRuntime?.state === "active"`.
        if (external && _canManage && _hostedRuntime?['state'] == 'active') ...[
          AgentHostedRuntimeModel(
            key: ValueKey('model-$agentId'),
            controller: widget.controller,
            agentId: agentId,
          ),
          // Web AgentProfileInfo.tsx:633: not for an app-managed agent.
          if (a['managedByAppInstallId'] == null)
            AgentConnectionsSection(
              key: ValueKey('connections-$agentId'),
              controller: widget.controller,
              agentId: agentId,
              agentName: '${a['displayName'] ?? a['name'] ?? ''}',
            ),
          AgentHostedRuntimeUsage(
            key: ValueKey('usage-$agentId'),
            controller: widget.controller,
            agentId: agentId,
          ),
        ],
        if (!_bounded)
          RaftPanelSection(
            children: [
              RaftSectionEyebrow(raftText(context, 'Info')),
              RaftInfoList(
                children: [
                  RaftInfoRow(
                    label: raftText(context, 'Role'),
                    actions: [
                      RaftInlineIconButton(
                        key: const ValueKey('agent-role-help'),
                        glyph: RaftGlyph.circleHelp,
                        tooltip: raftText(context, 'Agent Roles'),
                        onPressed: () =>
                            showRaftRolePermissionHelp(context, agent: true),
                      ),
                      if (canEdit && roleChip != null && role != 'owner')
                        RaftInlineIconButton(
                          key: const ValueKey('agent-edit-role'),
                          glyph: RaftGlyph.pencil,
                          tooltip: raftText(context, 'Edit Role'),
                          onPressed: widget.actions.onEditRole,
                        ),
                    ],
                    child: roleChip == null
                        ? const SizedBox.shrink()
                        : _roleValue(context, roleChip),
                  ),
                  RaftInfoRow(
                    label: raftText(context, 'Computer'),
                    child: external
                        ? RaftCssText(
                            raftText(context, 'External runtime'),
                            style: RaftInfoRow.mutedStyleOf(context),
                          )
                        : pending
                        ? const SizedBox.shrink()
                        : m != null
                        ? _profileLink(
                            key: const ValueKey('agent-computer-link'),
                            onPressed: widget.actions.onOpenComputer == null
                                ? null
                                : () => widget.actions.onOpenComputer!(
                                    '${m['id']}',
                                  ),
                            tooltip: '${m['name']}',
                            child: RaftCssText(
                              '${m['name']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              // v1.24: `font-mono text-foreground`.
                              style: RaftInfoRow.monoStyleOf(context),
                            ),
                          )
                        : archivedMachine != null
                        // An archived agent has no Computer; say where it last ran.
                        ? RaftCssText(
                            raftFormat(context, 'Last on {name}', {
                              'name': archivedMachine,
                            }),
                            key: const ValueKey('agent-archived-last-computer'),
                            style: RaftInfoRow.mutedStyleOf(context),
                          )
                        : RaftCssText(
                            raftText(context, 'No computer assigned'),
                            style: RaftInfoRow.hintStyleOf(context),
                          ),
                  ),
                  if (!external && m != null) ...[
                    RaftInfoRow(
                      label: raftText(context, 'Computer status'),
                      child: RaftConnectionValue(
                        online: m['status'] == 'online',
                      ),
                    ),
                    RaftInfoRow(
                      label: raftText(context, 'Computer version'),
                      child: RaftCssText(
                        runLabel(m, context),
                        style: RaftInfoRow.monoStyleOf(context),
                      ),
                    ),
                  ],
                  RaftInfoRow(
                    label: raftText(context, 'Created'),
                    child: RaftCssText(
                      createdDate(context),
                      // v1.24: `font-mono`.
                      style: RaftInfoRow.monoStyleOf(context),
                    ),
                  ),
                  RaftInfoRow(
                    label: raftText(context, 'Creator'),
                    child: creator is Map
                        ? _profileLink(
                            key: const ValueKey('agent-creator-link'),
                            onPressed:
                                widget.actions.onOpenCreator == null ||
                                    creator['id'] is! String
                                ? null
                                : () => widget.actions.onOpenCreator!(
                                    creator['type'] == 'human'
                                        ? 'human'
                                        : 'agent',
                                    creator['id'] as String,
                                  ),
                            tooltip: nonEmptyOr(
                              creator['displayName'],
                              creator['name'],
                            ),
                            child: RaftCreatorLink(
                              name: nonEmptyOr(
                                creator['displayName'],
                                creator['name'],
                              ),
                              handle: '${creator['name']}',
                              human: creator['type'] == 'human',
                              avatarUrl: creator['avatarUrl'] as String?,
                            ),
                          )
                        : RaftCssText(
                            raftText(context, 'No creator'),
                            style: RaftInfoRow.hintStyleOf(context),
                          ),
                  ),
                ],
              ),
            ],
          ),
        if (!_bounded && !external)
          RaftPanelSection(
            children: [
              RaftEditableEyebrow(
                raftText(context, 'Runtime Config'),
                onEdit: canEdit ? widget.actions.onEditRuntime : null,
                editLabel: raftText(context, 'Edit Runtime Config'),
                editKey: const ValueKey('agent-edit-runtime'),
              ),
              RaftInfoList(
                children: [
                  RaftInfoRow(
                    label: raftText(context, 'Runtime'),
                    child:
                        // RuntimeAccountUsageGateChip: the agent's Computer usage.
                        runtimeUsageGateChip(
                          controller: widget.controller,
                          enabled: canViewRuntimeUsage(
                            widget.controller,
                            machine,
                          ),
                          runtimeId: runtime,
                          machineId: '${machine?['id'] ?? ''}',
                          label: runtimeLabelWithStatus(
                            context,
                            runtime,
                            deprecated: deprecatedHere(runtime),
                          ),
                          runtimeVersion: machine?['runtimeVersions'] is Map
                              ? (machine!['runtimeVersions'] as Map)[runtime]
                                    as String?
                              : null,
                          chip: (status) => RaftRecipeBadge(
                            runtimeLabelWithStatus(
                              context,
                              runtime,
                              deprecated: deprecatedHere(runtime),
                            ),
                            // v1.24: `soft information` in machine type
                            // (RUNTIME_CHIP_CLASS).
                            appearance: RaftBadgeRecipeAppearance.soft,
                            variant: RaftBadgeRecipeVariant.information,
                            mono: true,
                            trailing: status,
                          ),
                        ),
                  ),
                  // Web `currentRuntimeDeprecated` (AgentProfileInfo.tsx:233): the
                  // agent keeps running, but new agents cannot select this runtime.
                  if (deprecatedHere(runtime))
                    RaftBanner(
                      status: RaftBannerRecipeStatus.warning,
                      size: RaftBannerRecipeSize.sm,
                      descriptionWeight: FontWeight.w700,
                      description: raftText(
                        context,
                        'This agent uses a deprecated runtime. It can keep running, but new agents cannot select this runtime.',
                      ),
                    ),
                  RaftInfoRow(
                    label: raftText(context, 'Model'),
                    child: _modelValue(context, a, config, model, runtime),
                  ),
                  if (config.supportsReasoning)
                    RaftInfoRow(
                      label: raftText(context, 'Reasoning'),
                      child: RaftCssText(
                        raftText(
                          context,
                          _reasoningEffortLabel(config.reasoningEffort),
                        ),
                      ),
                    ),
                  if (config.supportsFastMode)
                    RaftInfoRow(
                      label: raftText(context, 'Mode'),
                      child: RaftCssText(
                        raftText(
                          context,
                          config.fastMode ? 'Fast mode' : 'Default',
                        ),
                      ),
                    ),
                  // Web (Claude only): the custom provider's API URL and the
                  // command override, in machine type, else "Default".
                  if (runtime == 'claude') ...[
                    for (final (label, value) in [
                      ('Provider', config.providerApiUrl),
                      ('Command', config.commandText),
                    ])
                      RaftInfoRow(
                        key: ValueKey('agent-runtime-${label.toLowerCase()}'),
                        label: raftText(context, label),
                        child: value.isEmpty
                            ? RaftCssText(
                                raftText(context, 'Default'),
                                style: RaftInfoRow.hintStyleOf(context),
                              )
                            : RaftCssText(
                                value,
                                style: RaftInfoRow.monoStyleOf(context),
                              ),
                      ),
                  ],
                ],
              ),
              // Web `agent.modelLimits?.defaultsReported &&
              // <AgentModelLimitsWarning className="mt-3" />`.
              if (RaftAgentFields(a).modelDefaultsReported == true)
                const AgentModelLimitsWarning(),
              if (env.isNotEmpty) RaftEnvVarsBlock(vars: env),
            ],
          ),
        // v1.21.23: no "Created agents" section on an agent profile (a
        // person's profile keeps it).
        if (_canViewPrivate &&
            a['deletedAt'] == null &&
            a['managedByAppInstallId'] == null &&
            (!external || (machineId is String && machineId.isNotEmpty)))
          AgentSkillsSection(
            controller: widget.controller,
            agentId: '${a['id']}',
          ),
        // Web `{canManageAgent && !agent.deletedAt && !isExternalAgent &&
        // <AgentMigrationSection />}`, between Skills and Actions.
        if (widget.actions.canMigrate && canEdit && !external)
          AgentMigrationSection(
            controller: widget.controller,
            agent: a,
            machines: widget.machines ?? const [],
            now: widget.clock,
          ),
        if (widget.actions.canShowCloudArrival &&
            canEdit &&
            external &&
            _hostedRuntime != null)
          AgentMigrationSection(
            key: ValueKey('cloud-arrival-$agentId'),
            controller: widget.controller,
            agent: a,
            machines: widget.machines ?? const [],
            now: widget.clock,
            arrivalOnly: true,
          ),
        // Web `agent.deletedAt && canViewPrivateAgentSurfaces`.
        if (a['deletedAt'] != null && _canViewPrivate)
          AgentArchiveSection(
            controller: widget.controller,
            agentId: agentId,
            canManage: !_bounded && widget.actions.canArchive,
          ),
        if (canEdit && buttons.isNotEmpty)
          RaftPanelSection(
            children: [
              RaftSectionEyebrow(raftText(context, 'Actions')),
              RaftGapColumn(children: buttons),
            ],
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- tabs

/// Last accepted data of one agent tab, kept in the controller's
/// server-identity-bound cache. A tab opens with it at its first frame, a
/// reload replaces it in place, and view state (expanded folders, the open
/// file) survives tab switches and leaving the agent.
abstract class _AgentTabSnapshot {
  bool loaded = false;
}

class _ChatSnapshot extends _AgentTabSnapshot {
  List<Map<String, dynamic>> channels = [], dms = [];

  /// Web keeps the channels and DMs reads (and their failures) separate.
  // ignore: raft_lints/avoid_imperative_notice_state -- Rewritten (null on success) by every reload of the chat tab snapshot, which is keyed by agent and server.
  String? channelsError, dmsError;
}

class _RemindersSnapshot extends _AgentTabSnapshot {
  List<Map<String, dynamic>> reminders = [];
}

class _WorkspaceSnapshot extends _AgentTabSnapshot {
  final children = <String, List<Map<String, dynamic>>>{};
  final expanded = <String>{};
  bool showHidden = false;
  String? openFile, openContent;

  /// `DirTruncation` per listing (`''` is the root): the server cut it short.
  final truncation = <String, ({int shown, int? omitted})>{};

  /// Last read per file (`/workspace-files/read` body), shown at once when the
  /// file opens again.
  final contents = <String, Map<String, dynamic>>{};
  Map<String, dynamic>? openMeta;
}

mixin _AgentTabLoader<T extends StatefulWidget> on State<T> {
  WorkspaceController get w;
  int _ticket = 0;

  /// Skeleton/"Loading…" only while there is nothing to show yet (also before
  /// the tab is first active: a snapshot is shown, never a skeleton).
  late bool loading = !hasContent;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when reload() starts, set only for a current ticket and only when nothing is on screen; the tab is keyed by agent.
  String? loadError;
  bool tabActive = true, reloadWhenActive = false;

  /// Web's per-surface `... Failed` message for a read that carries no server
  /// error text.
  String get loadFailedFallback => raftGenericErrorText;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wasActive = tabActive;
    tabActive = TickerMode.valuesOf(context).enabled;
    if (tabActive && (!wasActive || reloadWhenActive)) {
      reloadWhenActive = false;
      unawaited(reload());
    }
  }

  /// An earlier accepted result is on screen; reloads keep it.
  bool get hasContent;
  Future<void> fetch();
  Future<void> reload() async {
    if (!tabActive) {
      reloadWhenActive = true;
      return;
    }
    final ticket = ++_ticket;
    setState(() {
      loading = !hasContent;
      loadError = null;
    });
    try {
      await fetch();
      if (!mounted || ticket != _ticket) return;
      setState(() => loading = false);
    } catch (e) {
      if (!mounted || ticket != _ticket) return;
      setState(() {
        loading = false;
        // A failed background refresh never replaces rows already shown.
        loadError = hasContent
            ? null
            : userErrorText(
                e,
                fallback: loadFailedFallback,
                where: 'agent tab load',
              );
      });
    }
  }
}

/// AgentChatTab: the agent's channels and DMs (`/agents/:id/channels`,
/// `/agents/:id/agent-dms`).
class AgentChatTab extends StatefulWidget {
  const AgentChatTab({
    super.key,
    required this.controller,
    required this.agentId,
    this.clock,
    this.onOpenChannel,
  });
  final WorkspaceController controller;
  final String agentId;
  final DateTime Function()? clock;

  /// A channel row opens that channel (Web `nav.toChannel`).
  final ValueChanged<String>? onOpenChannel;
  @override
  State<AgentChatTab> createState() => _AgentChatTabState();
}

class _AgentChatTabState extends State<AgentChatTab> with _AgentTabLoader {
  @override
  WorkspaceController get w => widget.controller;
  late final _ChatSnapshot snapshot = w.agentTabCache.putIfAbsent(
    'chat/${widget.agentId}',
    _ChatSnapshot.new,
  ) as _ChatSnapshot;
  List<Map<String, dynamic>> get channels => snapshot.channels;
  List<Map<String, dynamic>> get dms => snapshot.dms;
  @override
  bool get hasContent => snapshot.loaded;
  @override
  void initState() {
    super.initState();
    reload();
  }

  List<Map<String, dynamic>> _rows(dynamic v, String key) => [
    for (final r
        in (v is Map
            ? v[key] ?? const []
            : v is List
            ? v
            : const []))
      if (r is Map) Map<String, dynamic>.from(r),
  ];

  @override
  Future<void> fetch() async {
    // Web loads the two lists independently; each failure shows in its own
    // section (`agent.detail.loadAgentChannelsFailed` / `loadAgentDmsFailed`).
    final channelsRead = w.query('/agents/${widget.agentId}/channels');
    final dmsRead = w.query('/agents/${widget.agentId}/agent-dms');
    Object? channelsFailure, dmsFailure;
    Object? channelsResult, dmsResult;
    await Future.wait([
      channelsRead.then<void>(
        (v) => channelsResult = v,
        onError: (Object e) => channelsFailure = e,
      ),
      dmsRead.then<void>(
        (v) => dmsResult = v,
        onError: (Object e) => dmsFailure = e,
      ),
    ]);
    snapshot
      ..channels = channelsFailure != null
          ? const []
          : _rows(channelsResult, 'channels')
      ..dms = dmsFailure != null ? const [] : _rows(dmsResult, 'dms')
      ..channelsError = channelsFailure == null
          ? null
          : userErrorText(
              channelsFailure,
              fallback: 'Failed to load agent channels',
              where: 'agent channels',
            )
      ..dmsError = dmsFailure == null
          ? null
          : userErrorText(
              dmsFailure,
              fallback: 'Failed to load agent DMs',
              where: 'agent dms',
            )
      ..loaded = true;
  }

  @override
  Widget build(BuildContext context) {
    // Nothing accepted yet: no "Channels 0" counts that would then fill in.
    if (!hasContent) {
      return RaftPanelMessage(
        raftText(context, loadError ?? 'Loading profile…'),
        action: loadError == null
            ? null
            : RaftButton(label: raftText(context, 'Retry'), onPressed: reload),
      );
    }
    final origin = w.client.origin;
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    // The peers' faces are read live from the agent directory.
    return ListenableBuilder(
      listenable: w.services.entityDirectory,
      builder: (context, _) => _chatView(origin, chinese),
    );
  }

  Widget _chatView(String origin, bool chinese) {
    return RaftAgentChatView(
      channelsError: snapshot.channelsError,
      dmsError: snapshot.dmsError,
      // visibleAgentChatChannels: archived memberships are not listed.
      channels: [
        for (final c in channels)
          if (c['archivedAt'] == null)
            RaftAgentChannelRow(
              id: '${c['id']}',
              name: '${c['name'] ?? c['id']}',
              description: c['description'] as String?,
              type: '${c['type'] ?? 'channel'}',
              activityMuted: c['activityMuted'] == true,
              muteFromSeq: c['muteFromSeq'],
              onTap: widget.onOpenChannel == null
                  ? null
                  : () => widget.onOpenChannel!('${c['id']}'),
            ),
      ],
      dms: [
        for (final d in dms)
          RaftAgentDmRow(
            id: '${d['id']}',
            name: '${d['peerDisplayName'] ?? d['peerName'] ?? d['id']}',
            handle: '@${d['peerName'] ?? ''}',
            avatar: ChannelCandidateAvatar(
              candidate: ChannelMemberCandidate(
                kind: 'agent',
                id: '${d['peerId'] ?? d['id']}',
                name: '${d['peerName'] ?? ''}',
                displayName: d['peerDisplayName'] as String?,
                avatarUrl: liveAgentDmPeerAvatarUrl(w, d),
              ),
              avatarContext: RaftMountedAvatarContext.previewMini,
              origin: origin,
            ),
            timestamp: resourceRelativeTime(
              '${d['lastMessageAt'] ?? d['createdAt']}',
              now: widget.clock?.call(),
              chinese: chinese,
            ),
            preview: (d['lastMessagePreview'] as String?)?.isNotEmpty == true
                ? d['lastMessagePreview'] as String
                : null,
          ),
      ],
    );
  }
}

/// AgentRemindersSection variant="tab": `GET /reminders?ownerAgentId=&status=
/// scheduled`, kept current by reminder socket events.
class AgentRemindersTab extends StatefulWidget {
  const AgentRemindersTab({
    super.key,
    required this.controller,
    required this.agentId,
    this.clock,
    this.onOpenMessage,
  });
  final WorkspaceController controller;
  final String agentId;
  final DateTime Function()? clock;

  /// Opens the message a reminder was set from, given its `msgPermalink`.
  final ValueChanged<String>? onOpenMessage;
  @override
  State<AgentRemindersTab> createState() => _AgentRemindersTabState();
}

class _AgentRemindersTabState extends State<AgentRemindersTab>
    with _AgentTabLoader {
  @override
  WorkspaceController get w => widget.controller;
  late final _RemindersSnapshot snapshot = w.agentTabCache.putIfAbsent(
    'reminders/${widget.agentId}',
    _RemindersSnapshot.new,
  ) as _RemindersSnapshot;
  List<Map<String, dynamic>> get reminders => snapshot.reminders;
  set reminders(List<Map<String, dynamic>> value) => snapshot.reminders = value;
  @override
  String get loadFailedFallback => 'Failed to load reminders';

  @override
  bool get hasContent => snapshot.loaded;
  StreamSubscription<RaftEvent>? events;

  @override
  void initState() {
    super.initState();
    reload();
    events = w.client.events.listen(_event);
  }

  @override
  void dispose() {
    events?.cancel();
    super.dispose();
  }

  void _event(RaftEvent e) {
    final p = e.payload;
    if (e.name == 'connected') {
      reload();
      return;
    }
    if (p is! Map) return;
    switch (e.name) {
      case 'reminder:fired':
        if (p['ownerAgentId'] != widget.agentId) return;
        final next = p['nextFireAt'];
        setState(() {
          reminders = next is String
              ? [
                  for (final r in reminders)
                    r['reminderId'] == p['reminderId']
                        ? {...r, 'fireAt': next}
                        : r,
                ]
              : reminders
                    .where((r) => r['reminderId'] != p['reminderId'])
                    .toList();
        });
      case 'reminder:scheduled' || 'reminder:updated':
        final r = p['reminder'];
        if (r is! Map || r['ownerAgentId'] != widget.agentId) return;
        setState(() {
          reminders = [
            ...reminders.where((x) => x['reminderId'] != r['reminderId']),
            if (r['status'] == 'scheduled') Map<String, dynamic>.from(r),
          ]..sort((a, b) => '${a['fireAt']}'.compareTo('${b['fireAt']}'));
        });
      case 'reminder:canceled':
        if (p['ownerAgentId'] != widget.agentId) return;
        setState(() {
          reminders = reminders
              .where((r) => r['reminderId'] != p['reminderId'])
              .toList();
        });
    }
  }

  @override
  Future<void> fetch() async {
    final result = await w.query(
      '/reminders',
      query: {'ownerAgentId': widget.agentId, 'status': 'scheduled'},
    );
    final rows = result is Map ? result['reminders'] : result;
    reminders = [
      for (final r in (rows is List ? rows : const []))
        if (r is Map) Map<String, dynamic>.from(r),
    ];
    snapshot.loaded = true;
  }

  @override
  Widget build(BuildContext context) {
    final f = agentTimeFormatter(context, w);
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    return RaftReminderListView(
      loading: loading,
      error: loadError,
      onRetry: reload,
      reminders: [
        for (final r in reminders)
          RaftReminderItem(
            title: '${r['title'] ?? ''}',
            relative: resourceRelativeTime(
              '${r['fireAt']}',
              now: widget.clock?.call(),
              chinese: chinese,
            ),
            dateTime: f.shortDateTime(r['fireAt']),
            recurrence: r['recurrence'] is Map
                ? '${(r['recurrence'] as Map)['description'] ?? ''}'
                : null,
            msgRef: r['msgRef'] is String ? r['msgRef'] as String : null,
            onOpenMessage:
                widget.onOpenMessage == null ||
                    r['msgPermalink'] is! String ||
                    (r['msgPermalink'] as String).isEmpty
                ? null
                : () => widget.onOpenMessage!(r['msgPermalink'] as String),
          ),
      ],
    );
  }
}

/// AgentWorkspace: path bar + expandable file tree
/// (`/agents/:id/workspace-files?dirPath=`), file preview via `/read`.
class AgentWorkspaceTab extends StatefulWidget {
  const AgentWorkspaceTab({
    super.key,
    required this.controller,
    required this.agentId,
    this.hosted = false,
  });
  final WorkspaceController controller;
  final String agentId;
  final bool hosted;
  @override
  State<AgentWorkspaceTab> createState() => _AgentWorkspaceTabState();
}

class _AgentWorkspaceTabState extends State<AgentWorkspaceTab>
    with _AgentTabLoader {
  @override
  WorkspaceController get w => widget.controller;
  late final _WorkspaceSnapshot snapshot = w.agentTabCache.putIfAbsent(
    'workspace/${widget.agentId}',
    _WorkspaceSnapshot.new,
  ) as _WorkspaceSnapshot;
  Map<String, List<Map<String, dynamic>>> get children => snapshot.children;
  Set<String> get expanded => snapshot.expanded;
  bool get showHidden => snapshot.showHidden;
  set showHidden(bool value) => snapshot.showHidden = value;
  String? get openFile => snapshot.openFile;
  set openFile(String? value) => snapshot.openFile = value;
  String? get openContent => snapshot.openContent;
  set openContent(String? value) => snapshot.openContent = value;

  /// The open file's read body (binary / encoding / mime / size / time).
  Map<String, dynamic>? get openMeta => snapshot.openMeta;
  set openMeta(Map<String, dynamic>? value) => snapshot.openMeta = value;
  @override
  String get loadFailedFallback => 'Failed to load files';

  @override
  bool get hasContent => snapshot.loaded;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Folders whose listing is in flight (`loadingDirs`).
  final loadingDirs = <String>{};

  /// The server's `code` of the last failed root listing: an archived agent's
  /// workspace says why it cannot be read (`loadErrorMessageId`).
  String? errorCode;

  /// `isFinalLoadError`: nothing to retry and no Computer path to show.
  bool get errorFinal =>
      errorCode == 'archive_workspace_unavailable' ||
      errorCode == 'computer_access_revoked';

  String get errorText => switch (errorCode) {
    'archive_workspace_unavailable' => 'This workspace was deleted from its Computer, so there is nothing to browse.',
    'machine_offline' || 'daemon_offline' => 'The Computer that holds this workspace is offline. Files can be browsed again when it reconnects.',
    'computer_access_revoked' => 'Computer access revoked: move the agent to another computer (re-attaching adds a new one)',
    _ => 'Failed to load files',
  };

  Future<List<Map<String, dynamic>>> list(String dir) async {
    final result = await w.query(
      '/agents/${widget.agentId}/workspace-files',
      // The server owns which entries are hidden (`includeHidden`).
      query: {
        if (dir.isNotEmpty) 'dirPath': dir,
        'includeHidden': '$showHidden',
      },
    );
    final files = result is Map ? result['files'] : result;
    // Web `listingTruncation`: only `truncated: true` shows the hint.
    if (result is Map && result['truncated'] == true) {
      snapshot.truncation[dir] = (
        shown: files is List ? files.length : 0,
        omitted: result['omitted'] is num
            ? (result['omitted'] as num).toInt()
            : null,
      );
    } else {
      snapshot.truncation.remove(dir);
    }
    return [
      for (final f in (files is List ? files : const []))
        if (f is Map) Map<String, dynamic>.from(f),
    ];
  }

  @override
  Future<void> fetch() async {
    // Refresh in place: the tree and the folders the member opened stay
    // exactly as shown until each listing is replaced.
    final List<Map<String, dynamic>> root;
    try {
      root = await list('');
      errorCode = null;
    } on RaftApiException catch (e) {
      final code = e.details['code'];
      errorCode = code is String ? code : null;
      rethrow;
    }
    final open = expanded.toList();
    final refreshed = await Future.wait([
      for (final dir in open)
        list(dir).then<List<Map<String, dynamic>>?>(
          (rows) => rows,
          onError: (Object _) => null,
        ),
    ]);
    children[''] = root;
    for (var i = 0; i < open.length; i++) {
      final rows = refreshed[i];
      if (rows != null) children[open[i]] = rows;
    }
    snapshot.loaded = true;
  }

  /// Web `handleToggleHiddenFiles`: the listing is read again with the new
  /// `includeHidden`; the open file and every expanded folder reset.
  void toggleHidden() {
    setState(() {
      showHidden = !showHidden;
      expanded.clear();
      children.clear();
      snapshot
        ..loaded = false
        ..truncation.clear();
      openFile = null;
      openContent = null;
      openMeta = null;
      openError = null;
    });
    reload();
  }

  Future<void> toggle(String path) async {
    if (expanded.remove(path)) {
      setState(() {});
      return;
    }
    setState(() {
      expanded.add(path);
      // Nothing remembered for the folder: its row shows the loading line.
      if (children[path] == null) loadingDirs.add(path);
    });
    // A remembered listing shows at once; the read refreshes it in place.
    try {
      final rows = await list(path);
      if (mounted) setState(() => children[path] = rows);
    } catch (_) {
      // Keep whatever listing is already shown for this folder.
    } finally {
      if (mounted) setState(() => loadingDirs.remove(path));
    }
  }

  int openTicket = 0;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next file opens; set only for the current open ticket and file.
  String? openError;
  bool openLoading = false;

  Future<void> open(String path) async {
    // The preview opens at once: with the content read before when there is
    // one, else empty until the read lands (never another file's content).
    final ticket = ++openTicket;
    final known = snapshot.contents[path];
    setState(() {
      openFile = path;
      openMeta = known;
      openContent = known == null ? '' : '${known['content'] ?? ''}';
      openError = null;
      // Web `loadingFile`: nothing read before, so the pane shows "Loading...".
      openLoading = known == null;
    });
    final Object? result;
    try {
      result = await w.query(
        '/agents/${widget.agentId}/workspace-files/read',
        query: {'path': path},
      );
    } catch (e) {
      // Web `fileError || agent.workspace.fileLoadFailed` in the preview pane;
      // the tree is still usable.
      if (mounted && ticket == openTicket && openFile == path) {
        setState(() {
          openLoading = false;
          openError = userErrorText(
            e,
            fallback: 'Failed to load file',
            where: 'agent workspace file',
          );
        });
      }
      return;
    }
    if (!mounted) return;
    final file = result is Map
        ? Map<String, dynamic>.from(result)
        : <String, dynamic>{'content': '$result'};
    snapshot.contents[path] = file;
    if (ticket != openTicket || openFile != path) return;
    setState(() {
      openMeta = file;
      openContent = '${file['content'] ?? ''}';
      openLoading = false;
    });
  }

  /// Web `TruncationHint`.
  RaftWorkspaceNode? hint(String dir, int depth) {
    final cut = snapshot.truncation[dir];
    if (cut == null) return null;
    return RaftWorkspaceNode.hint(
      cut.omitted != null
          ? raftFormat(
              context,
              'Showing the first {shown} items; {omitted} more not shown',
              {'shown': cut.shown, 'omitted': cut.omitted},
            )
          : raftFormat(
              context,
              'Showing the first {shown} items; more not shown',
              {'shown': cut.shown},
            ),
      depth: dir.isEmpty ? -1 : depth,
    );
  }

  List<RaftWorkspaceNode> nodes(String dir, int depth) => [
    for (final f in children[dir] ?? const <Map<String, dynamic>>[]) ...[
      RaftWorkspaceNode(
        name: '${f['name']}',
        depth: depth,
        directory: f['isDirectory'] == true,
        open: expanded.contains(f['path']),
        bold: f['name'] == 'memory.md',
        hidden: f['isHidden'] == true,
        selected: f['isDirectory'] != true && openFile == f['path'],
        // Web `node.isSymlink`: shown, never opened.
        symlinkLabel: f['isDirectory'] != true && f['isSymlink'] == true
            ? raftText(context, 'Link — not opened in the workspace viewer')
            : null,
        onTap: () => f['isDirectory'] == true
            ? toggle('${f['path']}')
            : open('${f['path']}'),
      ),
      if (f['isDirectory'] == true && expanded.contains(f['path']))
        if (loadingDirs.contains('${f['path']}'))
          RaftWorkspaceNode.loading(depth: depth + 1)
        else if (children['${f['path']}'] != null) ...[
          ...nodes('${f['path']}', depth + 1),
          ?hint('${f['path']}', depth + 1),
        ],
    ],
  ];

  Map<String, dynamic>? _imageFrom;
  Uint8List? _imageBytes;

  /// `isWorkspaceImagePreview`: a binary file the server sent base64 with an
  /// `image/*` type, decoded once per read.
  Uint8List? get _openImage {
    final meta = openMeta;
    if (meta == null) return null;
    if (identical(meta, _imageFrom)) return _imageBytes;
    _imageFrom = meta;
    _imageBytes = null;
    final content = meta['content'];
    if (meta['binary'] == true &&
        meta['encoding'] == 'base64' &&
        content is String &&
        content.isNotEmpty &&
        '${meta['mimeType'] ?? ''}'.startsWith('image/')) {
      try {
        _imageBytes = base64Decode(content);
      } on FormatException {
        _imageBytes = null;
      }
    }
    return _imageBytes;
  }

  @override
  Widget build(BuildContext context) {
    final path = '~/.slock/agents/${widget.agentId}/';
    final wide = MediaQuery.sizeOf(context).width >= 768;
    return RaftWorkspaceTreeView(
      preview: openFile == null
          ? null
          : RaftWorkspaceFilePreview(
              // The phone shows the pane alone and closes it with the arrow.
              onBack: wide ? null : () => setState(() => openFile = null),
              embedded: true,
              path: openFile!,
              content: openContent ?? '',
              error: openError,
              loading: openLoading,
              imageBytes: _openImage,
              binary: openMeta?['binary'] == true,
              sizeLabel: openMeta?['size'] is num
                  ? workspaceFileSize((openMeta!['size'] as num).toInt())
                  : null,
              modifiedLabel: openMeta?['modifiedAt'] == null
                  ? null
                  : agentTimeFormatter(
                      context,
                      w,
                    ).shortDateTime(openMeta!['modifiedAt']),
            ),
      path: path,
      showPath: !widget.hosted,
      nodes: [...nodes('', 0), ?hint('', 0)],
      loading: loading,
      // Web: fixed catalog messages, not the server's text.
      error: loadError == null ? null : errorText,
      errorFinal: loadError != null && errorFinal,
      showHidden: showHidden,
      treeWidth: workspaceTreeWidth.value,
      onTreeWidthChanged: workspaceTreeWidth.save,
      treeResizeLabel: raftText(context, 'Resize file tree'),
      onCopyPath: () => Clipboard.setData(ClipboardData(text: path)),
      onToggleHidden: toggleHidden,
      onRefresh: reload,
    );
  }
}
