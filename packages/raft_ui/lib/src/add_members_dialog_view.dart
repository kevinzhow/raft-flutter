import 'overlays/dialog.dart' show RaftDialog;
// Presentation of the Web AddMembersDialog
// (packages/web/src/components/channel/AddMembersDialog.tsx), opened from a
// `channel:add_member` action card: DialogCard with the target-channel row,
// the agent's quoted reason, a warning banner, the framed ChannelMemberList
// (Agents / Humans sections with one row per candidate and a remove-from-list
// button) and Cancel / "Add N members". The adapter owns candidates, selection
// and the batch add.
import 'card.dart' show RaftCard;
import 'hover_region.dart';

import 'package:flutter/material.dart';

import 'design_primitives.dart' show RaftDensity, RaftDensityScope;
import 'dialog_card.dart';
import 'error_presentation.dart' show RaftErrorBanner;
import 'form_presentation.dart' show RaftFormFrame;
import 'icons.dart';
import 'localization.dart';
import 'raft/button.dart' show RaftButton, RaftButtonSize, RaftButtonVariant;
import 'raft/icon_tile.dart' show RaftIconTile, RaftIconTileSize;
import 'raft/ui_tokens.dart';
import 'stacked_actions.dart' show RaftActionRow;
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;

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
    final inSheet = RaftFormFrame.sheetOf(context);
    final submitButton = RaftButton(
      key: const ValueKey('add-members-submit'),
      label: submitting
          ? 'Adding…'
          : selectedCount == 1
          ? 'Add 1 member'
          : raftFormat(context, 'Add {count} members', {
              'count': selectedCount,
            }),
      uiVariant: RaftButtonVariant.primary,
      uiSize: inSheet ? RaftButtonSize.md : RaftButtonSize.lg,
      disabled: !canSubmit,
      onPressed: canSubmit ? onSubmit : null,
    );
    return RaftModalBackdrop(
      child: RaftDialog.card(
        key: const ValueKey('add-members-dialog'),
        title: 'Add members',
        onClose: onClose,
        footerGap: 0,
        sheetCommit: submitButton,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // `mb-3 flex min-w-0 items-center gap-2 text-callout text-foreground`.
            Padding(
              key: const ValueKey('add-members-target'),
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  RaftIconTile(
                    size: RaftIconTileSize.sm,
                    glyph: privateChannel ? RaftGlyph.lock : RaftGlyph.hash,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      channelName ?? raftText(context, '(unknown channel)'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.scale(
                        RaftTypeScale.callout,
                        weight: FontWeight.w700,
                        color: t.ui.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    raftText(context, '— target channel'),
                    style: t.scale(
                      RaftTypeScale.callout,
                      color: t.ui.foregroundMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (draftHint != null)
              // `mb-3 border-l-2 border-line-seam pl-2.5 text-callout text-foreground-muted`.
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: t.colors['line-seam']!, width: 2),
                  ),
                ),
                child: Text(
                  draftHint!,
                  style: t.scale(
                    RaftTypeScale.callout,
                    color: t.ui.foregroundMuted,
                  ),
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RaftErrorBanner(error!, small: true),
              ),
            if (nothingToAdd)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: RaftCard(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    raftText(
                      context,
                      'Everyone the agent suggested is already a member of this channel. Nothing to add.',
                    ),
                    style: t.scale(
                      RaftTypeScale.subhead,
                      weight: FontWeight.w400,
                      color: t.ui.foregroundHint,
                    ),
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
          ],
        ),
        footer: inSheet
            ? null
            : RaftActionRow(
                gap: 8,
                children: [
                  RaftButton(
                    label: 'Cancel',
                    uiVariant: RaftButtonVariant.ghost,
                    uiSize: RaftButtonSize.lg,
                    disabled: submitting,
                    onPressed: onClose,
                  ),
                  submitButton,
                ],
              ),
      ),
    );
  }
}

/// ChannelMemberListShell (`max-h-72 overflow-y-auto border bg-layer-panel
/// shadow-raft-sm`) with ChannelMemberSectionHeader sections.
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
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: RaftDialogSectionEyebrow(raftText(context, text)),
    );
    return RaftCard(
      clip: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 288),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (agentSection) ...[
                header('Agents'),
                for (var i = 0; i < agents.length; i++)
                  _Row(row: agents[i], topRule: i > 0),
              ],
              if (humanSection) ...[
                header('Humans'),
                for (var i = 0; i < humans.length; i++)
                  _Row(row: humans[i], topRule: i > 0),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ChannelMemberRow: `group relative flex min-h-16 items-center gap-3 px-4
/// py-2.5 hover:bg-fill-subtle` with 1px hairline at left 63px between rows.
class _Row extends StatefulWidget {
  const _Row({required this.row, this.topRule = false});
  final RaftAddMemberRow row;
  final bool topRule;
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
      child: Stack(
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 64),
            color: hovered ? t.colors['fill-subtle'] : null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                row.avatar,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.scale(
                          RaftTypeScale.subhead,
                          weight: FontWeight.w600,
                          color: t.ui.foreground,
                        ),
                      ),
                      if (row.secondary != null && row.secondary!.isNotEmpty)
                        Text(
                          row.secondary!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.scale(
                            RaftTypeScale.caption,
                            color: t.ui.foregroundHint,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Opacity(
                  opacity: reveal ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !reveal,
                    child: RaftButton(
                      key: ValueKey('add-members-remove-${row.key}'),
                      glyph: RaftGlyph.x,
                      uiVariant: RaftButtonVariant.ghost,
                      uiSize: RaftButtonSize.iconMd,
                      tooltip: row.removeLabel,
                      semanticLabel: row.removeLabel,
                      onPressed: row.onRemove,
                    ),
                  ),
                ),
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
                child: ColoredBox(color: t.colors['line-hairline']!),
              ),
            ),
        ],
      ),
    );
  }
}
