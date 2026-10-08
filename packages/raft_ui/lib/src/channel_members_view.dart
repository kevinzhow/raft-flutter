// Presentation of the Web ChannelMembers "modal" presentation
// (packages/web/src/components/agent/ChannelMembers.tsx): header trigger,
// Modal Card `max-w-sm p-6` with the roster and the staged multi-select
// Add Member view (search, AGENTS / HUMANS candidates with CheckMarker +
// AvatarSlot compact-list + description tooltip, pinned "Create a New Agent"
// entry, "Add selected (N)"). The app adapter owns roster data, selection and
// commands.
import 'package:flutter/material.dart';

import 'create_channel_view.dart';
import 'design_primitives.dart';
import 'dialog_card.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
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
  });
  final String label;
  final Widget avatar;
  final VoidCallback? onRemove;
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

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final total = humans.length + agents.length;
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
            child: Text(
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
                RaftSectionEyebrow(
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
                RaftSectionEyebrow(
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

  List<Widget> _addView(BuildContext context, RaftTokens t) {
    final query = search.text;
    Widget eyebrow(String text) => RaftSectionEyebrow(
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
      // border-black bg-white shadow-brutal-sm, max-h-72.
      constraints: const BoxConstraints(maxHeight: 288),
      decoration: BoxDecoration(
        color: t.brutal ? Colors.white : t.panel,
        border: Border.all(
          color: t.brutal ? Colors.black : t.colors['line-muted']!,
          width: t.brutal ? 2 : 1,
        ),
        boxShadow: t.brutal ? RaftShadowSet.brutalSm : t.themeShadows.sm.outer,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
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
                        raftText(context, 'No matches for "${query.trim()}"'),
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
              autofocus: true,
            ),
          ),
        ),
      list,
      const SizedBox(height: 16), // mt-4
      RaftRecipeButton(
        key: const ValueKey('add-member-confirm'),
        label: adding
            ? 'Adding…'
            : '${raftText(context, 'Add selected')} (${chips.length})',
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
      child: MouseRegion(
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
                    raftText(
                      context,
                      'Joins #$channelName automatically after creation',
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
