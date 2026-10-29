import 'overlays/dialog.dart' show RaftDialog;
// Presentation of the Web AddMembersDialog
// (packages/web/src/components/channel/AddMembersDialog.tsx), opened from a
// `channel:add_member` action card: DialogCard with the target-channel strip,
// the agent's quoted reason, a warning banner, the framed ChannelMemberList
// (Agents / Humans sections with one row per candidate and a remove-from-list
// button) and Cancel / "Add N members". The adapter owns candidates, selection
// and the batch add.
import 'card.dart' show RaftCard;
import 'hover_region.dart';

import 'package:flutter/material.dart';

import 'design_primitives.dart' show RaftDensity, RaftDensityScope;
import 'dialog_card.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'error_presentation.dart' show RaftErrorBanner;
import 'theme.dart';

/// One candidate row: [avatar] (adapter-built, `members-row`), [name],
/// optional [secondary] line and the remove button's [removeLabel].
@immutable
class RaftAddMemberRow {
  const RaftAddMemberRow({
    required this.key,
    required this.name,
    required this.avatar,
    required this.removeLabel,
    required this.onRemove,
    this.secondary,
    this.human = false,
  });
  final String key, name, removeLabel;
  final String? secondary;
  final Widget avatar;
  final bool human;
  final VoidCallback onRemove;
}

class RaftAddMembersDialogView extends StatelessWidget {
  const RaftAddMembersDialogView({
    super.key,
    required this.channelName,
    required this.agents,
    required this.humans,
    required this.selectedCount,
    required this.onClose,
    required this.onSubmit,
    this.privateChannel = false,
    this.draftHint,
    this.error,
    this.nothingToAdd = false,
    this.submitting = false,
    this.agentSection,
    this.humanSection,
  });
  final String? channelName;
  final bool privateChannel, nothingToAdd, submitting;
  final List<RaftAddMemberRow> agents, humans;

  /// A section header stays while any candidate of its kind exists even after
  /// every row was removed from the list (null: shown when it has rows).
  final bool? agentSection, humanSection;
  final int selectedCount;
  final String? draftHint, error;
  final VoidCallback onClose;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final canSubmit = !submitting && !nothingToAdd && selectedCount > 0;
    return RaftModalBackdrop(
      child: RaftDialog.card(
        title: 'Add Members',
        onClose: onClose,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // `mb-3 flex items-center gap-2 border bg-layer-inset p-2 text-sm`.
            Container(
              key: const ValueKey('add-members-target'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(8.0 + (1)),
              decoration: BoxDecoration(
                color: t.colors['layer-inset'],
                border: Border.all(
                  color: t.colors['line-muted']!,
                  width: t.border,
                ),
              ),
              child: Row(
                spacing: 8,
                children: [
                  RaftIcon(
                    privateChannel ? RaftGlyph.lock : RaftGlyph.hash,
                    size: 14,
                    color: t.strong,
                  ),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text:
                                channelName ??
                                raftText(context, '(unknown channel)'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: ' ${raftText(context, '— target channel')}',
                            style: TextStyle(
                              color: t.colors['foreground-muted'],
                            ),
                          ),
                        ],
                      ),
                      style: raftCssTextStyle(
                        family: t.headingFont,
                        step: RaftTextSteps.sm,
                        color: t.strong,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (draftHint != null)
              // `mb-3 border-l-2 pl-2 text-xs italic text-foreground-muted`.
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: t.colors['line-muted']!, width: 2),
                  ),
                ),
                child: Text(
                  draftHint!,
                  style: raftCssTextStyle(
                    family: t.headingFont,
                    step: RaftTextSteps.xs,
                    color: t.colors['foreground-muted'],
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RaftErrorBanner(error!, small: true),
              ),
            if (nothingToAdd)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: EdgeInsets.all(12.0 + (1)),
                decoration: BoxDecoration(
                  color: t.panel,
                  border: Border.all(
                    color: t.colors['line-muted']!,
                    width: t.border,
                  ),
                ),
                child: Text(
                  raftText(
                    context,
                    'Everyone the agent suggested is already a member of this channel. Nothing to add.',
                  ),
                  style: raftCssTextStyle(
                    family: t.headingFont,
                    step: RaftTextSteps.sm,
                    color: t.colors['foreground-muted'],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _MemberListShell(
                  key: const ValueKey('add-members-action-list'),
                  agents: agents,
                  humans: humans,
                  agentSection: agentSection ?? agents.isNotEmpty,
                  humanSection: humanSection ?? humans.isNotEmpty,
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                RaftRecipeButton(
                  label: 'Cancel',
                  variant: RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.sm,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  textStep: RaftTextSteps.sm,
                  disabled: submitting,
                  onPressed: onClose,
                ),
                const SizedBox(width: 8), // gap-2
                RaftRecipeButton(
                  key: const ValueKey('add-members-submit'),
                  label: submitting
                      ? 'Adding…'
                      : selectedCount == 1
                      ? 'Add 1 Member'
                      : raftFormat(context, 'Add {count} Members', {
                          'count': selectedCount,
                        }),
                  variant: RaftButtonRecipeVariant.accent,
                  size: RaftButtonRecipeSize.sm,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  textStep: RaftTextSteps.sm,
                  disabled: !canSubmit,
                  onPressed: canSubmit ? onSubmit : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ChannelMemberListShell (`max-h-72 overflow-y-auto border bg-layer-panel
/// shadow-raft-sm`, brutal `border-2 border-black bg-white shadow-brutal-sm`)
/// with ChannelMemberSectionHeader sections.
class _MemberListShell extends StatelessWidget {
  const _MemberListShell({
    super.key,
    required this.agents,
    required this.humans,
    required this.agentSection,
    required this.humanSection,
  });
  final List<RaftAddMemberRow> agents, humans;
  final bool agentSection, humanSection;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    Widget header(String text) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: t.colors['fill-muted'],
      child: Text(
        raftText(context, text),
        style: raftCssTextStyle(
          family: t.headingFont,
          step: RaftTextSteps.xs,
          weight: FontWeight.w700,
          color: t.colors['foreground-muted'],
          trackingEm: .1,
        ),
      ),
    );
    return RaftCard(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 288 - 4),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (agentSection) ...[
                header('Agents'),
                for (final row in agents) _Row(row: row),
              ],
              if (humanSection) ...[
                header('Humans'),
                for (final row in humans) _Row(row: row),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ChannelMemberRow: `group flex items-start gap-2 px-3 py-2 hover:bg-fill-muted`,
/// avatar `mt-1`, name `truncate text-sm` (humans bold, agents medium), muted
/// `text-xs` secondary line and the `size-6 mt-1` remove button (hover-revealed
/// on desktop, always shown on touch).
class _Row extends StatefulWidget {
  const _Row({required this.row});
  final RaftAddMemberRow row;
  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final row = widget.row;
    final reveal = hovered || RaftDensityScope.of(context) == RaftDensity.touch;
    return RaftHoverRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: Container(
        color: hovered ? t.colors['fill-muted'] : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 4), child: row.avatar),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: raftCssTextStyle(
                      family: t.headingFont,
                      step: RaftTextSteps.sm,
                      weight: row.human ? FontWeight.w700 : FontWeight.w500,
                      color: t.strong,
                    ),
                  ),
                  if (row.secondary != null && row.secondary!.isNotEmpty)
                    Text(
                      row.secondary!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: raftCssTextStyle(
                        family: t.headingFont,
                        step: RaftTextSteps.xs,
                        color: t.colors['foreground-muted'],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // `invisible` keeps the button's box so the row never shifts.
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Opacity(
                opacity: reveal ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !reveal,
                  child: _RemoveButton(
                    key: ValueKey('add-members-remove-${row.key}'),
                    label: row.removeLabel,
                    onPressed: row.onRemove,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `size-6 rounded-sm border border-line-muted bg-danger-soft text-danger-strong
/// hover:bg-danger/30` (brutal `rounded-none border-black bg-brutal-red/20`) with an
/// `X size=12`.
class _RemoveButton extends StatefulWidget {
  const _RemoveButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;
  @override
  State<_RemoveButton> createState() => _RemoveButtonState();
}

class _RemoveButtonState extends State<_RemoveButton> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final fill = hovered
        ? t.colors['danger']!.withValues(alpha: .3)
        : t.colors['danger-soft'];
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.label,
        child: RaftHoverRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => hovered = true),
          onExit: (_) => setState(() => hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                border: Border.all(color: t.colors['line-muted']!),
                borderRadius: BorderRadius.circular(2),
              ),
              child: RaftIcon(
                RaftGlyph.x,
                size: 12,
                color: t.colors['danger-strong'],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
