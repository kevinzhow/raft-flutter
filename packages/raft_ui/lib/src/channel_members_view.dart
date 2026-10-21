// Presentation of the Web ChannelMembers "modal" presentation
// (packages/web/src/components/agent/ChannelMembers.tsx): header trigger,
// Modal Card `max-w-sm p-6` with the roster and the staged multi-select
// Add Member view (search, AGENTS / HUMANS candidates with CheckMarker +
// AvatarSlot compact-list + description tooltip, pinned "Create a New Agent"
// entry, "Add selected (N)"). The app adapter owns roster data, selection and
// commands.
import 'interaction.dart';
import 'hover_region.dart';

import 'package:flutter/material.dart';

import 'create_channel_view.dart';
import 'design_primitives.dart';
import 'dialog_card.dart';
import 'icons.dart';
import 'indicators.dart';
import 'inline_badge_editor.dart' show RaftTouchTargetExpander;
import 'joint_server_badges.dart';
import 'localization.dart';
import 'recipe_min_height.dart' show RaftMinHeightBox;
import 'recipes/button_variants.g.dart';
import 'system_inset.dart';
import 'text_scaling.dart' show RaftScaled;
import 'status_bar.dart';
import 'theme.dart';
import 'tooltip.dart';

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
    return RaftRecipeButton(
      size: RaftButtonRecipeSize.sm,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      gap: 4,
      tooltip: raftText(context, 'View participants'),
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
                  style: TextStyle(
                    fontFamily: t.monoFont,
                    fontSize: 11,
                    height: 1,
                    fontWeight: FontWeight.w700,
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

  /// `JointServerBadges`: the servers a joint-channel member participates
  /// through, shown after the name. Empty for a purely local member.
  final List<String> serverBadges;

  /// Stable id of the row: keys the row (`<id>`), its profile button
  /// (`<id>-open`), role action (`<id>-role`) and remove button (`<id>-remove`).
  final String? testId;
  final Widget avatar;
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
    this.chips = const [],
    required this.isChecked,
    required this.onToggle,
    this.canCreateAgent = false,
    this.onConfirm,
    this.page = false,
  });
  final VoidCallback onClose;
  final TextEditingController search;
  final String channelName;
  final bool addView, loading, adding, hasCandidates, canCreateAgent;
  final String? error;
  final List<RaftMemberRowData> humans, agents;

  /// Roster header "+" (hidden when null: no add capability).
  final VoidCallback? onAdd;
  final VoidCallback? onBack;
  final List<RaftPickerItem> candidateAgents, candidateHumans;

  /// Selected `(key, label)` pairs in selection order.
  final List<(String, String)> chips;
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
            RaftRecipeButton(
              key: const ValueKey('add-member-back'),
              glyph: RaftGlyph.arrowLeft,
              variant: RaftButtonRecipeVariant.outline,
              size: RaftButtonRecipeSize.sm,
              padding: const EdgeInsets.all(4),
              tooltip: raftText(context, 'Back to members'),
              onPressed: onBack,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              addView
                  ? raftText(context, 'Add Member')
                  : loading
                  ? raftText(context, 'Members')
                  : '${raftText(context, 'Members')} ($total)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: raftCssTextStyle(
                family: t.headingFont,
                step: RaftTextSteps.lg,
                weight: FontWeight.w700,
                color: t.strong,
              ),
            ),
          ),
          if (!addView && !loading && onAdd != null) ...[
            RaftRecipeButton(
              key: const ValueKey('add-member-open'),
              glyph: RaftGlyph.plus,
              variant: RaftButtonRecipeVariant.outline,
              size: RaftButtonRecipeSize.sm,
              padding: const EdgeInsets.all(4),
              tooltip: raftText(context, 'Add Member'),
              disabled: !hasCandidates,
              onPressed: onAdd,
            ),
            const SizedBox(width: 6),
          ],
          RaftCloseButton(
            onPressed: onClose,
            tooltip: 'Close channel settings',
          ),
        ],
      ),
    );
    return RaftModalBackdrop(
      child: RaftRecipeCard(
        maxWidth: 384, // max-w-sm
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (error != null) ...[
              RaftWarningBanner(error!),
              const SizedBox(height: 12),
            ],
            if (addView) ..._addView(context, t) else _roster(context, t),
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
    Widget row(RaftMemberRowData m) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          m.avatar,
          const SizedBox(width: 8),
          Expanded(
            child: RaftMemberNameLine(
              labels: m.serverBadges,
              name: Text(
                m.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: raftCssTextStyle(
                  family: t.headingFont,
                  step: RaftTextSteps.sm,
                  weight: FontWeight.w500,
                  color: t.strong,
                ),
              ),
            ),
          ),
          if (m.onRemove != null)
            RaftIconButton(
              glyph: RaftGlyph.x,
              tooltip: 'Remove ${m.label}',
              visualSize: 24,
              onPressed: m.onRemove,
            ),
        ],
      ),
    );

    final eyebrowFill = t.brutal
        ? Colors.white.withValues(alpha: .5)
        : t.colors['fill-muted'];
    return RaftRecipeCard(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 288),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (humans.isNotEmpty) ...[
                RaftDialogSectionEyebrow(
                  'Humans',
                  uppercase: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  background: eyebrowFill,
                ),
                for (final h in humans) row(h),
              ],
              if (agents.isNotEmpty) ...[
                RaftDialogSectionEyebrow(
                  'Agents',
                  uppercase: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  background: eyebrowFill,
                ),
                for (final a in agents) row(a),
              ],
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
    final query = search.text;
    Widget eyebrow(String text) => RaftDialogSectionEyebrow(
      text,
      uppercase: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      background: t.brutal
          ? Colors.white.withValues(alpha: .5)
          : t.colors['fill-muted'],
      color: t.brutal ? Colors.black : null,
    );
    Widget candidateRow(RaftPickerItem c) => _CandidateRow(
      key: ValueKey('add-candidate-${c.key}'),
      candidate: c,
      checked: isChecked(c.key),
      disabled: adding,
      onTap: () => onToggle(c.key),
    );

    final mutedText = raftCssTextStyle(
      family: t.monoFont,
      step: RaftTextSteps.sm,
      color: t.colors['foreground-muted'],
    );
    final list = Container(
      // flex flex-col border bg-layer-panel shadow-raft-sm, brutal border-2
      // border-black bg-white shadow-brutal-sm, max-h-72 (the members page
      // fills the remaining height: `min-h-0 flex-1`).
      constraints: fill ? null : const BoxConstraints(maxHeight: 288),
      decoration: BoxDecoration(
        color: t.brutal ? Colors.white : t.panel,
        border: Border.all(
          color: t.brutal ? Colors.black : t.colors['line-muted']!,
          width: t.brutal ? 2 : 1,
        ),
        boxShadow: t.brutal ? RaftShadowSet.brutalSm : t.themeShadows.sm.outer,
      ),
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            fit: fill ? FlexFit.tight : FlexFit.loose,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (candidateAgents.isNotEmpty) ...[
                    eyebrow('Agents'),
                    for (final c in candidateAgents) candidateRow(c),
                  ],
                  if (candidateHumans.isNotEmpty) ...[
                    eyebrow('Humans'),
                    for (final c in candidateHumans) candidateRow(c),
                  ],
                  if (!hasCandidates)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      child: Text(
                        raftText(context, 'All members added'),
                        textAlign: TextAlign.center,
                        style: mutedText,
                      ),
                    )
                  else if (candidateAgents.isEmpty && candidateHumans.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      child: Text(
                        raftFormat(context, 'No matches for "{query}"', {
                          'query': query.trim(),
                        }),
                        textAlign: TextAlign.center,
                        style: mutedText,
                      ),
                    ),
                ],
              ),
            ),
          ),
          _CreateAgentEntry(
            channelName: channelName,
            enabled: canCreateAgent && !adding,
          ),
        ],
      ),
    );
    return [
      if (chips.isNotEmpty) ...[
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (key, label) in chips)
              _SelectedChip(
                label: label,
                agent: key.startsWith('agent:'),
                onRemove: adding ? null : () => onToggle(key),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
      if (hasCandidates)
        Padding(
          padding: const EdgeInsets.only(bottom: 12), // mb-3
          child: RaftProductFormField(
            label: 'Search',
            uppercase: false,
            child: RaftDialogTextInput(
              controller: search,
              placeholder: 'Name',
              leadingGlyph: RaftGlyph.search,
              autofocus: !page && RaftInteraction.of(context).pointer,
            ),
          ),
        ),
      if (fill) Expanded(child: list) else list,
      const SizedBox(height: 16), // mt-4
      RaftRecipeButton(
        key: const ValueKey('add-member-confirm'),
        label: adding
            ? 'Adding…'
            : raftFormat(context, 'Add selected ({count})', {
                'count': chips.length,
              }),
        glyph: RaftGlyph.plus,
        glyphSize: 14,
        variant: RaftButtonRecipeVariant.primary,
        expand: true,
        gap: 6,
        // px-3 py-1.5 text-sm font-bold; theme-brutal:bg-brutal-pink.
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        textStep: RaftTextSteps.sm,
        disabled: adding || chips.isEmpty,
        foreground: t.brutal ? Colors.black : null,
        brutalSurface: (t, hovered) => BoxDecoration(
          color: t.colors['color-brutal-pink'],
          border: Border.all(color: t.colors['line-strong']!, width: 2),
          boxShadow: hovered
              ? t.themeShadows.md.outer
              : t.themeShadows.sm.outer,
        ),
        onPressed: onConfirm,
      ),
    ];
  }
}

/// Multi-select candidate: `flex w-full items-center gap-2 px-3 py-2`,
/// CheckMarker sm, AvatarSlot compact-list (+ activity badge) and the
/// name / truncated description (description carries a Tooltip).
class _CandidateRow extends StatefulWidget {
  const _CandidateRow({
    super.key,
    required this.candidate,
    required this.checked,
    required this.disabled,
    required this.onTap,
  });
  final RaftPickerItem candidate;
  final bool checked, disabled;
  final VoidCallback onTap;
  @override
  State<_CandidateRow> createState() => _CandidateRowState();
}

class _CandidateRowState extends State<_CandidateRow> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final c = widget.candidate;
    final description = c.description?.trim();
    final fill = hovered && !widget.disabled
        ? (t.brutal ? t.colors['color-soft-signal'] : t.colors['fill-muted'])
        : null;
    final ink = t.brutal ? Colors.black : t.strong;
    return Semantics(
      button: true,
      toggled: widget.checked,
      child: RaftHoverRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.disabled ? null : widget.onTap,
          child: Opacity(
            opacity: widget.disabled ? .6 : 1,
            child: Container(
              color: fill,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _CheckMarker(checked: widget.checked),
                  const SizedBox(width: 8),
                  c.avatar,
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: raftCssTextStyle(
                            family: t.headingFont,
                            step: RaftTextSteps.sm,
                            weight: FontWeight.w500,
                            color: ink,
                          ),
                        ),
                        if (description != null && description.isNotEmpty)
                          RaftTooltip(
                            message: description,
                            onlyWhenTruncated: true,
                            child: SizedBox(
                              width: double.infinity,
                              child: Text(
                                description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: raftCssTextStyle(
                                  family: t.headingFont,
                                  step: RaftTextSteps.xs,
                                  color: t.colors['foreground-muted'],
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
          ),
        ),
      ),
    );
  }
}

/// Web CheckMarker sm: `size-3.5 border border-line-strong
/// theme-brutal:border-2 theme-brutal:border-black`, checked black fill with
/// a white `Check size={10} strokeWidth={4}`.
class _CheckMarker extends StatelessWidget {
  const _CheckMarker({required this.checked});
  final bool checked;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: checked
            ? (t.brutal ? Colors.black : t.strong)
            : (t.brutal ? Colors.white : t.panel),
        border: Border.all(
          color: t.brutal ? Colors.black : t.colors['line-strong']!,
          width: t.brutal ? 2 : 1,
        ),
      ),
      child: checked
          ? RaftIcon(
              RaftGlyph.check,
              size: 10,
              strokeWidth: 4,
              color: t.brutal ? Colors.white : t.colors['foreground-inverse'],
            )
          : null,
    );
  }
}

/// Pinned "Create a New Agent" footer: `border-t-2 border-black px-3
/// py-2.5 gap-2.5`, dashed `size-6` plus tile, bold title + auto-join line.
class _CreateAgentEntry extends StatelessWidget {
  const _CreateAgentEntry({required this.channelName, required this.enabled});
  final String channelName;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ink = t.brutal ? Colors.black : t.strong;
    return Opacity(
      opacity: enabled ? 1 : .5,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: t.brutal ? Colors.white : t.panel,
          border: Border(
            top: BorderSide(
              color: t.brutal ? Colors.black : t.colors['line-strong']!,
              width: t.brutal ? 2 : 1,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 24,
              child: CustomPaint(
                painter: _DashedBoxPainter(
                  color: t.brutal ? Colors.black : t.colors['line-strong']!,
                  width: t.brutal ? 2 : 1,
                ),
                child: Center(
                  child: RaftIcon(RaftGlyph.plus, size: 14, color: ink),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    raftText(context, 'Create a New Agent'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: raftCssTextStyle(
                      family: t.headingFont,
                      step: RaftTextSteps.sm,
                      weight: FontWeight.w700,
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
                    style: raftCssTextStyle(
                      family: t.headingFont,
                      step: RaftTextSteps.xs,
                      color: t.brutal
                          ? Colors.black.withValues(alpha: .5)
                          : t.colors['foreground-muted'],
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
}

class _DashedBoxPainter extends CustomPainter {
  _DashedBoxPainter({required this.color, required this.width});
  final Color color;
  final double width;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    // CSS dashed: dash length = 2 * border width, centred on each edge.
    final dash = width * 2;
    final inset = width / 2;
    void edge(Offset a, Offset b) {
      final length = (b - a).distance;
      final dir = (b - a) / length;
      for (double d = 0; d < length; d += dash * 2) {
        canvas.drawLine(
          a + dir * d,
          a + dir * (d + dash).clamp(0, length),
          paint,
        );
      }
    }

    final r = Rect.fromLTWH(
      inset,
      inset,
      size.width - width,
      size.height - width,
    );
    edge(r.topLeft, r.topRight);
    edge(r.topRight, r.bottomRight);
    edge(r.bottomRight, r.bottomLeft);
    edge(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(_DashedBoxPainter old) =>
      old.color != color || old.width != width;
}

class _SelectedChip extends StatelessWidget {
  const _SelectedChip({
    required this.label,
    required this.agent,
    required this.onRemove,
  });
  final String label;
  final bool agent;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final fill = t.brutal
        ? t.colors[agent ? 'color-brutal-cyan' : 'color-brutal-lavender']
        : t.colors[agent ? 'info-soft' : 'accent-soft'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        border: t.brutal ? Border.all(color: Colors.black, width: 2) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 128),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: raftCssTextStyle(
                family: t.headingFont,
                step: RaftTextSteps.xs,
                weight: FontWeight.w700,
                color: t.brutal ? Colors.black : t.strong,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const RaftIcon(RaftGlyph.x, size: 12),
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
//   group head  brutal px-2 + border-2 transparent => chevron box at 10;
//               elegant px-0 + border => 1 (`[--sidebar-row-inset-x:0px]`)
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
      child: RaftRecipeButton(
        key: m.addView
            ? const ValueKey('add-member-back')
            : const ValueKey('member-page-back'),
        glyph: RaftGlyph.arrowLeft,
        glyphSize: 16,
        variant: RaftButtonRecipeVariant.outline,
        size: RaftButtonRecipeSize.iconSm,
        tooltip: raftText(context, m.addView ? 'Back to members' : 'Back'),
        onPressed: m.addView ? m.onBack : m.onClose,
      ),
    );
    final headerColor = (t.brutal
        ? t.colors['color-soft-signal']
        : t.colors['layer-inset'])!;
    return RaftStatusBarSource(
      color: headerColor,
      child: Container(
        // `flex h-panel-header shrink-0 items-center gap-2 border-b
        // border-line-muted bg-layer-inset px-4`, brutal `border-b-2
        // border-black bg-soft-signal`. The drawer portals out of the AppShell,
        // so `h-panel-header` is the 62px fallback.
        height: RaftMetrics.brutalPanelHeader,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: headerColor,
          border: Border(
            bottom: BorderSide(
              color: t.brutal ? Colors.black : t.colors['line-muted']!,
              width: t.brutal ? 2 : 1,
            ),
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
                      ? raftText(context, 'Add Member')
                      : raftText(context, 'Members'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: raftCssTextStyle(
                    family: t.bodyFont,
                    step: RaftTextSteps.base,
                    weight: FontWeight.w700,
                    color: t.brutal ? Colors.black : t.strong,
                  ),
                ),
              ),
            ),
            if (!m.addView && !m.loading) ...[
              const SizedBox(width: 8),
              RaftBadge(
                key: const ValueKey('member-page-count'),
                label: '$total',
                appearance: RaftBadgeRecipeAppearance.soft,
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
    final paper = t.brutal ? Colors.white : t.panel;
    // Edge-to-edge: the page reaches the screen's bottom edge, so its bottom
    // controls pad themselves by the system gesture / navigation bar inset.
    final inset = raftBottomInset(context);
    return RaftNavigationBarStyle(
      background: paper,
      child: Material(
        color: paper,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: t.brutal ? Colors.black : t.strong),
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
                              RaftWarningBanner(m.error!),
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
        query.isEmpty || r.label.toLowerCase().contains(query);
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
      color: t.brutal ? Colors.black.withValues(alpha: .5) : muted,
    );
    final rule = BorderSide(
      color: t.brutal
          ? Colors.black.withValues(alpha: .1)
          : t.colors['line-muted']!,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (m.error != null)
          // `m-3 shrink-0 font-bold`
          Padding(
            padding: const EdgeInsets.all(12),
            child: RaftWarningBanner(m.error!),
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
                      raftFormat(context, 'No matches for "{query}"', {
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
            // `shrink-0 border-t-2 border-line-muted p-3`, brutal `border-black`;
            // the system inset is added so the button clears the gesture bar.
            padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomInset),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: t.brutal ? Colors.black : t.colors['line-muted']!,
                  width: 2,
                ),
              ),
            ),
            child: RaftRecipeButton(
              key: const ValueKey('add-member-open'),
              label: raftText(context, 'Add Member'),
              glyph: RaftGlyph.plus,
              glyphSize: 14,
              variant: RaftButtonRecipeVariant.outline,
              size: RaftButtonRecipeSize.md,
              expand: true,
              gap: 6,
              fontWeight: FontWeight.w700,
              disabled: !m.hasCandidates,
              onPressed: m.onAdd,
            ),
          ),
      ],
    );
  }
}

/// `MemberPageSection`: a `SidebarSection` disclosure (starts open) over the
/// member rows. Brutal header `mt-3 mb-1 h-6 px-2` holding a `h-6 gap-1.5
/// border-2 border-transparent text-xs font-bold tracking-widest` button;
/// elegant `mt-4 h-8 px-0` / `border border-transparent text-xs font-medium`.
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
    final brutal = t.brutal;
    final fg = brutal ? Colors.black : t.colors['foreground-icon']!;
    final title = raftCssTextStyle(
      family: t.headingFont,
      step: RaftTextSteps.xs,
      weight: brutal ? FontWeight.w700 : FontWeight.w500,
      color: fg,
    ).copyWith(letterSpacing: brutal ? 12 * .1 : 0);
    final count = brutal
        ? raftCssTextStyle(
            family: t.monoFont,
            step: RaftTextSteps.xs,
            weight: FontWeight.w500,
            color: Colors.black.withValues(alpha: .7),
          )
        : raftCssTextStyle(
            family: t.bodyFont,
            step: RaftTextSteps.xs,
            weight: FontWeight.w500,
            color: fg,
          );
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: brutal ? 12 : 16,
            bottom: brutal ? 4 : 0,
          ),
          // The toggle row is a minimum height: the label wraps and the row
          // grows once the text is larger than the default.
          child: RaftMinHeightBox(
            height: brutal ? 24 : 32,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: brutal ? 8 : 0),
              child: RaftHoverRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => open = !open),
                  child: Semantics(
                    button: true,
                    expanded: open,
                    child: Padding(
                      // `border-2 border-transparent` (brutal) / `border`
                      padding: EdgeInsets.symmetric(horizontal: t.border),
                      child: Row(
                        children: [
                          SizedBox.square(
                            dimension: 18,
                            child: Center(
                              child: Opacity(
                                opacity: brutal ? 1 : .55,
                                child: AnimatedRotation(
                                  turns: open ? .25 : 0,
                                  duration: reduce
                                      ? Duration.zero
                                      : const Duration(milliseconds: 150),
                                  child: RaftIcon(
                                    RaftGlyph.chevronRight,
                                    size: 12,
                                    color: fg,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
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
                          Text('· ${widget.count}', style: count),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (open)
          for (final r in widget.rows) _MemberPageRow(row: r),
      ],
    );
  }
}

/// `ChannelMemberRow` (row = profile button) with its `MemberRoleTag`
/// trailing slot: `group flex items-start gap-2 px-3 py-2 hover:bg-fill-muted`,
/// avatar `mt-1`, name `truncate text-sm` (human bold, agent medium) over a
/// `truncate text-xs text-foreground-muted` line. From md the role tag and the
/// hover actions share one grid cell (the tag hides while the actions show);
/// below md they sit side by side.
class _MemberPageRow extends StatefulWidget {
  const _MemberPageRow({required this.row});
  final RaftMemberRowData row;
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
    final ink = t.brutal ? Colors.black : t.strong;
    final tag = r.roleLabel == null
        ? null
        : RaftBadge(
            label: r.roleLabel!,
            appearance: RaftBadgeRecipeAppearance.soft,
            variant: r.guest
                ? RaftBadgeRecipeVariant.information
                : RaftBadgeRecipeVariant.muted,
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
    return RaftHoverRegion(
      key: r.testId == null ? null : ValueKey<String>(r.testId!),
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: Container(
        color: hovered ? t.colors['fill-muted'] : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: _RowTap(
                key: r.testId == null ? null : ValueKey('${r.testId}-open'),
                onTap: r.onTap,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: r.avatar,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: RaftMemberNameLine(
                              labels: r.serverBadges,
                              name: Text(
                                r.label,
                                maxLines: grows ? null : 1,
                                overflow: grows
                                    ? TextOverflow.clip
                                    : TextOverflow.ellipsis,
                                style: raftCssTextStyle(
                                  family: t.headingFont,
                                  step: RaftTextSteps.sm,
                                  weight: r.human
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: ink,
                                ),
                              ),
                            ),
                          ),
                          if (r.secondary != null && r.secondary!.isNotEmpty)
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                r.secondary!,
                                maxLines: grows ? null : 1,
                                overflow: grows
                                    ? TextOverflow.clip
                                    : TextOverflow.ellipsis,
                                style: raftCssTextStyle(
                                  family: r.secondaryMono
                                      ? t.monoFont
                                      : t.headingFont,
                                  step: RaftTextSteps.xs,
                                  color: t.colors['foreground-muted'],
                                ),
                              ),
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
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ],
        ),
      ),
    );
  }
}

/// `ChannelMemberRemoveButton` (member-management rows): `h-7 w-7 rounded-sm
/// border border-line-muted bg-danger-soft text-danger-strong` with a
/// `UserMinus size={14}`; brutal square, `border-black bg-brutal-red/20`.
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
    final t = RaftTokens.of(context);
    final fg = t.brutal ? Colors.black : t.colors['danger-strong']!;
    return RaftTooltip(
      message: 'Remove $label',
      child: Semantics(
        button: true,
        label: 'Remove $label',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.brutal
                  ? t.colors['color-brutal-red']!.withValues(alpha: .2)
                  : t.colors['danger-soft'],
              border: Border.all(
                color: t.brutal ? Colors.black : t.colors['line-muted']!,
              ),
              borderRadius: BorderRadius.circular(t.brutal ? 0 : 2),
            ),
            child: RaftIcon(RaftGlyph.userMinus, size: 14, color: fg),
          ),
        ),
      ),
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
      : Semantics(
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: child,
          ),
        );
}

/// `ChannelMemberHoverActions` role action: outline `Button size="sm"` with
/// `h-7 whitespace-nowrap px-2 text-xs`.
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
  Widget build(BuildContext context) => SizedBox(
    height: 28,
    child: Semantics(
      label: semantics,
      child: RaftRecipeButton(
        label: label,
        variant: RaftButtonRecipeVariant.outline,
        size: RaftButtonRecipeSize.sm,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStep: RaftTextSteps.xs,
        disabled: disabled,
        onPressed: onPressed,
      ),
    ),
  );
}
