// Agent detail panel, rebuilt from Web
// packages/web/src/components/agent/AgentDetailPanel.tsx: PanelHeader
// (back, avatar, name, overflow actions), the scrollable tab strip
// (Profile / Activity / Chat / Reminders / Workspace / Apps / MCP) and each
// tab's content. FleetDetail keeps the data loading, authority fencing and
// lifecycle commands and hands them to this view.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_time_formatter.dart';
import '../data/workspace_controller.dart';
import 'agent_apps_view.dart';
import 'agent_metadata_catalog.dart';
import 'mcp_views.dart';
import 'agent_avatar_dialog.dart' show agentProfileAvatarUrl;
import 'resource_cards.dart' show resourceRelativeTime;

enum AgentDetailTab { profile, activity, chat, reminders, workspace, apps, mcp }

/// Lifecycle and edit commands owned by FleetDetail.
class AgentDetailActions {
  const AgentDetailActions({
    this.onBack,
    this.onEditProfile,
    this.onEditAvatar,
    this.onEditRuntime,
    this.onStartStop,
    this.onRestartReset,
    this.onDelete,
    this.onMessage,
    this.onMigrate,
    this.onPermissions,
  });
  final VoidCallback? onBack,
      onEditProfile,
      onEditAvatar,
      onEditRuntime,
      onStartStop,
      onRestartReset,
      onDelete,
      onMessage,
      onMigrate,
      onPermissions;
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

/// shared/src/index.ts REASONING_EFFORT_RUNTIMES / RUNTIME_FAST_MODE_RUNTIMES.
const _reasoningRuntimes = {
  'builtin',
  'claude',
  'codex',
  'grok',
  'copilot',
  'pi',
  'kimi-sdk',
};
const _fastModeRuntimes = {'claude', 'codex'};
const _reasoningLabels = {
  'low': 'Low',
  'medium': 'Medium',
  'high': 'High',
  'xhigh': 'Extra High',
};
const _activityLabels = {
  'online': 'Online',
  'thinking': 'Thinking',
  'working': 'Working',
  'error': 'Error',
  'offline': 'Offline',
};

class AgentDetailPanel extends StatefulWidget {
  const AgentDetailPanel({
    super.key,
    required this.controller,
    required this.agent,
    required this.machines,
    required this.actions,
    this.liveActivity,
    this.initialTab = AgentDetailTab.profile,
    this.canManage = false,
    this.canViewPrivate = false,
    this.canControlRuntime = false,
    this.busy = false,
    this.error,
    this.clock,
  });
  final WorkspaceController controller;
  final Map<String, dynamic> agent;

  /// null while GET /servers/:id/machines is in flight.
  final List<Map<String, dynamic>>? machines;
  final AgentDetailActions actions;

  /// Latest `agent:activity` socket projection ({activity, detail}).
  final Map<String, dynamic>? liveActivity;
  final AgentDetailTab initialTab;
  final bool canManage, canViewPrivate, canControlRuntime, busy;
  final String? error;
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

class _AgentDetailPanelState extends State<AgentDetailPanel> {
  late AgentDetailTab tab = widget.initialTab;

  Map<String, dynamic> get a => widget.agent;
  String get displayName => '${a['displayName'] ?? a['name'] ?? ''}';
  bool get external => a['external'] == true || a['runtime'] == 'external';
  String get activity =>
      '${widget.liveActivity?['activity'] ?? a['activity'] ?? (a['status'] == 'active' ? 'online' : 'offline')}';
  bool get online => activity != 'offline';

  List<AgentDetailTab> get tabs => [
    AgentDetailTab.profile,
    if (widget.canViewPrivate) ...[
      AgentDetailTab.activity,
      AgentDetailTab.chat,
      AgentDetailTab.reminders,
      AgentDetailTab.workspace,
      AgentDetailTab.apps,
    ],
    if (widget.canManage) AgentDetailTab.mcp,
  ];

  @override
  Widget build(BuildContext context) {
    final visible = tabs;
    final current = visible.contains(tab) ? tab : AgentDetailTab.profile;
    final menu = <RaftMenuEntry>[
      if (widget.actions.onMessage != null)
        RaftMenuEntry(
          label: raftText(context, 'Direct Message'),
          glyph: RaftGlyph.messageSquareMore,
          onPressed: widget.actions.onMessage,
        ),
      if (widget.canControlRuntime && !external) ...[
        RaftMenuEntry(
          label: raftText(context, online ? 'Stop Agent' : 'Start Agent'),
          glyph: online ? RaftGlyph.square : RaftGlyph.play,
          onPressed: widget.actions.onStartStop,
        ),
        RaftMenuEntry(
          label: raftText(context, 'Restart / Reset'),
          glyph: RaftGlyph.rotateCcw,
          onPressed: widget.actions.onRestartReset,
        ),
      ],
    ];
    return RaftPanelTextScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftPanelHeaderBar(
            title: displayName,
            onBack: widget.actions.onBack,
            backTooltip: raftText(context, 'Back'),
            iconSlot: RaftAvatarSlot(
              name: displayName,
              avatarUrl: agentProfileAvatarUrl(
                widget.controller.client.origin,
                a['avatarUrl'] as String?,
              ),
              slot: RaftAvatarSlotContext.panelHeader,
            ),
            actions: [
              if (a['deletedAt'] == null && menu.isNotEmpty)
                RaftOverflowMenuButton(
                  key: const Key('agent-profile-overflow-trigger'),
                  entries: menu,
                  tooltip: raftText(context, 'More actions'),
                ),
            ],
          ),
          RaftPanelTabBar<AgentDetailTab>(
            tabs: [for (final id in visible) _tabSpec(context, id)],
            value: current,
            onChanged: (v) => setState(() => tab = v),
          ),
          if (widget.error != null) RaftPanelError(widget.error!),
          Expanded(child: _content(context, current)),
        ],
      ),
    );
  }

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
    AgentDetailTab.chat => RaftPanelTab(
      id,
      raftText(context, 'Chat'),
      RaftGlyph.messageSquareMore,
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
      AgentDetailTab.activity => AgentActivityTab(
        controller: w,
        agentId: agentId,
      ),
      AgentDetailTab.chat => AgentChatTab(controller: w, agentId: agentId),
      AgentDetailTab.reminders => AgentRemindersTab(
        controller: w,
        agentId: agentId,
        clock: widget.clock,
      ),
      AgentDetailTab.workspace => AgentWorkspaceTab(
        controller: w,
        agentId: agentId,
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
  String runLabel(Map<String, dynamic> m) {
    if (m['status'] != 'online') {
      return m['isComputer'] == true ? 'computer offline' : 'legacy offline';
    }
    return m['isComputer'] == true && m['computerVersion'] != null
        ? 'computer v${m['computerVersion']}'
        : 'legacy v${m['daemonVersion'] ?? '?'}';
  }

  String createdDate(BuildContext context) {
    final raw = a['createdAt'];
    final date = raw is String ? DateTime.tryParse(raw) : null;
    if (date == null) return '';
    return DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
        .format(agentTimeFormatter(context, widget.controller).wallTime(date));
  }

  Widget _profile(BuildContext context) {
    final t = RaftTokens.of(context);
    final canEdit = widget.canManage && a['deletedAt'] == null;
    final detail = widget.liveActivity?['detail'] ?? a['activityDetail'];
    final status =
        widget.canViewPrivate && detail is String && detail.isNotEmpty
        ? detail
        : raftText(context, _activityLabels[activity] ?? activity);
    final role = a['serverRole'];
    final pending =
        a['machineId'] is String && widget.machines == null && !external;
    final m = machine;
    final creator = a['creator'];
    final runtime = '${a['runtime'] ?? ''}';
    final model = '${a['model'] ?? ''}';
    final env = {
      if (a['envVars'] is Map)
        for (final e in (a['envVars'] as Map).entries) '${e.key}': '${e.value}',
    };
    final created = (a['createdAgents'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final buttons = <Widget>[
      if (!external) ...[
        if (widget.actions.onMigrate != null)
          RaftButton(
            label: raftText(context, 'Move to another computer'),
            glyph: RaftGlyph.moveRight,
            tone: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.md,
            expand: true,
            onPressed: widget.busy ? null : widget.actions.onMigrate,
          ),
        if (widget.canControlRuntime) ...[
          RaftButton(
            label: raftText(context, online ? 'Stop Agent' : 'Start Agent'),
            glyph: online ? RaftGlyph.square : RaftGlyph.play,
            tone: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.md,
            expand: true,
            onPressed: widget.busy ? null : widget.actions.onStartStop,
          ),
          RaftButton(
            label: raftText(context, 'Restart / Reset'),
            glyph: RaftGlyph.rotateCcw,
            tone: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.md,
            expand: true,
            onPressed: widget.busy ? null : widget.actions.onRestartReset,
          ),
        ],
      ],
      if (widget.actions.onDelete != null)
        RaftButton(
          label: raftText(context, 'Delete Agent'),
          glyph: RaftGlyph.trash2,
          tone: RaftButtonRecipeVariant.danger,
          size: RaftButtonRecipeSize.md,
          expand: true,
          onPressed: widget.busy ? null : widget.actions.onDelete,
        ),
    ];
    return ListView(
      key: const Key('fleet-detail'),
      padding: EdgeInsets.zero,
      children: [
        RaftProfileIdentity(
          name: displayName,
          handle: '${a['name'] ?? ''}',
          avatarUrl: agentProfileAvatarUrl(
            widget.controller.client.origin,
            a['avatarUrl'] as String?,
          ),
          avatarButton: canEdit,
          onAvatar: canEdit ? widget.actions.onEditAvatar : null,
          onEditName: canEdit ? widget.actions.onEditProfile : null,
          statusColor: raftActivityDotColor(t, activity),
          statusText: a['deletedAt'] == null ? status : null,
          // `min-h-[66px] theme-brutal:min-h-[72px]`.
          minHeight: t.brutal ? 72 : 66,
        ),
        // Description: `px-5 py-3` (no top border).
        RaftPanelSection(
          topBorder: false,
          vertical: 12,
          children: [
            RaftDescriptionBlock(
              text: '${a['description'] ?? ''}',
              onEdit: canEdit ? widget.actions.onEditProfile : null,
            ),
          ],
        ),
        RaftPanelSection(
          children: [
            RaftSectionEyebrow(raftText(context, 'Info')),
            RaftInfoRow(
              label: raftText(context, 'Role'),
              actions: [
                RaftInlineIconButton(
                  glyph: RaftGlyph.circleHelp,
                  tooltip: raftText(context, 'Role permissions'),
                ),
                if (canEdit && role != null && role != 'owner')
                  RaftInlineIconButton(
                    glyph: RaftGlyph.pencil,
                    tooltip: raftText(context, 'Edit role'),
                    onPressed: widget.actions.onPermissions,
                  ),
              ],
              child: role == null
                  ? const SizedBox.shrink()
                  : RaftInlineBadge(
                      badge: RaftRecipeBadge(
                        raftText(context, role == 'admin' ? 'Admin' : 'Member'),
                        variant: role == 'admin'
                            ? RaftBadgeRecipeVariant.accent
                            : RaftBadgeRecipeVariant.muted,
                      ),
                    ),
            ),
            RaftInfoRow(
              label: raftText(context, 'Computer'),
              child: external
                  ? RaftCssText(
                      raftText(context, 'External runtime'),
                      style: RaftPanelText.muted(t),
                    )
                  : pending
                  ? const SizedBox.shrink()
                  : m != null
                  ? RaftCssText(
                      '${m['name']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RaftPanelText.monoSemibold(t),
                    )
                  : RaftCssText(
                      raftText(context, 'No computer assigned'),
                      style: RaftPanelText.muted(t),
                    ),
            ),
            if (!external && m != null) ...[
              RaftInfoRow(
                label: raftText(context, 'Computer status'),
                child: RaftConnectionValue(online: m['status'] == 'online'),
              ),
              RaftInfoRow(
                label: raftText(context, 'Computer Version'),
                child: RaftCssText(runLabel(m), style: RaftPanelText.mono(t)),
              ),
            ],
            RaftInfoRow(
              label: raftText(context, 'Created'),
              child: RaftCssText(createdDate(context)),
            ),
            RaftInfoRow(
              label: raftText(context, 'Creator'),
              child: creator is Map
                  ? RaftCreatorLink(
                      name: '${creator['displayName'] ?? creator['name']}',
                      handle: '${creator['name']}',
                      human: creator['type'] == 'human',
                      avatarUrl: creator['avatarUrl'] as String?,
                    )
                  : RaftCssText(
                      raftText(context, 'No creator assigned'),
                      style: RaftPanelText.muted(t),
                    ),
            ),
          ],
        ),
        if (!external)
          RaftPanelSection(
            children: [
              RaftEditableEyebrow(
                raftText(context, 'Runtime Config'),
                onEdit: canEdit ? widget.actions.onEditRuntime : null,
                editLabel: raftText(context, 'Edit runtime config'),
              ),
              RaftInfoRow(
                label: raftText(context, 'Runtime'),
                child: RaftInlineBadge(
                  badge: RaftRecipeBadge(
                    sourceRuntimeDisplayNames[runtime] ?? runtime,
                    appearance: RaftBadgeRecipeAppearance.solid,
                    variant: RaftBadgeRecipeVariant.information,
                  ),
                ),
              ),
              RaftInfoRow(
                label: raftText(context, 'Model'),
                child: RaftInlineBadge(
                  badge: RaftRecipeBadge(
                    model.isEmpty
                        ? raftText(context, 'Default')
                        : sourceRuntimeModelLabels[runtime]?[model] ?? model,
                    variant: RaftBadgeRecipeVariant.accent,
                  ),
                ),
              ),
              if (_reasoningRuntimes.contains(runtime))
                RaftInfoRow(
                  label: raftText(context, 'Reasoning'),
                  child: RaftInlineBadge(
                    badge: RaftRecipeBadge(
                      raftText(
                        context,
                        _reasoningLabels[a['reasoningEffort']] ?? 'Default',
                      ),
                      variant: RaftBadgeRecipeVariant.primary,
                    ),
                  ),
                ),
              if (_fastModeRuntimes.contains(runtime))
                RaftInfoRow(
                  label: raftText(context, 'Mode'),
                  child: RaftInlineBadge(
                    badge: RaftRecipeBadge(
                      raftText(
                        context,
                        a['fastMode'] == true ? 'Fast mode' : 'Default',
                      ),
                      variant: RaftBadgeRecipeVariant.warning,
                    ),
                  ),
                ),
              if (env.isNotEmpty) RaftEnvVarsBlock(vars: env),
            ],
          ),
        RaftPanelSection(
          children: [
            RaftSectionHeader(
              label: raftText(context, 'Created Agents'),
              count: created.length,
            ),
            if (created.isNotEmpty)
              RaftGapColumn(
                children: [
                  for (final c in created)
                    RaftAvatarListRow(
                      avatar: RaftAvatarSlot(
                        name: '${c['displayName'] ?? c['name']}',
                        avatarUrl: c['avatarUrl'] as String?,
                        slot: RaftAvatarSlotContext.surfaceList,
                      ),
                      name: '${c['displayName'] ?? c['name']}',
                      subtitle:
                          sourceRuntimeDisplayNames['${c['runtime']}'] ??
                          '${c['runtime'] ?? ''}',
                      rightContent: [
                        RaftActivityDot(
                          color: raftActivityDotColor(
                            t,
                            c['status'] == 'active' ? 'online' : 'offline',
                          ),
                        ),
                      ],
                    ),
                ],
              ),
          ],
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

mixin _AgentTabLoader<T extends StatefulWidget> on State<T> {
  WorkspaceController get w;
  int _ticket = 0;
  bool loading = true;
  String? loadError;
  Future<void> fetch();
  Future<void> reload() async {
    final ticket = ++_ticket;
    setState(() {
      loading = true;
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
        loadError = '$e';
      });
    }
  }
}

/// AgentDetailPanel activity tab: `/agents/:id/activity-log` rendered as
/// AgentActivityLog rows.
class AgentActivityTab extends StatefulWidget {
  const AgentActivityTab({
    super.key,
    required this.controller,
    required this.agentId,
  });
  final WorkspaceController controller;
  final String agentId;
  @override
  State<AgentActivityTab> createState() => _AgentActivityTabState();
}

class _AgentActivityTabState extends State<AgentActivityTab>
    with _AgentTabLoader {
  @override
  WorkspaceController get w => widget.controller;
  List<Map<String, dynamic>> entries = [];
  StreamSubscription<RaftEvent>? events;
  @override
  void initState() {
    super.initState();
    reload();
    events = w.client.events.listen((e) {
      if (e.name.startsWith('agent:activity') &&
          e.payload is Map &&
          (e.payload as Map)['agentId'] == widget.agentId) {
        reload();
      }
    });
  }

  @override
  void dispose() {
    events?.cancel();
    super.dispose();
  }

  @override
  Future<void> fetch() async {
    final result = await w.query(
      '/agents/${widget.agentId}/activity-log',
      query: {'limit': '50'},
    );
    entries = [
      for (final e in (result is List ? result : const []))
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  static String _toolLabel(String name) => switch (name) {
    'shell' || 'bash' || 'Bash' => 'Running command',
    'read' || 'Read' => 'Reading file',
    'write' || 'Write' => 'Writing file',
    'edit' || 'Edit' => 'Editing file',
    _ => 'Using $name',
  };

  RaftActivityLogEntry _entry(
    BuildContext context,
    RaftTokens t,
    SourceTimeFormatter f,
    Map<String, dynamic> item,
  ) {
    final entry = item['entry'] is Map
        ? Map<String, dynamic>.from(item['entry'] as Map)
        : <String, dynamic>{};
    final time = f.clock(item['timestamp'], seconds: true).toUpperCase();
    final kind = entry['kind'];
    final text = '${entry['text'] ?? ''}';
    return switch (kind) {
      'status' => RaftActivityLogEntry(
        time: time,
        dot: raftActivityDotColor(t, '${entry['activity']}'),
        title: raftText(
          context,
          _activityLabels['${entry['activity']}'] ?? '${entry['activity']}',
        ),
        inlineDetail: '${entry['detail'] ?? ''}',
        compact: true,
      ),
      'tool_start' => RaftActivityLogEntry(
        time: time,
        dot: t.product.statusBusy,
        title: raftText(context, _toolLabel('${entry['toolName']}')),
        inlineDetail: '${entry['toolInput'] ?? ''}',
        inlineMono: true,
      ),
      _ => RaftActivityLogEntry(
        time: time,
        dot: switch (kind) {
          'thinking' => t.product.statusBusy,
          'text' => t.product.brutalCyan,
          'slock_action' => raftBlue300,
          _ => t.product.brutalOrange,
        },
        title: switch (kind) {
          'thinking' => raftText(context, 'Thinking'),
          'text' => raftText(context, 'Message'),
          _ => '${entry['title'] ?? entry['kind'] ?? ''}',
        },
        detail: text,
        clamp: text.length > 200,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final f = agentTimeFormatter(context, w);
    return RaftActivityLogView(
      entries: [for (final e in entries) _entry(context, t, f, e)],
      emptyLabel: loading ? raftText(context, 'Loading…') : loadError,
      onCopy: () => Clipboard.setData(
        ClipboardData(
          text: [for (final e in entries) '${e['timestamp']} ${e['entry']}']
              .join('\n'),
        ),
      ),
    );
  }
}

/// AgentChatTab: the agent's channels and DMs (`/agents/:id/channels`,
/// `/agents/:id/agent-dms`).
class AgentChatTab extends StatefulWidget {
  const AgentChatTab({
    super.key,
    required this.controller,
    required this.agentId,
  });
  final WorkspaceController controller;
  final String agentId;
  @override
  State<AgentChatTab> createState() => _AgentChatTabState();
}

class _AgentChatTabState extends State<AgentChatTab> with _AgentTabLoader {
  @override
  WorkspaceController get w => widget.controller;
  List<Map<String, dynamic>> channels = [], dms = [];
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
    final results = await Future.wait([
      w.query('/agents/${widget.agentId}/channels'),
      w.query('/agents/${widget.agentId}/agent-dms'),
    ]);
    channels = _rows(results[0], 'channels');
    dms = _rows(results[1], 'dms');
  }

  List<Widget> _section(String title, List<Map<String, dynamic>> rows) => [
    RaftSectionHeader(label: title, count: rows.length),
    for (final r in rows)
      RaftAccessCard(title: '${r['name'] ?? r['displayName'] ?? r['id']}'),
  ];

  @override
  Widget build(BuildContext context) => RaftPanelGroups(
    groups: [
      _section(raftText(context, 'Channels'), channels),
      _section(raftText(context, 'Direct messages'), dms),
    ],
  );
}

/// AgentRemindersSection variant="tab": `GET /reminders?ownerAgentId=&status=
/// scheduled`, kept current by reminder socket events.
class AgentRemindersTab extends StatefulWidget {
  const AgentRemindersTab({
    super.key,
    required this.controller,
    required this.agentId,
    this.clock,
  });
  final WorkspaceController controller;
  final String agentId;
  final DateTime Function()? clock;
  @override
  State<AgentRemindersTab> createState() => _AgentRemindersTabState();
}

class _AgentRemindersTabState extends State<AgentRemindersTab>
    with _AgentTabLoader {
  @override
  WorkspaceController get w => widget.controller;
  List<Map<String, dynamic>> reminders = [];
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
  }

  @override
  Widget build(BuildContext context) {
    final f = agentTimeFormatter(context, w);
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    return RaftReminderListView(
      loading: loading,
      error: loadError,
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
  });
  final WorkspaceController controller;
  final String agentId;
  @override
  State<AgentWorkspaceTab> createState() => _AgentWorkspaceTabState();
}

class _AgentWorkspaceTabState extends State<AgentWorkspaceTab>
    with _AgentTabLoader {
  @override
  WorkspaceController get w => widget.controller;
  final children = <String, List<Map<String, dynamic>>>{};
  final expanded = <String>{};
  bool showHidden = false;
  String? openFile, openContent;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<List<Map<String, dynamic>>> list(String dir) async {
    final result = await w.query(
      '/agents/${widget.agentId}/workspace-files',
      query: {if (dir.isNotEmpty) 'dirPath': dir},
    );
    final files = result is Map ? result['files'] : result;
    return [
      for (final f in (files is List ? files : const []))
        if (f is Map) Map<String, dynamic>.from(f),
    ];
  }

  @override
  Future<void> fetch() async {
    final root = await list('');
    children
      ..clear()
      ..[''] = root;
    expanded.clear();
  }

  Future<void> toggle(String path) async {
    if (expanded.remove(path)) {
      setState(() {});
      return;
    }
    setState(() => expanded.add(path));
    if (!children.containsKey(path)) {
      final rows = await list(path);
      if (mounted) setState(() => children[path] = rows);
    }
  }

  Future<void> open(String path) async {
    final result = await w.query(
      '/agents/${widget.agentId}/workspace-files/read',
      query: {'path': path},
    );
    if (!mounted) return;
    setState(() {
      openFile = path;
      openContent = result is Map ? '${result['content'] ?? ''}' : '$result';
    });
  }

  List<RaftWorkspaceNode> nodes(String dir, int depth) => [
    for (final f in children[dir] ?? const <Map<String, dynamic>>[])
      if (showHidden || !'${f['name']}'.startsWith('.')) ...[
        RaftWorkspaceNode(
          name: '${f['name']}',
          depth: depth,
          directory: f['isDirectory'] == true,
          open: expanded.contains(f['path']),
          bold: f['name'] == 'memory.md',
          onTap: () => f['isDirectory'] == true
              ? toggle('${f['path']}')
              : open('${f['path']}'),
        ),
        if (f['isDirectory'] == true && expanded.contains(f['path']))
          ...nodes('${f['path']}', depth + 1),
      ],
  ];

  @override
  Widget build(BuildContext context) {
    final path = '~/.slock/agents/${widget.agentId}/';
    if (openFile != null) {
      return RaftWorkspaceFilePreview(
        path: openFile!,
        content: openContent ?? '',
        onBack: () => setState(() => openFile = null),
      );
    }
    return RaftWorkspaceTreeView(
      path: path,
      nodes: nodes('', 0),
      loading: loading,
      error: loadError,
      showHidden: showHidden,
      onCopyPath: () => Clipboard.setData(ClipboardData(text: path)),
      onToggleHidden: () => setState(() => showHidden = !showHidden),
      onRefresh: reload,
    );
  }
}
