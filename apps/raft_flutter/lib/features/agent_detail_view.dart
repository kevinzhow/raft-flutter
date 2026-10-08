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
import 'package:raft_ui/recipes.dart';

import '../data/source_time_formatter.dart';
import '../data/workspace_controller.dart';
import 'agent_apps_view.dart';
import 'agent_metadata_catalog.dart';
import 'mcp_views.dart';
import 'resource_cards.dart' show resourceRelativeTime;

enum AgentDetailTab { profile, activity, chat, reminders, workspace, apps, mcp }

/// Lifecycle and edit commands owned by FleetDetail.
class AgentDetailActions {
  const AgentDetailActions({
    this.onBack,
    this.onEditProfile,
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

/// utils/activity.ts getActivityDotClass.
Color agentActivityDotColor(RaftTokens t, String? activity) =>
    switch (activity) {
      'online' => t.product.brutalLime,
      'thinking' || 'working' => t.product.statusBusy,
      'error' => t.product.brutalOrange,
      _ => _gray400,
    };

/// Tailwind `bg-gray-400` (oklch(70.7% 0.022 261.325)), StatusDot default.
const _gray400 = Color(0xFF99A1AF);

/// Tailwind `bg-blue-300` (oklch(80.9% 0.105 251.813)), slock_action dot.
const _blue300 = Color(0xFF8EC5FF);

/// StatusDot.tsx: `inline-block shrink-0 rounded-full border
/// border-line-strong theme-brutal:border-black`, size md 10 / sm 8.
class AgentStatusDot extends StatelessWidget {
  const AgentStatusDot({super.key, required this.color, this.size = 10});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: t.brutal ? Colors.black : t.colors['line-strong']!,
        ),
      ),
    );
  }
}

/// raft-ui Badge (`badge` recipe), `uppercase={false}` unless set.
class AgentBadge extends StatelessWidget {
  const AgentBadge(
    this.label, {
    super.key,
    this.appearance = RaftBadgeRecipeAppearance.soft,
    this.variant,
    this.uppercase = false,
    this.background,
  });
  final String label;
  final RaftBadgeRecipeAppearance appearance;
  final RaftBadgeRecipeVariant? variant;
  final bool uppercase;

  /// Web `className` background override (HumanDetailPanel ROLE_CONFIG).
  final Color? background;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final s = RaftBadgeRecipe.resolve(
      theme: raftRecipeTheme(t),
      appearance: appearance,
      variant: variant,
      uppercase: uppercase,
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: rt,
    ).root;
    final decoration = s.decoration(rt);
    final text = s.textStyle(rt);
    return Container(
      height: s.height,
      padding: s.padding,
      decoration: background == null
          ? decoration
          : decoration.copyWith(color: background),
      child: Center(
        widthFactor: 1,
        child: Text(
        uppercase ? label.toUpperCase() : label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: raftCssText(
          RaftTypography.body(t, size: 10, line: 10).merge(text),
        ),
      ),
      ),
    );
  }
}

/// A Badge sitting inline in the `text-sm` (14/20) line of an InfoRow value
/// (`<dd>` text flow), baseline-aligned like Web inline layout.
class InlineInLine extends StatelessWidget {
  const InlineInLine({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final s = RaftBadgeRecipe.resolve(theme: raftRecipeTheme(t)).root;
    return RaftInlineBox(
      lineText: RaftInfoRow.valueStyle(t),
      childText: RaftTypography.body(
        t,
        size: s.fontSize ?? 10,
        line: (s.lineHeight ?? 1) * (s.fontSize ?? 10),
        weight: FontWeight.w700,
      ),
      height: s.height ?? 20,
      child: child,
    );
  }
}

/// Web AvatarSlot (components/ui/AvatarSlot.tsx RAFT_AVATAR_SPEC): raft-ui
/// Avatar with the context's size and border override.
class AgentAvatarSlot extends StatelessWidget {
  const AgentAvatarSlot({
    super.key,
    required this.name,
    required this.size,
    required this.border,
    this.agent = true,
    this.avatarUrl,
  });
  final String name;
  final double size, border;
  final bool agent;
  final String? avatarUrl;

  static String? pixelKey(String? url) =>
      url != null && url.startsWith('pixel:') ? url.substring(6) : null;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final s = RaftAvatarRecipe.resolve(
      theme: raftRecipeTheme(t),
      type_: agent ? RaftAvatarRecipeType.agent : RaftAvatarRecipeType.human,
      size: RaftAvatarRecipeSize.xl,
      tokens: rt,
    );
    final decoration = s.root.decoration(rt);
    final fallbackIcon = size >= 64
        ? 24.0
        : size >= 36
        ? 18.0
        : 12.0;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: decoration.copyWith(
        border: Border.all(
          color: s.root.borderColor?.resolve(rt) ?? Colors.black,
          width: border,
        ),
      ),
      child: RaftAvatarContent(
        name: name,
        kind: agent ? RaftAvatarContentKind.agent : RaftAvatarContentKind.human,
        pixelKey: pixelKey(avatarUrl),
        uploadedUrl: pixelKey(avatarUrl) == null ? avatarUrl : null,
        fallback: Center(
          child: RaftIcon(
            agent ? RaftGlyph.bot : RaftGlyph.user,
            size: fallbackIcon,
            color: s.fallback.color?.resolve(rt),
          ),
        ),
      ),
    );
  }
}

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

class _AgentDetailPanelState extends State<AgentDetailPanel> {
  late AgentDetailTab tab = widget.initialTab;
  final menu = OverlayPortalController();
  final menuAnchor = LayerLink();

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

  SourceTimeFormatter get formatter => SourceTimeFormatter(
    locale: Localizations.localeOf(context).toLanguageTag(),
    preferredTimezone:
        widget.controller.client.user?.string('preferredTimezone') ??
        widget.controller.client.user?.string('timezone'),
    preferredTimeFormat: sourceTimeFormatPreference(
      widget.controller.client.user?.string('preferredTimeFormat') ??
          widget.controller.client.user?.string('timeFormat'),
    ),
    systemTimeFormat: MediaQuery.alwaysUse24HourFormatOf(context)
        ? SourceTimeFormat.twentyFourHour
        : null,
  );

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final visible = tabs;
    final current = visible.contains(tab) ? tab : AgentDetailTab.profile;
    // body: `font-family: var(--font-sans)`, `color: var(--foreground)`.
    return DefaultTextStyle(
      style: raftCssText(RaftTypography.body(t, color: t.ink)),
      child: ColoredBox(
      color: t.colors['layer-panel']!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftPanelHeaderBar(
            title: displayName,
            onBack: widget.actions.onBack,
            backTooltip: raftText(context, 'Back'),
            iconSlot: AgentAvatarSlot(
              name: displayName,
              avatarUrl: a['avatarUrl'] as String?,
              size: 36,
              border: 2,
            ),
            actions: [if (a['deletedAt'] == null) overflow(context)],
          ),
          RaftPanelTabBar<AgentDetailTab>(
            tabs: [for (final id in visible) _tabSpec(context, id)],
            value: current,
            onChanged: (v) => setState(() => tab = v),
          ),
          if (widget.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  widget.error!,
                  style: RaftTypography.body(
                    t,
                    size: 12,
                    line: 16,
                    color: t.colors['danger-strong'] ?? t.strong,
                  ),
                ),
              ),
            ),
          Expanded(child: _content(context, current)),
        ],
      ),
      ),
    );
  }

  RaftPanelTab<AgentDetailTab> _tabSpec(BuildContext context, AgentDetailTab id) =>
      switch (id) {
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

  /// AgentProfileOverflowMenu: outline icon-sm trigger, dropdown aligned to
  /// the trigger's end with `sideOffset={4}`.
  Widget overflow(BuildContext context) {
    final entries = <RaftMenuEntry>[
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
    if (entries.isEmpty) return const SizedBox.shrink();
    return CompositedTransformTarget(
      link: menuAnchor,
      child: OverlayPortal(
        controller: menu,
        overlayChildBuilder: (_) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: menu.hide,
              ),
            ),
            CompositedTransformFollower(
              link: menuAnchor,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 4),
              child: Align(
                alignment: Alignment.topRight,
                child: RaftMenuPanel(
                  onDismiss: menu.hide,
                  children: [
                    for (final e in entries)
                      RaftMenuItem(
                        label: e.label!,
                        glyph: e.glyph,
                        onPressed: () {
                          menu.hide();
                          e.onPressed?.call();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        child: RaftPanelIconButton(
          key: const Key('agent-profile-overflow-trigger'),
          glyph: RaftGlyph.ellipsisVertical,
          tooltip: raftText(context, 'More actions'),
          onPressed: menu.toggle,
        ),
      ),
    );
  }

  Widget _content(BuildContext context, AgentDetailTab id) {
    final w = widget.controller;
    final agentId = a['id'] as String;
    return switch (id) {
      AgentDetailTab.profile => _profile(context),
      AgentDetailTab.activity => AgentActivityTab(
        controller: w,
        agentId: agentId,
        formatter: formatter,
      ),
      AgentDetailTab.chat => AgentChatTab(controller: w, agentId: agentId),
      AgentDetailTab.reminders => AgentRemindersTab(
        controller: w,
        agentId: agentId,
        formatter: formatter,
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

  Color ink(RaftTokens t, double alpha, String token) =>
      raftPanelInk(t, alpha, t.colors[token]!);

  /// `border-t border-line-muted theme-brutal:border-black/10`.
  BoxDecoration section(RaftTokens t) => BoxDecoration(
    border: Border(top: BorderSide(color: ink(t, .1, 'line-muted'))),
  );

  Widget _profile(BuildContext context) {
    final t = RaftTokens.of(context);
    final canEdit = widget.canManage && a['deletedAt'] == null;
    final description = '${a['description'] ?? ''}';
    return ListView(
      key: const Key('fleet-detail'),
      padding: EdgeInsets.zero,
      children: [
        _identity(context, t, canEdit),
        // Description: `px-5 py-3`, header `flex items-center gap-2 mb-1`.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RaftSectionEyebrow(raftText(context, 'Description')),
                  if (canEdit) ...[
                    const SizedBox(width: 8),
                    RaftInlineIconButton(
                      glyph: RaftGlyph.pencil,
                      tooltip: raftText(context, 'Edit description'),
                      onPressed: widget.actions.onEditProfile,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              description.isEmpty
                  ? Text(
                      raftText(context, 'No description'),
                      style: RaftInfoRow.valueStyle(t).copyWith(
                        fontStyle: FontStyle.italic,
                        color: ink(t, .4, 'foreground-placeholder'),
                      ),
                    )
                  : SelectableText(
                      description,
                      style: RaftInfoRow.valueStyle(t),
                    ),
            ],
          ),
        ),
        _info(context, t, canEdit),
        if (!external) _runtimeConfig(context, t, canEdit),
        _createdAgents(context, t),
        if (canEdit) _actions(context, t),
      ],
    );
  }

  /// Profile header: `min-h-[66px] flex items-start gap-4 px-5 py-5
  /// theme-brutal:min-h-[72px]`.
  Widget _identity(BuildContext context, RaftTokens t, bool canEdit) {
    final rt = RaftRecipeTokens(t);
    final avatar = AgentAvatarSlot(
      name: displayName,
      avatarUrl: a['avatarUrl'] as String?,
      size: 64,
      border: 2,
    );
    // canManageAgent wraps the tile in `<Button variant="outline"
    // className="size-16 !p-0">`, which contributes the outline shadow.
    final button = RaftButtonRecipe.resolve(
      theme: raftRecipeTheme(t),
      variant: RaftButtonRecipeVariant.outline,
      size: RaftButtonRecipeSize.md,
      tokens: rt,
    ).root;
    final detail = widget.liveActivity?['detail'] ?? a['activityDetail'];
    final activityText = widget.canViewPrivate &&
            detail is String &&
            detail.isNotEmpty
        ? detail
        : raftText(context, _activityLabels[activity] ?? activity);
    final muted = ink(t, .6, 'foreground-muted');
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: t.brutal ? 72 : 66),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            canEdit
                ? Semantics(
                    button: true,
                    label: raftText(context, 'Change avatar'),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        boxShadow: button.boxShadow.toBoxShadows(rt),
                      ),
                      child: avatar,
                    ),
                  )
                : avatar,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: raftCssText(
                            RaftTypography.body(
                              t,
                              size: 18,
                              line: 22.5,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (canEdit) ...[
                        const SizedBox(width: 8),
                        RaftInlineIconButton(
                          glyph: RaftGlyph.pencil,
                          size: 14,
                          tooltip: raftText(context, 'Edit display name'),
                          onPressed: widget.actions.onEditProfile,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '@${a['name'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: raftCssText(
                      RaftTypography.mono(
                        t,
                        size: 14,
                        line: 20,
                        color: t.colors['foreground-muted'],
                      ),
                    ),
                  ),
                  if (a['deletedAt'] == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          AgentStatusDot(
                            color: agentActivityDotColor(t, activity),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              activityText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: raftCssText(
                                RaftTypography.mono(
                                  t,
                                  size: 14,
                                  line: 20,
                                  color: muted,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
    return DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(formatter.wallTime(date));
  }

  Widget _info(BuildContext context, RaftTokens t, bool canEdit) {
    final role = a['serverRole'];
    final pending =
        a['machineId'] is String && widget.machines == null && !external;
    final m = machine;
    final mutedValue = TextStyle(color: ink(t, .5, 'foreground-muted'));
    final creator = a['creator'];
    Widget rows(List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    );
    return Container(
      decoration: section(t),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftSectionEyebrow(raftText(context, 'Info')),
          const SizedBox(height: 12),
          rows([
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
                  ? const SizedBox(height: 20)
                  : InlineInLine(
                      child: AgentBadge(
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
                  ? Text(raftText(context, 'External runtime'), style: mutedValue)
                  : pending
                  ? const SizedBox(height: 20)
                  : m != null
                  ? Text(
                      '${m['name']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: t.monoFont,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Text(
                      raftText(context, 'No computer assigned'),
                      style: mutedValue,
                    ),
            ),
            if (!external && m != null) ...[
              RaftInfoRow(
                label: raftText(context, 'Computer status'),
                child: Row(
                  children: [
                    AgentStatusDot(
                      color: m['status'] == 'online'
                          ? t.product.brutalLime
                          : _gray400,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      raftText(
                        context,
                        m['status'] == 'online' ? 'Connected' : 'Offline',
                      ),
                    ),
                  ],
                ),
              ),
              RaftInfoRow(
                label: raftText(context, 'Computer Version'),
                child: Text(
                  runLabel(m),
                  style: TextStyle(fontFamily: t.monoFont),
                ),
              ),
            ],
            RaftInfoRow(
              label: raftText(context, 'Created'),
              child: Text(createdDate(context)),
            ),
            RaftInfoRow(
              label: raftText(context, 'Creator'),
              child: creator is Map
                  ? Row(
                      children: [
                        AgentAvatarSlot(
                          name: '${creator['displayName'] ?? creator['name']}',
                          agent: creator['type'] != 'human',
                          avatarUrl: creator['avatarUrl'] as String?,
                          size: 22,
                          border: 1,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${creator['displayName'] ?? creator['name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '@${creator['name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: raftCssText(
                              RaftTypography.mono(
                                t,
                                size: 12,
                                line: 16,
                                color: ink(t, .5, 'foreground-muted'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      raftText(context, 'No creator assigned'),
                      style: mutedValue,
                    ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _runtimeConfig(BuildContext context, RaftTokens t, bool canEdit) {
    final runtime = '${a['runtime'] ?? ''}';
    final model = '${a['model'] ?? ''}';
    final modelLabel = model.isEmpty
        ? raftText(context, 'Default')
        : sourceRuntimeModelLabels[runtime]?[model] ?? model;
    final effort = a['reasoningEffort'];
    final env = a['envVars'] is Map
        ? Map<String, dynamic>.from(a['envVars'] as Map)
        : <String, dynamic>{};
    final rows = <Widget>[
      RaftInfoRow(
        label: raftText(context, 'Runtime'),
        child: InlineInLine(
          child: AgentBadge(
            sourceRuntimeDisplayNames[runtime] ?? runtime,
            appearance: RaftBadgeRecipeAppearance.solid,
            variant: RaftBadgeRecipeVariant.information,
          ),
        ),
      ),
      RaftInfoRow(
        label: raftText(context, 'Model'),
        child: InlineInLine(
          child: AgentBadge(modelLabel, variant: RaftBadgeRecipeVariant.accent),
        ),
      ),
      if (_reasoningRuntimes.contains(runtime))
        RaftInfoRow(
          label: raftText(context, 'Reasoning'),
          child: InlineInLine(
            child: AgentBadge(
              raftText(context, _reasoningLabels[effort] ?? 'Default'),
              variant: RaftBadgeRecipeVariant.primary,
            ),
          ),
        ),
      if (_fastModeRuntimes.contains(runtime))
        RaftInfoRow(
          label: raftText(context, 'Mode'),
          child: InlineInLine(
            child: AgentBadge(
              raftText(
                context,
                a['fastMode'] == true ? 'Fast mode' : 'Default',
              ),
              variant: RaftBadgeRecipeVariant.warning,
            ),
          ),
        ),
    ];
    return Container(
      decoration: section(t),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RaftSectionEyebrow(raftText(context, 'Runtime Config')),
              if (canEdit && widget.actions.onEditRuntime != null) ...[
                const SizedBox(width: 8),
                RaftInlineIconButton(
                  glyph: RaftGlyph.pencil,
                  tooltip: raftText(context, 'Edit runtime config'),
                  onPressed: widget.actions.onEditRuntime,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            rows[i],
          ],
          if (env.isNotEmpty) ...[
            const SizedBox(height: 12),
            RaftSectionEyebrow(raftText(context, 'Environment Variables')),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in env.entries) _envChip(t, e.key, '${e.value}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// `inline-block border border-line-muted bg-layer-card px-2 py-0.5
  /// text-xs font-mono text-foreground-strong theme-brutal:border-2
  /// theme-brutal:border-black theme-brutal:bg-white`.
  Widget _envChip(RaftTokens t, String key, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: t.brutal ? Colors.white : t.colors['layer-card'],
      border: Border.all(
        color: t.brutal ? Colors.black : t.colors['line-muted']!,
        width: t.brutal ? 2 : 1,
      ),
    ),
    child: Text.rich(
      TextSpan(
        text: '$key=',
        children: [
          TextSpan(
            text: '•' * (value.length < 8 ? value.length : 8),
            style: TextStyle(color: t.colors['foreground-muted']),
          ),
        ],
      ),
      style: raftCssText(
        RaftTypography.mono(
          t,
          size: 12,
          line: 16,
          color: t.brutal ? Colors.black : t.strong,
        ),
      ),
    ),
  );

  Widget _createdAgents(BuildContext context, RaftTokens t) {
    final created = (a['createdAgents'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    return Container(
      decoration: section(t),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftSectionHeader(
            label: raftText(context, 'Created Agents'),
            count: created.length,
          ),
          if (created.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < created.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              AgentListRow(
                name: '${created[i]['displayName'] ?? created[i]['name']}',
                avatarUrl: created[i]['avatarUrl'] as String?,
                subtitle:
                    sourceRuntimeDisplayNames['${created[i]['runtime']}'] ??
                    '${created[i]['runtime'] ?? ''}',
                trailing: AgentStatusDot(
                  color: agentActivityDotColor(
                    t,
                    created[i]['status'] == 'active' ? 'online' : 'offline',
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Actions: `px-5 py-4 border-t`, eyebrow mb-3, `space-y-2` full-width
  /// outline md buttons, danger Delete.
  Widget _actions(BuildContext context, RaftTokens t) {
    final buttons = <Widget>[
      if (!external) ...[
        if (widget.actions.onMigrate != null)
          RaftButton(
            label: raftText(context, 'Move to another computer'),
            secondary: true,
            onPressed: widget.busy ? null : widget.actions.onMigrate,
          ),
        if (widget.canControlRuntime) ...[
          RaftButton(
            label: raftText(context, online ? 'Stop Agent' : 'Start Agent'),
            secondary: true,
            onPressed: widget.busy ? null : widget.actions.onStartStop,
          ),
          RaftButton(
            label: raftText(context, 'Restart / Reset'),
            secondary: true,
            onPressed: widget.busy ? null : widget.actions.onRestartReset,
          ),
        ],
      ],
      if (widget.actions.onDelete != null)
        RaftButton(
          label: raftText(context, 'Delete Agent'),
          destructive: true,
          onPressed: widget.busy ? null : widget.actions.onDelete,
        ),
    ];
    return Container(
      decoration: section(t),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftSectionEyebrow(raftText(context, 'Actions')),
          const SizedBox(height: 12),
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            buttons[i],
          ],
        ],
      ),
    );
  }
}

/// AvatarListRow inside SurfaceListItem (created agents / chat lists).
class AgentListRow extends StatelessWidget {
  const AgentListRow({
    super.key,
    required this.name,
    this.avatarUrl,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
  final String name;
  final String? avatarUrl, subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AgentSurfaceItem(
        child: Row(
          children: [
            AgentAvatarSlot(
              name: name,
              avatarUrl: avatarUrl,
              size: 32,
              border: 2,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: raftCssText(
                      RaftTypography.body(
                        t,
                        size: 14,
                        line: 20,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: raftCssText(
                        RaftTypography.mono(t, size: 12, line: 16),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Web SurfaceListItem: brutal card surface (`border-2 border-black bg-white
/// shadow-brutal-sm`, `p-4`) / elegant hairline card.
class AgentSurfaceItem extends StatelessWidget {
  const AgentSurfaceItem({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final s = RaftCardRecipe.resolve(
      theme: raftRecipeTheme(t),
      tokens: rt,
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
    ).root;
    return Container(
      padding: s.padding == EdgeInsets.zero ? const EdgeInsets.all(16) : s.padding,
      decoration: s.decoration(rt),
      child: child,
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

/// AgentDetailPanel activity tab: diagnostics header + AgentActivityLog.
class AgentActivityTab extends StatefulWidget {
  const AgentActivityTab({
    super.key,
    required this.controller,
    required this.agentId,
    required this.formatter,
  });
  final WorkspaceController controller;
  final String agentId;
  final SourceTimeFormatter formatter;
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

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ColoredBox(
      color: t.brutal ? Colors.white : t.colors['layer-panel']!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // `flex items-center justify-between border-b theme-brutal:border-b-2
          // border-line-muted theme-brutal:border-black px-5 py-2`.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: t.brutal ? Colors.black : t.colors['line-muted']!,
                  width: t.brutal ? 2 : 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: RaftSectionEyebrow(
                    raftText(context, 'Activity Diagnostics'),
                  ),
                ),
                RaftPanelIconButton(
                  glyph: RaftGlyph.copy,
                  tooltip: raftText(context, 'Copy diagnostic info'),
                  onPressed: () => Clipboard.setData(
                    ClipboardData(
                      text: [
                        for (final e in entries) '${e['timestamp']} ${e['entry']}',
                      ].join('\n'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty && !loading
                ? Center(
                    child: Text(
                      raftText(context, loadError ?? 'No activity yet'),
                      style: RaftTypography.body(t, size: 14, line: 20),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [for (final e in entries) _entry(context, t, e)],
                  ),
          ),
        ],
      ),
    );
  }

  static String _toolLabel(String name) => switch (name) {
    'shell' || 'bash' || 'Bash' => 'Running command',
    'read' || 'Read' => 'Reading file',
    'write' || 'Write' => 'Writing file',
    'edit' || 'Edit' => 'Editing file',
    _ => 'Using $name',
  };

  Widget _entry(BuildContext context, RaftTokens t, Map<String, dynamic> item) {
    final entry = item['entry'] is Map
        ? Map<String, dynamic>.from(item['entry'] as Map)
        : <String, dynamic>{};
    final time = widget.formatter
        .clock(item['timestamp'], seconds: true)
        .toUpperCase();
    final kind = entry['kind'];
    final strong = t.brutal ? Colors.black : t.strong;
    final primaryStyle = raftCssText(
      RaftTypography.body(t, size: 14, line: 20, weight: FontWeight.w500, color: strong),
    );
    final monoMuted = raftCssText(
      RaftTypography.mono(
        t,
        size: 12,
        line: 16,
        color: raftPanelInk(t, .5, t.colors['foreground-muted']!),
      ),
    );
    late final Color dot;
    late final Widget body;
    var vertical = 6.0;
    switch (kind) {
      case 'status':
        vertical = 4;
        dot = agentActivityDotColor(t, '${entry['activity']}');
        final detail = '${entry['detail'] ?? ''}';
        body = Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: raftText(
                  context,
                  _activityLabels['${entry['activity']}'] ?? '${entry['activity']}',
                ),
                style: primaryStyle,
              ),
              if (detail.isNotEmpty) ...[
                const WidgetSpan(child: SizedBox(width: 6)),
                TextSpan(
                  text: detail,
                  style: primaryStyle.copyWith(
                    fontWeight: FontWeight.w400,
                    color: raftPanelInk(t, .6, t.colors['foreground-muted']!),
                  ),
                ),
              ],
            ],
          ),
        );
      case 'tool_start':
        dot = t.product.statusBusy;
        body = Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: raftText(context, _toolLabel('${entry['toolName']}')),
                style: primaryStyle,
              ),
              if ('${entry['toolInput'] ?? ''}'.isNotEmpty) ...[
                const WidgetSpan(child: SizedBox(width: 6)),
                // `break-all`: any character may end a line.
                TextSpan(
                  text: '${entry['toolInput']}'.characters.join('\u200B'),
                  // Inline in the `text-sm` (20px) line box.
                  style: monoMuted.copyWith(height: 20 / 12),
                ),
              ],
            ],
          ),
        );
      default:
        dot = switch (kind) {
          'thinking' => t.product.statusBusy,
          'text' => t.product.brutalCyan,
          'slock_action' => _blue300,
          _ => t.product.brutalOrange,
        };
        final title = switch (kind) {
          'thinking' => raftText(context, 'Thinking'),
          'text' => raftText(context, 'Message'),
          _ => '${entry['title'] ?? entry['kind'] ?? ''}',
        };
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: primaryStyle),
            if ('${entry['text'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${entry['text']}',
                  style: monoMuted,
                  // `line-clamp-2` only while a long (>200 chars) entry is
                  // collapsed.
                  maxLines: '${entry['text']}'.length > 200 ? 2 : null,
                  overflow: '${entry['text']}'.length > 200
                      ? TextOverflow.ellipsis
                      : null,
                ),
              ),
          ],
        );
    }
    // `flex items-start gap-2 py-1.5 px-3`; time `font-mono text-xs
    // text-foreground-placeholder theme-brutal:text-black/40 mt-0.5`, dot sm
    // `mt-1.5`.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: vertical),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              time,
              style: raftCssText(
                RaftTypography.mono(
                  t,
                  size: 12,
                  line: 16,
                  color: raftPanelInk(t, .4, t.colors['foreground-placeholder']!),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: AgentStatusDot(color: dot, size: 8),
          ),
          const SizedBox(width: 8),
          Expanded(child: body),
        ],
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
    for (final r in (v is Map ? v[key] ?? const [] : v is List ? v : const []))
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

  Widget _section(BuildContext context, String title, List<Map<String, dynamic>> rows) {
    final t = RaftTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftSectionHeader(label: title, count: rows.length),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text(
              raftText(context, loading ? 'Loading…' : 'None'),
              style: raftCssText(RaftTypography.mono(t, size: 12, line: 16)),
            ),
          for (final r in rows) ...[
            AgentSurfaceItem(
              child: Text(
                '${r['name'] ?? r['displayName'] ?? r['id']}',
                style: RaftTypography.body(
                  t,
                  size: 14,
                  line: 20,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      _section(context, raftText(context, 'Channels'), channels),
      _section(context, raftText(context, 'Direct messages'), dms),
    ],
  );
}

/// AgentRemindersSection variant="tab": `GET /reminders?ownerAgentId=&status=
/// scheduled`, cards with relative + short date-time.
class AgentRemindersTab extends StatefulWidget {
  const AgentRemindersTab({
    super.key,
    required this.controller,
    required this.agentId,
    required this.formatter,
    this.clock,
  });
  final WorkspaceController controller;
  final String agentId;
  final SourceTimeFormatter formatter;
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
    if (p is! Map) return;
    switch (e.name) {
      case 'reminder:fired':
        if (p['ownerAgentId'] != widget.agentId) return;
        setState(() {
          final next = p['nextFireAt'];
          reminders = next is String
              ? [
                  for (final r in reminders)
                    r['reminderId'] == p['reminderId'] ? {...r, 'fireAt': next} : r,
                ]
              : reminders.where((r) => r['reminderId'] != p['reminderId']).toList();
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
      case 'connected':
        reload();
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
    final t = RaftTokens.of(context);
    final muted = raftPanelInk(t, .5, t.colors['foreground-muted']!);
    return Container(
      color: t.brutal ? Colors.white : t.colors['layer-panel'],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (loading)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                raftText(context, 'Loading…'),
                style: RaftTypography.body(
                  t,
                  size: 12,
                  line: 16,
                  weight: FontWeight.w700,
                  color: muted,
                ),
              ),
            ),
          if (loadError != null)
            Text(loadError!, style: RaftTypography.body(t, size: 12, line: 16))
          else if (reminders.isEmpty && !loading)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Column(
                children: [
                  RaftIcon(RaftGlyph.bellRing, size: 28, color: muted),
                  const SizedBox(height: 12),
                  Text(
                    raftText(context, 'No reminders'),
                    style: RaftTypography.body(
                      t,
                      size: 14,
                      line: 20,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < reminders.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _card(context, t, reminders[i]),
            ],
        ],
      ),
    );
  }

  Widget _card(BuildContext context, RaftTokens t, Map<String, dynamic> r) {
    final relative = resourceRelativeTime(
      '${r['fireAt']}',
      now: widget.clock?.call(),
      chinese: Localizations.localeOf(context).languageCode == 'zh',
    );
    final recurrence = r['recurrence'] is Map
        ? '${(r['recurrence'] as Map)['description'] ?? ''}'
        : '';
    final meta = raftPanelInk(t, .5, t.colors['foreground-muted']!);
    return AgentSurfaceItem(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${r['title'] ?? ''}',
            style: raftCssText(
              RaftTypography.body(
                t,
                size: 14,
                line: 20,
                weight: FontWeight.w700,
                color: t.brutal ? Colors.black : t.strong,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // `mt-1 flex flex-wrap items-center gap-2 text-xs`.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RaftIcon(
                    RaftGlyph.clock3,
                    size: 12,
                    color: raftPanelInk(t, .6, t.colors['foreground-muted']!),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    relative,
                    style: raftCssText(
                      RaftTypography.body(
                        t,
                        size: 12,
                        line: 16,
                        weight: FontWeight.w500,
                        color: raftPanelInk(
                          t,
                          .6,
                          t.colors['foreground-muted']!,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                widget.formatter.shortDateTime(r['fireAt']),
                style: raftCssText(
                  RaftTypography.mono(t, size: 12, line: 16, color: meta),
                ),
              ),
              if (recurrence.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: t.brutal
                        ? t.product.brutalLavender.withValues(alpha: .3)
                        : t.colors['accent-soft'],
                    border: Border.all(
                      color: t.brutal ? Colors.black : t.colors['line-muted']!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RaftIcon(RaftGlyph.repeat, size: 11, color: t.strong),
                      const SizedBox(width: 4),
                      Text(
                        recurrence,
                        style: RaftTypography.mono(
                          t,
                          size: 11,
                          line: 16,
                          color: t.strong,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// AgentWorkspace: path bar + expandable file tree
/// (`/agents/:id/workspace-files?dirPath=`).
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
    expanded.add(path);
    setState(() {});
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

  List<Widget> nodes(RaftTokens t, String dir, int depth) => [
    for (final f in children[dir] ?? const <Map<String, dynamic>>[])
      if (showHidden || !'${f['name']}'.startsWith('.')) ...[
        _node(t, f, depth),
        if (f['isDirectory'] == true && expanded.contains(f['path']))
          ...nodes(t, '${f['path']}', depth + 1),
      ],
  ];

  Widget _node(RaftTokens t, Map<String, dynamic> f, int depth) {
    final dir = f['isDirectory'] == true;
    final path = '${f['path']}';
    final open = expanded.contains(path);
    final text = raftCssText(
      RaftTypography.body(
        t,
        size: 14,
        line: 20,
        weight: dir
            ? FontWeight.w500
            : '${f['name']}' == 'memory.md'
            ? FontWeight.w700
            : FontWeight.w400,
      ),
    );
    final folder = t.brutal
        ? t.product.brutalOrange
        : t.colors['warning-strong'] ?? t.strong;
    // `flex w-full items-center gap-1 py-1 pr-2 text-sm`, padding-left
    // depth*16+8 (dirs) / depth*16+22 (files).
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => dir ? toggle(path) : this.open(path),
      child: Padding(
        padding: EdgeInsets.fromLTRB(depth * 16 + (dir ? 8 : 22), 4, 8, 4),
        child: Row(
          children: [
            if (dir) ...[
              Transform.rotate(
                angle: open ? 1.5708 : 0,
                child: RaftIcon(RaftGlyph.chevronRight, size: 14, color: t.strong),
              ),
              const SizedBox(width: 4),
              RaftIcon(
                open ? RaftGlyph.folderOpen : RaftGlyph.folderClosed,
                size: 14,
                color: folder,
              ),
            ] else
              RaftIcon(
                RaftGlyph.fileText,
                size: 14,
                color: raftPanelInk(t, .5, t.colors['foreground-muted']!),
              ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '${f['name']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final hairline = BorderSide(
      color: raftPanelInk(t, .1, t.colors['line-muted']!),
    );
    final path = '~/.slock/agents/${widget.agentId}/';
    final placeholder = raftPanelInk(t, .4, t.colors['foreground-placeholder']!);
    if (openFile != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(border: Border(bottom: hairline)),
            child: Row(
              children: [
                RaftInlineIconButton(
                  glyph: RaftGlyph.arrowLeft,
                  size: 14,
                  tooltip: raftText(context, 'Back'),
                  onPressed: () => setState(() => openFile = null),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    openFile!,
                    style: raftCssText(RaftTypography.mono(t, size: 12, line: 16)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                openContent ?? '',
                style: RaftTypography.mono(t, size: 12, line: 18, color: t.strong),
              ),
            ),
          ),
        ],
      );
    }
    return ColoredBox(
      color: t.brutal ? Colors.white : t.colors['layer-panel']!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Path bar: `flex items-center gap-2 border-b px-3 py-1.5`.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(border: Border(bottom: hairline)),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: raftCssText(
                      RaftTypography.mono(
                        t,
                        size: 12,
                        line: 16,
                        color: raftPanelInk(t, .5, t.colors['foreground-muted']!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                RaftInlineIconButton(
                  glyph: RaftGlyph.copy,
                  tooltip: raftText(context, 'Copy path'),
                  onPressed: () => Clipboard.setData(ClipboardData(text: path)),
                ),
              ],
            ),
          ),
          // Tree header: `flex items-center justify-between border-b px-3
          // py-2`, actions `size-7` hidden toggle (13) + refresh (12).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(border: Border(bottom: hairline)),
            child: Row(
              children: [
                Expanded(child: RaftSectionEyebrow(raftText(context, 'Workspace'))),
                SizedBox.square(
                  dimension: 28,
                  child: Center(
                    child: RaftInlineIconButton(
                      glyph: showHidden ? RaftGlyph.eye : RaftGlyph.eyeOff,
                      size: 13,
                      tooltip: raftText(context, 'Hidden files'),
                      onPressed: () => setState(() => showHidden = !showHidden),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                RaftInlineIconButton(
                  glyph: RaftGlyph.refreshCw,
                  tooltip: raftText(context, 'Refresh'),
                  onPressed: reload,
                ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      raftText(context, 'Loading…'),
                      textAlign: TextAlign.center,
                      style: RaftTypography.mono(t, size: 14, line: 20, color: placeholder),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: loadError != null
                        ? [Text(loadError!, textAlign: TextAlign.center)]
                        : nodes(t, '', 0),
                  ),
          ),
        ],
      ),
    );
  }
}
