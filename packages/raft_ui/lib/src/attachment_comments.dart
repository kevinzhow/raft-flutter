// Web AttachmentCommentsPanel.tsx: header ("Comments · file"), the
// anchored comment cards, and the compact composer area with the pending
// location-anchor chip. The app owns loading, posting and authority; this
// file only renders. Classes are resolved from the TSX (brutal / elegant
// pairs are cited per element).
import 'package:flutter/material.dart';

import 'attachment_preview_shell.dart' show RaftCommentsSheetControls;
import 'dialog_card.dart' show RaftRecipeButton;
import 'icons.dart';
import 'system_inset.dart';
import 'recipes/button_variants.g.dart';
import 'design_primitives.dart';
import 'localization.dart';
import 'message_body.dart';
import 'theme.dart';

@immutable
class RaftAttachmentCommentView {
  const RaftAttachmentCommentView({
    required this.id,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.avatar,
    this.anchorLabel,
    this.quote,
    this.onJump,
  });
  final String id, senderName, content, timestamp;
  final Widget? avatar;

  /// `anchorLabel(anchor)`; null for unanchored comments (FileText + name).
  final String? anchorLabel;
  final String? quote;
  final VoidCallback? onJump;
}

/// `inline-flex items-center gap-1 border border-line-muted
/// bg-layer-canvas-muted px-1.5 py-0.5 text-[10px] font-display font-bold`;
/// brutal `border-black bg-brutal-stone/25 text-black`.
class RaftCommentAnchorChip extends StatelessWidget {
  const RaftCommentAnchorChip({
    super.key,
    required this.label,
    this.glyph = RaftGlyph.mapPin,
    this.onRemove,
    this.removeLabel,
  });
  final String label;
  final RaftGlyph glyph;
  final VoidCallback? onRemove;
  final String? removeLabel;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ink = t.strong;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: t.colors['layer-canvas-muted'],
        border: Border.all(color: t.colors['line-muted']!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RaftIcon(glyph, size: 9, color: ink),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: t.headingFont,
                fontSize: 10,
                height: 1.5,
                fontWeight: FontWeight.w700,
                color: ink,
                leadingDistribution: TextLeadingDistribution.even,
              ),
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            RaftDensityScope(
              // Source pending-anchor remove is the bare 9px X button.
              density: RaftDensity.desktop,
              child: RaftInteractive(
                onPressed: onRemove,
                semanticLabel:
                    removeLabel ?? raftText(context, 'Remove Anchor'),
                tooltip: removeLabel ?? raftText(context, 'Remove Anchor'),
                builder: (_, state) => RaftIcon(
                  RaftGlyph.x,
                  size: 9,
                  color: state.hovered || state.focusVisible
                      ? ink
                      : t.colors['foreground-muted'],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class RaftAttachmentCommentsPanel extends StatelessWidget {
  const RaftAttachmentCommentsPanel({
    super.key,
    required this.filename,
    required this.comments,
    required this.composer,
    this.loading = false,
    this.error,
    this.blockedMessage,
    this.sheet,
    this.collapsedBody = false,
  });
  final String filename;

  /// Mobile bottom sheet: the header row carries the expand / collapse
  /// chevron (Web `sheetControls`).
  final RaftCommentsSheetControls? sheet;

  /// Hides the list and composer while the sheet is collapsed to its header.
  final bool collapsedBody;

  /// Sorted cards; null while loading.
  final List<RaftAttachmentCommentView>? comments;

  /// The compact MessageInput (with the pending anchor in its accessory).
  final Widget composer;
  final bool loading;
  final String? error, blockedMessage;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rule = BorderSide(color: t.colors['line-muted']!, width: 2);
    final strong = t.strong;
    final muted = t.colors['foreground-muted']!;
    final list = comments;
    return DefaultTextHeightBehavior(
      textHeightBehavior: raftCssTextHeightBehavior,
      child: ColoredBox(
        // `bg-layer-panel theme-brutal:bg-white`.
        color: t.colors['layer-panel']!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // `border-b-2 px-3 py-2 gap-2`, title `text-xs font-bold truncate`.
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              // Collapsed, the header is the whole sheet: its rule would sit
              // exactly on the system bar line once the sheet extends under it.
              decoration: BoxDecoration(
                border: collapsedBody && raftBottomInset(context) > 0
                    ? null
                    : Border(bottom: rule),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      raftFormat(context, 'Comments · {filename}', {
                        'filename': filename,
                      }),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: t.headingFont,
                        fontSize: 12,
                        height: 16 / 12,
                        fontWeight: FontWeight.w700,
                        color: strong,
                      ),
                    ),
                  ),
                  if (sheet != null) ...[
                    const SizedBox(width: 8),
                    RaftRecipeButton(
                      key: const ValueKey('attachment-comments-sheet-toggle'),
                      variant: RaftButtonRecipeVariant.outline,
                      size: RaftButtonRecipeSize.sm,
                      padding: const EdgeInsets.all(2),
                      glyph: sheet!.expanded
                          ? RaftGlyph.chevronDown
                          : RaftGlyph.chevronUp,
                      glyphSize: 10,
                      tooltip: sheet!.expanded
                          ? 'Collapse Comments'
                          : 'Expand Comments',
                      onPressed: sheet!.onToggle,
                    ),
                  ],
                ],
              ),
            ),
            if (!collapsedBody)
              Expanded(
                child: list == null || loading
                    ? Center(
                        child: error != null
                            ? Text(error!)
                            : Semantics(
                                label: raftText(context, 'Loading'),
                                child: const RaftSpinner(),
                              ),
                      )
                    : list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: Text(
                          raftFormat(
                            context,
                            'Comments here are pinned to {filename}. For general discussion, reply in the thread.',
                            {'filename': filename},
                          ),
                          style: TextStyle(
                            fontFamily: t.headingFont,
                            fontSize: 11,
                            height: 1.625,
                            color: muted,
                          ),
                        ),
                      )
                    : ListView(
                        // `px-3 py-2`, cards `gap-3`.
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        children: [
                          for (var i = 0; i < list.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            _CommentCard(comment: list[i], filename: filename),
                          ],
                        ],
                      ),
              ),
            // `border-t-2 p-2`.
            if (!collapsedBody)
              Container(
                // The panel background reaches the screen bottom; the composer
                // clears the system bar (0 while the keyboard is up).
                padding: const EdgeInsets.all(8)
                    .copyWith(bottom: 8 + raftBottomInset(context)),
                decoration: BoxDecoration(border: Border(top: rule)),
                child: blockedMessage != null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Text(
                          blockedMessage!,
                          style: TextStyle(
                            fontFamily: t.headingFont,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: muted,
                          ),
                        ),
                      )
                    : composer,
              ),
          ],
        ),
      ),
    );
  }
}

/// `rounded border border-line-muted bg-layer-panel px-2.5 py-2`; brutal
/// `border-black/15 bg-white`. Header `flex items-center gap-1.5 pr-6`.
class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment, required this.filename});
  final RaftAttachmentCommentView comment;
  final String filename;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final strong = t.strong;
    final c = comment;
    Widget card({bool hovered = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: hovered
            ? t.product.brutalStone.withValues(alpha: .1)
            : t.colors['layer-panel'],
        border: Border.all(color: t.colors['line-muted']!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Row(
              children: [
                SizedBox.square(dimension: 20, child: c.avatar),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    c.senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: t.headingFont,
                      fontSize: 11,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                      color: strong,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  c.timestamp,
                  style: TextStyle(
                    fontFamily: t.headingFont,
                    fontSize: 10,
                    height: 1.5,
                    color: t.colors['foreground-muted'],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          RaftCommentAnchorChip(
            label: c.anchorLabel ?? filename,
            glyph: c.anchorLabel == null
                ? RaftGlyph.fileText
                : RaftGlyph.mapPin,
          ),
          if (c.quote != null && c.quote!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(width: 2, color: t.colors['line-muted']!),
                ),
              ),
              child: Text(
                c.quote!,
                style: TextStyle(
                  fontFamily: t.headingFont,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: t.colors['foreground-muted'],
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          // `text-xs leading-relaxed text-foreground-muted`, brutal
          // `text-black/80`, MarkdownContent density compact.
          RaftMessageBody(
            content: c.content,
            // Source index.css disables selection inside its whole-card button.
            enableProseSelection: c.onJump == null,
            fontSize: 12,
            lineHeight: 19.5,
            foregroundColor: t.colors['foreground-muted'],
          ),
        ],
      ),
    );
    if (c.onJump == null) return card();
    return RaftInteractive(
      onPressed: c.onJump,
      tooltip: c.quote?.isNotEmpty == true
          ? c.quote
          : raftText(context, 'Jump to Location'),
      builder: (_, state) => card(hovered: state.hovered),
    );
  }
}

/// Full-height host for the comments panel opened from an attachment
/// preview on touch layouts (Material ancestor for the composer field).
///
/// The page background reaches the screen bottom; the composer inside pads
/// itself by the system inset.
class RaftAttachmentCommentsPage extends StatelessWidget {
  const RaftAttachmentCommentsPage({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final color = RaftTokens.of(context).colors['layer-panel']!;
    return RaftNavigationBarStyle(
      background: color,
      child: Material(
        color: color,
        child: SafeArea(bottom: false, child: child),
      ),
    );
  }
}
