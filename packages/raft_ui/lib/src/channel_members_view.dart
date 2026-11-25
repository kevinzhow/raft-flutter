// Web features/channel/ChannelMembers.tsx modal and members-page presentation.
import 'card.dart' show RaftCard;
import 'interaction.dart';
import 'hover_region.dart';

import 'package:flutter/material.dart';

import 'banner.dart';
import 'create_channel_view.dart';
import 'recipe_surface.dart';
import 'recipes/recipe_router.dart' show resolveRecipeClasses;
import 'design_primitives.dart';
import 'dialog_card.dart';
import 'icons.dart';
import 'indicators.dart';
import 'inline_badge_editor.dart' show RaftTouchTargetExpander;
import 'joint_server_badges.dart';
import 'localization.dart';
import 'raft/button.dart' show RaftButton, RaftButtonSize, RaftButtonVariant;
import 'raft/ui_tokens.dart';
import 'recipe_min_height.dart' show RaftMinHeightBox;
import 'system_inset.dart';
import 'text_scaling.dart' show RaftScaled;
import 'status_bar.dart';
import 'error_presentation.dart' show RaftErrorBanner;
import 'theme.dart';
import 'tokens/tokens.dart' show RaftDesktopMetrics, RaftTypeScale;

/// Header trigger: `Button size="sm" className="min-w-7 gap-1 px-1.5"` with
/// `Users size={14}` and the mono participant count (spinner while loading).
class RaftMembersTrigger extends StatelessWidget {
  const RaftMembersTrigger({super.key, required this.count, this.onPressed});
  final int? count;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final n = count;
    return RaftButton(
      uiVariant: RaftButtonVariant.outline,
      uiSize: RaftButtonSize.sm,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      gap: 4,
      tooltip: raftText(context, 'Members'),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RaftIcon(RaftGlyph.users, size: 14),
          const SizedBox(width: 4),
          n == null
              ? const RaftSpinner(size: 12)
              : Text(
                  n > 99 ? '99+' : '$n',
                  style: t.scale(
                    RaftTypeScale.monoMeta,
                    mono: true,
                    weight: FontWeight.w700,
                  ),
                ),
        ],
      ),
    );
  }
}

/// One roster row: adapter-built avatar, label and optional remove action.
@immutable
class RaftMemberRowData {
  const RaftMemberRowData({
    required this.label,
    required this.avatar,
    this.onRemove,
    this.secondary,
    this.secondaryMono = false,
    this.searchText,
    this.badge,
    this.roleLabel,
    this.guest = false,
    this.human = false,
    this.onTap,
    this.roleActionLabel,
    this.roleActionSemantics,
    this.onRoleAction,
    this.roleActionDisabled = false,
    this.serverBadges = const [],
    this.testId,
  });
  final String label;
  final String? searchText;

  /// `JointServerBadges`: the servers a joint-channel member participates
  /// through, shown after the name. Empty for a purely local member.
  final List<String> serverBadges;

  /// Stable id of the row: keys the row (`<id>`), its profile button
  /// (`<id>-open`), role action (`<id>-role`) and remove button (`<id>-remove`).
  final String? testId;
  final Widget avatar;
  final Widget? badge;
  final VoidCallback? onRemove;

  /// Members page: the row body IS the profile button (`onRowClick`).
  final VoidCallback? onTap;

  /// `ChannelMemberHoverActions` role action (`Make admin` / `Demote`):
  /// `Button size="sm" variant="outline" className="h-7 px-2 text-xs"`.
  final String? roleActionLabel, roleActionSemantics;
  final VoidCallback? onRoleAction;
  final bool roleActionDisabled;

  /// `truncate text-xs text-foreground-muted` sub-line of the members page row
  /// (agent activity in `font-mono`, a human's description).
  final String? secondary;
  final bool secondaryMono;

  /// `MemberRoleTag` of the members page (`Channel Admin` / `Guest`).
  final String? roleLabel;
  final bool guest;

  /// Humans render the name `font-bold`, agents `font-medium`.
  final bool human;
}

class RaftChannelMembersModal extends StatelessWidget {
  const RaftChannelMembersModal({
    super.key,
    required this.onClose,
    required this.search,
    required this.channelName,
    this.addView = false,
    this.loading = false,
    this.adding = false,
    this.error,
    this.humans = const [],
    this.agents = const [],
    this.onAdd,
    this.onBack,
    this.hasCandidates = false,
    this.candidateAgents = const [],
    this.candidateHumans = const [],
    this.matchedCandidateKeys,
    this.chips = const [],
    this.failedChoices = const {},
    required this.isChecked,
    required this.onToggle,
    this.canCreateAgent = false,
    this.onCreateAgent,
    this.createAgentName,
    this.joinFailedAgent,
    this.onRetryJoin,
    this.retryingJoin = false,
    this.onConfirm,
    this.page = false,
    this.afterRoster,
  });
  final Widget? afterRoster;
  final VoidCallback onClose;
  final TextEditingController search;
  final String channelName;
  final bool addView, loading, adding, hasCandidates, canCreateAgent;

  /// The pinned "Create Agent" entry of the add view (Web
  /// `add-member-create-agent-entry`); null leaves it inert.
  final VoidCallback? onCreateAgent;

  /// The typed search text when it matches nobody: the entry then reads
  /// "Create agent “{name}”" and steps up to the primary next action.
  final String? createAgentName;

  /// A created agent that could not join the channel (D-state): the banner
  /// names it and offers the retry. Null when there is none.
  final String? joinFailedAgent;
  final VoidCallback? onRetryJoin;
  final bool retryingJoin;
  final String? error;
  final List<RaftMemberRowData> humans, agents;

  /// Roster header "+" (hidden when null: no add capability).
  final VoidCallback? onAdd;
  final VoidCallback? onBack;
  final List<RaftPickerItem> candidateAgents, candidateHumans;
  final List<String>? matchedCandidateKeys;

  /// Selected `(key, label)` pairs in selection order.
  final List<(String, String)> chips;
  final Set<String> failedChoices;
  final bool Function(String key) isChecked;
  final ValueChanged<String> onToggle;
  final VoidCallback? onConfirm;
  final bool page;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final total = humans.length + agents.length;
    if (page) {
      return _MembersPage(modal: this);
    }
    final header = Padding(
      padding: const EdgeInsets.only(bottom: 16), // mb-4
      child: Row(
        children: [
          if (addView) ...[
            RaftButton(
              key: const ValueKey('add-member-back'),
              glyph: RaftGlyph.arrowLeft,
              uiVariant: RaftButtonVariant.ghost,
              uiSize: RaftButtonSize.iconMd,
              tooltip: raftText(context, 'Back to Members'),
              onPressed: onBack,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              addView
                  ? raftText(context, 'Add member')
                  : loading
                  ? raftText(context, 'Members')
                  : '${raftText(context, 'Members')} ($total)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.scale(RaftTypeScale.headline, color: t.ui.foreground),
            ),
          ),
          if (!addView && !loading && onAdd != null) ...[
            RaftButton(
              key: const ValueKey('add-member-open'),
              glyph: RaftGlyph.userPlus,
              uiVariant: RaftButtonVariant.ghost,
              uiSize: RaftButtonSize.iconMd,
              tooltip: raftText(context, 'Add member'),
              disabled: !hasCandidates,
              onPressed: onAdd,
            ),
            const SizedBox(width: 6),
          ],
          RaftCloseButton(
            onPressed: onClose,
            tooltip: 'Close Channel Settings',
          ),
        ],
      ),
    );
    return RaftModalBackdrop(
      child: RaftCard(
        dialog: true,
        maxWidth: 384, // max-w-sm
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (error != null) ...[
              RaftErrorBanner(error!),
              const SizedBox(height: 12),
            ],
            if (addView) ..._addView(context, t) else _roster(context, t),
            if (addView) ?afterRoster,
          ],
        ),
      ),
    );
  }

  Widget _roster(BuildContext context, RaftTokens t) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: RaftSpinner()),
      );
    }
    Widget row(RaftMemberRowData member, int index) =>
        _MemberPageRow(row: member, topRule: index > 0);

    final eyebrowFill = t.colors['fill-muted'];
    return RaftCard(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 288),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (humans.isNotEmpty) ...[
                RaftDialogSectionEyebrow(
                  'Humans',
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  background: eyebrowFill,
                ),
                for (var i = 0; i < humans.length; i++) row(humans[i], i),
              ],
              if (agents.isNotEmpty) ...[
                RaftDialogSectionEyebrow(
                  'Agents',
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  background: eyebrowFill,
                ),
                for (var i = 0; i < agents.length; i++) row(agents[i], i),
              ],
              ?afterRoster,
              if (humans.isEmpty && agents.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  child: Text(
                    raftText(context, 'No members'),
                    textAlign: TextAlign.center,
                    style: raftCssTextStyle(
                      family: t.monoFont,
                      step: RaftTextSteps.sm,
                      color: t.colors['foreground-muted'],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _addView(
    BuildContext context,
    RaftTokens t, {
    bool fill = false,
  }) {
    final list = RaftMemberPickerContent(
      search: search,
      agents: candidateAgents,
      humans: candidateHumans,
      hasCandidates: hasCandidates,
      matchedKeys: matchedCandidateKeys,
      isSelected: isChecked,
      onToggle: adding ? null : onToggle,
      fill: fill,
      showDescriptions: true,
      rowKeyPrefix: 'add-candidate-',
      searchPlaceholder: 'Name',
      emptyLabel: 'All members added',
      footer: _CreateAgentEntry(
        channelName: channelName,
        canCreate: canCreateAgent,
        enabled: !adding,
        promotedName: createAgentName,
        onTap: onCreateAgent,
      ),
    );
    return [
      if (joinFailedAgent != null) ...[
        RaftBanner(
          key: const ValueKey('add-member-create-agent-join-failed'),
          status: RaftBannerRecipeStatus.warning,
          title: raftFormat(
            context,
            'Agent “{name}” was created but could not join {channel}',
            {'name': joinFailedAgent, 'channel': '#$channelName'},
          ),
          description: raftText(
            context,
            'It already exists on this server — do not create another one with the same name. Retry joining instead.',
          ),
          footer: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: RaftButton(
                key: const ValueKey('add-member-create-agent-retry-join'),
                label: 'Retry joining this channel',
                uiVariant: RaftButtonVariant.outline,
                uiSize: RaftButtonSize.md,
                disabled: retryingJoin || adding,
                onPressed: onRetryJoin,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (chips.isNotEmpty) ...[
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (key, label) in chips)
              _SelectedChip(
                label: label,
                failed: failedChoices.contains(key),
                onRemove: adding ? null : () => onToggle(key),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
      if (fill) Expanded(child: list) else list,
      const SizedBox(height: 16), // mt-4
      RaftButton(
        key: const ValueKey('add-member-confirm'),
        label: adding
            ? 'Adding…'
            : raftFormat(context, 'Add Selected ({count})', {
                'count': chips.length,
              }),
        glyph: RaftGlyph.userPlus,
        glyphSize: 14,
        uiVariant: RaftButtonVariant.primary,
        uiSize: RaftButtonSize.lg,
        expand: true,
        disabled: adding || chips.isEmpty,
        onPressed: onConfirm,
      ),
    ];
  }
}

/// Pinned "Create a New Agent" footer: `rounded-chip px-2.5 py-2 gap-2.5`,
/// dashed `size-6 rounded-sticker` plus tile, semibold title + caption line.
class _CreateAgentEntry extends StatelessWidget {
  const _CreateAgentEntry({
    required this.channelName,
    required this.canCreate,
    required this.enabled,
    this.promotedName,
    this.onTap,
  });
  final String channelName;

  /// The `createAgents` capability. Without it the row stays visible but
  /// inert, with the reason under it: hiding it would recreate the dead end
  /// this entry exists to remove.
  final bool canCreate, enabled;
  final String? promotedName;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ink = t.strong;
    final hint = t.colors['foreground-hint'] ?? t.colors['foreground-muted'];
    final promoted = promotedName != null && promotedName!.isNotEmpty;
    final stickerRadius = t.size('radius.sticker', fallback: 4);
    final chipRadius = t.size('radius.chip', fallback: 6);
    Widget plus(Color color) => SizedBox.square(
      dimension: 24,
      child: CustomPaint(
        painter: _DashedBoxPainter(
          color: color,
          width: 1.5,
          radius: stickerRadius,
        ),
        child: Center(child: RaftIcon(RaftGlyph.plus, size: 14, color: color)),
      ),
    );
    if (!canCreate) {
      return Container(
        key: const ValueKey('add-member-create-agent-entry-disabled'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: t.panel),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                plus(t.colors['foreground-disabled']!),
                const SizedBox(width: 10),
                Text(
                  raftText(context, 'Create Agent'),
                  style: t.scale(
                    RaftTypeScale.callout,
                    weight: FontWeight.w600,
                    color: t.colors['foreground-disabled'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              raftText(
                context,
                'You can add members here, but creating Agents on this server needs an owner or admin. Ask one to grant the permission, or have them create the Agent so you can add it.',
              ),
              style: t.scale(RaftTypeScale.caption, color: hint),
            ),
          ],
        ),
      );
    }
    return RaftInteractive(
      onPressed: enabled ? onTap : null,
      semanticLabel: promoted
          ? raftFormat(context, 'Create agent “{name}”', {'name': promotedName})
          : raftText(context, 'Create Agent'),
      builder: (context, st) => Opacity(
        opacity: enabled ? 1 : .5,
        child: Container(
          key: const ValueKey('add-member-create-agent-entry'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(chipRadius),
            color: promoted
                ? t.colors['brand-soft']
                : st.hovered
                ? t.colors['fill-subtle']
                : t.panel,
          ),
          child: Row(
            children: [
              plus(promoted ? ink : (hint ?? ink)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promoted
                          ? raftFormat(context, 'Create agent “{name}”', {
                              'name': promotedName,
                            })
                          : raftText(context, 'Create Agent'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.scale(
                        RaftTypeScale.callout,
                        weight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                    Text(
                      raftFormat(
                        context,
                        'Joins {channel} automatically after creation',
                        {'channel': '#$channelName'},
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.scale(RaftTypeScale.caption, color: hint),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBoxPainter extends CustomPainter {
  _DashedBoxPainter({
    required this.color,
    required this.width,
    required this.radius,
  });
  final Color color;
  final double width, radius;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    final inset = width / 2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - width, size.height - width),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rect);
    final dash = width * 2;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += dash * 2) {
        canvas.drawPath(
          metric.extractPath(d, (d + dash).clamp(0, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBoxPainter old) =>
      old.color != color || old.width != width || old.radius != radius;
}

class _SelectedChip extends StatelessWidget {
  const _SelectedChip({
    required this.label,
    required this.failed,
    required this.onRemove,
  });
  final String label;
  final bool failed;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftBadge(
      label: label,
      appearance: RaftBadgeRecipeAppearance.soft,
      variant: failed
          ? RaftBadgeRecipeVariant.warning
          : RaftBadgeRecipeVariant.default_,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (failed) ...[
            const RaftIcon(RaftGlyph.triangleAlert, size: 12),
            const SizedBox(width: 4),
            Text(
              raftText(context, 'Failed to add'),
              style: t.scale(RaftTypeScale.caption),
            ),
          ],
          RaftButton(
            tooltip: raftFormat(context, 'Deselect {name}', {'name': label}),
            semanticLabel: raftFormat(context, 'Deselect {name}', {
              'name': label,
            }),
            glyph: RaftGlyph.x,
            glyphSize: 14,
            uiVariant: RaftButtonVariant.ghost,
            uiSize: RaftButtonSize.iconXs,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The drawer-internal members page (ChannelMembers presentation="page"): the
// page the Web OverflowSheet mounts, bare, when the Members strip is opened
// (desktop drawer and the phone's full-screen drawer alike).
//
// Its column insets differ BY DESIGN and are reproduced as such, not unified:
//   header      px-4  (16)  - back button, title, count Badge
//   search      px-4  (16)  - `shrink-0 border-b px-4 py-3`
//   group head  px-0 + border => 1 (`[--sidebar-row-inset-x:0px]`)
//   member row  px-3  (12)  - ChannelMemberRow, role tag right edge at 12
//   Add button  p-3   (12)  - `border-t-2 p-3`, so wider than the search field
//   add view    px-4  (16)  - search, candidate list card and confirm button
// ---------------------------------------------------------------------------

class _MembersPage extends StatefulWidget {
  const _MembersPage({required this.modal});
  final RaftChannelMembersModal modal;
  @override
  State<_MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<_MembersPage> {
  final rosterSearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    rosterSearch.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    rosterSearch.dispose();
    super.dispose();
  }

  RaftChannelMembersModal get m => widget.modal;

  Widget _header(BuildContext context, RaftTokens t, int total) {
    final back = RaftTouchTargetExpander(
      minSize: const Size.square(RaftMetrics.touchTarget),
      child: RaftButton(
        key: m.addView
            ? const ValueKey('add-member-back')
            : const ValueKey('member-page-back'),
        glyph: RaftGlyph.arrowLeft,
        uiVariant: RaftButtonVariant.ghost,
        uiSize: t.desktop ? RaftButtonSize.iconMd : RaftButtonSize.iconLg,
        physicalHeight: t.desktop ? RaftDesktopMetrics.barButtonSize : null,
        visualWidth: t.desktop ? RaftDesktopMetrics.barButtonSize : null,
        tooltip: raftText(context, m.addView ? 'Back to Members' : 'Back'),
        semanticLabel: raftText(
          context,
          m.addView ? 'Back to Members' : 'Back',
        ),
        onPressed: m.addView ? m.onBack : m.onClose,
      ),
    );
    // raft-ui `PanelHeader`: the shared panel header role.
    final headerColor = t.colors['layer-member-header']!;
    final headerHeight = RaftLayoutMetrics.shellHeaderHeight(
      t,
      MediaQuery.sizeOf(context).height,
    );
    return RaftStatusBarSource(
      color: headerColor,
      child: Container(
        height: headerHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: headerColor,
          border: Border(
            bottom: BorderSide(color: t.colors['line-seam']!, width: 1),
          ),
        ),
        child: Row(
          children: [
            back,
            const SizedBox(width: 8),
            Flexible(
              child: Semantics(
                header: true,
                child: Text(
                  m.addView
                      ? raftText(context, 'Add member')
                      : raftText(context, 'Members'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.scale(
                    RaftTypeScale.headline,
                    color: t.ui.foreground,
                  ),
                ),
              ),
            ),
            if (!m.addView && !m.loading) ...[
              const SizedBox(width: 8),
              RaftBadge(
                key: const ValueKey('member-page-count'),
                label: '$total',
                appearance: RaftBadgeRecipeAppearance.outline,
                variant: RaftBadgeRecipeVariant.muted,
                fontFamily: t.monoFont,
              ),
            ],
            if (!m.addView && m.loading) ...[
              const SizedBox(width: 8),
              const RaftSpinner(size: 14),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final total = m.humans.length + m.agents.length;
    final paper = t.panel;
    // Edge-to-edge: the page reaches the screen's bottom edge, so its bottom
    // controls pad themselves by the system gesture / navigation bar inset.
    final inset = raftBottomInset(context);
    return RaftNavigationBarStyle(
      background: paper,
      child: Material(
        color: paper,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: t.strong),
          child: Column(
            key: const ValueKey('member-page'),
            children: [
              _header(context, t, total),
              Expanded(
                child: m.addView
                    ? Padding(
                        // `flex min-h-0 flex-1 flex-col px-4 py-3`
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + inset),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (m.error != null) ...[
                              RaftErrorBanner(m.error!),
                              const SizedBox(height: 12),
                            ],
                            ...m._addView(context, t, fill: true),
                          ],
                        ),
                      )
                    : _roster(context, t, inset),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roster(BuildContext context, RaftTokens t, double bottomInset) {
    final query = rosterSearch.text.trim().toLowerCase();
    bool matches(RaftMemberRowData r) =>
        query.isEmpty ||
        (r.searchText ?? r.label).toLowerCase().contains(query);
    final humans = [
      for (final h in m.humans)
        if (matches(h)) h,
    ];
    final agents = [
      for (final a in m.agents)
        if (matches(a)) a,
    ];
    final total = m.humans.length + m.agents.length;
    final muted = t.colors['foreground-muted'];
    TextStyle note() => raftCssTextStyle(
      family: t.monoFont,
      step: RaftTextSteps.sm,
      color: muted,
    );
    final rule = BorderSide(color: t.colors['line-hairline']!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (m.error != null)
          // `m-3 shrink-0 font-bold`
          Padding(
            padding: const EdgeInsets.all(12),
            child: RaftErrorBanner(m.error!),
          ),
        Container(
          // `shrink-0 border-b border-line-muted px-4 py-3`
          key: const ValueKey('member-page-search'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: rule)),
          child: RaftDialogTextInput(
            controller: rosterSearch,
            placeholder: 'Search members…',
            leadingGlyph: RaftGlyph.search,
            enabled: !m.loading,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            // Without the pinned Add footer the last row must scroll clear
            // of the system bar; with it the footer pads itself.
            padding: EdgeInsets.only(
              bottom: !m.loading && m.onAdd != null ? 0 : bottomInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (m.loading)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 128),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const RaftSpinner(size: 14),
                          const SizedBox(width: 8),
                          Text(
                            raftText(context, 'Loading members…'),
                            style: note(),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!m.loading && humans.isNotEmpty)
                  _MemberSection(
                    key: const ValueKey('member-page-section-humans'),
                    label: raftText(context, 'Humans'),
                    count: humans.length,
                    rows: humans,
                  ),
                if (!m.loading && agents.isNotEmpty)
                  _MemberSection(
                    key: const ValueKey('member-page-section-agents'),
                    label: raftText(context, 'Agents'),
                    count: agents.length,
                    rows: agents,
                  ),
                ?m.afterRoster,
                if (!m.loading && total == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    child: Text(
                      raftText(context, 'No members'),
                      textAlign: TextAlign.center,
                      style: note(),
                    ),
                  ),
                if (!m.loading && total > 0 && humans.isEmpty && agents.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    child: Text(
                      raftFormat(context, 'No members match "{query}"', {
                        'query': rosterSearch.text.trim(),
                      }),
                      textAlign: TextAlign.center,
                      style: note(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!m.loading && m.onAdd != null)
          Container(
            // `shrink-0 border-t border-line-seam p-3`;
            // the system inset is added so the button clears the gesture bar.
            padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomInset),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: t.colors['line-seam']!, width: 1),
              ),
            ),
            child: RaftButton(
              key: const ValueKey('add-member-open'),
              label: raftText(context, 'Add member'),
              glyph: RaftGlyph.userPlus,
              glyphSize: 14,
              uiVariant: RaftButtonVariant.outline,
              uiSize: RaftButtonSize.lg,
              expand: true,
              disabled: !m.hasCandidates,
              onPressed: m.onAdd,
            ),
          ),
      ],
    );
  }
}

/// `MemberPageSection`: a `SidebarSection` disclosure (starts open) over the
/// member rows. Header `mt-4 h-8 px-0` / `border border-transparent text-xs
/// font-medium`.
class _MemberSection extends StatefulWidget {
  const _MemberSection({
    super.key,
    required this.label,
    required this.count,
    required this.rows,
  });
  final String label;
  final int count;
  final List<RaftMemberRowData> rows;
  @override
  State<_MemberSection> createState() => _MemberSectionState();
}

class _MemberSectionState extends State<_MemberSection> {
  bool open = true;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final fg = t.colors['foreground-icon']!;
    final title = raftCssTextStyle(
      family: t.headingFont,
      step: RaftTextSteps.xs,
      weight: FontWeight.w500,
      color: fg,
    ).copyWith(letterSpacing: 0);
    final count = raftCssTextStyle(
      family: t.bodyFont,
      step: RaftTextSteps.xs,
      weight: FontWeight.w500,
      color: fg,
    );
    final reduce = MediaQuery.disableAnimationsOf(context);
    final trailingChevron =
        !RaftInteraction.of(context).touch &&
        MediaQuery.sizeOf(context).width >= RaftLayoutMetrics.desktopBreakpoint;
    final countStyle = trailingChevron
        ? t.scale(
            RaftTypeScale.monoMeta,
            mono: true,
            color: t.ui.foregroundMuted,
          )
        : count;
    final chevron = AnimatedRotation(
      turns: open ? .25 : 0,
      duration: reduce ? Duration.zero : const Duration(milliseconds: 150),
      child: RaftIcon(RaftGlyph.chevronRight, size: 12, color: fg),
    );
    final header = RaftMinHeightBox(
      height: 32,
      child: RaftHoverRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => open = !open),
          child: Semantics(
            button: true,
            expanded: open,
            child: Padding(
              padding: trailingChevron
                  ? const EdgeInsets.fromLTRB(16, 8, 18, 0)
                  : EdgeInsets.symmetric(horizontal: t.border),
              child: Row(
                children: [
                  if (!trailingChevron) ...[
                    SizedBox.square(
                      dimension: 18,
                      child: Center(
                        child: Opacity(opacity: .55, child: chevron),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ] else
                    const SizedBox(width: 24, height: 18),
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: RaftScaled.grows(context) ? null : 1,
                      overflow: RaftScaled.grows(context)
                          ? TextOverflow.clip
                          : TextOverflow.ellipsis,
                      style: title,
                    ),
                  ),
                  // `{" · "}{count}` inside a flex item: the leading space collapses.
                  Text(' · ${widget.count}', style: countStyle),
                  if (trailingChevron) ...[
                    const Spacer(),
                    SizedBox.square(
                      dimension: 24,
                      child: Center(
                        child: Opacity(opacity: .55, child: chevron),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        trailingChevron
            ? header
            : Padding(padding: const EdgeInsets.only(top: 16), child: header),
        if (open)
          if (trailingChevron)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 2,
                children: [
                  for (var i = 0; i < widget.rows.length; i++)
                    _MemberPageRow(row: widget.rows[i], topRule: i > 0),
                ],
              ),
            )
          else
            for (var i = 0; i < widget.rows.length; i++)
              _MemberPageRow(row: widget.rows[i], topRule: i > 0),
      ],
    );
  }
}

/// The shared Web ChannelMemberList row, with separate profile and action targets.
class _MemberPageRow extends StatefulWidget {
  const _MemberPageRow({required this.row, this.topRule = false});
  final RaftMemberRowData row;
  final bool topRule;
  @override
  State<_MemberPageRow> createState() => _MemberPageRowState();
}

class _MemberPageRowState extends State<_MemberPageRow> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final r = widget.row;
    final wide =
        MediaQuery.sizeOf(context).width >= RaftLayoutMetrics.desktopBreakpoint;
    final tag = r.roleLabel == null
        ? null
        : RaftBadge(
            label: r.roleLabel!,
            appearance: RaftBadgeRecipeAppearance.outline,
            fontFamily: t.monoFont,
          );
    final roleAction = r.onRoleAction == null || r.roleActionLabel == null
        ? null
        : _RoleActionButton(
            key: r.testId == null ? null : ValueKey('${r.testId}-role'),
            label: r.roleActionLabel!,
            semantics: r.roleActionSemantics,
            disabled: r.roleActionDisabled,
            onPressed: r.onRoleAction!,
          );
    final remove = r.onRemove == null
        ? null
        : _RemoveMemberButton(
            key: r.testId == null ? null : ValueKey('${r.testId}-remove'),
            label: r.label,
            onPressed: r.onRemove!,
          );
    // `ChannelMemberHoverActions`: `flex items-center gap-2`.
    final actions = roleAction == null && remove == null
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [?roleAction, ?remove],
          );
    Widget? trailing;
    // Hover swaps the role tag for the actions: a pointer affordance. A finger
    // has no hover, so touch keeps both in view at any width.
    if (wide &&
        !RaftInteraction.of(context).touch &&
        (tag != null || actions != null)) {
      trailing = Stack(
        alignment: Alignment.centerRight,
        children: [
          if (tag != null)
            Visibility(
              visible: !(hovered && actions != null),
              maintainSize: true,
              maintainState: true,
              maintainAnimation: true,
              child: tag,
            ),
          if (actions != null)
            Visibility(
              visible: hovered,
              maintainSize: true,
              maintainState: true,
              maintainAnimation: true,
              child: actions,
            ),
        ],
      );
    } else if (tag != null || actions != null) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tag != null) tag,
          if (tag != null && actions != null) const SizedBox(width: 8),
          if (actions != null) actions,
        ],
      );
    }
    // Above the default text size the name and detail wrap instead of
    // truncating, and the role tag / actions move under them.
    final grows = RaftScaled.grows(context);
    final stacked = grows ? trailing : null;
    if (grows) trailing = null;
    final short = MediaQuery.sizeOf(context).height <= 600;
    final rowStyle = resolveRecipeClasses(
      [
        'font-sans',
        'items-center',
        'gap-3',
        'px-4',
        short ? 'min-h-0' : 'min-h-16',
        short ? 'py-1.5' : 'py-2.5',
        if (!short && wide) 'pointer-coarse:min-h-14',
        'hover:bg-fill-subtle',
      ],
      t.recipeStates(
        hovered: hovered,
        responsive: true,
        pointerCoarse: RaftInteraction.of(context).touch,
      ),
      t.recipeTokens,
    );
    final titleStyle = resolveRecipeClasses(
      const ['text-subhead', 'font-semibold', 'text-foreground'],
      t.recipeStates(),
      t.recipeTokens,
    ).text(t.recipeTokens, base: TextStyle(fontFamily: t.headingFont));
    final subStyle =
        resolveRecipeClasses(
          const ['text-caption', 'text-foreground-hint'],
          t.recipeStates(),
          t.recipeTokens,
        ).text(
          t.recipeTokens,
          base: TextStyle(
            fontFamily: r.secondaryMono ? t.monoFont : t.headingFont,
          ),
        );
    return RaftHoverRegion(
      key: r.testId == null ? null : ValueKey<String>(r.testId!),
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: Stack(
        children: [
          RaftRecipeBox(
            style: rowStyle,
            tokens: t.recipeTokens,
            applyText: false,
            child: Row(
              children: [
                Expanded(
                  child: _RowTap(
                    key: r.testId == null ? null : ValueKey('${r.testId}-open'),
                    onTap: r.onTap,
                    child: Row(
                      children: [
                        r.avatar,
                        SizedBox(width: rowStyle.columnGap ?? 0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: RaftMemberNameLine(
                                      labels: r.serverBadges,
                                      name: Text(
                                        r.label,
                                        maxLines: grows ? null : 1,
                                        overflow: grows
                                            ? TextOverflow.clip
                                            : TextOverflow.ellipsis,
                                        style: titleStyle,
                                      ),
                                    ),
                                  ),
                                  if (r.badge case final badge?) ...[
                                    const SizedBox(width: 6),
                                    badge,
                                  ],
                                ],
                              ),
                              if (r.secondary case final secondary?
                                  when secondary.isNotEmpty)
                                Text(
                                  secondary,
                                  maxLines: grows ? null : 1,
                                  overflow: grows
                                      ? TextOverflow.clip
                                      : TextOverflow.ellipsis,
                                  style: subStyle,
                                ),
                              if (stacked != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: stacked,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  SizedBox(width: rowStyle.columnGap ?? 0),
                  trailing,
                ],
              ],
            ),
          ),
          if (widget.topRule)
            Positioned(
              top: 0,
              left: 63,
              right: 0,
              height: 1,
              child: IgnorePointer(
                child: ColoredBox(
                  key: r.testId == null ? null : ValueKey('${r.testId}-rule'),
                  color: t.colors['line-hairline']!,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `ChannelMemberRemoveButton` (member-management rows): ghost `icon-md` Button
/// with `UserMinus`.
class _RemoveMemberButton extends StatelessWidget {
  const _RemoveMemberButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return RaftButton(
      glyph: RaftGlyph.userMinus,
      uiVariant: RaftButtonVariant.ghost,
      uiSize: RaftButtonSize.iconMd,
      tooltip: 'Remove $label',
      semanticLabel: 'Remove $label',
      onPressed: onPressed,
    );
  }
}

/// The row body as the profile `<button>` (`flex min-w-0 flex-1 items-start
/// gap-2 text-left`); inert when the row has no profile to open.
class _RowTap extends StatelessWidget {
  const _RowTap({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => onTap == null
      ? child
      : RaftInteractive(onPressed: onTap, builder: (context, state) => child);
}

/// `ChannelMemberHoverActions` role action: outline `Button size="md"`.
class _RoleActionButton extends StatelessWidget {
  const _RoleActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.semantics,
    this.disabled = false,
  });
  final String label;
  final String? semantics;
  final bool disabled;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    label: semantics,
    child: RaftButton(
      label: label,
      uiVariant: RaftButtonVariant.outline,
      uiSize: RaftButtonSize.md,
      disabled: disabled,
      onPressed: onPressed,
    ),
  );
}
